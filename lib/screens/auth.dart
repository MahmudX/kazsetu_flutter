import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../i18n.dart';
import '../ui.dart';

/// Signs in when needed and reports whether the person is signed in afterwards.
Future<bool> requireSignIn(BuildContext context) async {
  if (session.signedIn) return true;
  await Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const AuthScreen()));
  return session.signedIn;
}

/// Shown in place of a private tab for guests.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Message(
        icon: icon,
        title: t('Sign in to see this'),
        body: t('Sign in prompt body'),
        action: t('Sign in'),
        onAction: () => requireSignIn(context),
      );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.register = false});
  final bool register;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _register = widget.register;
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool _terms = false, _hidden = true, _busy = false, _termsError = false;
  String? _error, _usernameError;

  @override
  void dispose() {
    _login.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    if (_register && !_terms) setState(() => _termsError = true);
    if (!valid || (_register && !_terms)) {
      HapticFeedback.mediumImpact();
      return;
    }
    setState(() => (_busy = true, _error = null, _usernameError = null));
    try {
      if (_register) {
        await session.register({
          'phone': _login.text.trim(),
          'displayName': _name.text.trim(),
          'password': _password.text,
          'acceptTerms': true,
        });
      } else {
        await session.login(_login.text.trim(), _password.text);
      }
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      HapticFeedback.mediumImpact();
      setState(() => (_busy = false, _error = e.message));
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? t('Required') : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: K.deep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          TextButton(
            onPressed: () => session.setLang(bn ? 'en' : 'bn').then((_) => setState(() {})),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: Text(bn ? 'English' : 'বাংলা'),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: K.brandGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const Logo(height: 64),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(key: ValueKey(_register), children: [
                    Text(t(_register ? 'Join KazSetu' : 'Welcome back'),
                        style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white), textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    Text(t(_register ? 'Join body' : 'Sign in body'),
                        style: const TextStyle(color: Colors.white70, fontSize: 15), textAlign: TextAlign.center),
                  ]),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _form,
                      child: AutofillGroup(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 14, children: [
                          TextFormField(
                            controller: _login,
                            keyboardType: _register ? TextInputType.phone : TextInputType.text,
                            autofillHints: [_register ? AutofillHints.telephoneNumber : AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            validator: _required,
                            decoration: InputDecoration(
                              labelText: t(_register ? 'Phone number' : 'Phone or username'),
                              hintText: _register ? '01XXXXXXXXX' : null,
                              prefixIcon: Icon(_register ? FluentIcons.phone_24_regular : FluentIcons.person_24_regular),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            child: _register
                                ? TextFormField(
                                    controller: _name,
                                    autofillHints: const [AutofillHints.name],
                                    textCapitalization: TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    validator: _required,
                                    decoration: InputDecoration(
                                      labelText: t('Your name'),
                                      errorText: _usernameError,
                                      prefixIcon: const Icon(FluentIcons.contact_card_24_regular),
                                    ),
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                          TextFormField(
                            controller: _password,
                            obscureText: _hidden,
                            autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            validator: (v) => _register && (v ?? '').length < 6 ? t('Password hint') : _required(v),
                            decoration: InputDecoration(
                              labelText: t('Password'),
                              helperText: _register ? t('Password hint') : null,
                              prefixIcon: const Icon(FluentIcons.lock_closed_24_regular),
                              suffixIcon: IconButton(
                                tooltip: t(_hidden ? 'Show password' : 'Hide password'),
                                icon: Icon(_hidden ? FluentIcons.eye_24_regular : FluentIcons.eye_off_24_regular),
                                onPressed: () => setState(() => _hidden = !_hidden),
                              ),
                            ),
                          ),
                          if (_register)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _terms,
                              onChanged: (v) => setState(() => (_terms = v ?? false, _termsError = false)),
                              title: Text(t('Accept terms')),
                              subtitle: _termsError
                                  ? Text(t('Required'), style: TextStyle(color: theme.colorScheme.error))
                                  : GestureDetector(
                                      onTap: () => openWeb('/terms'),
                                      child: Text(t('Read terms'), style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline)),
                                    ),
                            ),
                          if (_error != null)
                            Semantics(
                              liveRegion: true,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: theme.colorScheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.tertiary, foregroundColor: theme.colorScheme.onTertiary),
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : Text(t(_register ? 'Create account' : 'Sign in')),
                          ),
                          if (!_register)
                            TextButton(onPressed: () => openWeb('/account/forgot-password'), child: Text(t('Forgot password?'))),
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(t(_register ? 'Have account?' : 'No account?'), style: const TextStyle(color: Colors.white70)),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: () => setState(() => (_register = !_register, _error = null)),
                    child: Text(t(_register ? 'Sign in' : 'Create account'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
