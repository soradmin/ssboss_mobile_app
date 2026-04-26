# Финальные шаги по обновлению с сохранением push-уведомлений

## ✅ Что уже сделано

1. ✅ Сохранены все критически важные файлы push-уведомлений
2. ✅ Файлы скопированы в папку `Update` перед обновлением
3. ✅ Файл миграции БД скопирован
4. ✅ Файл `.env` сохранен отдельно (правильно, его нет в Update.zip)

---

## 📋 Финальные шаги по обновлению

### Шаг 1: Проверка файлов в папке Update

Перед применением обновления убедитесь, что все файлы на месте:

```bash
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

# Проверьте критически важные файлы
ls -la Update/service-account.json
ls -la Update/app/Services/PushNotificationService.php
ls -la Update/app/Http/Controllers/FcmController.php

# Проверьте файлы, которые могут быть изменены
ls -la Update/app/Models/User.php
ls -la Update/app/Http/Controllers/OrdersController.php
ls -la Update/app/Http/Controllers/SubscriptionEmailsController.php
ls -la Update/routes/api.php

# Проверьте миграцию
ls -la Update/database/migrations/2025_11_12_045732_add_fcm_token_to_users_table.php
```

### Шаг 2: Создание резервной копии (на всякий случай)

```bash
# Создайте полную резервную копию проекта
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop
tar -czf ~/backup_before_update_$(date +%Y%m%d_%H%M%S).tar.gz .

# Или хотя бы критически важные файлы
mkdir -p ~/backup_push_files_$(date +%Y%m%d_%H%M%S)
cp service-account.json ~/backup_push_files_*/
cp app/Services/PushNotificationService.php ~/backup_push_files_*/
cp app/Http/Controllers/FcmController.php ~/backup_push_files_*/
```

### Шаг 3: Применение обновления

