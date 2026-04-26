# Отладка Push-уведомлений

## Проблема 1: Маршрут push-test не работает

**Ошибка:** `The POST method is not supported for route api/v1/admin/push-test`

**Решение:** Нужно очистить кэш маршрутов на сервере:

```bash
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop
php artisan route:clear
php artisan config:clear
php artisan cache:clear
```

Или через API (если есть доступ):
```
POST /api/v1/admin/clear-cache
```

## Проблема 2: Push-уведомления не приходят при изменении статуса заказа

### Шаг 1: Проверьте логи сервера

```bash
tail -f storage/logs/laravel.log | grep "PushNotificationService\|OrdersController.*updateStatus\|FCM"
```

### Шаг 2: Проверьте, что у пользователя есть FCM токен

```sql
USE ssboss_db;
SELECT id, email, fcm_token FROM users WHERE id = 3;
```

Поле `fcm_token` должно быть заполнено.

### Шаг 3: Проверьте, что заказ связан с пользователем

```sql
USE ssboss_db;
SELECT id, user_id, order, status FROM orders WHERE id = {ваш_order_id};
```

Поле `user_id` должно совпадать с ID пользователя, у которого есть FCM токен.

### Шаг 4: Проверьте логи при изменении статуса

После изменения статуса заказа в админ-панели проверьте логи:

```bash
tail -f storage/logs/laravel.log | grep "OrdersController.*updateStatus"
```

Должны быть записи:
- `🔔 OrdersController.updateStatus: Начинаем отправку push-уведомления`
- `✅ OrdersController.updateStatus: Push-уведомление успешно отправлено`

Если есть ошибки, они будут в логах.

## Проверка работы Firebase

### Проверка инициализации Firebase

```bash
tail -f storage/logs/laravel.log | grep "PushNotificationService.*инициализации"
```

Если есть ошибки инициализации, проверьте:
1. Файл `service-account.json` существует и доступен
2. Переменные окружения `FIREBASE_CREDENTIALS` и `FIREBASE_PROJECT_ID` правильные

### Проверка отправки уведомлений

```bash
tail -f storage/logs/laravel.log | grep "PushNotificationService.*отправлено\|Failed"
```

## Тестирование через тестовый endpoint

После очистки кэша попробуйте:

**Endpoint:** `POST /api/v1/admin/push-test`

**Headers:**
```
Authorization: Bearer {admin_token}
Accept: application/json
Content-Type: application/json
```

**Body:**
```json
{
  "user_id": 3,
  "title": "🔔 Тестовое уведомление",
  "body": "Если видите это — push работает!"
}
```

## Частые проблемы и решения

### Проблема: "User does not have FCM token registered"

**Решение:** Зарегистрируйте FCM токен через `/api/v1/user/fcm-token`

### Проблема: "Push-уведомление не отправлено (вернул false)"

**Причины:**
1. FCM токен недействителен
2. Проблемы с Firebase credentials
3. Проблемы с сетью

**Решение:** Проверьте логи Firebase и убедитесь, что credentials правильные.

### Проблема: Нет записей в логах при изменении статуса

**Причины:**
1. Код не выполняется (возможно, используется другой метод)
2. Ошибка происходит до логирования

**Решение:** Проверьте, какой именно endpoint вызывается при изменении статуса в админ-панели.

## Проверка через мобильное приложение

1. Убедитесь, что приложение запущено и активно
2. Проверьте разрешения на уведомления в настройках устройства
3. Проверьте логи приложения на наличие ошибок

## Команды для быстрой проверки

```bash
# Проверка всех push-операций
tail -f storage/logs/laravel.log | grep -i "push\|fcm\|notification"

# Проверка только ошибок
tail -f storage/logs/laravel.log | grep -i "error.*push\|failed.*push"

# Проверка успешных отправок
tail -f storage/logs/laravel.log | grep -i "✅\|sent.*push"
```

## КРИТИЧЕСКАЯ ПРОБЛЕМА: Ошибка прав доступа Firebase

### Ошибка в логах (2025-12-01 07:29:37):

```
PushNotificationService: Ошибка отправки уведомления
{
  "error": "Permission 'cloudmessaging.messages.create' denied on resource '//cloudresourcemanager.googleapis.com/projects/ssbossactual' (or it may not exist).",
  "title": "Статус заказа изменён",
  "token_preview": "dE6JpCiHQnWIP9GNmqr0..."
}
```

### Анализ проблемы:

1. **Несоответствие проектов:**
   - В логе ошибка указывала на проект `ssbossactual`
   - В `service-account.json` теперь указан правильный проект `ssboss-940a1`
   - В коде используется fallback `ssboss-940a1`

2. **Причина:**
   - В `.env` файле на сервере, вероятно, указан `FIREBASE_PROJECT_ID=ssbossactual`
   - Или service account пытается использовать другой проект
   - У service account нет прав на отправку FCM сообщений

### Решение:

#### Шаг 1: Проверьте `.env` файл на сервере

Убедитесь, что в `.env` указан правильный проект:

```env
FIREBASE_PROJECT_ID=ssboss-940a1
```

Это должен быть ваш актуальный проект Firebase.

#### Шаг 2: Проверьте `service-account.json`

Убедитесь, что `project_id` в файле соответствует проекту, который вы используете:

```json
{
  "project_id": "ssboss-940a1",
  ...
}
```

#### Шаг 3: Проверьте права service account в Google Cloud Console

1. Откройте [Google Cloud Console](https://console.cloud.google.com/)
2. Выберите проект `ssboss-940a1`
3. Перейдите в **IAM & Admin** → **IAM**
4. Найдите service account: `6679984923-compute@developer.gserviceaccount.com`
5. Убедитесь, что у него есть одна из следующих ролей:
   - **Firebase Cloud Messaging Admin**
   - **Firebase Admin SDK Administrator Service Agent**
   - **Firebase Admin** (полные права)

Если роли нет:
1. Нажмите на service account
2. Нажмите **ADD ANOTHER ROLE**
3. Выберите **Firebase Cloud Messaging Admin**
4. Сохраните

#### Шаг 4: Очистите кэш Laravel

После изменения `.env`:

```bash
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop
php artisan config:clear
php artisan cache:clear
```

#### Шаг 5: Проверьте логи после исправления

```bash
tail -f storage/logs/laravel.log | grep "PushNotificationService"
```

Должны появиться записи:
- `✅ PushNotificationService: Уведомление отправлено` (успех)
- Или более детальные ошибки, если проблема не решена

### Альтернативное решение: Использовать правильный проект

**✅ Обновлено:** Теперь используется правильный проект `ssboss-940a1` с новым service account файлом.

### Проверка успешной регистрации FCM токена

В логах есть успешная запись:

```
[2025-12-01 07:10:14] local.INFO: FCM token updated for user 3 {"device_type":"android","email":"sorbon_9191@mail.ru"}
```

Это означает, что регистрация токена работает правильно. Проблема только в отправке уведомлений из-за прав доступа Firebase.

