@echo off
REM Скрипт для создания keystore для подписи Android приложения (Windows)
REM Использование: .\create_keystore.bat (в PowerShell) или create_keystore.bat (в CMD)

echo ==========================================
echo Создание keystore для SSBOSS Android App
echo ==========================================
echo.

REM Определяем путь к keystore (в домашней директории пользователя)
set KEYSTORE_PATH=%USERPROFILE%\upload-keystore.jks
set KEYSTORE_ALIAS=upload

echo Keystore будет создан по пути: %KEYSTORE_PATH%
echo Алиас ключа: %KEYSTORE_ALIAS%
echo.
echo Вам будет предложено ввести:
echo 1. Пароль для keystore (запомните его!)
echo 2. Подтверждение пароля
echo 3. Пароль для ключа (можно использовать тот же)
echo 4. Подтверждение пароля ключа
echo 5. Информацию о вашей организации
echo.

pause

REM Создаем keystore
keytool -genkey -v -keystore "%KEYSTORE_PATH%" -keyalg RSA -keysize 2048 -validity 10000 -alias "%KEYSTORE_ALIAS%"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ==========================================
    echo Keystore успешно создан!
    echo ==========================================
    echo.
    echo Путь к keystore: %KEYSTORE_PATH%
    echo Алиас: %KEYSTORE_ALIAS%
    echo.
    echo ВАЖНО:
    echo 1. Сохраните пароли в безопасном месте!
    echo 2. Создайте файл android\key.properties с данными:
    echo.
    echo    storePassword=ваш_пароль_keystore
    echo    keyPassword=ваш_пароль_ключа
    echo    keyAlias=%KEYSTORE_ALIAS%
    echo    storeFile=%KEYSTORE_PATH%
    echo.
    echo 3. НЕ коммитьте key.properties в git!
    echo.
) else (
    echo.
    echo Ошибка при создании keystore
    exit /b 1
)

pause

