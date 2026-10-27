import 'package:flutter/material.dart';

// ---------- Validators ----------

String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Please enter your email address';
  }
  final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  if (!pattern.hasMatch(value.trim())) {
    return 'Please enter a valid email address';
  }
  return null;
}

const int kMinPasswordLength = 7;

bool hasMinLength(String v) => v.length >= kMinPasswordLength;
bool hasLetter(String v) => RegExp(r'[A-Za-z]').hasMatch(v);
bool hasNumber(String v) => RegExp(r'\d').hasMatch(v);
bool hasSymbol(String v) => RegExp(r'[^A-Za-z0-9\s]').hasMatch(v);

/// Used on SIGN UP only (existing users just need a non-empty password to log in).
String? validateNewPassword(String? value) {
  if (value == null || value.isEmpty) return 'Please enter a password';
  if (!hasMinLength(value)) {
    return 'Password must be at least $kMinPasswordLength characters';
  }
  if (!hasLetter(value)) return 'Password must include a letter';
  if (!hasNumber(value)) return 'Password must include a number';
  if (!hasSymbol(value)) return 'Password must include a symbol (e.g. @ # \$ !)';
  return null;
}

// ---------- Shared UI ----------

InputDecoration authFieldDecoration({
  required String label,
  required String hint,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: c),
  );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.black38),
    floatingLabelStyle: const TextStyle(color: Colors.black),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    suffixIcon: suffixIcon,
    enabledBorder: border(const Color(0xFFE0E0E0)),
    focusedBorder: border(Colors.black),
    errorBorder: border(Colors.red),
    focusedErrorBorder: border(Colors.red),
  );
}

class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.confirmation_number, size: 64, color: Colors.black),
        SizedBox(height: 8),
        Text(
          'TICKET MASTER',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class AuthHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const AuthHeading({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
      ],
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const PrimaryButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFE0E0E0))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('or',
              style: TextStyle(color: Colors.black45, fontSize: 13)),
        ),
        Expanded(child: Divider(color: Color(0xFFE0E0E0))),
      ],
    );
  }
}

class GoogleButton extends StatelessWidget {
  final VoidCallback onPressed;
  const GoogleButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEEEEEE),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    );
  }
}

/// "Don't have an account? Sign up" / "Already have an account? Log in"
class SwitchAuthRow extends StatelessWidget {
  final String question;
  final String actionLabel;
  final VoidCallback onPressed;
  const SwitchAuthRow({
    super.key,
    required this.question,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(question,
              style: const TextStyle(color: Colors.black54, fontSize: 13)),
        ),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: Text(actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// Live checklist shown under the password field on sign up.
class PasswordRequirements extends StatelessWidget {
  final String password;
  const PasswordRequirements({super.key, required this.password});

  Widget _row(String text, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: ok ? Colors.green : Colors.black38,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: ok ? Colors.green.shade700 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('At least $kMinPasswordLength characters', hasMinLength(password)),
          _row('Contains a letter (a-z)', hasLetter(password)),
          _row('Contains a number (0-9)', hasNumber(password)),
          _row('Contains a symbol (! @ # \$ % ...)', hasSymbol(password)),
        ],
      ),
    );
  }
}