# 🔧 Пошаговое исправление push-уведомлений после обновления

## 📋 Проблема

После обновления системы push-уведомления перестали работать. Причина: код отправки push-уведомлений был удален из контроллеров при обновлении.

---

## ✅ Шаг 1: Проверка миграции базы данных

**Проверьте, выполнена ли миграция для добавления поля `fcm_token`:**

```bash
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

# Проверьте статус миграций
php artisan migrate:status | grep fcm_token

# Если миграция не выполнена, выполните её:
php artisan migrate
```

**Проверьте наличие поля в базе данных:**

```bash
# Проверьте структуру таблицы users
php artisan tinker
>>> Schema::hasColumn('users', 'fcm_token');
# Должно вернуть: true
>>> exit
```

**Или через SQL:**

```sql
DESCRIBE users;
-- Должно быть поле: fcm_token varchar(255) NULL
```

---

## ✅ Шаг 2: Проверка файлов

### 2.1. Проверьте `app/Models/User.php`

```bash
grep "fcm_token" app/Models/User.php
```

**Должно быть:**
```php
protected $fillable = [..., 'fcm_token'];
```

### 2.2. Проверьте `routes/api.php`

```bash
grep "fcm-token\|FcmController" routes/api.php
```

**Должно быть:**
```php
Route::post('fcm-token', [\App\Http\Controllers\FcmController::class, 'registerToken']);
Route::delete('fcm-token', [\App\Http\Controllers\FcmController::class, 'removeToken']);
```

### 2.3. Проверьте `app/Http/Controllers/FcmController.php`

```bash
ls -la app/Http/Controllers/FcmController.php
```

**Файл должен существовать.**

### 2.4. Проверьте `app/Services/PushNotificationService.php`

```bash
ls -la app/Services/PushNotificationService.php
grep "ssboss-940a1" app/Services/PushNotificationService.php
```

**Должно быть:**
```php
->withProjectId(env('FIREBASE_PROJECT_ID', 'ssboss-940a1'));
```

---

## ✅ Шаг 3: Проверка кода отправки push-уведомлений

### 3.1. Проверьте `app/Http/Controllers/OrdersController.php`

```bash
grep -A 20 "Order::where('id', \$request->id)->update(\$updatedStatus);" app/Http/Controllers/OrdersController.php
```

**Должен быть код отправки push-уведомлений после обновления статуса заказа.**

### 3.2. Проверьте `app/Http/Controllers/SubscriptionEmailsController.php`

```bash
grep -A 10 "MailHelper::sendingSubscriptionEmail" app/Http/Controllers/SubscriptionEmailsController.php
```

**Должен быть код отправки push-уведомлений после отправки email рассылки.**

---

## ✅ Шаг 4: Проверка Firebase credentials

### 4.1. Проверьте `.env` файл

```bash
grep -E "FIREBASE|firebase" .env
```

**Должно быть:**
```
FIREBASE_CREDENTIALS=/var/www/ssboss_shop_usr/data/www/ssboss.shop/config/firebase-adminsdk.json
# или
FIREBASE_CREDENTIALS=service-account.json
FIREBASE_PROJECT_ID=ssboss-940a1
```

### 4.2. Проверьте наличие файла Firebase credentials

```bash
# Проверьте файл, указанный в .env
if [ -f "config/firebase-adminsdk.json" ]; then
    echo "✅ config/firebase-adminsdk.json существует"
    cat config/firebase-adminsdk.json | grep project_id
elif [ -f "service-account.json" ]; then
    echo "✅ service-account.json существует"
    cat service-account.json | grep project_id
else
    echo "❌ Файл Firebase credentials не найден!"
fi
```

**Должно показать:**
```json
"project_id": "ssboss-940a1"
```

---

## ✅ Шаг 5: Очистка кэша

**Выполните все команды очистки кэша:**

```bash
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear
php artisan config:cache
php artisan route:cache
composer dump-autoload
```

---

## ✅ Шаг 6: Проверка регистрации FCM токенов

### 6.1. Проверьте логи при регистрации токена

```bash
# Войдите в приложение и зарегистрируйте FCM токен
# Затем проверьте логи:
tail -n 50 storage/logs/laravel.log | grep -i "fcm token updated"
```

**Должно быть:**
```
FCM token updated for user {user_id}
```

### 6.2. Проверьте токены в базе данных

```sql
SELECT id, email, LEFT(fcm_token, 30) as token_preview 
FROM users 
WHERE fcm_token IS NOT NULL 
LIMIT 5;
```

---

## ✅ Шаг 7: Тестирование отправки push-уведомлений

### 7.1. Измените статус заказа через админ-панель

1. Откройте админ-панель
2. Найдите заказ пользователя с FCM токеном
3. Измените статус заказа
4. Проверьте логи:

```bash
tail -f storage/logs/laravel.log | grep -i "push\|fcm\|notification"
```

