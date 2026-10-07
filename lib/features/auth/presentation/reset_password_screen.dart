import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:worklaw_maroc/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/language_selector.dart';
import '../application/auth_providers.dart';
import '../domain/auth_validators.dart';
import 'validation_messages.dart';

/// Reached after the user clicks a password-reset email link. Supabase
/// briefly treats them as signed in with a "recovery" session — the
/// router's redirect (see core/routing/auth_redirect.dart) keeps them
/// pinned here until updateUser() succeeds, at which point Supabase emits
/// a fresh auth event and the normal "signed in" redirect takes over.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _submitting = false;
  bool _done = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resetPasswordTitle),
        actions: const [
          Padding(padding: EdgeInsets.all(8), child: LanguageSelector()),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: _done
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.resetPasswordSuccessMessage),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    shrinkWrap: true,
                    children: [
                      TextFormField(
                        controller: _passwordController,
                        decoration:
                            InputDecoration(labelText: l10n.newPasswordLabel),
                        obscureText: true,
                        validator: (value) =>
                            mapValidationError(validatePassword(value), l10n),
                      ),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: l10n.confirmNewPasswordLabel,
                        ),
                        obscureText: true,
                        validator: (value) => mapValidationError(
                          validatePasswordsMatch(
                            _passwordController.text,
                            value,
                          ),
                          l10n,
                        ),
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
                        child: Text(l10n.resetPasswordSubmit),
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
          .updatePassword(_passwordController.text);
      // Supabase emits a fresh (non-recovery) auth event here, which
      // unblocks the router's redirect lock and sends the user to
      // /employees automatically — no navigation call needed.
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              AppLocalizations.of(context)!.resetPasswordGenericError,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
