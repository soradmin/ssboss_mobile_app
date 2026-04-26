# Исправление проблем с сайтом

## Возможные причины

Изменения в Firebase не должны влиять на изображения и авторизацию. Возможные причины:

1. **Кэш Laravel** - нужно очистить все кэши
2. **Символическая ссылка storage** - могла сломаться
3. **Права доступа к файлам** - могли измениться
4. **Проблемы с .env** - возможно, при редактировании что-то сломалось
5. **Кэш браузера** - старые версии страниц

## Быстрое исправление

### ⚡ Шаг 1: Пересоздать автозагрузку Composer (ЧАСТО РЕШАЕТ ПРОБЛЕМУ!)

```bash
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

# Пересоздать автозагрузку классов
composer dump-autoload
```

**Это особенно важно после:**
- Создания новых классов (например, `PushNotificationService`)
- Изменения namespace классов
- Добавления новых файлов в `app/` директорию

### Шаг 2: Очистить все кэши Laravel

```bash
# Очистить все кэши
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear

# Пересоздать кэш конфигурации (если нужно)
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

### Шаг 2: Проверить символическую ссылку storage

```bash
# Проверить, существует ли ссылка
ls -la public/storage

# Если ссылки нет или она сломана, пересоздать
php artisan storage:link
```

### Шаг 3: Проверить права доступа

```bash
# Проверить права на storage
ls -la storage/

# Установить правильные права (если нужно)
chmod -R 775 storage/
chmod -R 775 bootstrap/cache/
```

### Шаг 4: Проверить .env файл

```bash
# Проверить, что .env файл не поврежден
cat .env | head -20

# Проверить, что нет синтаксических ошибок
php artisan config:clear
php artisan config:cache
```

### Шаг 5: Проверить логи на ошибки

```bash
# Проверить последние ошибки
tail -n 50 storage/logs/laravel.log | grep -i "error\|exception\|fatal"

# Проверить ошибки веб-сервера (если есть доступ)
tail -n 50 /var/log/nginx/error.log
# или
tail -n 50 /var/log/apache2/error.log
```

### Шаг 6: Очистить кэш браузера

В браузере:
- Нажмите `Ctrl+Shift+R` (Windows/Linux) или `Cmd+Shift+R` (Mac) для жесткой перезагрузки
- Или очистите кэш браузера вручную

## Проверка изображений

### Проверить, где хранятся изображения

```bash
# Проверить папку uploads
ls -la uploads/ | head -20

# Проверить storage/app/public
ls -la storage/app/public/ | head -20

# Проверить public/uploads
ls -la public/uploads/ | head -20
```

### Проверить конфигурацию файлов

В файле `config/filesystems.php` проверьте, где настроены диски для хранения файлов.

## Проверка авторизации

### Проверить сессии

```bash
# Проверить папку сессий
ls -la storage/framework/sessions/

# Очистить старые сессии (осторожно!)
php artisan session:flush
```

### Проверить конфигурацию сессий

В `.env` проверьте:
```env
SESSION_DRIVER=file
# или
SESSION_DRIVER=database
```

### Проверить куки в браузере

В браузере:
1. Откройте DevTools (F12)
2. Application/Storage → Cookies
3. Удалите все куки для домена
4. Попробуйте авторизоваться снова

## Полная перезагрузка (если ничего не помогло)

```bash
# 1. Очистить все кэши
php artisan optimize:clear

# 2. Пересоздать все кэши
php artisan config:cache
php artisan route:cache
php artisan view:cache

# 3. Пересоздать символическую ссылку
rm -f public/storage
php artisan storage:link

# 4. Проверить права
chmod -R 775 storage/
chmod -R 775 bootstrap/cache/

# 5. Перезапустить веб-сервер (если есть доступ)
sudo systemctl restart nginx
# или
sudo systemctl restart apache2
```

## Проверка изменений в .env

Если вы редактировали `.env`, убедитесь, что:

1. **Нет лишних пробелов** в начале/конце строк
2. **Нет пустых строк** с пробелами
3. **Все значения в кавычках**, если содержат пробелы
4. **Нет дублирующихся переменных**

Проверьте:
```bash
# Показать все строки с FIREBASE
grep FIREBASE .env

# Проверить синтаксис (должно быть без ошибок)
php artisan config:clear
```

## Откат изменений (если нужно)

Если проблема критическая и нужно быстро восстановить сайт:

```bash
# 1. Откатить изменения в .env (вернуть старый FIREBASE_PROJECT_ID)
# Отредактируйте .env и верните:
# FIREBASE_PROJECT_ID=augmented-tract-380310

# 2. Очистить кэши
php artisan optimize:clear

# 3. Перезапустить веб-сервер
```

**НО:** Это не должно влиять на изображения и авторизацию. Проблема скорее всего в кэше или правах доступа.

## Диагностика

Выполните все команды и пришлите результаты:

```bash
# 1. Проверить кэши
php artisan optimize:clear && echo "✅ Кэши очищены"

# 2. Проверить storage link
ls -la public/storage && echo "✅ Storage link существует"

# 3. Проверить последние ошибки
tail -n 20 storage/logs/laravel.log | grep -i "error\|exception" && echo "✅ Ошибки найдены" || echo "✅ Ошибок нет"

# 4. Проверить права
ls -ld storage/ bootstrap/cache/ && echo "✅ Права проверены"
```

