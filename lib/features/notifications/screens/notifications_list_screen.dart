import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import 'notification_details_screen.dart';
import '../../../core/widgets/bottom_navigation_bar.dart';

class NotificationsListScreen extends StatefulWidget {
  const NotificationsListScreen({super.key});

  @override
  State<NotificationsListScreen> createState() => _NotificationsListScreenState();
}

class _NotificationsListScreenState extends State<NotificationsListScreen> {
  final NotificationService _notificationService = NotificationService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _notificationService.getRecentNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      print('[NOTIFICATIONS] ❌ Ошибка загрузки уведомлений: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Только что';
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Только что';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} мин. назад';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} ч. назад';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} дн. назад';
      } else {
        return DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
      }
    } catch (e) {
      return 'Только что';
    }
  }

  String _cleanHtmlFromText(String text) {
    if (text.isEmpty) return text;
    // Удаляем HTML теги
    String cleaned = text.replaceAll(RegExp(r'<[^>]*>'), '');
    // Декодируем HTML entities
    cleaned = cleaned
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    // Удаляем лишние пробелы
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  IconData _getNotificationIcon(Map<String, dynamic> data) {
    if (data.containsKey('type')) {
      final type = data['type'] as String?;
      if (type == 'order') {
        return Icons.shopping_bag_rounded;
      } else if (type == 'promotion') {
        return Icons.local_offer_rounded;
      }
    }
    return Icons.notifications_rounded;
  }

  Color _getNotificationIconColor(Map<String, dynamic> data) {
    if (data.containsKey('type')) {
      final type = data['type'] as String?;
      if (type == 'order') {
        return const Color(0xFF2196F3);
      } else if (type == 'promotion') {
        return const Color(0xFF9C27B0);
      }
    }
    return const Color(0xFF4CAF50);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Уведомления',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF9C27B0),
              ),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Нет уведомлений',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Здесь будут отображаться последние уведомления',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: const Color(0xFF9C27B0),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      final title = notification['title'] as String? ?? 'Уведомление';
                      final body = notification['body'] as String? ?? '';
                      final timestamp = notification['timestamp'] as String?;
                      final data = notification['data'] as Map<String, dynamic>? ?? {};
                      final cleanBody = _cleanHtmlFromText(body);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // Открываем детали уведомления
                              String? htmlBody;
                              try {
                                if (data.containsKey('html_body') && data['html_body'] != null) {
                                  final base64String = data['html_body'] as String;
                                  final bytes = base64Decode(base64String);
                                  htmlBody = utf8.decode(bytes);
                                }
                              } catch (e) {
                                print('[NOTIFICATIONS] ⚠️ Ошибка декодирования HTML: $e');
                              }

                              context.push('/notification-details', extra: {
                                'title': title,
                                'htmlBody': htmlBody ?? body,
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Иконка уведомления
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _getNotificationIconColor(data).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _getNotificationIcon(data),
                                      color: _getNotificationIconColor(data),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Текст уведомления
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1A1A1A),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (cleanBody.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            cleanBody,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                              height: 1.4,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatDateTime(timestamp),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Стрелка
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.grey[300],
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: const BottomNavigationBarWidget(selectedIndex: 0),
    );
  }
}

