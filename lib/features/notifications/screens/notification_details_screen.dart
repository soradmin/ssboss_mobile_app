import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

/// Экран для отображения полного содержимого push-уведомления
class NotificationDetailsScreen extends StatefulWidget {
  final String title;
  final String? htmlBody;

  const NotificationDetailsScreen({
    super.key,
    required this.title,
    this.htmlBody,
  });

  @override
  State<NotificationDetailsScreen> createState() => _NotificationDetailsScreenState();
}

class _NotificationDetailsScreenState extends State<NotificationDetailsScreen> {
  bool _isLoadingUrl = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомление'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (widget.htmlBody != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareNotification(context),
              tooltip: 'Поделиться',
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 24),
                
                // Тело сообщения
                if (widget.htmlBody != null && widget.htmlBody!.isNotEmpty)
                  _buildHtmlContent(context, widget.htmlBody!)
                else
                  _buildPlainTextContent(context),
              ],
            ),
          ),
          // Индикатор загрузки при открытии ссылки
          if (_isLoadingUrl)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  /// Отображает HTML содержимое
  Widget _buildHtmlContent(BuildContext context, String html) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: HtmlWidget(
        html,
        textStyle: Theme.of(context).textTheme.bodyLarge,
        // Обработка кликов по ссылкам и кнопкам
        onTapUrl: (url) async {
          await _handleUrlTap(context, url);
          return true; // Возвращаем true, чтобы предотвратить стандартную обработку
        },
        // Настройки для правильного отображения кнопок и ссылок
        customStylesBuilder: (element) {
          // Делаем ссылки и кнопки более заметными
          if (element.localName == 'a') {
            // Проверяем, является ли это кнопкой (имеет стиль с background)
            final style = element.attributes['style'] ?? '';
            final isButton = style.contains('background') || 
                           style.contains('padding') && style.contains('color');
            
            if (isButton) {
              // Это кнопка-ссылка - делаем её более интерактивной
              return {
                'cursor': 'pointer',
                'display': 'inline-block',
                'text-align': 'center',
              };
            } else {
              // Обычная ссылка
              return {
                'color': '#4380F3', // Синий цвет для ссылок
                'text-decoration': 'underline',
                'cursor': 'pointer',
              };
            }
          }
          // Стили для кнопок
          if (element.localName == 'button') {
            return {
              'cursor': 'pointer',
            };
          }
          return null;
        },
        // Включаем поддержку всех HTML элементов
        enableCaching: true,
        rebuildTriggers: [html],
        // Дополнительные настройки для лучшей поддержки HTML
        baseUrl: Uri.parse('https://ssboss.shop'),
      ),
    );
  }

  /// Обрабатывает клик по URL (ссылке или кнопке)
  Future<void> _handleUrlTap(BuildContext context, String url) async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingUrl = true;
    });

    try {
      print('[NOTIFICATIONS] 🔗 Открываем URL: $url');
      
      // Обрабатываем относительные ссылки
      Uri uri;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        uri = Uri.parse(url);
      } else if (url.startsWith('//')) {
        // Протокол-относительная ссылка
        uri = Uri.parse('https:$url');
      } else if (url.startsWith('/')) {
        // Абсолютный путь - добавляем базовый URL
        uri = Uri.parse('https://ssboss.shop$url');
      } else {
        // Относительный путь
        uri = Uri.parse('https://ssboss.shop/$url');
      }
      
      print('[NOTIFICATIONS] 🔗 Обработанный URI: $uri');
      
      // Пытаемся открыть URL напрямую, без проверки canLaunchUrl
      // так как canLaunchUrl может возвращать false даже для валидных URL
      bool launched = false;
      
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        // HTTP/HTTPS ссылки - открываем в браузере
        try {
          launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          print('[NOTIFICATIONS] ✅ URL открыт в браузере: $launched');
        } catch (launchError) {
          print('[NOTIFICATIONS] ⚠️ Ошибка при открытии в externalApplication: $launchError');
          // Пробуем альтернативный режим
          try {
            launched = await launchUrl(
              uri,
              mode: LaunchMode.platformDefault,
            );
            print('[NOTIFICATIONS] ✅ URL открыт в platformDefault: $launched');
          } catch (platformError) {
            print('[NOTIFICATIONS] ⚠️ Ошибка при открытии в platformDefault: $platformError');
            // Последняя попытка - inAppWebView
            try {
              launched = await launchUrl(
                uri,
                mode: LaunchMode.inAppWebView,
              );
              print('[NOTIFICATIONS] ✅ URL открыт в inAppWebView: $launched');
            } catch (webViewError) {
              print('[NOTIFICATIONS] ❌ Все попытки открыть URL не удались: $webViewError');
            }
          }
        }
      } else if (uri.scheme == 'tel' || uri.scheme == 'mailto' || uri.scheme == 'sms') {
        // Телефон, email, SMS - открываем в соответствующем приложении
        try {
          launched = await launchUrl(uri);
          print('[NOTIFICATIONS] ✅ Специальная схема открыта: $launched');
        } catch (e) {
          print('[NOTIFICATIONS] ❌ Ошибка при открытии специальной схемы: $e');
        }
      } else {
        // Другие схемы - пробуем открыть
        try {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {
          print('[NOTIFICATIONS] ❌ Ошибка при открытии другой схемы: $e');
        }
      }
      
      if (!launched) {
        // Если не удалось открыть, показываем сообщение
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Не удалось открыть ссылку: $url'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Скопировать',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ссылка скопирована в буфер обмена'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('[NOTIFICATIONS] ❌ Критическая ошибка при открытии URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при открытии ссылки: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Скопировать',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ссылка скопирована в буфер обмена'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUrl = false;
        });
      }
    }
  }

  /// Отображает обычный текст (fallback)
  Widget _buildPlainTextContent(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'Содержимое уведомления недоступно',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
      ),
    );
  }

  /// Поделиться уведомлением
  void _shareNotification(BuildContext context) {
    if (widget.htmlBody == null) return;

    // Извлекаем текст из HTML для шаринга
    final text = _extractTextFromHtml(widget.htmlBody!);
    final shareText = '${widget.title}\n\n$text';

    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Текст уведомления скопирован в буфер обмена'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Извлекает текст из HTML
  String _extractTextFromHtml(String html) {
    // Простое удаление HTML тегов
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

