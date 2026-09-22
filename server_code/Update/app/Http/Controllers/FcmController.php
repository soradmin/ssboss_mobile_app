<?php
namespace App\Http\Controllers;

use App\Models\Helper\Response;
use App\Models\Helper\Validation;
use App\Models\UserFcmToken;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class FcmController extends Controller
{
    public function registerToken(Request $request)
    {
        try {
            $request->validate([
                'fcm_token' => 'required|string',
                'device_type' => 'nullable|string|in:android,ios',
            ]);

            $user = $request->user('user');
            
            if (!$user) {
                \Log::error("FCM token registration: User not found despite auth middleware");
                return response()->json(Validation::unauthorized());
            }

            $token = trim((string) $request->fcm_token);
            $deviceType = $request->device_type ?: null;

            // Мульти-устройство: Android и iPhone хранятся отдельно.
            UserFcmToken::updateOrCreate(
                ['fcm_token' => $token],
                [
                    'user_id' => $user->id,
                    'device_type' => $deviceType,
                ]
            );

            // Legacy-колонка: последний токен (для старого кода / совместимости).
            $user->fcm_token = $token;
            $user->save();

            \Log::info("FCM token updated for user {$user->id}", [
                'device_type' => $deviceType ?? 'unknown',
                'email' => $user->email,
                'tokens_count' => $user->fcmTokens()->count(),
            ]);

            return response()->json(new Response($request->token ?? '', [
                'message' => 'FCM token registered',
                'user_id' => $user->id
            ]));

        } catch (\Exception $e) {
            \Log::error("FCM token registration failed", [
                'error' => $e->getMessage()
            ]);
            return response()->json(Validation::error($request->token ?? '', $e->getMessage()));
        }
    }

    public function removeToken(Request $request)
    {
        try {
            $user = $request->user('user') ?: Auth::guard('user')->user();
            
            if ($user) {
                $token = trim((string) $request->input('fcm_token', ''));
                if ($token !== '') {
                    UserFcmToken::where('user_id', $user->id)
                        ->where('fcm_token', $token)
                        ->delete();
                    if ($user->fcm_token === $token) {
                        $user->fcm_token = UserFcmToken::where('user_id', $user->id)->value('fcm_token');
                        $user->save();
                    }
                } else {
                    UserFcmToken::where('user_id', $user->id)->delete();
                    $user->fcm_token = null;
                    $user->save();
                }

                \Log::info("FCM token removed for user {$user->id}");

                return response()->json(new Response($request->token ?? '', [
                    'message' => 'FCM token removed'
                ]));
            }

            return response()->json(Validation::unauthorized());

        } catch (\Exception $e) {
            \Log::error("FCM token removal failed", [
                'error' => $e->getMessage()
            ]);
            return response()->json(Validation::error($request->token ?? '', $e->getMessage()));
        }
    }
}
