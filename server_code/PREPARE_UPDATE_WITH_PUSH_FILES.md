# Подготовка обновления с сохранением файлов push-уведомлений

## 💡 Идея

Перед применением обновления скопировать все файлы, связанные с push-уведомлениями, в папку `Update`, чтобы они автоматически включились в обновление и не были перезаписаны.

---

## 📋 План действий

### Шаг 1: Скачать и распаковать Update.zip

```bash
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

# Создайте временную папку
mkdir -p /tmp/update_prepare
cd /tmp/update_prepare

# Скачайте Update.zip (если еще не скачали)
# wget https://www.dropbox.com/scl/fi/z0uaxk0s9g1z7yj2y4iss/Update.zip?rlkey=rrsdyw6r1q1f9f9vafb5y5csgcx&st=lkv9o9cb&dl=1 -O Update.zip

# Распакуйте Update.zip
unzip Update.zip -d Update
cd Update
```

### Шаг 2: Скопировать файлы push-уведомлений в Update

```bash
# Вернитесь в корень проекта
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

# Скопируйте критически важные файлы в Update
cp service-account.json Update/
cp app/Services/PushNotificationService.php Update/app/Services/
cp app/Http/Controllers/FcmController.php Update/app/Http/Controllers/

# Скопируйте файлы, которые могут быть изменены обновлением
cp app/Models/User.php Update/app/Models/
cp app/Http/Controllers/OrdersController.php Update/app/Http/Controllers/
cp app/Http/Controllers/SubscriptionEmailsController.php Update/app/Http/Controllers/
cp routes/api.php Update/routes/

# Скопируйте миграцию (если она есть)
cp database/migrations/2025_11_12_045732_add_fcm_token_to_users_table.php Update/database/migrations/ 2>/dev/null || echo "Миграция не найдена"
```

### Шаг 3: Проверить структуру Update

```bash
cd /tmp/update_prepare/Update

# Проверьте, что файлы на месте
ls -la service-account.json
ls -la app/Services/PushNotificationService.php
ls -la app/Http/Controllers/FcmController.php
ls -la app/Models/User.php
ls -la app/Http/Controllers/OrdersController.php
ls -la app/Http/Controllers/SubscriptionEmailsController.php
ls -la routes/api.php
```

### Шаг 4: Создать новый Update.zip с файлами push-уведомлений

```bash
cd /tmp/update_prepare

# Создайте новый архив с включенными файлами push-уведомлений
zip -r Update_with_push_files.zip Update/

# Проверьте содержимое архива
unzip -l Update_with_push_files.zip | grep -E "PushNotification|Fcm|service-account|User\.php|OrdersController|SubscriptionEmails|api\.php"
```

### Шаг 5: Применить обновление

```bash
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

# Создайте резервную копию (на всякий случай)
tar -czf ~/backup_before_update_$(date +%Y%m%d_%H%M%S).tar.gz .

# Примените обновление
unzip -o /tmp/update_prepare/Update_with_push_files.zip

# Или если Update.zip уже распакован в Update/
cp -r /tmp/update_prepare/Update/* .
```

### Шаг 6: Очистить кэш и проверить

```bash
# Очистить все кэши
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# Пересоздать кэш
php artisan config:cache
php artisan route:cache

# Обновить автозагрузчик
composer dump-autoload

# Проверить файлы push-уведомлений
./check_push_files.sh
```

---

## 🔧 Автоматический скрипт

Создайте скрипт `prepare_update_with_push.sh`:

