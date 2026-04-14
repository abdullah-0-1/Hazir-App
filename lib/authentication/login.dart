import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sign_up.dart';
import '../consumer/consumer_screen.dart';
import '../provider/provider_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String role = 'Service Consumer';

  bool obscurePassword = true;

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter email';
    if (!EmailValidator.validate(v.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Please enter password';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _onLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(),
          ),
        );

        String collection =
        role == 'Service Consumer' ? 'userConsumer' : 'userProvider';

        QuerySnapshot emailQuery = await FirebaseFirestore.instance
            .collection(collection)
            .where('mail', isEqualTo: emailController.text.trim())
            .get();

        if (emailQuery.docs.isEmpty) {
          if (!mounted) return;
          Navigator.pop(context);

          _showLoginFailedDialog();
          return;
        }

        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        if (!mounted) return;

        Navigator.pop(context);

        if (role == 'Service Consumer') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ConsumerScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ProviderScreen()),
          );
        }
      } catch (e) {
        if (!mounted) return;

        Navigator.pop(context);

        _showLoginFailedDialog();
      }
    }
  }

  void _showLoginFailedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Failed'),
        content: const Text('Email, password or Role incorrect.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Column(
                      children: const [
                        Text(
                          'HAZIR',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 32,
                            letterSpacing: 3,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'bhai hazir hai!',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _FieldLabel(
                                icon: Icons.email_outlined, label: 'Email'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.black),
                              decoration:
                              _inputDecoration(hint: 'Enter your email'),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 14),
                            const _FieldLabel(
                                icon: Icons.lock_outline, label: 'Password'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              style: const TextStyle(color: Colors.black),
                              decoration: _inputDecoration(
                                hint: 'Enter your password',
                                suffix: IconButton(
                                  icon: Icon(obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () => setState(
                                          () => obscurePassword = !obscurePassword),
                                ),
                              ),
                              validator: _validatePassword,
                            ),
                            const SizedBox(height: 14),
                            const _FieldLabel(
                                icon: Icons.group_outlined, label: 'Role'),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: role,
                              style: const TextStyle(color: Colors.black),
                              items: const [
                                DropdownMenuItem(
                                    value: 'Service Provider',
                                    child: Text('Service Provider')),
                                DropdownMenuItem(
                                    value: 'Service Consumer',
                                    child: Text('Service Consumer')),
                              ],
                              onChanged: (v) =>
                                  setState(() => role = v ?? role),
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder(), isDense: true),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: _onLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text(
                                  'Login',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("Don't have an account? "),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                        const SignUpScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text('Sign Up'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffix,
      border: const OutlineInputBorder(),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FieldLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}