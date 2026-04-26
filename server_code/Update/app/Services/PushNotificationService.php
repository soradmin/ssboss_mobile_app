<?php

namespace App\Services;

use App\Models\User;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Config;

/**
 * Сервис для отправки push-уведомлений через Firebase Cloud Messaging
 */
class PushNotificationService
{
    private $messaging;

    public function __construct()
    {
        try {
            $factory = (new Factory)
                ->withServiceAccount(env('FIREBASE_CREDENTIALS', base_path('service-account.json')))
                ->withProjectId(env('FIREBASE_PROJECT_ID', 'ssboss-940a1'));

            $this->messaging = $factory->createMessaging();
        } catch (\Exception $e) {
            Log::error('PushNotificationService: Ошибка инициализации Firebase', [
                'error' => $e->getMessage()
            ]);
            $this->messaging = null;
        }
    }

    /**
     * Отправляет push-уведомление одному пользователю
     *
     * @param string $fcmToken FCM токен пользователя
     * @param string $title Заголовок уведомления
     * @param string $body Текст уведомления
     * @param array $data Дополнительные данные (order_id, type, etc.)
     * @return bool Успешность отправки
     */
    public function sendToUser(string $fcmToken, string $title, string $body, array $data = []): bool
    {
        if (!$this->messaging || empty($fcmToken)) {
            Log::warning('PushNotificationService: Пропущена отправка - нет messaging или токена', [
                'has_messaging' => !is_null($this->messaging),
                'has_token' => !empty($fcmToken)
            ]);
            return false;
        }

        try {
            $messageData = array_merge([
                'click_action' => 'FLUTTER_NOTIFICATION_CLICK'
            ], $data);

            // Преобразуем все значения в строки (требование FCM)
            $messageData = array_map(function($value) {
                return is_array($value) ? json_encode($value) : (string)$value;
            }, $messageData);

            $message = CloudMessage::fromArray([
                'token' => $fcmToken,
                'notification' => [
                    'title' => $title,
                    'body' => $body,
                ],
                'data' => $messageData,
            ]);

            $this->messaging->send($message);
            
            Log::info('PushNotificationService: Уведомление отправлено', [
                'title' => $title,
                'token_preview' => substr($fcmToken, 0, 20) . '...'
            ]);

            return true;
        } catch (\Exception $e) {
            $errorMessage = $e->getMessage();
            
            // Если токен недействителен, удаляем его из базы данных
            if (strpos($errorMessage, 'not a valid FCM registration token') !== false || 
                strpos($errorMessage, 'InvalidRegistration') !== false ||
                strpos($errorMessage, 'MismatchSenderId') !== false ||
                strpos($errorMessage, 'Requested entity was not found') !== false ||
                strpos($errorMessage, 'NOT_FOUND') !== false) {
                
                Log::warning('PushNotificationService: Недействительный FCM токен, удаляем из базы', [
                    'error' => $errorMessage,
                    'token_preview' => substr($fcmToken, 0, 20) . '...'
                ]);
                
                // Найти пользователя с этим токеном и удалить токен
                try {
                    User::where('fcm_token', $fcmToken)->update(['fcm_token' => null]);
                    Log::info('PushNotificationService: Недействительный токен удален из базы данных');
                } catch (\Exception $dbEx) {
                    Log::error('PushNotificationService: Ошибка при удалении недействительного токена', [
                        'error' => $dbEx->getMessage()
                    ]);
                }
            }
            
            Log::error('PushNotificationService: Ошибка отправки уведомления', [
                'error' => $errorMessage,
                'title' => $title,
                'token_preview' => substr($fcmToken, 0, 20) . '...'
            ]);
            return false;
        }
    }

    /**
     * Отправляет push-уведомление о изменении статуса заказа
     *
     * @param \App\Models\Order $order Заказ
     * @param int $newStatusId ID нового статуса
     * @return bool Успешность отправки
     */
    public function sendOrderStatusUpdate($order, int $newStatusId): bool
    {
        $user = $order->user;

        if (!$user || !$user->fcm_token) {
            Log::warning('PushNotificationService: Пропущена отправка статуса заказа - нет пользователя или токена', [
                'order_id' => $order->id,
                'user_id' => $user->id ?? null,
                'has_token' => $user && $user->fcm_token ? true : false
            ]);
            return false;
        }

        $statusText = $this->getStatusText($newStatusId);
        $title = "Статус заказа изменён";
        $body = "Ваш заказ #{$order->order} теперь: {$statusText}";

        $data = [
            'order_id' => (string)$order->id,
            'order_number' => $order->order,
            'status' => (string)$newStatusId,
            'type' => 'order_status',
        ];

        return $this->sendToUser($user->fcm_token, $title, $body, $data);
    }

