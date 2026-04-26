# Восстановление push-уведомлений после обновления

## 🔴 Проблема

После обновления обнаружены следующие проблемы:
1. ❌ `fcm_token` отсутствует в `app/Models/User.php`
2. ❌ Маршруты `fcm-token` отсутствуют в `routes/api.php`
3. ⚠️ Путь к Firebase credentials в `.env` указывает на несуществующий файл

---

## 🔧 Шаги по восстановлению

### Шаг 1: Восстановить `app/Models/User.php`

Добавьте `'fcm_token'` в массив `$fillable`:

```bash
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

# Откройте файл для редактирования
nano app/Models/User.php
```

Найдите строку:
```php
protected $fillable = ['name', 'email', 'password', 'code', 'default_address', 'phone',
    'verified', 'remember_token', 'facebook_id', 'google_id', 'viewed'];
```

Измените на:
```php
protected $fillable = ['name', 'email', 'password', 'code', 'default_address', 'phone',
    'verified', 'remember_token', 'facebook_id', 'google_id', 'viewed', 'fcm_token'];
```

**Или выполните команду:**
```bash
sed -i "s/'viewed'\]/'viewed', 'fcm_token']/" app/Models/User.php
```

### Шаг 2: Восстановить маршруты в `routes/api.php`

Добавьте маршруты для FCM токенов:

```bash
# Откройте файл для редактирования
nano routes/api.php
```

Найдите группу маршрутов с `'prefix' => 'user'` и `'middleware' => ['auth:user','scope:user']` (примерно строка 800).

Добавьте после строки с `Route::get('logout', ...)`:

```php
// FCM токен для push-уведомлений (требует OAuth токен)
Route::post('fcm-token', [\App\Http\Controllers\FcmController::class, 'registerToken']);
Route::delete('fcm-token', [\App\Http\Controllers\FcmController::class, 'removeToken']);
```

**Или выполните команду (если знаете точную строку):**
```bash
# Найдите строку с logout
grep -n "logout" routes/api.php

# Добавьте маршруты после logout (замените N на номер строки после logout)
sed -i "N a\\            Route::post('fcm-token', [\\\App\\\Http\\\Controllers\\\FcmController::class, 'registerToken']);\\n            Route::delete('fcm-token', [\\\App\\\Http\\\Controllers\\\FcmController::class, 'removeToken']);" routes/api.php
```

### Шаг 3: Проверить наличие `FcmController.php`

```bash
# Проверьте, существует ли файл
ls -la app/Http/Controllers/FcmController.php

# Если файл отсутствует, скопируйте из резервной копии или создайте заново
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
EOF
```

### Шаг 4: Исправить путь к Firebase credentials в `.env`

Текущий путь в `.env`:
```
FIREBASE_CREDENTIALS=/var/www/ssboss_shop_usr/data/www/ssboss.shop/config/firebase-adminsdk.json
```

Измените на:
```
FIREBASE_CREDENTIALS=service-account.json
```

**Или если нужен абсолютный путь:**
```
FIREBASE_CREDENTIALS=/var/www/ssboss_shop_usr/data/www/ssboss.shop/service-account.json
```

```bash
# Отредактируйте .env
nano .env

# Или выполните команду
sed -i 's|FIREBASE_CREDENTIALS=.*|FIREBASE_CREDENTIALS=service-account.json|' .env
```

### Шаг 5: Проверить `PushNotificationService.php`

Убедитесь, что файл существует и содержит правильный `project_id`:

```bash
# Проверьте файл
ls -la app/Services/PushNotificationService.php

# Проверьте project_id
grep "ssboss-940a1" app/Services/PushNotificationService.php
```

Если файл отсутствует или поврежден, восстановите из резервной копии.

### Шаг 6: Проверить использование PushNotificationService в контроллерах

```bash
# Проверьте OrdersController
grep -n "PushNotificationService\|sendOrderStatusUpdate" app/Http/Controllers/OrdersController.php

# Проверьте SubscriptionEmailsController
grep -n "PushNotificationService\|sendPromotionNotification" app/Http/Controllers/SubscriptionEmailsController.php
```

Если использование отсутствует, нужно восстановить эти методы. См. файлы в резервной копии.

### Шаг 7: Очистить кэш

```bash
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear
php artisan config:cache
php artisan route:cache
composer dump-autoload
```

### Шаг 8: Проверить восстановление

```bash
# Проверьте User.php
grep "fcm_token" app/Models/User.php
# Должно показать: 'fcm_token' в массиве $fillable

# Проверьте routes/api.php
grep "fcm-token\|FcmController" routes/api.php
# Должно показать маршруты

# Проверьте FcmController
ls -la app/Http/Controllers/FcmController.php
# Должен существовать

# Проверьте .env
grep "FIREBASE" .env
# Должно быть: FIREBASE_CREDENTIALS=service-account.json
```

### Шаг 9: Протестировать push-уведомления

1. Запустите мобильное приложение
2. Войдите в аккаунт (FCM токен должен зарегистрироваться)
3. Проверьте логи:
   ```bash
   tail -f storage/logs/laravel.log | grep -i "fcm\|push"
   ```
4. Измените статус заказа в админке
5. Проверьте, пришло ли уведомление

---

## 🚨 Если файлы отсутствуют в резервной копии

Если у вас нет резервной копии, используйте файлы из локального проекта:

1. Скопируйте файлы с локального компьютера на сервер:
   ```bash
   # На локальном компьютере (если есть доступ по SSH)
   scp app/Models/User.php user@server:/var/www/ssboss_shop_usr/data/www/ssboss.shop/app/Models/
   scp app/Http/Controllers/FcmController.php user@server:/var/www/ssboss_shop_usr/data/www/ssboss.shop/app/Http/Controllers/
   scp routes/api.php user@server:/var/www/ssboss_shop_usr/data/www/ssboss.shop/routes/
   ```

2. Или создайте файлы вручную по инструкциям выше.

---

## ✅ Чек-лист восстановления

- [ ] `app/Models/User.php` содержит `'fcm_token'` в `$fillable`
- [ ] `routes/api.php` содержит маршруты для FCM токенов
- [ ] `app/Http/Controllers/FcmController.php` существует
- [ ] `app/Services/PushNotificationService.php` существует и содержит `ssboss-940a1`
- [ ] `.env` содержит правильный путь к `service-account.json`
- [ ] `service-account.json` существует в корне проекта
- [ ] Кэш очищен
- [ ] Push-уведомления работают (протестировано)

---

**Дата создания:** 2025-12-01  
**Версия:** 1.0

