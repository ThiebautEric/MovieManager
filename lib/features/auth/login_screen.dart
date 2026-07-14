import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../widgets/language_button.dart';
import '../../widgets/theme_toggle_button.dart';
import 'auth_controller.dart';

/// Écran combiné connexion / inscription (e-mail + mot de passe).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = ref.read(authControllerProvider);
    try {
      if (_isSignUp) {
        final needsConfirm =
            await auth.signUp(_emailCtrl.text.trim(), _passwordCtrl.text);
        if (needsConfirm && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.authAccountCreated),
            ),
          );
          setState(() => _isSignUp = false);
        }
      } else {
        await auth.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
      }
      // La redirection est gérée par le routeur via l'état d'auth.
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Sélecteurs de langue et de thème, en haut à droite (pas d'AppBar).
            const Positioned(
              top: 4,
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LanguageButton(),
                  ThemeToggleButton(),
                ],
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.movie_filter,
                            size: 72,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 12),
                        Text(l10n.appTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration:
                              InputDecoration(labelText: l10n.authEmailLabel),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? l10n.authEmailInvalid
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                              labelText: l10n.authPasswordLabel),
                          validator: (v) => (v == null || v.length < 6)
                              ? l10n.authPasswordTooShort
                              : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(_isSignUp
                                  ? l10n.authSignUp
                                  : l10n.authSignIn),
                        ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => setState(() {
                                    _isSignUp = !_isSignUp;
                                    _error = null;
                                  }),
                          child: Text(_isSignUp
                              ? l10n.authAlreadyHaveAccount
                              : l10n.authSignUp),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
