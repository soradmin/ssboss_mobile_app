# 🚀 Краткая инструкция по безопасному обновлению

## ⚡ Быстрый старт

### Шаг 1: Создайте резервную копию

```bash
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop
chmod +x backup_push_files.sh
./backup_push_files.sh
```

### Шаг 2: Примените обновление

```bash
# Распакуйте Update.zip в корень проекта
unzip -o Update.zip
```

### Шаг 3: Проверьте файлы

```bash
chmod +x check_push_files.sh
./check_push_files.sh
```

### Шаг 4: Если что-то сломалось - восстановите

```bash
chmod +x restore_push_files.sh
./restore_push_files.sh ~/backup_push_files_YYYYMMDD_HHMMSS
```

### Шаг 5: Очистите кэш

```bash
php artisan config:clear
php artisan cache:clear
php artisan route:clear
composer dump-autoload
```

---

## 📋 Что сохраняется в резервной копии

✅ **Критически важные файлы:**
- `service-account.json` - Учетные данные Firebase
- `app/Services/PushNotificationService.php` - Сервис push-уведомлений
- `app/Http/Controllers/FcmController.php` - Контроллер FCM токенов

✅ **Файлы, которые могут быть изменены:**
- `app/Models/User.php` - Модель пользователя
- `app/Http/Controllers/OrdersController.php` - Контроллер заказов
- `app/Http/Controllers/SubscriptionEmailsController.php` - Контроллер рассылок
- `routes/api.php` - Маршруты API

---

## ⚠️ Риски обновления

### Низкий риск:
- Обновление затрагивает только админку (переводы)
- Файлы push-уведомлений обычно не затрагиваются

### Средний риск:
- Обновление может изменить контроллеры (OrdersController, SubscriptionEmailsController)
- Может измениться routes/api.php

### Высокий риск (маловероятно):
- Обновление может удалить кастомные файлы (PushNotificationService, FcmController)
- Может измениться структура проекта

---

## ✅ Рекомендации

1. **Всегда создавайте резервную копию перед обновлением**
2. **Проверяйте файлы после обновления** с помощью `check_push_files.sh`
3. **Восстанавливайте файлы только при необходимости**
4. **Тестируйте push-уведомления после обновления**

---

## 📞 Если что-то пошло не так

1. Проверьте логи: `tail -n 100 storage/logs/laravel.log | grep -i "push\|fcm\|error"`
2. Восстановите файлы: `./restore_push_files.sh ~/backup_push_files_YYYYMMDD_HHMMSS`
3. Очистите кэш: `php artisan config:clear && php artisan cache:clear && composer dump-autoload`
4. Проверьте снова: `./check_push_files.sh`

---

**Подробная инструкция:** См. `SAFE_UPDATE_INSTRUCTIONS.md`

