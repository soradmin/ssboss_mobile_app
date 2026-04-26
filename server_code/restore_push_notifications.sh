#!/bin/bash

# Скрипт для автоматического восстановления push-уведомлений после обновления

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_ROOT="/var/www/ssboss_shop_usr/data/www/ssboss.shop"

echo -e "${YELLOW}🔧 Восстановление push-уведомлений после обновления...${NC}"

cd "$PROJECT_ROOT"

# Шаг 1: Восстановить fcm_token в User.php
echo -e "${GREEN}📄 Шаг 1: Восстановление fcm_token в User.php...${NC}"

if grep -q "'fcm_token'" app/Models/User.php; then
    echo -e "  ✅ fcm_token уже присутствует в User.php"
else
    echo -e "  🔄 Добавление fcm_token в User.php..."
    sed -i "s/'viewed'\]/'viewed', 'fcm_token']/" app/Models/User.php
    echo -e "  ✅ fcm_token добавлен в User.php"
fi

# Шаг 2: Восстановить маршруты в routes/api.php
echo -e "${GREEN}📄 Шаг 2: Восстановление маршрутов FCM в routes/api.php...${NC}"

if grep -q "fcm-token\|FcmController" routes/api.php; then
    echo -e "  ✅ Маршруты FCM уже присутствуют в routes/api.php"
else
    echo -e "  🔄 Добавление маршрутов FCM в routes/api.php..."
    
    # Найдем строку с logout в группе user
    LOGOUT_LINE=$(grep -n "Route::get('logout'" routes/api.php | head -1 | cut -d: -f1)
    
    if [ -z "$LOGOUT_LINE" ]; then
        echo -e "  ${RED}❌ Не найдена строка с logout. Добавьте маршруты вручную.${NC}"
    else
        # Добавим маршруты после logout
        sed -i "${LOGOUT_LINE}a\\            Route::post('fcm-token', [\\\\App\\\\Http\\\\Controllers\\\\FcmController::class, 'registerToken']);\\n            Route::delete('fcm-token', [\\\\App\\\\Http\\\\Controllers\\\\FcmController::class, 'removeToken']);" routes/api.php
        echo -e "  ✅ Маршруты FCM добавлены в routes/api.php"
    fi
fi

# Шаг 3: Проверить FcmController.php
echo -e "${GREEN}📄 Шаг 3: Проверка FcmController.php...${NC}"

if [ -f "app/Http/Controllers/FcmController.php" ]; then
    echo -e "  ✅ FcmController.php существует"
else
    echo -e "  ${RED}❌ FcmController.php не найден. Создайте его вручную по инструкции.${NC}"
fi

# Шаг 4: Исправить путь к Firebase credentials в .env
echo -e "${GREEN}📄 Шаг 4: Исправление пути к Firebase credentials в .env...${NC}"

if grep -q "FIREBASE_CREDENTIALS=service-account.json" .env; then
    echo -e "  ✅ Путь к Firebase credentials правильный"
else
    echo -e "  🔄 Исправление пути к Firebase credentials..."
    sed -i 's|FIREBASE_CREDENTIALS=.*|FIREBASE_CREDENTIALS=service-account.json|' .env
    echo -e "  ✅ Путь к Firebase credentials исправлен"
fi

# Шаг 5: Проверить PushNotificationService.php
echo -e "${GREEN}📄 Шаг 5: Проверка PushNotificationService.php...${NC}"

if [ -f "app/Services/PushNotificationService.php" ]; then
    if grep -q "ssboss-940a1" app/Services/PushNotificationService.php; then
        echo -e "  ✅ PushNotificationService.php существует и содержит правильный project_id"
    else
        echo -e "  ${YELLOW}⚠️  PushNotificationService.php существует, но project_id может быть неправильным${NC}"
    fi
else
    echo -e "  ${RED}❌ PushNotificationService.php не найден. Восстановите из резервной копии.${NC}"
fi

# Шаг 6: Проверить service-account.json
echo -e "${GREEN}📄 Шаг 6: Проверка service-account.json...${NC}"

if [ -f "service-account.json" ]; then
    if grep -q '"project_id": "ssboss-940a1"' service-account.json; then
        echo -e "  ✅ service-account.json существует и содержит правильный project_id"
    else
        echo -e "  ${YELLOW}⚠️  service-account.json существует, но project_id может быть неправильным${NC}"
    fi
else
    echo -e "  ${RED}❌ service-account.json не найден. Восстановите из резервной копии.${NC}"
fi

# Шаг 7: Очистить кэш
echo -e "${GREEN}📄 Шаг 7: Очистка кэша...${NC}"

php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear
php artisan config:cache
php artisan route:cache
composer dump-autoload

echo -e "  ✅ Кэш очищен"

# Итоговая проверка
echo ""
echo -e "${GREEN}✅ Восстановление завершено!${NC}"
echo ""
echo -e "${YELLOW}📋 Проверьте результаты:${NC}"
echo -e "  1. grep 'fcm_token' app/Models/User.php"
echo -e "  2. grep 'fcm-token' routes/api.php"
echo -e "  3. ls -la app/Http/Controllers/FcmController.php"
echo -e "  4. grep 'FIREBASE' .env"
echo ""
echo -e "${YELLOW}📋 Следующие шаги:${NC}"
echo -e "  1. Протестируйте push-уведомления"
echo -e "  2. Проверьте логи: tail -f storage/logs/laravel.log | grep -i 'push\|fcm'"

