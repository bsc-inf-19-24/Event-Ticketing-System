import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import 'package:mobile/features/auth/data/presentation/provider/auth_provider.dart';

import 'auth_common.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.requestMessage,
    this.demoVerificationCode,
  });

  final String email;
  final String requestMessage;
  final String? demoVerificationCode;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _errorMessage = null);
    try {
      await context.read<AuthProvider>().resetPassword(
        email: widget.email,
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;

      Fluttertoast.showToast(
        msg: 'Your password has been changed successfully.',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _errorMessage = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Widget _passwordVisibilityButton(bool obscured, VoidCallback onPressed) {
    return IconButton(
      tooltip: obscured ? 'Show password' : 'Hide password',
      icon: Icon(
        obscured ? Icons.visibility_off : Icons.visibility,
        color: Colors.black54,
      ),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Reset password'),
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
                        title: 'Create a new password',
                        subtitle: 'Enter the verification code and choose a new password.',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Account: ${widget.email}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.requestMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                      if (widget.demoVerificationCode != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            border: Border.all(color: Colors.amber.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Demo mode: no email is sent. Your verification code is '
                            '${widget.demoVerificationCode}.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.brown.shade800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_errorMessage != null) ...[
                        _ResetErrorBanner(message: _errorMessage!),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: authFieldDecoration(
                          label: 'Verification Code',
                          hint: 'Enter the 6-digit code',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the verification code';
                          }
                          if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
                            return 'Enter a valid 6-digit code';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                        decoration: authFieldDecoration(
                          label: 'New Password',
                          hint: 'Create a new password',
                          suffixIcon: _passwordVisibilityButton(
                            _obscurePassword,
                            () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: validateNewPassword,
                      ),
                      PasswordRequirements(password: _passwordController.text),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _resetPassword(),
                        decoration: authFieldDecoration(
                          label: 'Confirm New Password',
                          hint: 'Re-enter your new password',
                          suffixIcon: _passwordVisibilityButton(
                            _obscureConfirmPassword,
                            () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      authProvider.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : PrimaryButton(
                              label: 'Save new password',
                              onPressed: _resetPassword,
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

class _ResetErrorBanner extends StatelessWidget {
  const _ResetErrorBanner({required this.message});

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
