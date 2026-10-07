import 'package:flutter/material.dart';
import 'package:worklaw_maroc/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/language_selector.dart';
import '../application/auth_providers.dart';
import '../domain/auth_validators.dart';
import 'validation_messages.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _organizationNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;
  String? _confirmationSentToEmail;

  @override
  void dispose() {
    _fullNameController.dispose();
    _organizationNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.signupTitle),
        actions: const [
          Padding(padding: EdgeInsets.all(8), child: LanguageSelector()),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _confirmationSentToEmail != null
              ? _ConfirmationSentView(
                  email: _confirmationSentToEmail!,
                  onGoToLogin: () => context.go('/login'),
                )
              : _buildForm(context, l10n),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        children: [
          TextFormField(
            controller: _fullNameController,
            decoration: InputDecoration(labelText: l10n.fullNameLabel),
            validator: (value) => mapValidationError(
              validateMaxLength(value, signupTextFieldMaxLength),
              l10n,
            ),
          ),
          TextFormField(
            controller: _organizationNameController,
            decoration: InputDecoration(labelText: l10n.organizationNameLabel),
            validator: (value) => mapValidationError(
              validateMaxLength(value, signupTextFieldMaxLength),
              l10n,
            ),
          ),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(labelText: l10n.emailLabel),
            keyboardType: TextInputType.emailAddress,
            validator: (value) => mapValidationError(validateEmail(value), l10n),
          ),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(labelText: l10n.passwordLabel),
            obscureText: true,
            validator: (value) => mapValidationError(validatePassword(value), l10n),
          ),
          TextFormField(
            controller: _confirmPasswordController,
            decoration: InputDecoration(labelText: l10n.confirmPasswordLabel),
            obscureText: true,
            validator: (value) => mapValidationError(
              validatePasswordsMatch(_passwordController.text, value),
              l10n,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(l10n.signupSubmit),
          ),
          TextButton(
            onPressed: () => context.go('/login'),
            child: Text(l10n.goToLogin),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final email = _emailController.text.trim();
    try {
      final response = await ref.read(authRepositoryProvider).signUp(
            email: email,
            password: _passwordController.text,
            fullName: _fullNameController.text.trim(),
            organizationName: _organizationNameController.text.trim(),
          );

      if (!mounted) return;
      if (response.session == null) {
        // Email confirmation is enabled on this project: signUp() succeeds
        // but returns no session until the user clicks the email link.
        setState(() => _confirmationSentToEmail = email);
      }
      // If a session was returned, the auth state stream fires and the
      // router's redirect takes the user to /employees — no navigation
      // call needed here.
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = AppLocalizations.of(context)!.signupGenericError,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

}

class _ConfirmationSentView extends StatelessWidget {
  const _ConfirmationSentView({required this.email, required this.onGoToLogin});

  final String email;
  final VoidCallback onGoToLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.signupConfirmationSentMessage(email)),
          const SizedBox(height: 16),
          FilledButton(onPressed: onGoToLogin, child: Text(l10n.backToLogin)),
        ],
      ),
    );
  }
}