    /**
     * Отправляет push-уведомление об акции/промо всем пользователям с FCM токенами
     *
     * @param string $title Заголовок уведомления
     * @param string $body Текст уведомления
     * @param array $data Дополнительные данные (promotion_id, etc.)
     * @param int|null $limit Лимит пользователей (null = все)
     * @return array Статистика отправки ['sent' => int, 'failed' => int, 'total' => int]
     */
    public function sendToAllUsers(string $title, string $body, array $data = [], ?int $limit = null): array
    {
        $query = User::whereNotNull('fcm_token')
            ->where('fcm_token', '!=', '');

        if ($limit) {
            $query->limit($limit);
        }

        $users = $query->get(['id', 'fcm_token', 'email']);
        $total = $users->count();
        $sent = 0;
        $failed = 0;

        Log::info('PushNotificationService: Начало массовой рассылки', [
            'total_users' => $total,
            'title' => $title
        ]);

        foreach ($users as $user) {
            if ($this->sendToUser($user->fcm_token, $title, $body, $data)) {
                $sent++;
            } else {
                $failed++;
            }

            // Небольшая задержка, чтобы не перегружать Firebase
            if ($sent % 100 === 0) {
                usleep(100000); // 0.1 секунды каждые 100 уведомлений
            }
        }

        Log::info('PushNotificationService: Массовая рассылка завершена', [
            'total' => $total,
            'sent' => $sent,
            'failed' => $failed
        ]);

        return [
            'sent' => $sent,
            'failed' => $failed,
            'total' => $total
        ];
    }

    /**
     * Отправляет push-уведомление об акции/промо
     *
     * @param string $title Заголовок уведомления
     * @param string $body Текст уведомления (может содержать HTML)
     * @param int|null $promotionId ID акции (опционально)
     * @return array Статистика отправки
     */
    public function sendPromotionNotification(string $title, string $body, ?int $promotionId = null): array
    {
        // Извлекаем чистый текст из HTML для отображения в уведомлении
        $plainBody = $this->extractTextFromHtml($body);
        
        // Сохраняем полный HTML в data для отображения при нажатии
        $data = [
            'type' => 'promotion',
            'html_body' => base64_encode($body), // Кодируем HTML в base64 для безопасной передачи
        ];

        if ($promotionId) {
            $data['promotion_id'] = (string)$promotionId;
        }

        return $this->sendToAllUsers($title, $plainBody, $data);
    }

    /**
     * Извлекает текст из HTML, удаляя теги
     *
     * @param string $html HTML строка
     * @return string Чистый текст
     */
    private function extractTextFromHtml(string $html): string
    {
        // Удаляем HTML теги
        $text = strip_tags($html);
        
        // Декодируем HTML entities
        $text = html_entity_decode($text, ENT_QUOTES | ENT_HTML5, 'UTF-8');
        
        // Удаляем лишние пробелы и переносы строк
        $text = preg_replace('/\s+/', ' ', $text);
        $text = trim($text);
        
        // Ограничиваем длину для уведомления (максимум 200 символов)
        if (mb_strlen($text) > 200) {
            $text = mb_substr($text, 0, 197) . '...';
        }
        
        return $text;
    }

    /**
     * Возвращает текст статуса по ID
     *
     * @param int $statusId ID статуса
     * @return string Текст статуса
     */
    private function getStatusText(int $statusId): string
    {
        $map = [
            Config::get('constants.orderStatus.PENDING') => 'Ожидает обработки',
            Config::get('constants.orderStatus.CONFIRMED') => 'Подтверждён',
            Config::get('constants.orderStatus.SHIPPED') => 'Отправлен',
            Config::get('constants.orderStatus.DELIVERED') => 'Доставлен',
            Config::get('constants.orderStatus.CANCELLED') => 'Отменён',
            Config::get('constants.orderStatus.REFUNDED') => 'Возвращён',
            Config::get('constants.orderStatus.FAILED') => 'Неудачный',
        ];

        return $map[$statusId] ?? 'Обновлён';
    }
}

