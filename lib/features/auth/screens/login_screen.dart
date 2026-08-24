import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../repo/auth_api.dart';
import '../widgets/auth_soft.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/result.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = '992${_phoneController.text.trim()}';
    final result = await AuthApi.sendOtp(phone: phone);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result is Ok<Map<String, dynamic>>) {
      final normalized =
          result.value['phone']?.toString() ?? AuthApi.normalizePhone(phone)!;
      context.push('/otp-verify', extra: {
        'phone': normalized,
      });
    } else if (result is Err<Map<String, dynamic>>) {
      setState(() => _errorMessage = result.message);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeControllerProvider);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return AuthSoftScaffold(
      backLabel: context.tr('auth.back'),
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      child: Form(
        key: _formKey,
        child: ListView(
          clipBehavior: Clip.none,
          padding: EdgeInsets.fromLTRB(28, 32, 28, bottom + 24),
          children: [
            Text(
              context.tr(AuthSoft.greetingTrKey()),
              style: AuthSoft.title(size: 30),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('auth.otp_login_subtitle'),
              style: AuthSoft.body(size: 14.5),
            ),
            const SizedBox(height: 28),
            AuthSoftPhoneField(
              controller: _phoneController,
              hint: context.tr('auth.phone_hint'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('auth.enter_phone');
                }
                if (AuthApi.normalizePhone('992${value.trim()}') == null) {
                  return context.tr('auth.invalid_phone');
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              AuthSoftErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: 22),
            AuthSoftButton(
              label: context.tr('auth.send_code'),
              loading: _isLoading,
              onPressed: _isLoading ? null : _sendCode,
            ),
          ],
        ),
      ),
    );
  }
}
