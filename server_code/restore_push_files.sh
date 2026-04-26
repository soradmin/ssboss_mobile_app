#!/bin/bash

# Скрипт для восстановления файлов push-уведомлений из резервной копии
# Использование: ./restore_push_files.sh [путь_к_резервной_копии]

set -e

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Получаем путь к резервной копии
if [ -z "$1" ]; then
    echo -e "${YELLOW}Использование: $0 [путь_к_резервной_копии]${NC}"
    echo ""
    echo -e "${YELLOW}Пример:${NC}"
    echo "  $0 ~/backup_push_files_20251201_120000"
    echo ""
    echo -e "${YELLOW}Доступные резервные копии:${NC}"
    ls -d ~/backup_push_files_* 2>/dev/null | tail -5 || echo "  Резервные копии не найдены"
    exit 1
fi

BACKUP_DIR="$1"

# Проверяем, что директория существует
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}❌ Ошибка: Директория $BACKUP_DIR не найдена${NC}"
    exit 1
fi

# Проверяем, что мы в корне проекта Laravel
if [ ! -f "artisan" ]; then
    echo -e "${RED}❌ Ошибка: Файл artisan не найден. Убедитесь, что вы находитесь в корне проекта Laravel.${NC}"
    exit 1
fi

echo -e "${YELLOW}🔄 Восстановление файлов push-уведомлений из резервной копии...${NC}"
echo -e "${YELLOW}📁 Источник: $BACKUP_DIR${NC}"
echo ""

# Восстановление критически важных файлов
echo -e "${GREEN}📄 Восстановление критически важных файлов:${NC}"

# service-account.json
if [ -f "$BACKUP_DIR/service-account.json" ]; then
    cp "$BACKUP_DIR/service-account.json" ./
    echo -e "  ✅ service-account.json восстановлен"
else
    echo -e "  ⚠️  service-account.json не найден в резервной копии"
fi

# PushNotificationService.php
if [ -f "$BACKUP_DIR/app/Services/PushNotificationService.php" ]; then
    mkdir -p app/Services
    cp "$BACKUP_DIR/app/Services/PushNotificationService.php" app/Services/
    echo -e "  ✅ app/Services/PushNotificationService.php восстановлен"
else
    echo -e "  ⚠️  app/Services/PushNotificationService.php не найден в резервной копии"
fi

# FcmController.php
if [ -f "$BACKUP_DIR/app/Http/Controllers/FcmController.php" ]; then
    mkdir -p app/Http/Controllers
    cp "$BACKUP_DIR/app/Http/Controllers/FcmController.php" app/Http/Controllers/
    echo -e "  ✅ app/Http/Controllers/FcmController.php восстановлен"
else
    echo -e "  ⚠️  app/Http/Controllers/FcmController.php не найден в резервной копии"
fi

# Восстановление файлов, которые могут быть изменены
echo -e "${GREEN}📄 Восстановление файлов, которые могут быть изменены обновлением:${NC}"

# User.php
if [ -f "$BACKUP_DIR/app/Models/User.php" ]; then
    read -p "  Восстановить app/Models/User.php? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p app/Models
        cp "$BACKUP_DIR/app/Models/User.php" app/Models/
        echo -e "  ✅ app/Models/User.php восстановлен"
    else
        echo -e "  ⏭️  app/Models/User.php пропущен"
    fi
fi

# OrdersController.php
if [ -f "$BACKUP_DIR/app/Http/Controllers/OrdersController.php" ]; then
    read -p "  Восстановить app/Http/Controllers/OrdersController.php? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p app/Http/Controllers
        cp "$BACKUP_DIR/app/Http/Controllers/OrdersController.php" app/Http/Controllers/
        echo -e "  ✅ app/Http/Controllers/OrdersController.php восстановлен"
    else
        echo -e "  ⏭️  app/Http/Controllers/OrdersController.php пропущен"
    fi
fi

# SubscriptionEmailsController.php
if [ -f "$BACKUP_DIR/app/Http/Controllers/SubscriptionEmailsController.php" ]; then
    read -p "  Восстановить app/Http/Controllers/SubscriptionEmailsController.php? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p app/Http/Controllers
        cp "$BACKUP_DIR/app/Http/Controllers/SubscriptionEmailsController.php" app/Http/Controllers/
        echo -e "  ✅ app/Http/Controllers/SubscriptionEmailsController.php восстановлен"
    else
        echo -e "  ⏭️  app/Http/Controllers/SubscriptionEmailsController.php пропущен"
    fi
fi

# routes/api.php
if [ -f "$BACKUP_DIR/routes/api.php" ]; then
    read -p "  Восстановить routes/api.php? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p routes
        cp "$BACKUP_DIR/routes/api.php" routes/
        echo -e "  ✅ routes/api.php восстановлен"
    else
        echo -e "  ⏭️  routes/api.php пропущен (рекомендуется проверить маршруты FCM вручную)"
    fi
fi

# Миграция
if [ -f "$BACKUP_DIR/database/migrations/2025_11_12_045732_add_fcm_token_to_users_table.php" ]; then
    mkdir -p database/migrations
    cp "$BACKUP_DIR/database/migrations/2025_11_12_045732_add_fcm_token_to_users_table.php" database/migrations/
    echo -e "  ✅ Миграция восстановлена"
fi

echo ""
echo -e "${GREEN}✅ Восстановление завершено!${NC}"
echo ""
echo -e "${YELLOW}📋 Следующие шаги:${NC}"
echo -e "  1. Очистите кэш Laravel:"
echo -e "     php artisan config:clear"
echo -e "     php artisan cache:clear"
echo -e "     php artisan route:clear"
echo ""
echo -e "  2. Обновите автозагрузчик Composer:"
echo -e "     composer dump-autoload"
echo ""
echo -e "  3. Проверьте работоспособность:"
echo -e "     ./check_push_files.sh"
echo ""
echo -e "  4. Протестируйте push-уведомления"

