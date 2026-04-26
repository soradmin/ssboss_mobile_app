# Инструкция по безопасному обновлению бэкенда

## ⚠️ ВАЖНО: Сохранение функциональности Push-уведомлений

Перед обновлением бэкенда необходимо сохранить все файлы, связанные с push-уведомлениями, чтобы не потерять настройки Firebase и функциональность.

---

## 📋 Файлы, которые НУЖНО сохранить перед обновлением

### 1. **Критически важные файлы (обязательно сохранить):**

#### `service-account.json`
- **Путь:** `server_code/service-account.json` (в корне проекта)
- **Важность:** ⚠️ КРИТИЧЕСКИ ВАЖНО
- **Содержит:** Учетные данные Firebase для проекта `ssboss-940a1`
- **Действие:** Скопировать в безопасное место

#### `app/Services/PushNotificationService.php`
- **Путь:** `server_code/app/Services/PushNotificationService.php`
- **Важность:** ⚠️ КРИТИЧЕСКИ ВАЖНО
- **Содержит:** Всю логику отправки push-уведомлений
- **Действие:** Скопировать в безопасное место

#### `app/Http/Controllers/FcmController.php`
- **Путь:** `server_code/app/Http/Controllers/FcmController.php`
- **Важность:** ⚠️ ВАЖНО
- **Содержит:** Логику регистрации FCM токенов
- **Действие:** Скопировать в безопасное место

### 2. **Файлы, которые могут быть изменены обновлением (проверить после обновления):**

#### `app/Models/User.php`
- **Путь:** `server_code/app/Models/User.php`
- **Проверить:** Поле `fcm_token` в массиве `$fillable` (строка 30)
- **Должно быть:** `'fcm_token'` в списке `$fillable`

#### `app/Http/Controllers/OrdersController.php`
- **Путь:** `server_code/app/Http/Controllers/OrdersController.php`
- **Проверить:** Использование `PushNotificationService` в методе `updateStatus()`
- **Должно быть:** Вызов `$pushService->sendOrderStatusUpdate()`

#### `app/Http/Controllers/SubscriptionEmailsController.php`
- **Путь:** `server_code/app/Http/Controllers/SubscriptionEmailsController.php`
- **Проверить:** Использование `PushNotificationService` в методе `sendSubscriptionEmail()`
- **Должно быть:** Вызов `$pushService->sendPromotionNotification()`

#### `routes/api.php`
- **Путь:** `server_code/routes/api.php`
- **Проверить:** Маршруты для FCM токенов (строки 804-805)
- **Должно быть:**
  ```php
  Route::post('fcm-token', [\App\Http\Controllers\FcmController::class, 'registerToken']);
  Route::delete('fcm-token', [\App\Http\Controllers\FcmController::class, 'removeToken']);
  ```

### 3. **Миграция базы данных (обычно не затрагивается обновлением):**

#### `database/migrations/2025_11_12_045732_add_fcm_token_to_users_table.php`
- **Путь:** `server_code/database/migrations/2025_11_12_045732_add_fcm_token_to_users_table.php`
- **Важность:** ⚠️ ВАЖНО (если обновление удалит миграции)
- **Содержит:** Миграцию для добавления поля `fcm_token` в таблицу `users`
- **Действие:** Скопировать в безопасное место

### 4. **Файл конфигурации `.env`:**

#### `.env`
- **Путь:** `server_code/.env` (в корне проекта)
- **Проверить:** Переменные окружения Firebase (если они есть):
  ```env
  FIREBASE_CREDENTIALS=service-account.json
  FIREBASE_PROJECT_ID=ssboss-940a1
  ```
- **Действие:** Записать текущие значения перед обновлением

---

## 🔄 Пошаговая инструкция по обновлению

### Шаг 1: Создание резервной копии

**На сервере выполните:**

