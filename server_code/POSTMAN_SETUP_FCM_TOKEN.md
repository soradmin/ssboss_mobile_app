# Настройка Postman для тестирования FCM токена

## Проблема: "Error: Header name must be a valid HTTP token ["Authorization: Bearer"]"

Эта ошибка возникает, когда заголовок Authorization заполнен неправильно в Postman.

---

## ✅ Правильная настройка Postman

### Вариант 1: Использование вкладки "Authorization" (рекомендуется)

1. **Откройте вкладку "Authorization"** (не "Headers"!)
2. **Выберите тип:** `Bearer Token`
3. **В поле "Token":** вставьте ваш `user_token` (без слова "Bearer" - оно добавится автоматически)
4. **Отправьте запрос**

**Пример:**
```
Type: Bearer Token
Token: dE6JpCiHQnWIP9GNmqr0os:APA91bH-hWkPfcUWRTDS9wrZuPFfDkKLEk95fhbdAehi-SuJyL2xHXZJXwykNVJAKaOV3IgoK00t7aCScy7wkfm2whnML1G-L5iS89ztrYFtTuLnm340JAK
```

---

### Вариант 2: Использование вкладки "Headers"

1. **Откройте вкладку "Headers"**
2. **Добавьте заголовок:**
   - **Key:** `Authorization` (только это слово, без "Bearer"!)
   - **Value:** `Bearer {ваш_user_token}` (здесь уже с "Bearer" и пробелом)

**Пример:**
```
Key: Authorization
Value: Bearer dE6JpCiHQnWIP9GNmqr0os:APA91bH-hWkPfcUWRTDS9wrZuPFfDkKLEk95fhbdAehi-SuJyL2xHXZJXwykNVJAKaOV3IgoK00t7aCScy7wkfm2whnML1G-L5iS89ztrYFtTuLnm340JAK
```

**⚠️ Важно:** 
- В поле "Key" должно быть только `Authorization`
- В поле "Value" должно быть `Bearer {token}` (с пробелом после Bearer)

---

## ❌ Неправильная настройка (вызывает ошибку)

**НЕПРАВИЛЬНО:**
```
Key: Authorization: Bearer
Value: dE6JpCiHQnWIP9GNmqr0os...
```

**НЕПРАВИЛЬНО:**
```
Key: Authorization Bearer
Value: dE6JpCiHQnWIP9GNmqr0os...
```

---

## Полная настройка запроса

### ⚠️ ВАЖНО: Полный URL и правильный путь

**Если вы получаете HTML вместо JSON** - это означает, что запрос попадает на фронтенд (Nuxt.js), а не на API.

**Проблема:** Возможно, на вашем сервере API находится по другому пути или требуется дополнительная настройка.

### Варианты правильного URL:

#### Вариант 1: Стандартный путь Laravel API
```
https://ssboss.shop/api/v1/user/fcm-token
```

#### Вариант 2: Если API на поддомене
```
https://api.ssboss.shop/v1/user/fcm-token
```

#### Вариант 3: Если используется другой префикс
```
https://ssboss.shop/api/v1/user/fcm-token
```

### 🔍 Как проверить правильный путь?

1. **Проверьте другие API запросы** - какой URL они используют?
   - Например, логин: `POST /api/v1/user/signin`
   - Если он работает, используйте тот же базовый URL

2. **Проверьте конфигурацию сервера:**
   - Nginx/Apache конфигурацию
   - Может быть настроен редирект на фронтенд

3. **Попробуйте добавить заголовок:**
   ```
   Accept: application/json
   ```

### Endpoint (полный URL)
```
https://ssboss.shop/api/v1/user/fcm-token
```
(замените на ваш реальный домен и проверьте правильность пути)

### ⚠️ Если всё равно получаете HTML:

Добавьте заголовок `Accept: application/json`:
```
Accept: application/json
Content-Type: application/json
Authorization: Bearer {token}
```

### Headers (если используете вкладку Headers)
```
Authorization: Bearer {ваш_user_token}
Content-Type: application/json
Accept: application/json
```

### Body (вкладка Body → raw → JSON)
```json
{
  "fcm_token": "dE6JpCiHQnWIP9GNmqr0os:APA91bH-hWkPfcUWRTDS9wrZuPFfDkKLEk95fhbdAehi-SuJyL2xHXZJXwykNVJAKaOV3IgoK00t7aCScy7wkfm2whnML1G-L5iS89ztrYFtTuLnm340JAK",
  "device_type": "android"
}
```

---

## Как получить user_token?

### Вариант 1: Из мобильного приложения
1. Запустите приложение
2. Войдите в аккаунт
3. Проверьте логи приложения - там должен быть user_token
4. Или проверьте в SharedPreferences/хранилище приложения

### Вариант 2: Через API логина
1. Отправьте запрос на логин:
   ```
   POST /api/v1/user/signin
   Body: {
     "email": "user@example.com",
     "password": "password"
   }
   ```
2. В ответе будет `token` - это и есть `user_token`

### Вариант 3: Из базы данных
```sql
SELECT id, email, remember_token FROM users WHERE email = 'user@example.com';
```
(Но обычно используется другой токен для API)

---

## Ожидаемый успешный ответ

```json
{
  "success": true,
  "data": {
    "message": "FCM token registered",
    "user_id": 123
  }
}
```

---

## Проверка в базе данных

После успешной отправки проверьте:
```sql
SELECT id, email, fcm_token FROM users WHERE id = 123;
```

Поле `fcm_token` должно быть заполнено.

---

## Альтернатива: Использование user_token в Body (для гостевых пользователей)

✅ **Теперь поддерживается!** Если у вас нет OAuth токена, можно передать `user_token` в теле запроса:

**Body:**
```json
{
  "fcm_token": "dE6JpCiHQnWIP9GNmqr0os:APA91bH...",
  "device_type": "android",
  "user_token": "ваш_guest_user_token"
}
```

В этом случае заголовок Authorization **НЕ обязателен**.

**Примечание:** `user_token` - это токен, который используется для гостевых пользователей в вашем приложении (не OAuth токен).

---

## Частые ошибки

1. **"Unauthorized"** - неправильный или отсутствующий токен
2. **"Header name must be a valid HTTP token"** - неправильный формат заголовка Authorization
3. **"FCM token registration failed"** - ошибка на сервере (проверьте логи)

---

## Проверка логов сервера

Если что-то не работает, проверьте логи:
```bash
tail -f storage/logs/laravel.log | grep "FCM token"
```

Должна быть запись:
```
FCM token updated for user 123
```

