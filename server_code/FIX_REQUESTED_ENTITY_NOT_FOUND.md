# Исправление ошибки "Requested entity was not found"

## ✅ Что сделано

Код уже обновлен для автоматической обработки ошибки `Requested entity was not found`. При этой ошибке токен автоматически удаляется из базы данных.

## Проблема

Ошибка `Requested entity was not found` означает, что FCM токен в базе данных недействителен. Это может произойти, если:
1. Токен был создан для старого проекта Firebase (`augmented-tract-380310`)
2. Приложение было переустановлено
3. Токен устарел или был удален из Firebase

## Решение

### Шаг 1: Проверить, что токен удален из базы

После следующей попытки отправки push-уведомления токен должен быть автоматически удален. Проверьте:

```bash
mysql -u root -p
USE ssboss_db;
SELECT id, email, fcm_token FROM users WHERE id = 3;
```

Если `fcm_token` = `NULL`, значит токен был удален автоматически.

### Шаг 2: Обновить токен через мобильное приложение

1. **Откройте мобильное приложение**
2. **Войдите в аккаунт** (user_id: 3)
3. **Приложение автоматически зарегистрирует новый FCM токен** при запуске
4. Проверьте логи сервера:

```bash
tail -f storage/logs/laravel.log | grep "FCM token updated"
```

Должна появиться запись:
```
[INFO] FCM token updated for user 3
```

### Шаг 3: Проверить новый токен в базе

```sql
SELECT id, email, LEFT(fcm_token, 30) as token_preview FROM users WHERE id = 3;
```

Новый токен должен начинаться с другого префикса (не `eTzhfm67QlmxqoyXm_cm...`).

### Шаг 4: Протестировать отправку push-уведомления

После обновления токена попробуйте изменить статус заказа и проверьте логи:

```bash
tail -n 20 storage/logs/laravel.log | grep -i "push\|fcm"
```

Должны появиться записи:
```
✅ PushNotificationService: Уведомление отправлено
```

## Автоматическая обработка

Код теперь автоматически обрабатывает следующие ошибки:
- ✅ `Requested entity was not found`
- ✅ `not a valid FCM registration token`
- ✅ `InvalidRegistration`
- ✅ `MismatchSenderId`
- ✅ `NOT_FOUND`

При любой из этих ошибок токен автоматически удаляется из базы данных, и в логах появляется:
```
⚠️ PushNotificationService: Недействительный FCM токен, удаляем из базы
✅ PushNotificationService: Недействительный токен удален из базы данных
```

## Проверка работы

### 1. Проверить текущий токен:

```sql
SELECT id, email, fcm_token FROM users WHERE id = 3;
```

### 2. Если токен есть, но недействителен:

Токен будет автоматически удален при следующей попытке отправки push-уведомления.

### 3. После удаления токена:

Пользователю нужно перезапустить мобильное приложение, чтобы зарегистрировать новый токен.

### 4. Проверить регистрацию нового токена:

```bash
tail -f storage/logs/laravel.log | grep "FCM token updated"
```

## Если проблема сохраняется

1. **Убедитесь, что мобильное приложение использует правильный проект Firebase:**
   - Проверьте `google-services.json` в `android/app/`
   - Убедитесь, что `package_name` соответствует `applicationId` в `build.gradle.kts`

2. **Проверьте, что приложение регистрирует токен:**
   - Откройте приложение
   - Войдите в аккаунт
   - Проверьте логи приложения на наличие FCM токена

3. **Проверьте права service account:**
   - Убедитесь, что service account имеет роль `Firebase Cloud Messaging Admin` в проекте `ssboss-940a1`

## Диагностика

Выполните команды для диагностики:

```bash
# 1. Проверить последние ошибки
tail -n 30 storage/logs/laravel.log | grep -i "push\|fcm\|token"

# 2. Проверить токен в базе
mysql -u root -p -e "USE ssboss_db; SELECT id, email, LEFT(fcm_token, 30) as token_preview FROM users WHERE id = 3;"

# 3. Проверить, удаляется ли токен автоматически
tail -f storage/logs/laravel.log | grep "Недействительный токен"
```

