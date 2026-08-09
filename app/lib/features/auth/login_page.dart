import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_errors.dart';
import '../../../core/invite/pending_invite_token.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/powered_by_casinworks.dart';
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
      final msg = _friendlyAuthError(e);
      setState(() => _error = msg);
      if (mounted) showAppError(context, msg);
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
                    child: const Text('Join with an invite link'),
                  ),
                  const PoweredByCasinworks(),
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
      // With mailer_autoconfirm, session is set and the router sends owners
      // to /onboarding/store (or invitees back to /invite).
      if (res.session == null) {
        final joining = readPendingInviteToken() != null;
        setState(() {
          _info = joining
              ? 'Check your email to confirm, then sign in with the invited email. '
                  'You’ll return to Join and accept automatically.'
              : 'Check your email to confirm your account, then sign in. '
                  'After that you’ll create your store.';
        });
        if (mounted) {
          showAppMessage(
            context,
            'Account created — confirm your email, then sign in.',
          );
        }
      }
      // If session != null, auth state listener + GoRouter redirect take over.
    } catch (e) {
      final msg = _friendlyAuthError(e);
      setState(() => _error = msg);
      if (mounted) showAppError(context, msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final joiningTeam = readPendingInviteToken() != null;

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
                    joiningTeam
                        ? 'Create account to join'
                        : 'Create your owner account',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    joiningTeam
                        ? 'Use the exact email from your invite. After signup you’ll join the store automatically.'
                        : 'This registers you as a new business owner. '
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
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton.tonal(
                      onPressed: _loading ? null : () => context.go('/login'),
                      child: const Text('I’ve confirmed — go to Sign in'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: (_loading || _info != null) ? null : _submit,
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
                  const PoweredByCasinworks(),
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
  bool _autoAcceptAttempted = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    final fromQuery = widget.initialToken?.trim();
    final stored = readPendingInviteToken();
    final initial = (fromQuery != null && fromQuery.isNotEmpty)
        ? fromQuery
        : (stored ?? '');
    _token = TextEditingController(text: initial);
    if (initial.isNotEmpty) {
      savePendingInviteToken(initial);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoAccept());
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  void _goAuth(String path) {
    final t = _token.text.trim();
    if (t.isNotEmpty) savePendingInviteToken(t);
    context.go(path);
  }

  Future<void> _maybeAutoAccept() async {
    if (_autoAcceptAttempted || !mounted) return;
    final session = ref.read(currentSessionProvider);
    final token = _token.text.trim();
    if (session == null || token.length < 8) return;
    _autoAcceptAttempted = true;
    await _submit(auto: true);
  }

  Future<void> _submit({bool auto = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      setState(() {
        _error =
            'Create an account or sign in with the invited email first, then accept.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = auto ? 'Accepting your invite…' : null;
    });
    try {
      await ref.read(storeRepositoryProvider).acceptInvitation(_token.text);
      clearPendingInviteToken();
      ref.invalidate(membershipsProvider);
      setState(() => _info = 'Invite accepted. Opening your store…');
      if (mounted) context.go('/');
    } catch (e) {
      final signedEmail = ref.read(currentSessionProvider)?.user.email;
      var msg = _friendlyAuthError(e);
      if (msg.contains('doesn’t match') && signedEmail != null) {
        msg =
            'You’re signed in as $signedEmail, which doesn’t match this invite. '
            'Sign out and use the invited email, then open the join link again.';
      }
      setState(() {
        _error = msg;
        if (auto) _info = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final signedIn = session != null;
    final signedEmail = session?.user.email;
    final hasToken = _token.text.trim().length >= 8;

    ref.listen(currentSessionProvider, (prev, next) {
      if (prev == null && next != null) {
        _autoAcceptAttempted = false;
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoAccept());
      }
    });

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
                    'Join your team',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    signedIn
                        ? (hasToken
                            ? 'You’re signed in${signedEmail != null ? ' as $signedEmail' : ''}. '
                                'Accept to join — your account email must match the invite.'
                            : 'Paste the invite token from your email or owner. '
                                'Your signed-in email must match the invite.')
                        : '1. Open the invite email link (token is filled for you).\n'
                            '2. Create an account or sign in with the invited email.\n'
                            '3. You’re in — Accept runs automatically once you’re signed in.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: _token,
                    onChanged: (v) => savePendingInviteToken(v),
                    decoration: InputDecoration(
                      labelText: 'Invite token',
                      hintText: hasToken
                          ? 'Filled from your invite link'
                          : 'Paste token if you don’t have the link',
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
                  if (!signedIn) ...[
                    FilledButton(
                      onPressed: _loading ? null : () => _goAuth('/signup'),
                      child: const Text('Create account with invited email'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: _loading ? null : () => _goAuth('/login'),
                      child: const Text('Sign in with invited email'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'After you create/sign in, you’ll return here and join automatically.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.slate500,
                          ),
                    ),
                  ] else ...[
                    FilledButton(
                      onPressed: _loading ? null : () => _submit(),
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Accept invite'),
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              final keep = _token.text.trim();
                              await ref.read(authRepositoryProvider).signOut();
                              if (keep.isNotEmpty) {
                                savePendingInviteToken(keep);
                              }
                              if (mounted) {
                                setState(() {
                                  _error = null;
                                  _info = null;
                                  _autoAcceptAttempted = false;
                                });
                              }
                            },
                      child: const Text('Wrong email? Sign out'),
                    ),
                  ],
                  const PoweredByCasinworks(),
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
  if (raw.contains('Email not confirmed') ||
      raw.contains('email_not_confirmed')) {
    return 'Confirm your email first (check inbox/spam), then sign in.';
  }
  if (raw.contains('User already registered')) {
    return 'That email is already registered. Sign in instead.';
  }
  if (raw.contains('Signup requires a valid password') ||
      raw.contains('Password should be at least')) {
    return 'Password must be at least 6 characters.';
  }
  if (raw.contains('Unable to validate email') ||
      raw.contains('invalid email') ||
      raw.contains('is invalid')) {
    return 'Enter a valid email address.';
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
  return friendlyError(e, fallback: 'Could not complete sign in. Please try again.');
}
