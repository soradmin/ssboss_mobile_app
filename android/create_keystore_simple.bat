@echo off
REM Простой скрипт для создания keystore
REM Использование: .\create_keystore_simple.bat

echo ==========================================
echo Создание keystore для SSBOSS
echo ==========================================
echo.

REM Используем переменную окружения USERPROFILE (более надежно)
set KEYSTORE_PATH=%USERPROFILE%\ssboss-keystore.jks

echo Keystore будет создан по пути:
echo %KEYSTORE_PATH%
echo.
echo Если этот путь не работает, keystore будет создан в папке проекта:
echo %CD%\ssboss-keystore.jks
echo.

pause

REM Пробуем создать в папке пользователя
keytool -genkey -v -keystore "%KEYSTORE_PATH%" -keyalg RSA -keysize 2048 -validity 10000 -alias upload

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Не удалось создать в папке пользователя, пробуем в папке проекта...
    echo.
    set KEYSTORE_PATH=%CD%\ssboss-keystore.jks
    keytool -genkey -v -keystore "%KEYSTORE_PATH%" -keyalg RSA -keysize 2048 -validity 10000 -alias upload
)

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ==========================================
    echo Keystore успешно создан!
    echo ==========================================
    echo.
    echo Путь: %KEYSTORE_PATH%
    echo Alias: upload
    echo.
    echo Теперь создайте файл android\key.properties:
    echo.
    echo storePassword=ваш_пароль
    echo keyPassword=ваш_пароль
    echo keyAlias=upload
    echo.
    REM Формируем путь с двойными слешами для key.properties
    set KEYSTORE_PATH_ESCAPED=%KEYSTORE_PATH:\=\\%
    echo storeFile=%KEYSTORE_PATH_ESCAPED%
    echo.
    echo Замените "ваш_пароль" на пароль, который вы ввели выше!
    echo.
    echo ИЛИ скопируйте этот путь (замените одинарные слеши на двойные):
    echo %KEYSTORE_PATH%
    echo.
) else (
    echo.
    echo ==========================================
    echo Ошибка при создании keystore
    echo ==========================================
    echo.
    echo Попробуйте создать вручную:
    echo.
    echo keytool -genkey -v -keystore ssboss-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
    echo.
    echo Это создаст keystore в текущей папке (android\)
    echo.
)

pause

