# Полное восстановление push-уведомлений - Пошаговая инструкция

## 📊 Анализ проблемы

Из логов видно:
- ✅ FCM токен получен приложением
- ✅ FCM токен успешно отправлен на сервер (`FCM token registered`)
- ❌ Push-уведомления не приходят при изменении статуса заказа

**Проблемы:**
1. В `.env` указан путь `/config/firebase-adminsdk.json`, но нужно проверить, существует ли этот файл
2. `fcm_token` отсутствует в `User.php` (удален обновлением)
3. Маршруты `fcm-token` отсутствуют в `routes/api.php` (удалены обновлением)
4. Возможно, `PushNotificationService` не используется в контроллерах

---

## 🔧 Пошаговое восстановление

### Шаг 1: Проверить файл Firebase credentials

```bash
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

# Проверить, какой файл существует
ls -la config/firebase-adminsdk.json
ls -la service-account.json

# Проверить project_id в существующем файле
if [ -f "config/firebase-adminsdk.json" ]; then
    echo "Файл config/firebase-adminsdk.json существует:"
    cat config/firebase-adminsdk.json | grep project_id
elif [ -f "service-account.json" ]; then
    echo "Файл service-account.json существует:"
    cat service-account.json | grep project_id
fi
```

**Вариант A:** Если `config/firebase-adminsdk.json` существует и содержит `"project_id": "ssboss-940a1"`:
- Оставьте путь в `.env` как есть: `FIREBASE_CREDENTIALS=/var/www/ssboss_shop_usr/data/www/ssboss.shop/config/firebase-adminsdk.json`

**Вариант B:** Если файл не существует или project_id неправильный:
- Используйте `service-account.json` в корне
- Обновите `.env`: `FIREBASE_CREDENTIALS=service-account.json`

### Шаг 2: Восстановить `fcm_token` в `User.php`

```bash
# Добавить fcm_token в массив $fillable
sed -i "s/'viewed'\]/'viewed', 'fcm_token']/" app/Models/User.php

# Проверить
grep "fcm_token" app/Models/User.php
# Должно показать: 'fcm_token' в массиве $fillable
```

### Шаг 3: Восстановить маршруты в `routes/api.php`

```bash
# Найти строку с logout в группе user
grep -n "Route::get('logout'" routes/api.php

# Открыть файл для редактирования
nano routes/api.php
```

Найдите группу маршрутов (примерно строка 800):
```php
Route::group([
    'prefix' => 'user',
    'middleware' => ['auth:user','scope:user']
], function () {
    Route::get('logout', [UsersController::class, "logout"]);
    
    // ДОБАВЬТЕ ЭТИ ДВЕ СТРОКИ ПОСЛЕ logout:
    Route::post('fcm-token', [\App\Http\Controllers\FcmController::class, 'registerToken']);
    Route::delete('fcm-token', [\App\Http\Controllers\FcmController::class, 'removeToken']);
    
    // ... остальные маршруты
});
```

### Шаг 4: Проверить наличие `FcmController.php`

```bash
# Проверить файл
ls -la app/Http/Controllers/FcmController.php

# Если файл отсутствует, создайте его (см. инструкцию ниже)
```

Если файл отсутствует, создайте его:

```bash
cat > app/Http/Controllers/FcmController.php << 'EOF'
<?php
namespace App\Http\Controllers;

use App\Models\Helper\Response;
use App\Models\Helper\Validation;
use App\Models\User;
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
EOF
```

### Шаг 5: Проверить использование `PushNotificationService` в контроллерах

```bash
# Проверить OrdersController
grep -n "PushNotificationService\|sendOrderStatusUpdate" app/Http/Controllers/OrdersController.php

# Проверить SubscriptionEmailsController
grep -n "PushNotificationService\|sendPromotionNotification" app/Http/Controllers/SubscriptionEmailsController.php
```

Если использование отсутствует, нужно восстановить. Проверьте резервную копию или файлы в папке `Update`.

### Шаг 6: Обновить `PushNotificationService.php` для поддержки абсолютных путей

Проверьте текущий код:

```bash
grep -A 5 "withServiceAccount" app/Services/PushNotificationService.php
```

Должно быть:
```php
->withServiceAccount(env('FIREBASE_CREDENTIALS', base_path('service-account.json')))
```

