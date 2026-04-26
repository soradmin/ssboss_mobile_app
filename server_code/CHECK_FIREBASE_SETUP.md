# Проверка настройки Firebase Push Notifications

## Быстрая проверка конфигурации

### 1. Проверить последние записи в логе (без фильтра)

```bash
tail -n 50 storage/logs/laravel.log
```

Это покажет последние 50 строк лога. Ищите записи с:
- `PushNotificationService`
- `FCM`
- `Firebase`
- `ERROR` или `INFO`

### 2. Проверить, есть ли записи с PushNotificationService в логе

```bash
grep -i "PushNotificationService" storage/logs/laravel.log | tail -20
```

Если команда ничего не выводит, значит еще не было попыток отправки уведомлений.

### 3. Проверить конфигурацию через Laravel Tinker

```bash
php artisan tinker
```

Затем выполните:

```php
// Проверить project_id
env('FIREBASE_PROJECT_ID', 'ssboss-940a1');

// Проверить путь к credentials
env('FIREBASE_CREDENTIALS', base_path('service-account.json'));

// Проверить, что файл существует
file_exists(base_path('service-account.json'));

// Проверить project_id в service-account.json
$json = json_decode(file_get_contents(base_path('service-account.json')), true);
$json['project_id'];

// Проверить инициализацию сервиса
$service = app(\App\Services\PushNotificationService::class);
// Если ошибок нет, сервис инициализирован успешно
```

### 4. Проверить файл service-account.json

```bash
# Проверить, что файл существует
ls -la service-account.json

# Проверить project_id в файле
cat service-account.json | grep project_id

# Проверить права доступа (должен быть читаемым)
cat service-account.json | head -5
```

### 5. Проверить переменные окружения

```bash
# Если используете .env файл
grep FIREBASE .env

# Или через php
php -r "echo getenv('FIREBASE_PROJECT_ID') ?: 'ssboss-940a1 (default)';"
```

### 6. Тестовая отправка push-уведомления

Если у вас есть доступ к админ-панели или API:

**Через Postman/API:**
```
POST /api/v1/admin/push-test
Authorization: Bearer {admin_token}
Content-Type: application/json

{
  "user_id": 3,
  "title": "🔔 Тестовое уведомление",
  "body": "Проверка работы push-уведомлений"
}
```

**Или изменить статус заказа:**
Измените статус любого заказа пользователя с ID 3 в админ-панели, это должно вызвать отправку push-уведомления.

### 7. Проверить логи в реальном времени (альтернативный способ)

```bash
# Показать последние 100 строк и следить за новыми
tail -n 100 -f storage/logs/laravel.log

# Или с фильтром по всем push-связанным записям
tail -f storage/logs/laravel.log | grep -i "push\|fcm\|firebase\|notification"
```

### 8. Проверить права service account в Google Cloud

Убедитесь, что service account `firebase-adminsdk-fbsvc@ssboss-940a1.iam.gserviceaccount.com` имеет роль:
- **Firebase Cloud Messaging Admin**

Проверка через Google Cloud Console:
1. Откройте https://console.cloud.google.com/
2. Выберите проект `ssboss-940a1`
3. IAM & Admin → IAM
4. Найдите service account

## Что делать, если ничего не происходит

### Если `grep` не находит записи:

1. **Проверьте, что сервис вызывается:**
   - Измените статус заказа в админ-панели
   - Или отправьте тестовое уведомление через API

2. **Проверьте, что код обновлен:**
   ```bash
   # Проверить, что PushNotificationService использует правильный project_id
   grep -A 5 "withProjectId" app/Services/PushNotificationService.php
   ```

3. **Проверьте логи при изменении статуса заказа:**
   ```bash
   # Следить за всеми логами при изменении статуса
   tail -f storage/logs/laravel.log
   ```
   Затем измените статус заказа и посмотрите, что появится в логах.

### Если есть ошибки в логах:

```bash
# Показать только ошибки
grep -i "error\|exception\|failed" storage/logs/laravel.log | tail -20

# Показать ошибки, связанные с Firebase
grep -i "firebase\|fcm\|push" storage/logs/laravel.log | grep -i "error\|exception" | tail -20
```

## Проверка успешной работы

После отправки тестового уведомления или изменения статуса заказа, в логах должны появиться:

**Успешная отправка:**
```
[INFO] PushNotificationService: Уведомление отправлено
```

**Ошибка:**
```
[ERROR] PushNotificationService: Ошибка отправки уведомления
```

**Предупреждение (нет токена):**
```
[WARNING] PushNotificationService: Пропущена отправка - нет messaging или токена
```

## Быстрая проверка всех компонентов

Выполните все команды последовательно:

```bash
# 1. Проверить файл
ls -la service-account.json && echo "✅ Файл существует"

# 2. Проверить project_id
cat service-account.json | grep project_id && echo "✅ project_id найден"

# 3. Проверить последние логи
tail -n 5 storage/logs/laravel.log && echo "✅ Логи доступны"

# 4. Проверить конфигурацию через tinker
php artisan tinker --execute="echo env('FIREBASE_PROJECT_ID', 'ssboss-940a1');" && echo "✅ Конфигурация загружена"
```

