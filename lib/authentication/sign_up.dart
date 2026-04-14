import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';


class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  String countryCode = '+92 (PK)';
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController passConfirmController = TextEditingController();
  String role = 'Service Consumer';

  bool obscurePassword = true;
  bool obscureConfirm = true;

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter email';
    if (!EmailValidator.validate(v.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Please enter password';
    if (v.length < 6) return 'Password must be at least 6 characters';

    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Must contain at least one uppercase letter';

    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Must contain at least one lowercase letter';

    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Must contain at least one numeric character';

    return null;
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    passConfirmController.dispose();
    super.dispose();
  }
  String _cleanCountryCode(String code) {
    return code.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
  }
  void _onSignUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final cleanedCode = _cleanCountryCode(countryCode);
    final fullPhone = '$cleanedCode${phoneController.text.trim()}';
    final collection = role == 'Service Consumer' ? 'userConsumer' : 'userProvider';

    try {
      _showLoadingDialog();

      final phoneQuery = await FirebaseFirestore.instance
          .collection(collection)
          .where('contactNumber', isEqualTo: fullPhone)
          .get();

      if (phoneQuery.docs.isNotEmpty) {
        if (!mounted) return;
        Navigator.pop(context);
        _showPhoneNumberExistsDialog();
        return;
      }

      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await FirebaseFirestore.instance.collection(collection).doc(userCredential.user!.uid).set({
        "contactNumber": fullPhone,
        "createdAt": FieldValue.serverTimestamp(),
        "isVerified": false,
        "mail": emailController.text.trim(),
        "name": nameController.text.trim(),
        "updatedAt": FieldValue.serverTimestamp(),
        "location": {"latitude": 0, "longitude": 0},
      });

      await userCredential.user?.sendEmailVerification();

      if (!mounted) return;
      Navigator.pop(context);
      await _showEmailVerificationDialog();

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      if (e.code == 'email-already-in-use') {
        _showEmailExistsDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message ?? e.toString()}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _showEmailVerificationDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verify Your Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A verification email has been sent to:'),
            const SizedBox(height: 8),
            Text(emailController.text.trim(), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Please check your inbox and click the verification link.'),
            const SizedBox(height: 8),
            const Text(
              'After verifying, return to the app and click "I\'ve Verified".',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _cancelSignUp,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _resendVerificationEmail,
            child: const Text('Resend Email'),
          ),
          ElevatedButton(
            onPressed: _checkEmailVerification,
            child: const Text('I\'ve Verified'),
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationEmail() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email resent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _cancelSignUp() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Sign Up?'),
        content: const Text('This will delete your account and all data. You can sign up again with a different email.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep It'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      _showLoadingDialog();

      final user = FirebaseAuth.instance.currentUser;
      final collection = role == 'Service Consumer' ? 'userConsumer' : 'userProvider';

      if (user?.uid != null) {
        await FirebaseFirestore.instance.collection(collection).doc(user!.uid).delete();
      }

      await user?.delete();

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign up cancelled. You can try again with a different email.')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _checkEmailVerification() async {
    try {
      _showLoadingDialog();

      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();

      if (!mounted) return;
      Navigator.pop(context);

      if (user?.emailVerified ?? false) {
        final collection = role == 'Service Consumer' ? 'userConsumer' : 'userProvider';
        await FirebaseFirestore.instance.collection(collection).doc(user!.uid).update({
          'isVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified successfully!')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email not verified yet. Please check your inbox and verify.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _showPhoneNumberExistsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phone Number Already Exists'),
        content: const Text('Use Different Phone Number To Sign-Up'),
      ),
    );
  }

  void _showEmailExistsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Already Exists'),
        content: const Text('This email is already registered. Please log in instead.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            child: const Text('Login'),
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
                  // Header
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
                  // Card with form
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
                            // Full Name
                            const _FieldLabel(icon: Icons.person_outline, label: 'Full Name'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: nameController,
                              decoration: _inputDecoration(hint: 'Enter your full name'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter full name' : null,
                            ),
                            const SizedBox(height: 14),

                            // Phone number with country dropdown
                            const _FieldLabel(icon: Icons.phone, label: 'Phone Number'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  width: 130,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    child: CountryCodePicker(
                                      onChanged: (country) => setState(() {
                                        countryCode = '${country.dialCode} (${country.code})';
                                      }),
                                      initialSelection: 'PK',
                                      favorite: const ['+92', 'PK'],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: phoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: _inputDecoration(hint: 'e.g., 321 1234567'),
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Please enter phone number';
                                      if (v.trim().length < 10) return 'Enter a valid phone number';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Email
                            const _FieldLabel(icon: Icons.email_outlined, label: 'Email'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration(hint: 'Enter your email'),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 14),

                            // Password
                            const _FieldLabel(icon: Icons.lock_outline, label: 'Password'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              decoration: _inputDecoration(
                                hint: 'Enter your password',
                                suffix: IconButton(
                                  icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => obscurePassword = !obscurePassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == passConfirmController.text) return _validatePassword(v);
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Confirm Password
                            const _FieldLabel(icon: Icons.lock_outline, label: 'Confirm Password'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: passConfirmController,
                              obscureText: obscureConfirm,
                              decoration: _inputDecoration(
                                hint: 'Re-enter your password',
                                suffix: IconButton(
                                  icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                                ),
                              ),
                              validator: (v) {
                                if (v != passwordController.text) return 'Passwords do not match'; // Priority check
                                final basic = _validatePassword(v);
                                if (basic != null) return basic;
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Role
                            const _FieldLabel(icon: Icons.group_outlined, label: 'Role'),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: role,
                              items: const [
                                DropdownMenuItem(value: 'Service Provider', child: Text('Service Provider')),
                                DropdownMenuItem(value: 'Service Consumer', child: Text('Service Consumer')),
                              ],
                              onChanged: (v) => setState(() => role = v ?? role),
                              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                            ),
                            const SizedBox(height: 18),

                            // Sign Up button
                            SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: _onSignUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text(
                                  'Sign Up',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Already have account
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Already have an account? '),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LoginScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text('Log In'),
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