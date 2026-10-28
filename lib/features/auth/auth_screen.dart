import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/widgets.dart';
import 'auth.dart';

/// Sign in and sign up on one screen, toggled by a link.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(firebaseAuthProvider);
    final email = _email.text.trim();
    try {
      if (_signUp) {
        await auth.createUserWithEmailAndPassword(email: email, password: _password.text);
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: _password.text);
      }
      // AuthGate swaps this screen out once authStateChanges emits.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = authErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(alignment: Alignment.centerLeft, child: Wordmark()),
                      const SizedBox(height: 40),
                      Text(_signUp ? 'Create your account' : 'Welcome back', style: text.displaySmall),
                      const SizedBox(height: Space.sm),
                      Text(
                        _signUp ? 'Your expenses are private to your account.' : 'Sign in to see today’s expenses.',
                        style: text.bodyLarge!.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: Space.xl + Space.sm),
                      TextFormField(
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) => validateEmail(v ?? ''),
                      ),
                      const SizedBox(height: Space.md),
                      TextFormField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText: _signUp ? 'At least 6 characters' : null,
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                        validator: (v) => validatePassword(v ?? ''),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[const SizedBox(height: Space.lg), InlineError(_error!)],
                      const SizedBox(height: Space.xl),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.white),
                              )
                            : Text(_signUp ? 'Create account' : 'Sign in'),
                      ),
                      const SizedBox(height: Space.sm),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _signUp = !_signUp;
                                _error = null;
                              }),
                        child: Text(_signUp ? 'Already have an account? Sign in' : 'New here? Create an account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
