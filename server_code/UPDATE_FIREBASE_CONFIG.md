# Обновление конфигурации Firebase

## ✅ Что было сделано

1. **Обновлен `service-account.json`** с новым правильным проектом `ssboss-940a1`
2. **Обновлен `PushNotificationService.php`** - изменен fallback project_id на `ssboss-940a1`
3. **Обновлена документация** с новым project_id

## 📋 Что нужно сделать на сервере

### Шаг 1: Загрузить новый `service-account.json`

Замените файл на сервере:
```bash
# На сервере
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop
# Загрузите новый service-account.json в корень проекта
```

### Шаг 2: Обновить `.env` файл

Добавьте или обновите в `.env`:
```env
FIREBASE_CREDENTIALS=service-account.json
FIREBASE_PROJECT_ID=ssboss-940a1
```

**Важно:** Если переменные не указаны в `.env`, код автоматически использует правильные значения по умолчанию.

### Шаг 3: Пересоздать автозагрузку и очистить кэши

```bash
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

# Пересоздать автозагрузку классов (ВАЖНО после создания новых классов!)
composer dump-autoload

# Очистить кэши Laravel
php artisan config:clear
php artisan cache:clear
```

### Шаг 4: Проверить права service account в Google Cloud Console

1. Откройте [Google Cloud Console](https://console.cloud.google.com/)
2. Выберите проект **`ssboss-940a1`**
3. Перейдите в **IAM & Admin** → **IAM**
4. Найдите service account: `firebase-adminsdk-fbsvc@ssboss-940a1.iam.gserviceaccount.com`
5. Убедитесь, что у него есть роль:
   - **Firebase Cloud Messaging Admin** (рекомендуется)
   - Или **Firebase Admin SDK Administrator Service Agent**

Если роли нет:
1. Нажмите на service account
2. Нажмите **ADD ANOTHER ROLE**
3. Выберите **Firebase Cloud Messaging Admin**
4. Сохраните

### Шаг 5: Проверить работу

#### Вариант 1: Проверить последние записи в логе
```bash
tail -n 50 storage/logs/laravel.log
```

#### Вариант 2: Проверить, есть ли записи с PushNotificationService
```bash
grep -i "PushNotificationService" storage/logs/laravel.log | tail -20
```

Если команда ничего не выводит, значит еще не было попыток отправки уведомлений.

#### Вариант 3: Проверить конфигурацию через Tinker
```bash
php artisan tinker
```

Затем выполните:
```php
// Проверить project_id
env('FIREBASE_PROJECT_ID', 'ssboss-940a1');

// Проверить, что файл существует
file_exists(base_path('service-account.json'));

// Проверить project_id в service-account.json
$json = json_decode(file_get_contents(base_path('service-account.json')), true);
$json['project_id'];
```

#### Вариант 4: Проверить файл service-account.json
```bash
# Проверить project_id
cat service-account.json | grep project_id
# Должно быть: "project_id": "ssboss-940a1"
```

#### Вариант 5: Отправить тестовое уведомление
Чтобы увидеть записи в логе, нужно отправить тестовое уведомление:
- Через API: `POST /api/v1/admin/push-test` (см. TESTING_PUSH_NOTIFICATIONS.md)
- Или изменить статус заказа в админ-панели

После отправки проверьте логи:
```bash
tail -n 20 storage/logs/laravel.log | grep -i "push\|fcm\|firebase"
```

При успешной отправке должны появиться записи:
```
✅ PushNotificationService: Уведомление отправлено
```

## 🔍 Проверка конфигурации

### Проверить project_id в service-account.json:
```bash
cat service-account.json | grep project_id
# Должно быть: "project_id": "ssboss-940a1"
```

### Проверить переменные окружения:
```bash
php artisan tinker
>>> env('FIREBASE_PROJECT_ID', 'ssboss-940a1')
# Должно вернуть: "ssboss-940a1"
```

## 📝 Примечания

- Новый service account: `firebase-adminsdk-fbsvc@ssboss-940a1.iam.gserviceaccount.com`
- Старый service account больше не используется
- Все ссылки на старый проект `augmented-tract-380310` обновлены на `ssboss-940a1`

