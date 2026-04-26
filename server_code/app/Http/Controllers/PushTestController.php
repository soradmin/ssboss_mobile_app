<?php
namespace App\Http\Controllers;

use App\Models\Helper\Response;
use App\Models\Helper\Validation;
use App\Models\User;
use Illuminate\Http\Request;

class PushTestController extends Controller
{
    /**
     * Отправляет тестовое push-уведомление пользователю по ID.
     * POST /api/v1/admin/push-test
     */
    public function sendTestPush(Request $request)
    {
        try {
            $request->validate([
                'user_id' => 'required|integer|exists:users,id',
                'title' => 'nullable|string|max:100',
                'body' => 'nullable|string|max:255',
            ]);

            $user = User::find($request->user_id);
            
            if (!$user) {
                return response()->json(Validation::error($request->token ?? '', 'User not found'));
            }

            if (!$user->fcm_token) {
                \Log::warning("PushTest: No FCM token for user ID: {$request->user_id}");
                return response()->json(Validation::error($request->token ?? '', 'User does not have FCM token registered'));
            }

            // Используем сервис для отправки
            $pushService = app(\App\Services\PushNotificationService::class);
            
            $title = $request->title ?: '🔔 Тестовое уведомление';
            $body = $request->body ?: 'Если видите это — push работает!';
            
            $success = $pushService->sendToUser(
                $user->fcm_token,
                $title,
                $body,
                [
                    'type' => 'test',
                    'sent_at' => now()->toIso8601String(),
                ]
            );

            if ($success) {
                \Log::info("✅ Push sent to user {$user->id} (TEST)", [
                    'email' => $user->email,
                    'title' => $title
                ]);
                return response()->json(new Response($request->token ?? '', [
                    'success' => true,
                    'message' => 'Push sent!',
                    'to' => $user->email,
                    'user_id' => $user->id
                ]));
            } else {
                return response()->json(Validation::error($request->token ?? '', 'Failed to send push notification. Check server logs.'));
            }
            
        } catch (\Exception $e) {
            \Log::error("❌ FCM send failed (TEST)", [
                'user_id' => $request->user_id ?? null,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
            return response()->json(Validation::error($request->token ?? '', $e->getMessage()));
        }
    }
}