<?php
namespace App\Http\Controllers;

use App\Models\Helper\Response;
use App\Models\Helper\Validation;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class FcmController extends Controller
{
    /**
     * Регистрирует FCM токен для авторизованного пользователя
     * POST /api/v1/user/fcm-token
     */
    public function registerToken(Request $request)
    {
        try {
            $request->validate([
                'fcm_token' => 'required|string',
                'device_type' => 'nullable|string|in:android,ios',
            ]);

            // Пользователь гарантированно авторизован через middleware auth:user
            $user = $request->user('user');
            
            if (!$user) {
                \Log::error("FCM token registration: User not found despite auth middleware");
                return response()->json(Validation::unauthorized());
            }

            $user->fcm_token = $request->fcm_token;
            $user->save();

            \Log::info("FCM token updated for user {$user->id}", [
                'device_type' => $request->device_type ?? 'unknown',
                'email' => $user->email
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

    /**
     * Удаляет FCM токен пользователя
     */
    public function removeToken(Request $request)
    {
        try {
            $user = Auth::user('user');
            
            if ($user) {
                $user->fcm_token = null;
                $user->save();

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