```bash
# Перейдите в корень проекта
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

# Создайте папку для резервной копии
mkdir -p ~/backup_before_update_$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=~/backup_before_update_$(date +%Y%m%d_%H%M%S)

# Скопируйте критически важные файлы
cp service-account.json $BACKUP_DIR/
cp app/Services/PushNotificationService.php $BACKUP_DIR/
cp app/Http/Controllers/FcmController.php $BACKUP_DIR/
cp app/Models/User.php $BACKUP_DIR/
cp app/Http/Controllers/OrdersController.php $BACKUP_DIR/
cp app/Http/Controllers/SubscriptionEmailsController.php $BACKUP_DIR/
cp routes/api.php $BACKUP_DIR/
cp database/migrations/2025_11_12_045732_add_fcm_token_to_users_table.php $BACKUP_DIR/ 2>/dev/null || echo "Миграция не найдена"

# Сохраните текущий .env
cp .env $BACKUP_DIR/.env.backup

echo "✅ Резервная копия создана в: $BACKUP_DIR"
```

### Шаг 2: Скачивание и распаковка обновления

```bash
# Скачайте Update.zip (если еще не скачали)
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

# Создайте временную папку для обновления
mkdir -p /tmp/update_extract
cd /tmp/update_extract

# Распакуйте Update.zip (замените путь на ваш)
unzip ~/Update.zip

# Посмотрите, какие файлы будут обновлены
find . -type f | head -20
```

### Шаг 3: Проверка файлов обновления

**Проверьте, какие файлы будут затронуты:**

```bash
# Посмотрите структуру обновления
cd /tmp/update_extract
find . -type f -name "*.php" | grep -E "(PushNotification|Fcm|User\.php|OrdersController|SubscriptionEmails)" || echo "✅ Файлы push-уведомлений не найдены в обновлении"
```

**Если файлы push-уведомлений НЕ найдены в обновлении:**
- ✅ Можно безопасно применять обновление
- После обновления проверьте, что ваши файлы на месте

**Если файлы push-уведомлений найдены в обновлении:**
- ⚠️ Нужно будет восстановить ваши версии после обновления

### Шаг 4: Применение обновления

```bash
# Вернитесь в корень проекта
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

# Создайте резервную копию всего проекта (опционально, но рекомендуется)
tar -czf ~/full_backup_$(date +%Y%m%d_%H%M%S).tar.gz .

# Примените обновление
# Скопируйте файлы из /tmp/update_extract в корень проекта
cp -r /tmp/update_extract/* .

# Или если обновление нужно применить вручную:
# Распакуйте Update.zip прямо в корень проекта
# unzip -o Update.zip
```

### Шаг 5: Восстановление файлов push-уведомлений

**Если обновление затронуло файлы push-уведомлений:**

```bash
# Восстановите критически важные файлы
BACKUP_DIR=~/backup_before_update_$(date +%Y%m%d_%H%M%S)  # Замените на реальную дату

cp $BACKUP_DIR/service-account.json ./
cp $BACKUP_DIR/PushNotificationService.php ./app/Services/
cp $BACKUP_DIR/FcmController.php ./app/Http/Controllers/
```

### Шаг 6: Проверка измененных файлов

**Проверьте файлы, которые могли быть изменены обновлением:**

```bash
# Проверьте User.php
grep -n "fcm_token" app/Models/User.php
# Должно быть: 'fcm_token' в массиве $fillable

# Проверьте OrdersController.php
grep -n "PushNotificationService\|sendOrderStatusUpdate" app/Http/Controllers/OrdersController.php
# Должно быть: использование PushNotificationService

# Проверьте SubscriptionEmailsController.php
grep -n "PushNotificationService\|sendPromotionNotification" app/Http/Controllers/SubscriptionEmailsController.php
# Должно быть: использование PushNotificationService

# Проверьте routes/api.php
grep -n "fcm-token\|FcmController" routes/api.php
# Должно быть: маршруты для FCM токенов
```

### Шаг 7: Восстановление измененных файлов (если нужно)

**Если обновление изменило файлы, которые используют push-уведомления:**

```bash
# Восстановите User.php (если fcm_token удален из $fillable)
# Откройте файл и добавьте 'fcm_token' в массив $fillable

# Восстановите OrdersController.php (если удален вызов PushNotificationService)
cp $BACKUP_DIR/OrdersController.php ./app/Http/Controllers/

# Восстановите SubscriptionEmailsController.php (если удален вызов PushNotificationService)
cp $BACKUP_DIR/SubscriptionEmailsController.php ./app/Http/Controllers/

# Восстановите routes/api.php (если удалены маршруты FCM)
# Откройте файл и добавьте маршруты:
# Route::post('fcm-token', [\App\Http\Controllers\FcmController::class, 'registerToken']);
# Route::delete('fcm-token', [\App\Http\Controllers\FcmController::class, 'removeToken']);
```

