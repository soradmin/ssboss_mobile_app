# Исправление проблемы с переключением языка в админке

## Проблема

При выборе русского языка в админке, при переходе в раздел (например, "Orders") и возврате обратно, текст становится на английском, хотя русский выбран. После обновления страницы всё снова на русском.

## Решение

Исправление реализовано без обновления системы. Добавлено сохранение выбранного языка в сессии Laravel, чтобы язык сохранялся при переходах между страницами.

### Что было сделано:

1. **Создан middleware `SetAdminLocale`** (`app/Http/Middleware/SetAdminLocale.php`)
   - Сохраняет выбранный язык в сессии
   - Автоматически использует сохраненный язык, если он не передан в запросе

2. **Обновлен метод `localizationAdmin`** в `FrontendController.php`
   - Теперь получает язык из нескольких источников: запрос, сессия, заголовок
   - Автоматически сохраняет язык в сессии при получении
   - Использует язык по умолчанию, если ничего не найдено

3. **Зарегистрирован middleware** в `bootstrap/app.php`
   - Добавлен алиас `admin.locale` для middleware

4. **Применен middleware к маршрутам админки** в `routes/api.php`
   - Все маршруты админки теперь используют middleware для сохранения языка

---

## Инструкция по применению

### Шаг 1: Применить изменения

Файлы, которые нужно обновить:

1. `app/Http/Middleware/SetAdminLocale.php` - **НОВЫЙ ФАЙЛ** (создать)
2. `app/Http/Controllers/FrontendController.php` - обновить метод `localizationAdmin`
3. `bootstrap/app.php` - добавить алиас middleware
4. `routes/api.php` - применить middleware к маршрутам админки

### Шаг 2: Очистить кэш

```bash
cd /var/www/ssboss_shop_usr/data/www/ssboss.shop

# Очистить все кэши
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# Пересоздать кэш
php artisan config:cache
php artisan route:cache

# Обновить автозагрузчик Composer
composer dump-autoload
```

### Шаг 3: Проверить работоспособность

1. Откройте админку в браузере
2. Выберите русский язык
3. Перейдите в раздел "Orders" (или любой другой)
4. Вернитесь на главную страницу (Dashboard)
5. Язык должен остаться русским без необходимости обновления страницы

---

## Как это работает

### До исправления:
1. Пользователь выбирает русский язык
2. Фронтенд отправляет запрос с `locale_code=ru` к `/api/admin/localization`
3. При переходе в другой раздел, фронтенд не передает `locale_code`
4. Бэкенд не знает, какой язык использовать, и возвращает язык по умолчанию (английский)

### После исправления:
1. Пользователь выбирает русский язык
2. Фронтенд отправляет запрос с `locale_code=ru` к `/api/admin/localization`
3. Middleware сохраняет `ru` в сессии Laravel
4. При переходе в другой раздел, даже если фронтенд не передает `locale_code`:
   - Middleware автоматически получает язык из сессии
   - Метод `localizationAdmin` использует язык из сессии
   - Язык остается русским

---

## Технические детали

### Middleware `SetAdminLocale`

```php
// Проверяет наличие locale_code в запросе
$localeCode = $request->input('locale_code') 
    ?? $request->query('locale_code') 
    ?? $request->header('locale_code');

// Сохраняет в сессии, если передан
if ($localeCode) {
    Session::put('admin_locale', $localeCode);
} else {
    // Использует из сессии, если не передан
    $localeCode = Session::get('admin_locale');
}
```

### Метод `localizationAdmin`

```php
// Получает язык из нескольких источников
$langCode = $request->locale_code 
    ?? $request->input('locale_code')
    ?? $request->query('locale_code')
    ?? $request->header('locale_code')
    ?? session('admin_locale'); // Использует сессию

// Сохраняет в сессии при получении
if ($request->locale_code || $request->input('locale_code') || $request->query('locale_code')) {
    session(['admin_locale' => $langCode]);
}
```

---

## Откат изменений (если что-то пошло не так)

Если после применения исправления возникли проблемы:

1. Удалите файл `app/Http/Middleware/SetAdminLocale.php`
2. Откатите изменения в `app/Http/Controllers/FrontendController.php`
3. Откатите изменения в `bootstrap/app.php`
4. Откатите изменения в `routes/api.php`
5. Очистите кэш:
   ```bash
   php artisan config:clear
   php artisan cache:clear
   php artisan route:clear
   composer dump-autoload
   ```

---

## Проверка логов

Если проблема не решена, проверьте логи:

```bash
tail -f storage/logs/laravel.log | grep -i "locale\|language\|admin"
```

Также проверьте, что сессии работают:

```bash
# Проверьте настройки сессий в .env
grep SESSION .env

# Должно быть что-то вроде:
# SESSION_DRIVER=file
# или
# SESSION_DRIVER=database
```

---

## Альтернативное решение (если сессии не работают)

Если сессии не работают, можно использовать cookies вместо сессий. Для этого нужно изменить middleware:

```php
// Вместо Session::put использовать Cookie
Cookie::queue('admin_locale', $localeCode, 60*24*30); // 30 дней

// И получать из cookie
$localeCode = $request->cookie('admin_locale');
```

Но сначала попробуйте решение с сессиями, так как оно более надежное.

---

**Дата создания:** 2025-12-01  
**Версия:** 1.0

