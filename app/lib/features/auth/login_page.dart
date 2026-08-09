import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../data/providers/session_providers.dart';
import '../../../domain/enums.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _email.text,
            password: _password.text,
          );
      // Router redirect handles next screen.
    } catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandMark(),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Welcome back',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Sign in with the email your owner invited, or your owner account.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Min 6 characters' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => context.go('/signup'),
                    child: const Text('Create a new store account'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/invite'),
                    child: const Text('I have an invite code'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final res = await ref.read(authRepositoryProvider).signUp(
            email: _email.text,
            password: _password.text,
            fullName: _name.text,
          );
      if (res.session == null) {
        setState(() {
          _info =
              'Check your email to confirm your account, then sign in. '
              'After that you’ll create your store.';
        });
      }
    } catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandMark(),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Create your owner account',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'This registers you as a new business owner. '
                    'Teammates join only via Owner/Admin invite — not free signup.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) =>
                        (v == null || v.trim().length < 2) ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Min 6 characters' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_info!, style: const TextStyle(color: AppColors.success)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create account'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Already have an account? Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InviteAcceptPage extends ConsumerStatefulWidget {
  const InviteAcceptPage({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<InviteAcceptPage> createState() => _InviteAcceptPageState();
}

class _InviteAcceptPageState extends ConsumerState<InviteAcceptPage> {
  late final TextEditingController _token;
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: widget.initialToken ?? '');
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      setState(() => _error = 'Sign in (or sign up with the invited email) first, then accept.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(storeRepositoryProvider).acceptInvitation(_token.text);
      ref.invalidate(membershipsProvider);
      setState(() => _info = 'Invite accepted. Opening your store…');
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(currentSessionProvider) != null;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandMark(businessType: BusinessType.retail),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Join with invite',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    signedIn
                        ? 'Paste the invite token from your Owner/Admin. Your signed-in email must match the invite.'
                        : 'Sign in with the invited email first, then paste the invite token.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _token,
                    decoration: const InputDecoration(
                      labelText: 'Invite token',
                      hintText: 'Paste token from invitation',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 8) ? 'Enter invite token' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_info!, style: const TextStyle(color: AppColors.success)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(signedIn ? 'Accept invite' : 'Accept (sign in required)'),
                  ),
                  if (!signedIn)
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Go to sign in'),
                    ),
                  TextButton(
                    onPressed: () => context.go('/signup'),
                    child: const Text('Create account with invited email'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _friendlyAuthError(Object e) {
  final raw = e.toString();
  if (raw.contains('Invalid login credentials')) {
    return 'Wrong email or password.';
  }
  if (raw.contains('User already registered')) {
    return 'That email is already registered. Sign in instead.';
  }
  if (raw.contains('INVITE_EMAIL_MISMATCH')) {
    return 'Signed-in email doesn’t match this invite.';
  }
  if (raw.contains('INVITE_INVALID_OR_EXPIRED')) {
    return 'Invite is invalid or expired.';
  }
  if (raw.contains('FREE_MONTHLY_LIMIT_REACHED')) {
    return 'Free monthly transaction limit reached.';
  }
  return raw.replaceFirst('Exception: ', '');
}
