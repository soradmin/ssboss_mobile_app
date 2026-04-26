# Реализация Push-уведомлений

## Обзор

Реализована централизованная система отправки push-уведомлений через Firebase Cloud Messaging (FCM) для:
- Изменения статуса заказа
- Массовой рассылки акций и промо

## Структура реализации

### 1. Сервис PushNotificationService
**Файл:** `app/Services/PushNotificationService.php`

Централизованный сервис для отправки push-уведомлений с методами:
- `sendToUser()` - отправка одному пользователю
- `sendOrderStatusUpdate()` - отправка при изменении статуса заказа
- `sendToAllUsers()` - массовая рассылка всем пользователям
- `sendPromotionNotification()` - отправка уведомлений об акциях

**Особенности:**
- Обработка ошибок с логированием
- Преобразование данных в строки (требование FCM)
- Задержки при массовой рассылке для избежания перегрузки Firebase
- Поддержка всех типов уведомлений

### 2. Обновлённая модель User
**Файл:** `app/Models/User.php`

Добавлено поле `fcm_token` в `$fillable` для массового присвоения.

### 3. Улучшенный FcmController
**Файл:** `app/Http/Controllers/FcmController.php`

**Методы:**
- `registerToken()` - регистрация FCM токена
  - Поддержка авторизованных пользователей (`auth:user`)
  - Поддержка гостевых пользователей через `user_token`
  - Валидация `device_type` (android/ios)

- `removeToken()` - удаление FCM токена

**Endpoint:** `POST /api/v1/user/fcm-token`

**Пример запроса:**
```json
{
  "fcm_token": "dK8x9Yz2...",
  "device_type": "android"
}
```

### 4. Обновлённый OrdersController
**Файл:** `app/Http/Controllers/OrdersController.php`

**Изменения:**
- Удалён старый метод `sendOrderStatusPushNotification()`
- Удалён метод `getStatusText()` (перенесён в сервис)
- Удалены импорты `Kreait\Firebase\Factory` и `CloudMessage`
- В методе `updateStatus()` используется `PushNotificationService`

**Логика:**
При изменении статуса заказа автоматически отправляется push-уведомление пользователю (если у него есть FCM токен).

### 5. Обновлённый SubscriptionEmailsController
**Файл:** `app/Http/Controllers/SubscriptionEmailsController.php`

**Изменения:**
В методе `sendSubscriptionEmail()` добавлена отправка push-уведомлений параллельно с email рассылкой.

**Логика:**
1. Отправляется email рассылка всем подписчикам
2. Отправляются push-уведомления всем пользователям с FCM токенами
3. Возвращается статистика по обеим рассылкам

### 6. Маршруты
**Файл:** `routes/api.php`

Добавлены маршруты для работы с FCM токенами:
```php
Route::post('fcm-token', [FcmController::class, 'registerToken']);
Route::delete('fcm-token', [FcmController::class, 'removeToken']);
```

**Расположение:** В группе маршрутов с middleware `auth:user`

## Настройка окружения

✅ **Файл `service-account.json` уже существует** в корне проекта `server_code/`

Убедитесь, что в `.env` файле указаны:
```env
FIREBASE_CREDENTIALS=service-account.json
FIREBASE_PROJECT_ID=ssboss-940a1
```

**Важно:**
- Файл `service-account.json` находится в корне проекта `server_code/`
- Путь `FIREBASE_CREDENTIALS` может быть:
  - **Относительным** (если Laravel запускается из `server_code/`): `service-account.json` ✅ (по умолчанию)
  - **Абсолютным**: `/full/path/to/server_code/service-account.json`
- `FIREBASE_PROJECT_ID` должен соответствовать `project_id` из `service-account.json` (сейчас: `ssboss-940a1`)
- Если переменные не указаны в `.env`, код использует значения по умолчанию:
  - `FIREBASE_CREDENTIALS` → `base_path('service-account.json')` (автоматически найдёт файл)
  - `FIREBASE_PROJECT_ID` → `ssboss-940a1`

## Формат уведомлений

### Уведомление о статусе заказа:
```json
{
  "notification": {
    "title": "Статус заказа изменён",
    "body": "Ваш заказ #20251911rfZW3 теперь: Доставлен"
  },
  "data": {
    "order_id": "123",
    "order_number": "20251911rfZW3",
    "status": "4",
    "type": "order_status",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  }
}
```

### Уведомление об акции:
```json
{
  "notification": {
    "title": "Новая акция! 🎉",
    "body": "Скидка 50% на все товары категории Электроника"
  },
  "data": {
    "promotion_id": "456",
    "type": "promotion",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  }
}
```

## Логирование

Все операции логируются в `storage/logs/laravel.log`:
- Успешные отправки
- Ошибки отправки
- Пропущенные отправки (нет токена)
- Статистика массовых рассылок

## Обработка ошибок

- Ошибки отправки push-уведомлений **НЕ прерывают** основную логику:
  - При изменении статуса заказа - статус всё равно обновляется
  - При массовой рассылке - email рассылка продолжается
- Все ошибки логируются для последующего анализа

## Производительность

- При массовой рассылке добавлена задержка 0.1 секунды каждые 100 уведомлений
- Это предотвращает перегрузку Firebase API
- Для больших рассылок рекомендуется использовать очереди (Queue)

## Следующие шаги (опционально)

1. **Очереди (Queue):** Перевести массовые рассылки на очереди для асинхронной обработки
2. **Группировка уведомлений:** Группировать уведомления по типу для лучшего UX
3. **Настройки пользователя:** Добавить возможность отключения push-уведомлений в профиле
4. **Аналитика:** Добавить отслеживание открытий уведомлений
5. **A/B тестирование:** Тестирование различных форматов уведомлений

## Тестирование

### Тестовый endpoint (если нужен):
Можно использовать существующий `PushTestController`:
```
POST /api/v1/admin/push-test
{
  "user_id": 1,
  "title": "Тестовое уведомление",
  "body": "Проверка работы push"
}
```

## Интеграция с мобильным приложением

Мобильное приложение должно:
1. Получать FCM токен при запуске
2. Отправлять токен на сервер через `POST /api/v1/user/fcm-token`
3. Обрабатывать входящие уведомления
4. Навигировать к нужному экрану при нажатии на уведомление

**Формат данных для навигации:**
- `type: "order_status"` → открыть детали заказа (`order_id`)
- `type: "promotion"` → открыть акцию (`promotion_id`)

