# Решение проблемы "Unauthorized access" при регистрации FCM токена

## Проблема

При отправке запроса `POST /api/v1/user/fcm-token` с OAuth токеном получаете:
```json
{
  "data": {
    "form": ["Unauthorized access."]
  },
  "status": 403,
  "token": null,
  "message": "Unauthorized access."
}
```

## Причины и решения

### 1. Проверьте правильность токена

**Проблема:** Токен может быть неполным или повреждённым при копировании.

**Решение:**
1. Убедитесь, что скопировали **весь токен** из ответа логина (он очень длинный)
2. В Postman вкладка "Authorization" → Type: `Bearer Token` → вставьте **весь токен** без пробелов

### 2. Проверьте формат заголовка Authorization

**Правильно в Postman:**
- Вкладка "Authorization"
- Type: `Bearer Token`
- Token: `весь_токен_без_пробелов`

**Неправильно:**
- Вкладка "Headers" с `Authorization: Bearer токен` (может работать, но лучше использовать вкладку Authorization)

### 3. Проверьте, что токен имеет scope 'user'

Токен должен быть создан с scope 'user'. При логине через `/api/v1/user/signin` токен создаётся правильно.

### 4. Проверьте срок действия токена

Токен может истечь. Получите новый токен через логин.

### 5. Проверьте логи сервера

```bash
tail -f storage/logs/laravel.log | grep "FCM token\|Unauthorized\|CheckForAllScopes"
```

Это поможет понять, на каком этапе происходит ошибка.

## Пошаговая проверка в Postman

### Шаг 1: Получите свежий OAuth токен

```
POST https://ssboss.shop/api/v1/user/signin
Headers:
  Accept: application/json
  Content-Type: application/json
Body:
{
  "email": "sorbon_9191@mail.ru",
  "password": "Sorbu20252"
}
```

**Скопируйте весь токен** из ответа (поле `data.token`).

### Шаг 2: Настройте запрос FCM токена

**URL:**
```
POST https://ssboss.shop/api/v1/user/fcm-token
```

**Authorization (вкладка):**
- Type: `Bearer Token`
- Token: `вставьте_весь_токен_из_шага_1`

**Headers:**
```
Accept: application/json
Content-Type: application/json
```

**Body (raw JSON):**
```json
{
  "fcm_token": "dE6JpCiHQnWIP9GNmqr0os:APA91bH-hWkPfcUWRTDS9wrZuPFfDkKLEk95fhbdAehi-SuJyL2xHXZJXwykNVJAKaOV3IgoK00t7aCScy7wkfm2whnML1G-L5iS89ztrYFtTuLnm340JAK",
  "device_type": "android"
}
```

### Шаг 3: Отправьте запрос

**Ожидаемый успешный ответ:**
```json
{
  "success": true,
  "data": {
    "message": "FCM token registered",
    "user_id": 3
  }
}
```

## Альтернативное решение: Использование user_token

Если OAuth токен не работает, можно использовать `user_token` в Body (но для этого нужно убрать middleware или создать отдельный маршрут):

**Body:**
```json
{
  "fcm_token": "ваш_fcm_токен",
  "device_type": "android",
  "user_token": "ваш_guest_user_token"
}
```

**Примечание:** Сейчас маршрут требует OAuth токен, так что этот вариант не будет работать без изменения кода.

## Проверка в базе данных

После успешной регистрации:
```sql
SELECT id, email, fcm_token FROM users WHERE id = 3;
```

Поле `fcm_token` должно быть заполнено.

## Если ничего не помогает

1. **Проверьте логи сервера:**
   ```bash
   tail -f storage/logs/laravel.log
   ```

2. **Проверьте конфигурацию Passport:**
   - Убедитесь, что Passport правильно настроен
   - Проверьте таблицу `oauth_access_tokens` в базе данных

3. **Попробуйте другой OAuth токен:**
   - Выйдите и войдите снова
   - Получите новый токен

4. **Проверьте, что токен действительно имеет scope 'user':**
   ```sql
   SELECT id, user_id, scopes, expires_at 
   FROM oauth_access_tokens 
   WHERE user_id = 3 
   ORDER BY created_at DESC 
   LIMIT 1;
   ```
   В поле `scopes` должно быть `["user"]`.

