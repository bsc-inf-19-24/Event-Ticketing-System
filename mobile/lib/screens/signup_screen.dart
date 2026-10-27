import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSignupPressed() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // TODO: call your AuthProvider.register(name, email, password) here.
    // Do not use login() to create a new account.
    Fluttertoast.showToast(
      msg: 'Form validated. Registration service is not connected yet.',
    );
  }

  void _onGooglePressed() {
    Fluttertoast.showToast(msg: 'Google sign-up is not connected yet.');
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
                                  () => _obscurePassword = !_obscurePassword),
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
                              () => setState(() => _obscureConfirmPassword =
                          !_obscureConfirmPassword),
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

                    PrimaryButton(
                        label: 'Create account', onPressed: _onSignupPressed),
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
                              text: 'By creating an account, you agree to our '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w500),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w500),
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