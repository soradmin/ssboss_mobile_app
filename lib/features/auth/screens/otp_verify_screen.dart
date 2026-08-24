import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../repo/auth_api.dart';
import '../widgets/auth_soft.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/result.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String phone;
  final String? name;
  final bool isRegistration;

  const OtpVerifyScreen({
    super.key,
    required this.phone,
    this.name,
    this.isRegistration = false,
  });

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _resending = false;
  String? _errorMessage;
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer([int seconds = 60]) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
      } else {
        if (mounted) setState(() => _secondsLeft -= 1);
      }
    });
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AuthApi.verifyOtp(
        phone: widget.phone,
        code: _codeController.text.trim(),
        name: widget.name,
      );

      if (!mounted) return;

      if (result is Ok<Map<String, dynamic>>) {
        final payload = result.value;
        final token = payload['token'] as String;
        Map<String, dynamic>? userMap;
        final rawUser = payload['user'];
        if (rawUser is Map) {
          userMap = Map<String, dynamic>.from(rawUser);
        }
        await ref.read(authProvider.notifier).completeOtpLogin(
              token: token,
              userPayload: userMap,
            );

        if (!mounted) return;
        await Future<void>.delayed(Duration.zero);
        if (!mounted) return;
        context.go('/profile');
        return;
      } else if (result is Err<Map<String, dynamic>>) {
        setState(() => _errorMessage = result.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '${context.tr('common.error')}: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _resending) return;
    setState(() => _resending = true);
    final result = await AuthApi.sendOtp(
      phone: widget.phone,
      name: widget.name,
      requireName: widget.isRegistration,
    );
    if (!mounted) return;
    setState(() => _resending = false);

    if (result is Ok<Map<String, dynamic>>) {
      final resendIn = result.value['resend_in'];
      _startTimer(resendIn is int ? resendIn : 60);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('auth.otp_resent'))),
      );
    } else if (result is Err<Map<String, dynamic>>) {
      setState(() => _errorMessage = result.message);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(localeControllerProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final display = AuthApi.formatPhoneDisplay(widget.phone);

    return AuthSoftScaffold(
      backLabel: context.tr('auth.back'),
      headerFlex: 0.28,
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/login');
        }
      },
      child: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(28, 32, 28, bottom + 24),
          children: [
            Text(
              context.tr('auth.otp_title'),
              style: AuthSoft.title(size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr(
                'auth.otp_subtitle',
                namedArgs: {'phone': display},
              ),
              style: AuthSoft.body(size: 14.5),
            ),
            const SizedBox(height: 28),
            AuthSoftField(
              controller: _codeController,
              hint: context.tr('auth.enter_code'),
              keyboardType: TextInputType.number,
              prefixIcon: Icons.sms_outlined,
              validator: (v) {
                if (v == null || v.trim().length < 4) {
                  return context.tr('auth.code_too_short');
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
              label: context.tr('auth.confirm'),
              loading: _isLoading,
              onPressed: _isLoading ? null : _verify,
            ),
            const SizedBox(height: 20),
            Center(
              child: _secondsLeft > 0
                  ? Text(
                      context.tr(
                        'auth.otp_resend_in',
                        namedArgs: {'sec': '$_secondsLeft'},
                      ),
                      style: AuthSoft.body(size: 13.5),
                    )
                  : TextButton(
                      onPressed: _resending ? null : _resend,
                      child: Text(
                        context.tr('auth.resend_code'),
                        style: AuthSoft.body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: AuthSoft.brand,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
