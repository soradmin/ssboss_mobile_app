# Исправление конфигурации .env

## Проблема

В `.env` файле на сервере указан старый `FIREBASE_PROJECT_ID=augmented-tract-380310`, хотя в `service-account.json` правильный `ssboss-940a1`.

Проверка показала:
```php
env('FIREBASE_PROJECT_ID', 'ssboss-940a1') // Возвращает "augmented-tract-380310"
```

## Решение

### Шаг 1: Обновить .env файл на сервере

Откройте файл `.env` на сервере:
```bash
nano .env
# или
vi .env
```

Найдите строку с `FIREBASE_PROJECT_ID` и обновите её:
```env
FIREBASE_PROJECT_ID=ssboss-940a1
```

Если строки нет, добавьте её в конец файла:
```env
FIREBASE_CREDENTIALS=service-account.json
FIREBASE_PROJECT_ID=ssboss-940a1
```

Сохраните файл (в nano: `Ctrl+O`, `Enter`, `Ctrl+X`; в vi: `:wq`)

### Шаг 2: Пересоздать автозагрузку и очистить кэши

```bash
# Пересоздать автозагрузку классов (ВАЖНО после создания новых классов!)
composer dump-autoload

# Очистить кэши Laravel
php artisan config:clear
php artisan cache:clear
php artisan config:cache  # Опционально: пересоздать кэш конфигурации
```

### Шаг 3: Проверить, что изменения применились

```bash
php artisan tinker
```

Затем выполните:
```php
env('FIREBASE_PROJECT_ID', 'ssboss-940a1')
// Должно вернуть: "ssboss-940a1"
```

### Шаг 4: Проверить инициализацию сервиса

В tinker:
```php
$service = app(\App\Services\PushNotificationService::class);
// Если ошибок нет, сервис инициализирован успешно
```

### Шаг 5: Проверить права service account в Google Cloud

Убедитесь, что service account `firebase-adminsdk-fbsvc@ssboss-940a1.iam.gserviceaccount.com` имеет роль:
- **Firebase Cloud Messaging Admin**

В Google Cloud Console:
1. Откройте https://console.cloud.google.com/
2. Выберите проект **`ssboss-940a1`**
3. IAM & Admin → IAM
4. Найдите `firebase-adminsdk-fbsvc@ssboss-940a1.iam.gserviceaccount.com`
5. Убедитесь, что есть роль **Firebase Cloud Messaging Admin**

### Шаг 6: Тестовая отправка

После всех изменений попробуйте отправить тестовое уведомление или изменить статус заказа, затем проверьте логи:

```bash
tail -n 30 storage/logs/laravel.log | grep -i "push\|fcm\|firebase"
```

## Альтернатива: Использовать значение по умолчанию

Если не хотите менять `.env`, можно удалить строку `FIREBASE_PROJECT_ID` из `.env`, и код будет использовать значение по умолчанию `ssboss-940a1` из `PushNotificationService.php`.

Но лучше явно указать в `.env` для ясности.

## Проверка всех компонентов

После исправления выполните:

```bash
# 1. Проверить .env
grep FIREBASE .env

# 2. Проверить service-account.json
cat service-account.json | grep project_id

# 3. Проверить через tinker
php artisan tinker --execute="echo env('FIREBASE_PROJECT_ID', 'ssboss-940a1');"

# 4. Очистить кэш
php artisan config:clear && php artisan cache:clear
```

Все должно указывать на `ssboss-940a1`.