**Должно быть:**
```
✅ OrdersController.updateStatus: Push-уведомление успешно отправлено
PushNotificationService: Уведомление отправлено
```

### 7.2. Отправьте промо-рассылку

1. Откройте админ-панель
2. Создайте и отправьте промо-рассылку
3. Проверьте логи:

```bash
tail -f storage/logs/laravel.log | grep -i "subscription email\|push"
```

**Должно быть:**
```
Subscription email: Push notifications sent
PushNotificationService: Массовая рассылка завершена
```

---

## 🔴 Возможные проблемы и решения

### Проблема 1: FCM токен не регистрируется

**Причина:** Маршрут не найден или пользователь не авторизован.

**Решение:**
```bash
# Проверьте маршруты
php artisan route:list | grep fcm

# Проверьте логи
tail -n 100 storage/logs/laravel.log | grep -i "fcm\|token"
```

### Проблема 2: Push-уведомления не отправляются

**Причина:** Ошибка инициализации Firebase или неверный путь к credentials.

**Решение:**
```bash
# Проверьте логи ошибок
tail -n 100 storage/logs/laravel.log | grep -i "firebase\|error\|push"

# Проверьте путь к credentials в .env
grep FIREBASE_CREDENTIALS .env

# Убедитесь, что файл существует
ls -la config/firebase-adminsdk.json
# или
ls -la service-account.json
```

### Проблема 3: "Requested entity was not found"

**Причина:** Неверный FCM токен или токен устарел.

**Решение:**
- Токен автоматически удаляется из базы данных при ошибке
- Пользователю нужно переустановить приложение или перелогиниться

### Проблема 4: Миграция не выполнена

**Причина:** Миграция не была выполнена после обновления.

**Решение:**
```bash
# Выполните миграцию
php artisan migrate

# Проверьте статус
php artisan migrate:status | grep fcm_token
```

---

## 📝 Чек-лист восстановления

- [ ] Миграция `fcm_token` выполнена
- [ ] `app/Models/User.php` содержит `'fcm_token'` в `$fillable`
- [ ] `routes/api.php` содержит маршруты для FCM токенов
- [ ] `app/Http/Controllers/FcmController.php` существует
- [ ] `app/Services/PushNotificationService.php` существует и содержит правильный `project_id`
- [ ] `app/Http/Controllers/OrdersController.php` содержит код отправки push-уведомлений
- [ ] `app/Http/Controllers/SubscriptionEmailsController.php` содержит код отправки push-уведомлений
- [ ] Firebase credentials файл существует и содержит правильный `project_id`
- [ ] `.env` содержит правильные пути к Firebase credentials
- [ ] Кэш очищен
- [ ] FCM токены регистрируются в базе данных
- [ ] Push-уведомления отправляются при изменении статуса заказа
- [ ] Push-уведомления отправляются при промо-рассылке

---

## 🚀 Быстрая проверка работоспособности

```bash
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

# 1. Проверка файлов
echo "=== Проверка файлов ==="
grep "fcm_token" app/Models/User.php && echo "✅ User.php OK" || echo "❌ User.php - проблема"
grep "fcm-token" routes/api.php && echo "✅ routes/api.php OK" || echo "❌ routes/api.php - проблема"
[ -f "app/Http/Controllers/FcmController.php" ] && echo "✅ FcmController.php OK" || echo "❌ FcmController.php - проблема"
[ -f "app/Services/PushNotificationService.php" ] && echo "✅ PushNotificationService.php OK" || echo "❌ PushNotificationService.php - проблема"

# 2. Проверка кода отправки
echo -e "\n=== Проверка кода отправки ==="
grep "PushNotificationService" app/Http/Controllers/OrdersController.php && echo "✅ OrdersController OK" || echo "❌ OrdersController - проблема"
grep "PushNotificationService" app/Http/Controllers/SubscriptionEmailsController.php && echo "✅ SubscriptionEmailsController OK" || echo "❌ SubscriptionEmailsController - проблема"

# 3. Проверка Firebase
echo -e "\n=== Проверка Firebase ==="
grep "FIREBASE_PROJECT_ID" .env && echo "✅ .env OK" || echo "❌ .env - проблема"
[ -f "config/firebase-adminsdk.json" ] || [ -f "service-account.json" ] && echo "✅ Firebase credentials OK" || echo "❌ Firebase credentials - проблема"

# 4. Проверка токенов в БД
echo -e "\n=== Проверка токенов в БД ==="
php artisan tinker --execute="echo 'Пользователей с FCM токенами: ' . \App\Models\User::whereNotNull('fcm_token')->count();"
```

---

## 📞 Если проблема не решена

1. Проверьте логи Laravel: `tail -f storage/logs/laravel.log`
2. Проверьте логи Firebase в консоли Firebase
3. Убедитесь, что приложение правильно регистрирует FCM токены
4. Проверьте, что пользователи имеют актуальные FCM токены в базе данных

