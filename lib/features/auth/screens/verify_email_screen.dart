// lib/features/auth/screens/verify_email_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../repo/auth_api.dart';
import '../../../core/config.dart';
import '../../../core/result.dart';
import '../../../theme.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String email;
  
  const VerifyEmailScreen({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String code = _codeController.text.trim();

    try {
      // Вызываем API метод для верификации кода
      final Result<String> result = await AuthApi.verifyEmail(
        email: widget.email,
        code: code,
      );
      
      if (!mounted) return;

      if (result is Ok<String>) {
        final response = result.value;
        
        if (response == 'LOGIN_REQUIRED') {
          // Показываем сообщение о необходимости входа
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email подтвержден! Теперь войдите в систему.'),
              duration: Duration(seconds: 3),
            ),
          );
          
          // Переходим на экран входа
          context.go('/');
        } else {
          // Если получили токен напрямую (старый сценарий)
          await AppConfig.saveBearerToken(response);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email подтвержден! Добро пожаловать!'),
              duration: Duration(seconds: 2),
            ),
          );
          
          context.go('/profile');
        }
      } else if (result is Err<String>) {
        setState(() {
          _errorMessage = result.message;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Произошла ошибка: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Вызываем API метод для повторной отправки кода
      final Result<String> result = await AuthApi.resendVerificationCode(
        email: widget.email,
      );
      
      if (!mounted) return;

      if (result is Ok<String>) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Код подтверждения повторно отправлен на ${widget.email}'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (result is Err<String>) {
        setState(() {
          _errorMessage = result.message;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Произошла ошибка при отправке кода: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: backgroundColor,
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
          'Подтверждение Email',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  
                  // Иконка с красивым фоном
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? const Color(0xFF9C27B0).withOpacity(0.2)
                            : const Color(0xFF9C27B0).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.email_outlined,
                        size: 64,
                        color: Color(0xFF9C27B0),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Заголовок
                  Text(
                    'Подтвердите ваш email',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Описание
                  Text(
                    'Мы отправили код подтверждения на',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.email,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF9C27B0),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Поле для ввода кода
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'Код подтверждения',
                      hintText: 'Введите код из письма',
                      prefixIcon: const Icon(Icons.security, color: Color(0xFF9C27B0)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 2),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w600,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите код подтверждения';
                      }
                      if (value.length < 4) {
                        return 'Код должен содержать минимум 4 символа';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Сообщение об ошибке
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.red[900]?.withOpacity(0.3)
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark 
                              ? Colors.red[700]!.withOpacity(0.5)
                              : Colors.red[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: isDark ? Colors.red[300] : Colors.red[700],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: isDark ? Colors.red[300] : Colors.red[700],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (_errorMessage != null) const SizedBox(height: 24),
                  
                  // Кнопка подтверждения с градиентом
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
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                              'Подтвердить',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Кнопка повторной отправки
                  TextButton(
                    onPressed: _isLoading ? null : _resendCode,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF9C27B0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Отправить код повторно',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Ссылка на вход
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Уже подтвердили? ',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF9C27B0),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        child: const Text(
                          'Войти',
                          style: TextStyle(
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
        ),
      ),
    );
  }
}
