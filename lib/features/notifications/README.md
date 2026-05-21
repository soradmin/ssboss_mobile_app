# Система Push-уведомлений

## Варианты реализации

### ⚠️ Realtime Database ≠ Push-уведомления

Письмо Firebase про **отключение Realtime Database** (например, проект `ssbossactual`) **не влияет** на push.

Мобильное приложение и сервер используют **Firebase Cloud Messaging** в проекте **`ssboss-940a1`**:
- токен устройства → `POST /user/fcm-token` → поле `users.fcm_token`
- отправка с сервера через `PushNotificationService` + `service-account.json`

Realtime Database в приложении **не используется**. Новые правила RTDB можно оставить для безопасности, но для push они не нужны.

### 1. **Firebase Cloud Messaging (FCM)** ✅ РЕАЛИЗОВАНО
**Описание:** Сервер отправляет уведомления через Firebase Cloud Messaging.

**Преимущества:**
- ✅ Надежная доставка уведомлений
- ✅ Работает даже когда приложение закрыто
- ✅ Бесплатно для большинства случаев
- ✅ Поддержка iOS и Android

**Как работает:**
1. Приложение получает FCM токен при запуске
2. Токен отправляется на сервер через API `/user/fcm-token`
3. Сервер сохраняет токен в базе данных
4. При изменении статуса заказа или создании акции сервер отправляет уведомление через FCM
5. Приложение получает уведомление и показывает его пользователю

**Требования на сервере:**
- Настроенный Firebase проект
- Серверный ключ Firebase (для отправки уведомлений)
- API endpoint для сохранения FCM токенов
- Логика отправки уведомлений при изменении статуса заказа

---

### 2. **Polling (опрос сервера)** - Альтернативный вариант
**Описание:** Приложение периодически проверяет изменения на сервере.

**Преимущества:**
- ✅ Не требует настройки Firebase на сервере
- ✅ Простая реализация

**Недостатки:**
- ❌ Потребляет больше батареи
- ❌ Задержка в получении уведомлений
- ❌ Не работает когда приложение закрыто

**Как работает:**
1. Приложение каждые N секунд (например, 30) делает запрос к API
2. Сервер возвращает список новых событий (изменения статусов, новые акции)
3. Приложение сравнивает с локальным состоянием и показывает уведомления

---

### 3. **WebSocket** - Для real-time обновлений
**Описание:** Постоянное соединение с сервером для мгновенных обновлений.

**Преимущества:**
- ✅ Мгновенные обновления
- ✅ Экономия батареи (по сравнению с polling)

**Недостатки:**
- ❌ Требует поддержку WebSocket на сервере
- ❌ Сложнее в реализации
- ❌ Не работает когда приложение закрыто

---

## Текущая реализация (FCM)

### Структура файлов:
```
lib/features/notifications/
├── services/
│   └── notification_service.dart  # Основной сервис уведомлений
├── providers/
│   └── notification_provider.dart # Riverpod провайдеры
└── README.md                      # Эта документация
```

### Что уже реализовано:

1. ✅ **Инициализация Firebase Messaging**
   - Запрос разрешений на уведомления
   - Получение FCM токена
   - Отправка токена на сервер

2. ✅ **Локальные уведомления**
   - Отображение уведомлений через `flutter_local_notifications`
   - Настройка каналов для Android
   - Обработка нажатий на уведомления

3. ✅ **Обработка сообщений**
   - Foreground (когда приложение открыто)
   - Background (когда приложение в фоне)
   - Terminated (когда приложение закрыто)

4. ✅ **Навигация**
   - Автоматический переход к заказу при нажатии на уведомление
   - Поддержка различных типов уведомлений

---

## Настройка на сервере

### 1. API для сохранения FCM токена

**Endpoint:** `POST /api/v1/user/fcm-token`

**Headers:**
```
Authorization: Bearer {user_token}
Content-Type: application/json
```

**Body:**
```json
{
  "fcm_token": "dK8x9Yz2...",
  "device_type": "android" // или "ios"
}
```

**Response:**
```json
{
  "success": true,
  "message": "FCM token saved"
}
```

### 2. Отправка уведомлений с сервера

#### Пример для PHP (Laravel):