Если путь в `.env` абсолютный (начинается с `/`), код должен работать. Если относительный, нужно убедиться, что путь правильный.

### Шаг 7: Обновить `.env` (если нужно)

```bash
# Проверить текущие настройки
grep "FIREBASE" .env

# Если нужно изменить путь:
# Вариант 1: Использовать config/firebase-adminsdk.json (если существует)
# FIREBASE_CREDENTIALS=/var/www/ssboss_shop_usr/data/www/ssboss.shop/config/firebase-adminsdk.json

# Вариант 2: Использовать service-account.json в корне
# FIREBASE_CREDENTIALS=service-account.json

# FIREBASE_PROJECT_ID должен быть:
# FIREBASE_PROJECT_ID=ssboss-940a1
```

### Шаг 8: Очистить кэш

```bash
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear
php artisan config:cache
php artisan route:cache
composer dump-autoload
```

### Шаг 9: Проверить восстановление

```bash
# 1. Проверить User.php
grep "fcm_token" app/Models/User.php
# Должно показать: 'fcm_token' в массиве $fillable

# 2. Проверить routes/api.php
grep "fcm-token\|FcmController" routes/api.php
# Должно показать маршруты

# 3. Проверить FcmController
ls -la app/Http/Controllers/FcmController.php
# Должен существовать

# 4. Проверить PushNotificationService
grep "ssboss-940a1" app/Services/PushNotificationService.php
# Должно показать project_id

# 5. Проверить .env
grep "FIREBASE" .env
# Должно показать правильные пути

# 6. Проверить файл credentials
if [ -f "config/firebase-adminsdk.json" ]; then
    cat config/firebase-adminsdk.json | grep project_id
elif [ -f "service-account.json" ]; then
    cat service-account.json | grep project_id
fi
# Должно показать: "project_id": "ssboss-940a1"
```

### Шаг 10: Протестировать push-уведомления

1. **Запустите мобильное приложение** (если еще не запущено)
2. **Войдите в аккаунт** (FCM токен должен зарегистрироваться)
3. **Проверьте логи регистрации токена:**
   ```bash
   tail -n 50 storage/logs/laravel.log | grep -i "fcm token updated"
   ```
4. **Измените статус заказа в админке**
5. **Проверьте логи отправки:**
   ```bash
   tail -f storage/logs/laravel.log | grep -i "push\|fcm\|notification"
   ```

---

## 🔍 Диагностика проблем

### Проблема: FCM токен не регистрируется

**Проверка:**
```bash
# Проверить маршруты
php artisan route:list | grep fcm

# Проверить логи
tail -n 100 storage/logs/laravel.log | grep -i "fcm\|token"
```

### Проблема: Push-уведомления не отправляются

**Проверка:**
```bash
# Проверить логи при изменении статуса заказа
tail -f storage/logs/laravel.log | grep -i "push\|order\|status"

# Проверить использование PushNotificationService
grep -n "PushNotificationService" app/Http/Controllers/OrdersController.php
```

### Проблема: Ошибка "File not found" для Firebase credentials

**Решение:**
```bash
# Проверить, какой файл существует
ls -la config/firebase-adminsdk.json service-account.json

# Обновить .env с правильным путем
nano .env
# Измените FIREBASE_CREDENTIALS на существующий файл
```

---

## ✅ Финальный чек-лист

- [ ] `app/Models/User.php` содержит `'fcm_token'` в `$fillable`
- [ ] `routes/api.php` содержит маршруты для FCM токенов
- [ ] `app/Http/Controllers/FcmController.php` существует
- [ ] `app/Services/PushNotificationService.php` существует и содержит `ssboss-940a1`
- [ ] Файл Firebase credentials существует (либо `config/firebase-adminsdk.json`, либо `service-account.json`)
- [ ] `.env` содержит правильный путь к Firebase credentials
- [ ] `.env` содержит `FIREBASE_PROJECT_ID=ssboss-940a1`
- [ ] `app/Http/Controllers/OrdersController.php` использует `PushNotificationService`
- [ ] Кэш очищен
- [ ] FCM токен зарегистрирован в базе данных
- [ ] Push-уведомления работают (протестировано)

---

**Дата создания:** 2025-12-01  
**Версия:** 2.0

