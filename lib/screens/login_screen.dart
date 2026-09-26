import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../services/supabase_service.dart';

/// Login screen — email + password with a "Forgot password" flow stub
/// and a link to the sign-up screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    setState(() { _errorMessage = null; });
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await SupabaseService.instance.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (_) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  void _onForgotPassword() {
    final email = _emailCtrl.text.trim();
    showDialog(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(prefillEmail: email),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: kColorBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenHeight - 80),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: screenHeight * 0.08),
                  _buildBrand(textTheme),
                  SizedBox(height: screenHeight * 0.06),
                  _buildForm(textTheme),
                  const SizedBox(height: 8),
                  _buildForgotPassword(textTheme),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) _buildError(textTheme),
                  _buildLoginButton(textTheme),
                  const Spacer(),
                  _buildSignUpLink(textTheme),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Brand header ───────────────────────────────────────────────────────────
  Widget _buildBrand(TextTheme textTheme) {
    return Column(
      children: [
        // App icon badge.
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: kColorSOS,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: kColorSOS.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.sos, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          'AidPulsate',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in to your account',
          style: textTheme.bodyLarge?.copyWith(color: kColorTextSecondary),
        ),
      ],
    );
  }

  // ── Form fields ────────────────────────────────────────────────────────────
  Widget _buildForm(TextTheme textTheme) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email.
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: _inputDecoration(
              label: 'Email address',
              icon: Icons.email_outlined,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Password.
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _onLogin(),
            decoration: _inputDecoration(
              label: 'Password',
              icon: Icons.lock_outline,
            ).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: kColorTextSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ── Forgot password link ───────────────────────────────────────────────────
  Widget _buildForgotPassword(TextTheme textTheme) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _onForgotPassword,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Forgot password?',
          style: textTheme.bodyLarge?.copyWith(
            color: kColorInfo,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ── Error banner ───────────────────────────────────────────────────────────
  Widget _buildError(TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kColorSOS.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kColorSOS.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: kColorSOS, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: textTheme.bodyLarge?.copyWith(
                  color: kColorSOS,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Login button ───────────────────────────────────────────────────────────
  Widget _buildLoginButton(TextTheme textTheme) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: kColorSOS,
          foregroundColor: Colors.white,
          disabledBackgroundColor: kColorSOS.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                'Sign In',
                style: textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  // ── Sign-up link ───────────────────────────────────────────────────────────
  Widget _buildSignUpLink(TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: textTheme.bodyLarge?.copyWith(
            color: kColorTextSecondary,
            fontSize: 15,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, AppRoutes.signup),
          child: Text(
            'Sign Up',
            style: textTheme.bodyLarge?.copyWith(
              color: kColorSOS,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: kColorTextSecondary, size: 20),
      filled: true,
      fillColor: kColorSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kColorBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kColorBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kColorInfo, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kColorSOS),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kColorSOS, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

// ── Forgot password dialog ─────────────────────────────────────────────────
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.prefillEmail});
  final String prefillEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _ctrl = TextEditingController();
  bool _sent = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.prefillEmail;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty || !_ctrl.text.contains('@')) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.instance.resetPassword(_ctrl.text.trim());
    } catch (_) {
      // Supabase does not reveal whether the email exists; always show success
      // to prevent email enumeration attacks.
    }
    if (!mounted) return;
    setState(() { _sent = true; _sending = false; });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: _sent
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_read_outlined,
                    color: kColorSafe, size: 40),
                const SizedBox(height: 12),
                Text(
                  'A reset link has been sent to ${_ctrl.text.trim()}.',
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Enter your email and we\'ll send you a reset link.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
      actions: _sent
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kColorInfo,
                  foregroundColor: Colors.white,
                ),
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send Link'),
              ),
            ],
    );
  }
}
