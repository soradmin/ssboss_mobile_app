// lib/features/auth/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../repo/auth_api.dart';
import '../providers/auth_provider.dart';
import '../../cart/controllers/cart_controller.dart';
import '../../../core/config.dart';
import '../../../core/result.dart';
import '../../notifications/services/notification_service.dart';
import 'register_screen.dart'; // Для перехода
import '../../profile/screens/profile_screen.dart'; // Для навигации

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final result = await AuthApi.login(email, password);
      if (result is Ok<String>) {
        final token = result.value;
        // Сохраняем токен как мобильный (независимый от сайта)
        await AppConfig.saveMobileBearerToken(token);
        
        print('[DEBUG] LoginScreen: Токен получен, начинаем обновление AuthProvider');
        
                // Обновляем AuthProvider
                await ref.read(authProvider.notifier).refreshAuthStatus();
                
                // Отправляем FCM токен на сервер после успешной авторизации
                try {
                  final notificationService = NotificationService();
                  if (notificationService.isInitialized) {
                    await notificationService.sendFcmTokenToServer();
                    print('[DEBUG] LoginScreen: FCM токен отправлен на сервер после авторизации');
                  } else {
                    print('[DEBUG] LoginScreen: NotificationService не инициализирован, FCM токен будет отправлен при инициализации');
                  }
                } catch (e) {
                  print('[DEBUG] LoginScreen: Ошибка отправки FCM токена: $e');
                }
                
                // Синхронизируем корзину при входе
                // Корзина остается локальной при входе
        
        print('[DEBUG] LoginScreen: AuthProvider обновлен');
        
        if (mounted) {
          // Проверяем статус авторизации после обновления
          final authState = ref.read(authProvider);
          print('[DEBUG] LoginScreen: Статус авторизации после входа: ${authState.isAuthenticated}');
          print('[DEBUG] LoginScreen: AppConfig.bearer после входа: ${AppConfig.bearer.isNotEmpty ? 'есть' : 'нет'}');
          
          // Показываем сообщение об успехе
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Вход выполнен успешно!'),
              duration: Duration(seconds: 1),
            ),
          );
          
          print('[DEBUG] LoginScreen: Сообщение показано, ждем 800мс');
          
          // Небольшая задержка перед переходом
          await Future.delayed(const Duration(milliseconds: 800));
          
          print('[DEBUG] LoginScreen: Задержка прошла, проверяем mounted: $mounted');
          
          if (mounted) {
            // Безопасно получаем параметры из URL
            String? fromParam;
            try {
              final uri = GoRouterState.of(context).uri;
              fromParam = uri.queryParameters['from'];
              print('[DEBUG] LoginScreen: Проверяем параметр from: $fromParam');
            } catch (e) {
              print('[DEBUG] LoginScreen: Ошибка получения параметров URL: $e');
              fromParam = null;
            }
            
            // Проверяем, откуда пришел пользователь
            if (fromParam == 'shipping') {
              // Возвращаемся на экран оформления заказа
              print('[DEBUG] LoginScreen: Переход на экран оформления заказа');
              context.go('/shipping');
            } else {
              // Иначе переходим в профиль
              print('[DEBUG] LoginScreen: Переход на экран профиля');
              try {
                // Используем go для надежной навигации
                context.go('/profile');
                print('[DEBUG] LoginScreen: Переход на профиль выполнен успешно');
              } catch (e) {
                print('[DEBUG] LoginScreen: Ошибка перехода на профиль: $e');
                // Fallback - возвращаемся на главную
                context.go('/');
              }
            }
          } else {
            print('[DEBUG] LoginScreen: Widget не mounted, переход не выполняется');
          }
        } else {
          print('[DEBUG] LoginScreen: Widget не mounted после обновления AuthProvider');
        }
      } else {
        setState(() {
          _errorMessage = (result as Err<String>).message;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Произошла ошибка: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF9C27B0), // Основной фиолетовый
                Color(0xFFE040FB), // Светло-фиолетовый
              ],
              stops: [0.0, 1.0],
            ),
          ),
        ),
        title: const Text(
          'Вход',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Логотип
                  Container(
                    margin: const EdgeInsets.only(bottom: 48),
                    child: CachedNetworkImage(
                      imageUrl: 'https://ssboss.shop/uploads/header_logo-1756897524-4.png',
                      height: 120,
                      width: 200,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Container(
                        height: 120,
                        width: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF9C27B0),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 120,
                        width: 200,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.image_outlined,
                          color: Color(0xFF9C27B0),
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                  
                  // Карточка с формой
                  Card(
                    elevation: 8,
                    shadowColor: Colors.black.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Заголовок
                          const Text(
                            'Добро пожаловать!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Войдите в свой аккаунт',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          
                          // Поле Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'example@email.com',
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF9C27B0)),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.red, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Введите email';
                              if (!value.contains('@')) return 'Введите корректный email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          
                          // Поле Пароль
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Пароль',
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF9C27B0)),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: Colors.grey[600],
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.red, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Введите пароль';
                              if (value.length < 6) return 'Пароль слишком короткий';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          
                          // Сообщение об ошибке
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red[700],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          // Кнопка Войти
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF9C27B0), // Основной фиолетовый
                                  Color(0xFFE040FB), // Светло-фиолетовый
                                ],
                                stops: [0.0, 1.0],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF9C27B0).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                disabledForegroundColor: Colors.grey[600],
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Войти',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Ссылка на регистрацию
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Нет аккаунта? ',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  context.push('/register');
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Зарегистрируйтесь',
                                  style: TextStyle(
                                    color: Color(0xFF9C27B0),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}