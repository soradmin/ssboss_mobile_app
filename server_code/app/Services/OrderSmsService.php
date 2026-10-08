<?php

namespace App\Services;

use App\Models\Order;
use App\Models\OrderedProduct;
use App\Models\Setting;
use App\Models\Store;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Log;

/**
 * SMS-уведомления по заказам через OsonSMS:
 * - покупателю и продавцу при оформлении;
 * - операторам маркетплейса (настройки + доп. номера);
 * - покупателю при смене статуса в админке.
 */
class OrderSmsService
{
    /**
     * Доп. номера операторов SSBOSS Marketplace (всегда при новом заказе).
     * Формат: 992XXXXXXXXX без «+».
     */
    private const EXTRA_OPS_PHONES = [
        '992884189999',
    ];

    public function __construct(private readonly OsonSmsService $sms)
    {
    }

    /**
     * После успешного оформления заказа.
     */
    public function notifyOrderPlaced(Order $order): void
    {
        try {
            $order->loadMissing(['user', 'address', 'guest_user']);

            $lines = OrderedProduct::with(['product_with_admin.admin'])
                ->where('order_id', $order->id)
                ->get();

            if ($lines->isEmpty()) {
                Log::warning('OrderSmsService.notifyOrderPlaced: нет позиций', [
                    'order_id' => $order->id,
                ]);
                return;
            }

            // Не слать повторно, если уже отправили (action + sendOrderEmail).
            $lockKey = 'order_sms_placed_' . $order->id;
            if (!Cache::add($lockKey, 1, now()->addDay())) {
                Log::info('OrderSmsService.notifyOrderPlaced: уже отправлено', [
                    'order_id' => $order->id,
                ]);
                return;
            }

            $currency = $this->currencyLabel();
            $total = $this->formatAmount((float) ($order->total_amount ?? $this->sumLines($lines)));
            $tracking = (string) $order->order;
            $customerName = $this->customerName($order);
            $customerPhoneDisplay = $this->customerPhoneDisplay($order);
            $buyerPart = $this->buyerPart($customerName, $customerPhoneDisplay);

            // Покупатель
            $buyerPhone = $this->resolveCustomerPhone($order);
            if ($buyerPhone) {
                $msg = "SSBOSS: заказ #{$tracking} на {$total} {$currency} принят. "
                    . "Клиент: {$buyerPart}. Статус: ожидает обработки.";
                $this->safeSend($buyerPhone, $this->clip($msg, 500), 'order_placed_customer', $order->id);
            } else {
                Log::warning('OrderSmsService: нет телефона покупателя', [
                    'order_id' => $order->id,
                ]);
            }

            // Операторы маркетплейса (телефон организации + доп. номера)
            $opsPhones = $this->opsPhones();
            $opsMsg = "SSBOSS: новый заказ #{$tracking}. Клиент: {$buyerPart}. "
                . "Сумма: {$total} {$currency}. Статус: ожидает обработки.";
            foreach ($opsPhones as $opsPhone) {
                $this->safeSend($opsPhone, $this->clip($opsMsg, 500), 'order_placed_ops', $order->id);
            }

            // Продавцы (по admin_id товаров)
            $byAdmin = [];
            foreach ($lines as $line) {
                $adminId = (int) ($line->product_with_admin->admin_id ?? 0);
                if ($adminId <= 0) {
                    continue;
                }
                $byAdmin[$adminId][] = $line;
            }

            foreach ($byAdmin as $adminId => $adminLines) {
                $sellerPhone = $this->resolveSellerPhone((int) $adminId);
                if (!$sellerPhone) {
                    Log::warning('OrderSmsService: нет телефона продавца (заполните WhatsApp магазина)', [
                        'order_id' => $order->id,
                        'admin_id' => $adminId,
                    ]);
                    continue;
                }

                // Не дублировать SMS, если номер продавца уже в списке операторов
                if (in_array($sellerPhone, $opsPhones, true)) {
                    continue;
                }

                $itemsText = $this->formatItems($adminLines);
                $sellerTotal = $this->formatAmount($this->sumLines(collect($adminLines)));

                $msg = "SSBOSS: новый заказ #{$tracking}. Клиент: {$buyerPart}. "
                    . "Товары: {$itemsText}. Сумма: {$sellerTotal} {$currency}.";
                $this->safeSend($sellerPhone, $this->clip($msg, 500), 'order_placed_seller', $order->id);
            }
        } catch (\Throwable $e) {
            Log::error('OrderSmsService.notifyOrderPlaced failed', [
                'order_id' => $order->id ?? null,
                'error' => $e->getMessage(),
            ]);
        }
    }

    /**
     * При смене статуса заказа в админке — SMS покупателю.
     */
    public function notifyOrderStatusChanged(Order $order, int $statusId): void
    {
        try {
            $order->loadMissing(['user', 'address', 'guest_user']);

            $phone = $this->resolveCustomerPhone($order);
            if (!$phone) {
                Log::warning('OrderSmsService.notifyOrderStatusChanged: нет телефона покупателя', [
                    'order_id' => $order->id,
                ]);
                return;
            }

            $statusText = $this->statusLabel($statusId);
            $tracking = (string) $order->order;
            $buyerPart = $this->buyerPart(
                $this->customerName($order),
                $this->customerPhoneDisplay($order)
            );
            $msg = "SSBOSS: заказ #{$tracking} — статус: {$statusText}. Клиент: {$buyerPart}.";

            $this->safeSend($phone, $this->clip($msg, 500), 'order_status_customer', $order->id);
        } catch (\Throwable $e) {
            Log::error('OrderSmsService.notifyOrderStatusChanged failed', [
                'order_id' => $order->id ?? null,
                'error' => $e->getMessage(),
            ]);
        }
    }

