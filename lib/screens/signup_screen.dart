import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../services/supabase_service.dart';

/// Sign-up screen — name, email, password, confirm password,
/// and role selection (Victim / Admin).
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  // 'victim' or 'admin'
  String _selectedRole = 'victim';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    setState(() => _errorMessage = null);
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.instance.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        fullName: _nameCtrl.text.trim(),
        role: _selectedRole,
      );

      if (!mounted) return;

      // Supabase may require email confirmation depending on your project
      // settings. If session is null, the user must confirm their email first.
      if (response.session == null) {
        setState(() => _isLoading = false);
        _showEmailConfirmationDialog();
        return;
      }

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

  void _showEmailConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Check your email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_unread_outlined,
                color: kColorInfo, size: 48),
            const SizedBox(height: 12),
            Text(
              'We sent a confirmation link to ${_emailCtrl.text.trim()}.\n\n'
              'Click the link to activate your account, then sign in.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kColorInfo,
              foregroundColor: Colors.white,
            ),
            child: const Text('Go to Sign In'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: kColorBackground,
      // Back arrow returns to login.
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kColorTextPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(textTheme, screenHeight),
              SizedBox(height: screenHeight * 0.04),
              _buildForm(textTheme),
              const SizedBox(height: 24),
              if (_errorMessage != null) _buildError(textTheme),
              _buildSignUpButton(textTheme),
              const SizedBox(height: 20),
              _buildLoginLink(textTheme),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(TextTheme textTheme, double screenHeight) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: kColorSOS,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: kColorSOS.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(Icons.person_add_alt_1_outlined,
              color: Colors.white, size: 34),
        ),
        const SizedBox(height: 16),
        Text(
          'Create Account',
          style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Join AidPulsate and stay protected',
          style: textTheme.bodyLarge?.copyWith(color: kColorTextSecondary),
        ),
      ],
    );
  }

  // ── Form ───────────────────────────────────────────────────────────────────
  Widget _buildForm(TextTheme textTheme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Full name.
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: 'Full Name',
              icon: Icons.person_outline,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Name is required';
              if (v.trim().length < 2) return 'Enter your full name';
              return null;
            },
          ),
          const SizedBox(height: 16),

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
              if (!v.contains('@') || !v.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password.
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: 'Password',
              icon: Icons.lock_outline,
            ).copyWith(
              helperText: 'At least 8 characters',
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
              if (v.length < 8) return 'Use at least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm password.
          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _onSignUp(),
            decoration: _inputDecoration(
              label: 'Confirm Password',
              icon: Icons.lock_outline,
            ).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: kColorTextSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != _passwordCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Role selection.
          _buildRoleSelector(textTheme),
        ],
      ),
    );
  }

  // ── Role selector ──────────────────────────────────────────────────────────
  Widget _buildRoleSelector(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account type',
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _RoleTile(
                title: 'Victim / User',
                subtitle: 'Send SOS alerts',
                icon: Icons.person_outline,
                selected: _selectedRole == 'victim',
                selectedColor: kColorSOS,
                onTap: () => setState(() => _selectedRole = 'victim'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RoleTile(
                title: 'Admin / Responder',
                subtitle: 'Monitor alerts',
                icon: Icons.admin_panel_settings_outlined,
                selected: _selectedRole == 'admin',
                selectedColor: kColorInfo,
                onTap: () => setState(() => _selectedRole = 'admin'),
              ),
            ),
          ],
        ),
      ],
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
                style:
                    textTheme.bodyLarge?.copyWith(color: kColorSOS, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sign-up button ─────────────────────────────────────────────────────────
  Widget _buildSignUpButton(TextTheme textTheme) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onSignUp,
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
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                'Create Account',
                style: textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  // ── Already have an account ────────────────────────────────────────────────
  Widget _buildLoginLink(TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style:
              textTheme.bodyLarge?.copyWith(color: kColorTextSecondary, fontSize: 15),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text(
            'Sign In',
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

// ── Role selection tile ────────────────────────────────────────────────────
class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.08)
              : kColorSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? selectedColor : kColorBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? selectedColor : kColorTextSecondary,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected ? selectedColor : kColorTextPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: kColorTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