Согласно [официальной документации](https://ishop.web-zed.com/doc/how-to-install.html):

1. **Скопируйте папку Update в корень проекта** (если еще не скопировали):
   ```bash
   cd /var/www/ssboss_shop_usr/data/www/ssboss.shop
   
   # Если Update.zip еще не распакован, распакуйте его
   # unzip Update.zip -d Update
   
   # Или если Update уже распакован, просто скопируйте файлы
   cp -r Update/* .
   ```

2. **Откройте в браузере**: `https://ssboss.shop/update`

3. **Нажмите кнопку "Update"** на странице обновления

4. **Дождитесь завершения обновления**

### Шаг 4: Проверка файлов после обновления

После обновления проверьте, что все файлы push-уведомлений на месте:

```bash
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

# Используйте скрипт проверки (если есть)
./check_push_files.sh

# Или проверьте вручную:
ls -la service-account.json
grep "ssboss-940a1" app/Services/PushNotificationService.php
grep "fcm_token" app/Models/User.php
grep "fcm-token\|FcmController" routes/api.php
```

### Шаг 5: Очистка кэша

```bash
# Очистите все кэши Laravel
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# Пересоздайте кэш
php artisan config:cache
php artisan route:cache

# Обновите автозагрузчик Composer
composer dump-autoload
```

### Шаг 6: Проверка .env файла

Файл `.env` **НЕ должен быть затронут** обновлением, так как его нет в Update.zip. Но проверьте:

```bash
# Убедитесь, что .env на месте и содержит нужные настройки
grep -E "FIREBASE|firebase" .env

# Если настройки Firebase отсутствуют, добавьте их:
# FIREBASE_CREDENTIALS=service-account.json
# FIREBASE_PROJECT_ID=ssboss-940a1
```

### Шаг 7: Проверка миграции БД

Убедитесь, что миграция применена:

```bash
# Проверьте статус миграций
php artisan migrate:status | grep fcm_token

# Если миграция не применена, примените её:
php artisan migrate
```

### Шаг 8: Тестирование push-уведомлений

1. **Запустите мобильное приложение**
2. **Войдите в аккаунт** (FCM токен должен зарегистрироваться)
3. **Измените статус заказа в админке**
4. **Проверьте логи**:
   ```bash
   tail -f storage/logs/laravel.log | grep -i "push\|fcm"
   ```
5. **Должно появиться**: `PushNotificationService: Уведомление отправлено`

---

## ⚠️ Что делать, если что-то пошло не так

### Проблема: Файлы push-уведомлений отсутствуют после обновления

**Решение:**
```bash
# Восстановите из резервной копии
BACKUP_DIR=~/backup_push_files_YYYYMMDD_HHMMSS  # Замените на реальную дату

cp $BACKUP_DIR/service-account.json ./
cp $BACKUP_DIR/PushNotificationService.php ./app/Services/
cp $BACKUP_DIR/FcmController.php ./app/Http/Controllers/

# Очистите кэш
php artisan config:clear
php artisan cache:clear
composer dump-autoload
```

### Проблема: Ошибка "Class PushNotificationService not found"

**Решение:**
```bash
# Обновите автозагрузчик
composer dump-autoload

# Очистите кэш
php artisan config:clear
php artisan cache:clear
```

### Проблема: Ошибка "Route fcm-token not found"

**Решение:**
```bash
# Проверьте routes/api.php
grep "fcm-token\|FcmController" routes/api.php

# Если маршруты отсутствуют, добавьте их вручную в routes/api.php:
# Route::post('fcm-token', [\App\Http\Controllers\FcmController::class, 'registerToken']);
# Route::delete('fcm-token', [\App\Http\Controllers\FcmController::class, 'removeToken']);

# Очистите кэш маршрутов
php artisan route:clear
php artisan route:cache
```

### Проблема: Push-уведомления не работают

**Решение:**
1. Проверьте `service-account.json`:
   ```bash
   cat service-account.json | grep project_id
   # Должно быть: "project_id": "ssboss-940a1"
   ```

2. Проверьте логи:
   ```bash
   tail -n 100 storage/logs/laravel.log | grep -i "push\|fcm\|error"
   ```

3. Проверьте FCM токен в базе данных:
   ```sql
   SELECT id, email, LEFT(fcm_token, 30) as token_preview FROM users WHERE fcm_token IS NOT NULL LIMIT 5;
   ```

---

## ✅ Чек-лист после обновления

- [ ] Все файлы push-уведомлений на месте (проверено `check_push_files.sh`)
- [ ] `service-account.json` содержит `"project_id": "ssboss-940a1"`
- [ ] `app/Services/PushNotificationService.php` существует
- [ ] `app/Http/Controllers/FcmController.php` существует
- [ ] `app/Models/User.php` содержит `'fcm_token'` в `$fillable`
- [ ] `routes/api.php` содержит маршруты для FCM токенов
- [ ] Кэш Laravel очищен
- [ ] Composer autoloader обновлен
- [ ] Миграция БД применена
- [ ] `.env` файл не изменен (проверено)
- [ ] Push-уведомления работают (протестировано)

---

## 📝 Важные замечания

### О файле .env

✅ **Правильно, что вы сохранили .env отдельно!** 

Файл `.env` обычно **НЕ включается** в обновления по следующим причинам:
- Содержит конфиденциальные данные (пароли, ключи API)
- Уникален для каждого сервера
- Может содержать кастомные настройки

**После обновления:**
- Проверьте, что `.env` не был изменен
- Если обновление требует новых переменных окружения, они будут указаны в документации обновления
- Добавьте их вручную в `.env`

### О миграции БД

Если миграция уже была применена ранее, она не будет применена повторно (Laravel отслеживает примененные миграции). Это нормально.

Если миграция не была применена, она будет применена автоматически при следующем запуске `php artisan migrate` или вручную.

---

## 🎉 Готово!

После выполнения всех шагов ваша система будет обновлена, а push-уведомления продолжат работать.

**Дата создания:** 2025-12-01  
**Версия:** 1.0

