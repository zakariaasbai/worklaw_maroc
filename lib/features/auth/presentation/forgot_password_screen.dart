import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:worklaw_maroc/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/language_selector.dart';
import '../application/auth_providers.dart';
import '../domain/auth_validators.dart';
import 'validation_messages.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _submitting = false;
  bool _sent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.forgotPasswordTitle),
        actions: const [
          Padding(padding: EdgeInsets.all(8), child: LanguageSelector()),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _sent
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.forgotPasswordSuccessMessage),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.go('/login'),
                        child: Text(l10n.backToLogin),
                      ),
                    ],
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    shrinkWrap: true,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(labelText: l10n.emailLabel),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            mapValidationError(validateEmail(value), l10n),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: Text(l10n.forgotPasswordSubmit),
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text(l10n.backToLogin),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPasswordForEmail(_emailController.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              AppLocalizations.of(context)!.forgotPasswordGenericError,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