### Шаг 8: Очистка кэша Laravel

```bash
# Очистите все кэши
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# Пересоздайте кэш конфигурации
php artisan config:cache
php artisan route:cache

# Обновите автозагрузчик Composer
composer dump-autoload
```

### Шаг 9: Проверка работоспособности

**Проверьте, что все работает:**

```bash
# Проверьте, что service-account.json на месте
ls -la service-account.json

# Проверьте логи на наличие ошибок
tail -n 50 storage/logs/laravel.log | grep -i "error\|fcm\|push"

# Проверьте, что миграция применена (если нужно)
php artisan migrate:status | grep fcm_token
```

### Шаг 10: Тестирование push-уведомлений

**Протестируйте отправку push-уведомления:**

1. Запустите мобильное приложение
2. Войдите в аккаунт
3. Измените статус заказа в админке
4. Проверьте логи:
   ```bash
   tail -f storage/logs/laravel.log | grep -i "push\|fcm"
   ```
5. Должно появиться сообщение: `PushNotificationService: Уведомление отправлено`

---

## 🔍 Что делать, если что-то пошло не так

### Проблема: Push-уведомления не работают после обновления

**Решение:**

1. Проверьте, что `service-account.json` на месте:
   ```bash
   ls -la service-account.json
   cat service-account.json | grep project_id
   # Должно быть: "project_id": "ssboss-940a1"
   ```

2. Проверьте, что `PushNotificationService.php` на месте:
   ```bash
   ls -la app/Services/PushNotificationService.php
   grep "ssboss-940a1" app/Services/PushNotificationService.php
   ```

3. Восстановите файлы из резервной копии:
   ```bash
   BACKUP_DIR=~/backup_before_update_YYYYMMDD_HHMMSS  # Замените на реальную дату
   cp $BACKUP_DIR/service-account.json ./
   cp $BACKUP_DIR/PushNotificationService.php ./app/Services/
   cp $BACKUP_DIR/FcmController.php ./app/Http/Controllers/
   ```

4. Очистите кэш:
   ```bash
   php artisan config:clear
   php artisan cache:clear
   composer dump-autoload
   ```

### Проблема: Ошибка "Class PushNotificationService not found"

**Решение:**

```bash
# Проверьте, что файл существует
ls -la app/Services/PushNotificationService.php

# Обновите автозагрузчик Composer
composer dump-autoload

# Очистите кэш
php artisan config:clear
php artisan cache:clear
```

### Проблема: Ошибка "FCM token not found" или "Route fcm-token not found"

**Решение:**

1. Проверьте маршруты:
   ```bash
   php artisan route:list | grep fcm
   ```

2. Если маршруты отсутствуют, восстановите `routes/api.php`:
   ```bash
   BACKUP_DIR=~/backup_before_update_YYYYMMDD_HHMMSS
   # Откройте routes/api.php и добавьте маршруты вручную
   ```

3. Очистите кэш маршрутов:
   ```bash
   php artisan route:clear
   php artisan route:cache
   ```

---

## ✅ Чек-лист после обновления

- [ ] `service-account.json` на месте и содержит `"project_id": "ssboss-940a1"`
- [ ] `app/Services/PushNotificationService.php` существует
- [ ] `app/Http/Controllers/FcmController.php` существует
- [ ] `app/Models/User.php` содержит `'fcm_token'` в `$fillable`
- [ ] `app/Http/Controllers/OrdersController.php` использует `PushNotificationService`
- [ ] `app/Http/Controllers/SubscriptionEmailsController.php` использует `PushNotificationService`
- [ ] `routes/api.php` содержит маршруты для FCM токенов
- [ ] Кэш Laravel очищен
- [ ] Composer autoloader обновлен
- [ ] Push-уведомления работают (протестировано)

---

## 📞 Если нужна помощь

Если после обновления push-уведомления не работают:

1. Проверьте логи: `tail -n 100 storage/logs/laravel.log | grep -i "push\|fcm\|error"`
2. Восстановите файлы из резервной копии
3. Очистите все кэши
4. Проверьте, что все файлы на месте по чек-листу выше

---

**Дата создания:** 2025-12-01  
**Версия:** 1.0

