<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class OsonSmsService
{
    /**
     * Нормализация телефона Таджикистана к формату 992XXXXXXXXX.
     */
    public static function normalizePhone(?string $phone): ?string
    {
        if ($phone === null) {
            return null;
        }

        $digits = preg_replace('/\D+/', '', $phone);
        if ($digits === null || $digits === '') {
            return null;
        }

        // +992 / 992 / 0XXXXXXXXX / 9XXXXXXXX
        if (Str::startsWith($digits, '992') && strlen($digits) === 12) {
            return $digits;
        }

        if (Str::startsWith($digits, '0') && strlen($digits) === 10) {
            return '992' . substr($digits, 1);
        }

        // Локальный номер Таджикистана — 9 цифр (90..., 100... и т.д.)
        if (strlen($digits) === 9) {
            return '992' . $digits;
        }

        return null;
    }

    public static function formatForDisplay(string $phone992): string
    {
        // 992901234567 → +992 90 123 45 67
        if (strlen($phone992) !== 12) {
            return $phone992;
        }

        return sprintf(
            '+%s %s %s %s %s',
            substr($phone992, 0, 3),
            substr($phone992, 3, 2),
            substr($phone992, 5, 3),
            substr($phone992, 8, 2),
            substr($phone992, 10, 2)
        );
    }

    /**
     * Отправка SMS через OsonSMS API (GET + Bearer).
     *
     * @return array{ok: bool, status?: int, body?: mixed, error?: string, txn_id?: string, msg_id?: mixed}
     */
    public function send(string $phone992, string $message): array
    {
        $login = config('osonsms.login');
        $token = config('osonsms.token');
        $sender = config('osonsms.sender');
        $server = config('osonsms.server');

        if (!$login || !$token || !$sender || !$server) {
            return [
                'ok' => false,
                'error' => 'SMS provider is not configured',
            ];
        }

        $txnId = (string) Str::uuid();

        try {
            $response = Http::withToken($token)
                ->timeout(20)
                ->acceptJson()
                ->get($server, [
                    'from' => $sender,
                    'phone_number' => $phone992,
                    'msg' => $message,
                    'login' => $login,
                    'txn_id' => $txnId,
                ]);

            $status = $response->status();
            $body = $response->json() ?? $response->body();

            Log::info('OsonSMS send', [
                'phone' => $phone992,
                'txn_id' => $txnId,
                'http_status' => $status,
                'body' => $body,
            ]);

            if ($status === 201) {
                return [
                    'ok' => true,
                    'status' => $status,
                    'body' => $body,
                    'txn_id' => $txnId,
                    'msg_id' => is_array($body) ? ($body['msg_id'] ?? null) : null,
                ];
            }

            $errorMsg = 'SMS send failed';
            if (is_array($body)) {
                $errorMsg = $body['error']['msg']
                    ?? $body['msg']
                    ?? $body['message']
                    ?? $errorMsg;
            }

            return [
                'ok' => false,
                'status' => $status,
                'body' => $body,
                'error' => $errorMsg,
                'txn_id' => $txnId,
            ];
        } catch (\Throwable $e) {
            Log::error('OsonSMS exception', [
                'phone' => $phone992,
                'error' => $e->getMessage(),
            ]);

            return [
                'ok' => false,
                'error' => $e->getMessage(),
                'txn_id' => $txnId,
            ];
        }
    }

    public function sendOtp(string $phone992, string $code): array
    {
        $msg = "SSBOSS: код подтверждения {$code}. Никому не сообщайте.";
        return $this->send($phone992, $msg);
    }

    public function sendGeneratedPassword(string $phone992, string $plainPassword): array
    {
        $msg = "SSBOSS: ваш пароль для входа на сайте: {$plainPassword}";
        return $this->send($phone992, $msg);
    }
}
