import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mobile/features/auth/data/presentation/provider/auth_provider.dart';

import 'auth_common.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _errorMessage = null);
    final authProvider = context.read<AuthProvider>();
    try {
      final request = await authProvider.requestPasswordReset(
        _emailController.text.trim(),
      );
      if (!mounted) return;

      final reset = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            email: _emailController.text.trim(),
            requestMessage: request.message,
            demoVerificationCode: request.demoVerificationCode,
          ),
        ),
      );
      if (reset == true && mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _errorMessage = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Forgot password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, _) => Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthLogo(),
                      const SizedBox(height: 32),
                      const AuthHeading(
                        title: 'Recover your account',
                        subtitle: 'Enter the email address associated with your account.',
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage != null) ...[
                        _ErrorBanner(message: _errorMessage!),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _requestReset(),
                        decoration: authFieldDecoration(
                          label: 'Email Address',
                          hint: 'email@domain.com',
                        ),
                        validator: validateEmail,
                      ),
                      const SizedBox(height: 20),
                      authProvider.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : PrimaryButton(
                              label: 'Send verification code',
                              onPressed: _requestReset,
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: Colors.red.shade800, fontSize: 13),
      ),
    );
  }
}
