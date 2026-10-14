import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // ---- Placeholder handlers ----
  void _onContinuePressed() {
    Fluttertoast.showToast(msg: 'Login pressed');
  }

  void _onGooglePressed() {
    Fluttertoast.showToast(msg: 'Google login pressed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                const Icon(Icons.confirmation_number,
                    size: 80, color: Colors.black),
                const SizedBox(height: 8),
                const Text(
                  'TICKET MASTER',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 56),

                // Heading
                const Text(
                  'Create an account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Enter your email to sign up for this app',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 20),

                // Email field
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'email@domain.com',
                    hintStyle: const TextStyle(color: Colors.black38),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _onContinuePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Continue',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(height: 20),

                // Divider with "or"
                Row(
                  children: const [
                    Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or',
                          style:
                              TextStyle(color: Colors.black45, fontSize: 13)),
                    ),
                    Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                  ],
                ),
                const SizedBox(height: 20),

                // Google button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _onGooglePressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEEEEE),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const SweepGradient(
                            colors: [
                              Color(0xFF4285F4),
                              Color(0xFF34A853),
                              Color(0xFFFBBC05),
                              Color(0xFFEA4335),
                              Color(0xFF4285F4),
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'G',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Continue with Google',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Terms text
                const Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                    children: [
                      TextSpan(text: 'By clicking continue, you agree to our '),
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.w500),
                      ),
                      TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.w500),
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
    );
  }
}