```bash
#!/bin/bash

# Скрипт для подготовки обновления с файлами push-уведомлений

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_ROOT="/var/www/ssboss_shop_usr/data/www/ssboss.shop"
UPDATE_ZIP_PATH="$1"

if [ -z "$UPDATE_ZIP_PATH" ]; then
    echo -e "${RED}Использование: $0 <путь_к_Update.zip>${NC}"
    echo "Пример: $0 ~/Update.zip"
    exit 1
fi

if [ ! -f "$UPDATE_ZIP_PATH" ]; then
    echo -e "${RED}Ошибка: Файл $UPDATE_ZIP_PATH не найден${NC}"
    exit 1
fi

echo -e "${YELLOW}📦 Подготовка обновления с файлами push-уведомлений...${NC}"

# Создаем временную папку
TEMP_DIR="/tmp/update_prepare_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Распаковываем Update.zip
echo -e "${GREEN}📂 Распаковка Update.zip...${NC}"
unzip -q "$UPDATE_ZIP_PATH" -d Update

# Переходим в корень проекта
cd "$PROJECT_ROOT"

# Копируем файлы push-уведомлений
echo -e "${GREEN}📄 Копирование файлов push-уведомлений...${NC}"

# Создаем необходимые директории
mkdir -p "$TEMP_DIR/Update/app/Services"
mkdir -p "$TEMP_DIR/Update/app/Http/Controllers"
mkdir -p "$TEMP_DIR/Update/app/Models"
mkdir -p "$TEMP_DIR/Update/routes"
mkdir -p "$TEMP_DIR/Update/database/migrations"

# Копируем критически важные файлы
if [ -f "service-account.json" ]; then
    cp service-account.json "$TEMP_DIR/Update/"
    echo -e "  ✅ service-account.json"
else
    echo -e "  ${RED}❌ service-account.json не найден${NC}"
fi

if [ -f "app/Services/PushNotificationService.php" ]; then
    cp app/Services/PushNotificationService.php "$TEMP_DIR/Update/app/Services/"
    echo -e "  ✅ app/Services/PushNotificationService.php"
else
    echo -e "  ${RED}❌ app/Services/PushNotificationService.php не найден${NC}"
fi

if [ -f "app/Http/Controllers/FcmController.php" ]; then
    cp app/Http/Controllers/FcmController.php "$TEMP_DIR/Update/app/Http/Controllers/"
    echo -e "  ✅ app/Http/Controllers/FcmController.php"
else
    echo -e "  ${RED}❌ app/Http/Controllers/FcmController.php не найден${NC}"
fi

# Копируем файлы, которые могут быть изменены
if [ -f "app/Models/User.php" ]; then
    cp app/Models/User.php "$TEMP_DIR/Update/app/Models/"
    echo -e "  ✅ app/Models/User.php"
fi

if [ -f "app/Http/Controllers/OrdersController.php" ]; then
    cp app/Http/Controllers/OrdersController.php "$TEMP_DIR/Update/app/Http/Controllers/"
    echo -e "  ✅ app/Http/Controllers/OrdersController.php"
fi

if [ -f "app/Http/Controllers/SubscriptionEmailsController.php" ]; then
    cp app/Http/Controllers/SubscriptionEmailsController.php "$TEMP_DIR/Update/app/Http/Controllers/"
    echo -e "  ✅ app/Http/Controllers/SubscriptionEmailsController.php"
fi

if [ -f "routes/api.php" ]; then
    cp routes/api.php "$TEMP_DIR/Update/routes/"
    echo -e "  ✅ routes/api.php"
fi

# Копируем миграцию
if [ -f "database/migrations/2025_11_12_045732_add_fcm_token_to_users_table.php" ]; then
    cp database/migrations/2025_11_12_045732_add_fcm_token_to_users_table.php "$TEMP_DIR/Update/database/migrations/"
    echo -e "  ✅ Миграция для fcm_token"
fi

# Создаем новый архив
echo -e "${GREEN}📦 Создание нового архива Update_with_push_files.zip...${NC}"
cd "$TEMP_DIR"
zip -r Update_with_push_files.zip Update/ > /dev/null

echo -e "${GREEN}✅ Готово!${NC}"
echo -e "${YELLOW}📁 Новый архив: $TEMP_DIR/Update_with_push_files.zip${NC}"
echo ""
echo -e "${YELLOW}📋 Следующие шаги:${NC}"
echo -e "  1. Проверьте содержимое архива:"
echo -e "     unzip -l $TEMP_DIR/Update_with_push_files.zip | grep -E 'PushNotification|Fcm|service-account'"
echo ""
echo -e "  2. Примените обновление:"
echo -e "     cd $PROJECT_ROOT"
echo -e "     unzip -o $TEMP_DIR/Update_with_push_files.zip"
echo ""
echo -e "  3. Очистите кэш:"
echo -e "     php artisan config:clear && php artisan cache:clear && composer dump-autoload"
echo ""
echo -e "  4. Проверьте файлы:"
echo -e "     ./check_push_files.sh"

```

---

## ⚠️ Важные замечания

### 1. Конфликты файлов

Если обновление изменяет те же файлы, что и push-уведомления (например, `OrdersController.php`), ваши версии перезапишут версии из обновления. Это может быть хорошо (если обновление не добавляет важные изменения), но может быть и проблемой.

**Решение:** После обновления проверьте, не были ли добавлены новые методы или функциональность в обновленных файлах, и при необходимости объедините изменения вручную.

### 2. Структура Update.zip

Убедитесь, что структура папок в `Update.zip` соответствует структуре вашего проекта. Если обновление использует другую структуру, скорректируйте пути при копировании.

### 3. Проверка перед применением

Перед применением обновления проверьте содержимое `Update.zip`:

```bash
unzip -l Update.zip | head -50
```

Это покажет структуру файлов и поможет понять, какие файлы будут обновлены.

---

## ✅ Преимущества этого подхода

1. ✅ **Автоматическое включение** - файлы push-уведомлений автоматически включены в обновление
2. ✅ **Минимум ручной работы** - не нужно восстанавливать файлы после обновления
3. ✅ **Безопасность** - файлы push-уведомлений гарантированно сохранятся
4. ✅ **Простота** - один архив содержит всё необходимое

---

## 🔍 Проверка после обновления

После применения обновления обязательно проверьте:

1. **Файлы на месте:**
   ```bash
   ./check_push_files.sh
   ```

2. **Push-уведомления работают:**
   - Запустите мобильное приложение
   - Измените статус заказа в админке
   - Проверьте логи: `tail -f storage/logs/laravel.log | grep -i "push\|fcm"`

3. **Нет ошибок:**
   ```bash
   tail -n 100 storage/logs/laravel.log | grep -i "error"
   ```

---

**Дата создания:** 2025-12-01  
**Версия:** 1.0

