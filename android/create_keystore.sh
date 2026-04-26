#!/bin/bash

# Скрипт для создания keystore для подписи Android приложения
# Использование: ./create_keystore.sh

echo "=========================================="
echo "Создание keystore для SSBOSS Android App"
echo "=========================================="
echo ""

# Определяем путь к keystore (в домашней директории)
KEYSTORE_PATH="$HOME/upload-keystore.jks"
KEYSTORE_ALIAS="upload"

echo "Keystore будет создан по пути: $KEYSTORE_PATH"
echo "Алиас ключа: $KEYSTORE_ALIAS"
echo ""
echo "Вам будет предложено ввести:"
echo "1. Пароль для keystore (запомните его!)"
echo "2. Подтверждение пароля"
echo "3. Пароль для ключа (можно использовать тот же)"
echo "4. Подтверждение пароля ключа"
echo "5. Информацию о вашей организации"
echo ""

read -p "Нажмите Enter для продолжения или Ctrl+C для отмены..."

# Создаем keystore
keytool -genkey -v \
  -keystore "$KEYSTORE_PATH" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias "$KEYSTORE_ALIAS"

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Keystore успешно создан!"
    echo "=========================================="
    echo ""
    echo "Путь к keystore: $KEYSTORE_PATH"
    echo "Алиас: $KEYSTORE_ALIAS"
    echo ""
    echo "⚠️  ВАЖНО:"
    echo "1. Сохраните пароли в безопасном месте!"
    echo "2. Создайте файл android/key.properties с данными:"
    echo ""
    echo "   storePassword=ваш_пароль_keystore"
    echo "   keyPassword=ваш_пароль_ключа"
    echo "   keyAlias=$KEYSTORE_ALIAS"
    echo "   storeFile=$KEYSTORE_PATH"
    echo ""
    echo "3. НЕ коммитьте key.properties в git!"
    echo ""
else
    echo ""
    echo "❌ Ошибка при создании keystore"
    exit 1
fi

