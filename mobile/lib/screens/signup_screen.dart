import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../features/auth/data/presentation/provider/auth_provider.dart';
import 'auth_common.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'CUSTOMER';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onSignupPressed() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole,
    );
    if (!mounted) return;

    if (success) {
      Fluttertoast.showToast(msg: 'Account created successfully.');
      Navigator.of(context).pop(true);
    } else {
      Fluttertoast.showToast(msg: auth.errorMessage ?? 'Sign-up failed.');
    }
  }

  Future<void> _onGooglePressed() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.loginWithGoogle();
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      Fluttertoast.showToast(
        msg: authProvider.errorMessage ?? 'Google sign-in failed.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Widget _eyeButton(bool obscured, VoidCallback onTap) {
    return IconButton(
      tooltip: obscured ? 'Show password' : 'Hide password',
      icon: Icon(
        obscured ? Icons.visibility_off : Icons.visibility,
        color: Colors.black54,
      ),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AuthLogo(),
                    const SizedBox(height: 32),
                    const AuthHeading(
                      title: 'Create an account',
                      subtitle: 'Enter your details to get started',
                    ),
                    const SizedBox(height: 24),
                    if (auth.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 13,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _onSignupPressed,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: authFieldDecoration(
                        label: 'Full Name',
                        hint: 'Enter your name',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        if (v.trim().length < 2) {
                          return 'Name must contain at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: authFieldDecoration(
                        label: 'Email Address',
                        hint: 'email@domain.com',
                      ),
                      validator: validateEmail,
                    ),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      decoration: authFieldDecoration(
                        label: 'Account type',
                        hint: 'Choose an account type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'CUSTOMER',
                          child: Text('Customer'),
                        ),
                        DropdownMenuItem(
                          value: 'ORGANIZER',
                          child: Text('Organizer'),
                        ),
                        DropdownMenuItem(
                          value: 'VALIDATOR',
                          child: Text('Validator'),
                        ),
                      ],
                      onChanged: auth.isLoading
                          ? null
                          : (role) {
                              if (role != null) {
                                setState(() => _selectedRole = role);
                              }
                            },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}), // refresh checklist
                      decoration: authFieldDecoration(
                        label: 'Password',
                        hint: 'Create a password',
                        suffixIcon: _eyeButton(
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
                      onFieldSubmitted: (_) => _onSignupPressed(),
                      decoration: authFieldDecoration(
                        label: 'Confirm Password',
                        hint: 'Re-enter your password',
                        suffixIcon: _eyeButton(
                          _obscureConfirmPassword,
                          () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (v != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    auth.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : PrimaryButton(
                            label: 'Create account',
                            onPressed: _onSignupPressed,
                          ),
                    const SizedBox(height: 20),
                    const OrDivider(),
                    const SizedBox(height: 20),
                    GoogleButton(onPressed: _onGooglePressed),
                    const SizedBox(height: 20),

                    SwitchAuthRow(
                      question: 'Already have an account?',
                      actionLabel: 'Log in',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 8),

                    const Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                        children: [
                          TextSpan(
                            text: 'By creating an account, you agree to our ',
                          ),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