    public function resolveCustomerPhone(Order $order): ?string
    {
        $candidates = [
            $order->user->phone ?? null,
            $order->address->phone ?? null,
        ];

        foreach ($candidates as $raw) {
            $normalized = OsonSmsService::normalizePhone($raw);
            if ($normalized) {
                return $normalized;
            }
        }

        return null;
    }

    /**
     * Телефон продавца: WhatsApp-номер магазина (stores.whatsapp_number).
     */
    public function resolveSellerPhone(int $adminId): ?string
    {
        $storePhone = Store::where('admin_id', $adminId)->value('whatsapp_number');
        $normalized = OsonSmsService::normalizePhone($storePhone ? (string) $storePhone : null);
        if ($normalized) {
            return $normalized;
        }

        // Запасной вариант — телефон сайта из настроек (для товаров супер-админа).
        $sitePhone = Setting::query()->value('phone');
        return OsonSmsService::normalizePhone($sitePhone ? (string) $sitePhone : null);
    }

    /**
     * Номера операторов: телефон организации + EXTRA_OPS_PHONES (уникальные).
     *
     * @return list<string>
     */
    public function opsPhones(): array
    {
        $phones = [];

        $sitePhone = Setting::query()->value('phone');
        $normalizedSite = OsonSmsService::normalizePhone($sitePhone ? (string) $sitePhone : null);
        if ($normalizedSite) {
            $phones[] = $normalizedSite;
        }

        foreach (self::EXTRA_OPS_PHONES as $raw) {
            $normalized = OsonSmsService::normalizePhone($raw);
            if ($normalized && !in_array($normalized, $phones, true)) {
                $phones[] = $normalized;
            }
        }

        return $phones;
    }

    public function statusLabel(int $statusId): string
    {
        $map = [
            (int) Config::get('constants.orderStatus.PENDING') => 'Ожидает обработки',
            (int) Config::get('constants.orderStatus.CONFIRMED') => 'Подтверждён',
            (int) Config::get('constants.orderStatus.PICKED_UP') => 'Собран',
            (int) Config::get('constants.orderStatus.ON_THE_WAY') => 'В пути',
            (int) Config::get('constants.orderStatus.DELIVERED') => 'Доставлен',
        ];

        return $map[$statusId] ?? 'Обновлён';
    }

    private function buyerPart(string $name, string $phoneDisplay): string
    {
        $part = trim($name . ($phoneDisplay !== '' ? ", {$phoneDisplay}" : ''));
        return $part !== '' ? $part : 'клиент';
    }

    private function customerName(Order $order): string
    {
        $name = trim((string) ($order->user->name ?? ''));
        if ($name !== '') {
            return $name;
        }

        $name = trim((string) ($order->address->name ?? ''));
        if ($name !== '') {
            return $name;
        }

        return trim((string) ($order->guest_user->name ?? ''));
    }

    private function customerPhoneDisplay(Order $order): string
    {
        $phone = $this->resolveCustomerPhone($order);
        return $phone ? OsonSmsService::formatForDisplay($phone) : '';
    }

    private function formatItems($lines): string
    {
        $parts = [];
        foreach ($lines as $line) {
            $title = trim((string) ($line->product_with_admin->title ?? 'Товар'));
            $title = mb_substr($title, 0, 40);
            $qty = (int) ($line->quantity ?? 1);
            $parts[] = "{$title} x{$qty}";
        }

        return implode('; ', $parts);
    }

    private function sumLines($lines): float
    {
        $sum = 0.0;
        foreach ($lines as $line) {
            $qty = max(1, (int) ($line->quantity ?? 1));
            $sum += ((float) $line->selling * $qty)
                + (float) $line->shipping_price
                + ((float) $line->tax_price * $qty);
        }
        return $sum;
    }

    private function formatAmount(float $amount): string
    {
        if (abs($amount - round($amount)) < 0.001) {
            return (string) (int) round($amount);
        }
        return number_format($amount, 2, '.', '');
    }

    private function currencyLabel(): string
    {
        $icon = Setting::query()->value('currency_icon');
        if (is_string($icon) && trim($icon) !== '') {
            return trim($icon);
        }
        return 'с.';
    }

    private function clip(string $text, int $max): string
    {
        if (mb_strlen($text) <= $max) {
            return $text;
        }
        return mb_substr($text, 0, $max - 1) . '…';
    }

    private function safeSend(string $phone992, string $message, string $kind, int $orderId): void
    {
        $result = $this->sms->send($phone992, $message);
        if (!($result['ok'] ?? false)) {
            Log::warning('OrderSmsService SMS failed', [
                'kind' => $kind,
                'order_id' => $orderId,
                'phone' => $phone992,
                'error' => $result['error'] ?? null,
            ]);
            return;
        }

        Log::info('OrderSmsService SMS sent', [
            'kind' => $kind,
            'order_id' => $orderId,
            'phone' => $phone992,
            'msg_id' => $result['msg_id'] ?? null,
        ]);
    }
}
