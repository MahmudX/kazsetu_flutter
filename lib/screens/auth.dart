import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../api.dart';
import '../google_auth.dart';
import '../i18n.dart';
import '../ui.dart';

/// Fills an empty phone field with a number from this phone's SIM. Android's Phone Number Hint
/// shows the SIM numbers to choose from and needs no phone permission; closing it just lets the
/// person type. The number is still only a claim, like a typed one.
Future<void> fillFromSim(TextEditingController field) async {
  if (field.text.isNotEmpty) return;
  final result = await SmartAuth.instance.requestPhoneNumberHint();
  final number = result.data;
  if (!result.isSuccess || number == null || field.text.isNotEmpty) return;
  // +8801XXXXXXXXX is shown the way people write it here: 01XXXXXXXXX.
  final local = number.replaceAll(RegExp(r'[\s-]'), '');
  field.text = local.startsWith('+880') ? '0${local.substring(4)}' : local;
}

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
  bool _terms = false, _hidden = true, _busy = false, _termsError = false, _askedSim = false;
  String? _error, _usernameError;

  // As the first screen of the app there is nothing to go back to; the root swaps to the app.
  void _done() {
    HapticFeedback.lightImpact();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  // Signs in, or on a first Google sign-in asks for a phone number on the next screen.
  Future<void> _withGoogle() async {
    setState(() => (_busy = true, _error = null));
    try {
      final token = await GoogleAuth.firebaseIdToken();
      if (token == null) return setState(() => _busy = false);
      final signup = await session.google(token);
      if (signup != null && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GoogleFinishScreen(signup: signup)));
      }
      if (!mounted) return;
      if (session.signedIn) {
        _done();
      } else {
        setState(() => _busy = false);
      }
    } on ApiError catch (e) {
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => (_busy = false, _error = e.message));
    }
  }

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
      if (mounted) _done();
    } on ApiError catch (e) {
      HapticFeedback.mediumImpact();
      setState(() => (_busy = false, _error = e.message));
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? t('Required') : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClarityMask(child: Scaffold(
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
                          ...[
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                              onPressed: _busy ? null : _withGoogle,
                              child: Text(t('Continue with Google')),
                            ),
                            Row(children: [
                              const Expanded(child: Divider()),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(t('or'))),
                              const Expanded(child: Divider()),
                            ]),
                          ],
                          TextFormField(
                            controller: _login,
                            onTap: () async {
                              if (_askedSim) return;
                              _askedSim = true;
                              await fillFromSim(_login);
                            },
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
    ));
  }
}

/// A first Google sign-in: Google already gave the name and email, so only a phone number is
/// asked. A number that already has an account links to it once its password is given.
class GoogleFinishScreen extends StatefulWidget {
  const GoogleFinishScreen({super.key, required this.signup});
  final Map<String, dynamic> signup;
  @override
  State<GoogleFinishScreen> createState() => _GoogleFinishScreenState();
}

class _GoogleFinishScreenState extends State<GoogleFinishScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  late final _name = TextEditingController(text: '${widget.signup['displayName'] ?? ''}');
  final _password = TextEditingController();
  bool _terms = false, _needsPassword = false, _busy = false, _termsError = false;
  String? _error;
  Map<String, String> _fields = const {};

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    // Linking an existing account needs its password, not the terms again.
    final termsMissing = !_needsPassword && !_terms;
    if (termsMissing) setState(() => _termsError = true);
    if (!valid || termsMissing) {
      HapticFeedback.mediumImpact();
      return;
    }
    setState(() => (_busy = true, _error = null, _fields = const {}));
    try {
      await session.googleFinish({
        'ticket': widget.signup['ticket'],
        'phone': _phone.text.trim(),
        'displayName': _name.text.trim(),
        'username': widget.signup['username'],
        'password': _needsPassword ? _password.text : null,
        'acceptTerms': _terms,
      });
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop();
    } on ApiError catch (e) {
      HapticFeedback.mediumImpact();
      final field = e.body['field'] as String?;
      setState(() {
        _busy = false;
        _needsPassword = _needsPassword || e.body['needsPassword'] == true;
        if (field == 'phone' || field == 'password' || field == 'displayName') {
          _fields = {field!: e.message};
        } else {
          _error = e.message;
        }
      });
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? t('Required') : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = widget.signup['email'] as String?;
    return Scaffold(
      appBar: AppBar(title: Text(t('Almost done'))),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text(t('Google phone body'), style: theme.textTheme.bodyLarge),
            if (email != null) ...[
              const SizedBox(height: 6),
              Text(email, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _phone,
              onTap: () => fillFromSim(_phone),
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              textInputAction: TextInputAction.next,
              validator: _required,
              onChanged: (_) {
                // A different number may not have an account: ask for the terms again.
                if (_needsPassword) setState(() => (_needsPassword = false, _fields = const {}));
              },
              decoration: InputDecoration(
                labelText: t('Phone number'),
                hintText: '01XXXXXXXXX',
                errorText: _fields['phone'],
                prefixIcon: const Icon(FluentIcons.phone_24_regular),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              validator: _required,
              decoration: InputDecoration(
                labelText: t('Your name'),
                errorText: _fields['displayName'],
                prefixIcon: const Icon(FluentIcons.contact_card_24_regular),
              ),
            ),
            if (_needsPassword) ...[
              const SizedBox(height: 14),
              Text(t('Google link body'), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                validator: _required,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: t('Password'),
                  errorText: _fields['password'],
                  prefixIcon: const Icon(FluentIcons.lock_closed_24_regular),
                ),
              ),
            ] else
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
                        child: Text(t('Read terms'),
                            style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline)),
                      ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.tertiary, foregroundColor: theme.colorScheme.onTertiary),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(t(_needsPassword ? 'Sign in' : 'Create account')),
            ),
          ]),
        ),
      ),
    );
  }
}
