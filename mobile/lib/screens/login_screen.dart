import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'auth_common.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // TODO: call your AuthProvider.login(email, password) here.
    Fluttertoast.showToast(msg: 'Login service is not connected yet.');
  }

  void _onForgotPassword() {
    // TODO: navigate to your forgot-password flow.
    Fluttertoast.showToast(msg: 'Forgot password is not connected yet.');
  }

  void _onGooglePressed() {
    Fluttertoast.showToast(msg: 'Google sign-in is not connected yet.');
  }

  Future<void> _goToSignup() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
    if (ok == true && mounted) Navigator.of(context).pop(true);
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
                    const SizedBox(height: 36),
                    const AuthHeading(
                      title: 'Welcome back',
                      subtitle: 'Log in to your account to continue',
                    ),
                    const SizedBox(height: 24),

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
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _onLoginPressed(),
                      decoration: authFieldDecoration(
                        label: 'Password',
                        hint: 'Enter your password',
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.black54,
                          ),
                          onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      // Existing accounts only need a non-empty password;
                      // the strength rules apply at sign up.
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Please enter your password'
                          : null,
                    ),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _onForgotPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: const Text('Forgot password?',
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 4),

                    PrimaryButton(label: 'Log in', onPressed: _onLoginPressed),
                    const SizedBox(height: 20),
                    const OrDivider(),
                    const SizedBox(height: 20),
                    GoogleButton(onPressed: _onGooglePressed),
                    const SizedBox(height: 24),

                    SwitchAuthRow(
                      question: "Don't have an account?",
                      actionLabel: 'Sign up',
                      onPressed: _goToSignup,
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