```php
use Illuminate\Support\Facades\Http;

// При изменении статуса заказа
public function updateOrderStatus($orderId, $newStatus) {
    // ... логика обновления статуса ...
    
    // Получаем FCM токен пользователя
    $user = $order->user;
    $fcmToken = $user->fcm_token;
    
    if ($fcmToken) {
        // Отправляем уведомление через Firebase
        $response = Http::withHeaders([
            'Authorization' => 'key=' . config('firebase.server_key'),
            'Content-Type' => 'application/json',
        ])->post('https://fcm.googleapis.com/fcm/send', [
            'to' => $fcmToken,
            'notification' => [
                'title' => 'Статус заказа изменен',
                'body' => "Ваш заказ #{$order->order_number} теперь: {$newStatus}",
                'sound' => 'default',
            ],
            'data' => [
                'order_id' => $orderId,
                'order_number' => $order->order_number,
                'status' => $newStatus,
                'type' => 'order_status',
            ],
        ]);
    }
}
```

#### Пример для Node.js:

```javascript
const admin = require('firebase-admin');

// При изменении статуса заказа
async function updateOrderStatus(orderId, newStatus) {
    // ... логика обновления статуса ...
    
    const user = await getUser(order.userId);
    const fcmToken = user.fcmToken;
    
    if (fcmToken) {
        const message = {
            token: fcmToken,
            notification: {
                title: 'Статус заказа изменен',
                body: `Ваш заказ #${order.orderNumber} теперь: ${newStatus}`,
            },
            data: {
                order_id: orderId.toString(),
                order_number: order.orderNumber,
                status: newStatus,
                type: 'order_status',
            },
        };
        
        await admin.messaging().send(message);
    }
}
```

### 3. Отправка уведомлений об акциях

```php
// При создании новой акции
public function createPromotion($promotion) {
    // ... логика создания акции ...
    
    // Получаем всех пользователей, подписанных на уведомления
    $users = User::whereNotNull('fcm_token')->get();
    
    foreach ($users as $user) {
        Http::withHeaders([
            'Authorization' => 'key=' . config('firebase.server_key'),
            'Content-Type' => 'application/json',
        ])->post('https://fcm.googleapis.com/fcm/send', [
            'to' => $user->fcm_token,
            'notification' => [
                'title' => 'Новая акция! 🎉',
                'body' => $promotion->title,
                'sound' => 'default',
            ],
            'data' => [
                'promotion_id' => $promotion->id,
                'type' => 'promotion',
            ],
        ]);
    }
}
```

---

## Формат данных уведомлений

### Уведомление о статусе заказа:

```json
{
  "notification": {
    "title": "Статус заказа изменен",
    "body": "Ваш заказ #20251911rfZW3 теперь: Доставлен"
  },
  "data": {
    "order_id": "123",
    "order_number": "20251911rfZW3",
    "status": "delivered",
    "type": "order_status"
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
    "type": "promotion"
  }
}
```

---

## Тестирование

### 1. Проверка получения FCM токена:
- Запустите приложение
- Проверьте логи: должно быть `[NOTIFICATIONS] 🔑 FCM токен получен: ...`
- Проверьте, что токен отправлен на сервер

### 2. Тестирование уведомлений:
- Используйте Firebase Console → Cloud Messaging → Send test message
- Или используйте Postman для отправки через FCM API

### 3. Проверка навигации:
- Отправьте тестовое уведомление с `order_id` в data
- Нажмите на уведомление
- Должен открыться экран деталей заказа

---

## Дополнительные возможности

### 1. Группировка уведомлений
Можно группировать уведомления по типу (заказы, акции) для лучшего UX.

### 2. Звуки и вибрация
Настроены по умолчанию, можно кастомизировать в `notification_service.dart`.

### 3. Badge (iOS)
Автоматически обновляется при получении уведомлений.

### 4. Действия в уведомлениях
Можно добавить кнопки действий (например, "Открыть заказ", "Позвонить").

---

## Проблемы и решения

### Проблема: Уведомления не приходят
**Решение:**
1. Проверьте, что Firebase правильно настроен
2. Проверьте, что FCM токен отправлен на сервер
3. Проверьте разрешения на уведомления в настройках устройства
4. Проверьте логи сервера при отправке уведомлений

### Проблема: Навигация не работает
**Решение:**
1. Убедитесь, что `navigatorKey` установлен в `MaterialApp`
2. Проверьте формат данных в уведомлении
3. Проверьте логи при нажатии на уведомление

---

## Следующие шаги

1. ✅ Реализовать сохранение FCM токена на сервере
2. ✅ Настроить отправку уведомлений при изменении статуса заказа
3. ✅ Настроить отправку уведомлений об акциях
4. ⏳ Добавить настройки уведомлений в профиле пользователя
5. ⏳ Реализовать группировку уведомлений
6. ⏳ Добавить действия в уведомлениях

