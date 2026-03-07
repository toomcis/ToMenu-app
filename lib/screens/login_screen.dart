import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../l10n/strings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),

            // ── Logo ──
            Text(
              'ToMenu',
              style: TextStyle(
                color:      accent,
                fontSize:   36,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              L10n.s.tagline,
              style: TextStyle(color: context.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // ── Tabs ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color:        isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(
                  color:        accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize:    TabBarIndicatorSize.tab,
                dividerColor:     Colors.transparent,
                labelColor:       Colors.white,
                unselectedLabelColor: context.textSecondary,
                labelStyle:       const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                tabs: [
                  Tab(text: L10n.s.login),
                  Tab(text: L10n.s.register),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Forms ──
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: const [
                  _LoginForm(),
                  _RegisterForm(),
                ],
              ),
            ),

            // ── Skip ──
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                L10n.s.continueAsGuest,
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Login form ────────────────────────────────────────────────────────────────

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool   _loading     = false;
  bool   _obscure     = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = L10n.s.fillAllFields);
      return;
    }

    setState(() { _loading = true; _error = null; });

    final result = await AuthService.instance.login(email, password);

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) => _FormBody(
    emailCtrl:    _emailCtrl,
    passwordCtrl: _passwordCtrl,
    loading:      _loading,
    obscure:      _obscure,
    error:        _error,
    onToggleObscure: () => setState(() => _obscure = !_obscure),
    onSubmit:     _submit,
    submitLabel:  L10n.s.login,
  );
}

// ── Register form ─────────────────────────────────────────────────────────────

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool   _loading     = false;
  bool   _obscure     = true;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name     = _nameCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = L10n.s.fillAllFields);
      return;
    }
    if (password.length < 8) {
      setState(() => _error = L10n.s.passwordTooShort);
      return;
    }

    setState(() { _loading = true; _error = null; });

    final result = await AuthService.instance.register(
      email, password,
      displayName: name.isNotEmpty ? name : null,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) => _FormBody(
    nameCtrl:     _nameCtrl,
    emailCtrl:    _emailCtrl,
    passwordCtrl: _passwordCtrl,
    loading:      _loading,
    obscure:      _obscure,
    error:        _error,
    onToggleObscure: () => setState(() => _obscure = !_obscure),
    onSubmit:     _submit,
    submitLabel:  L10n.s.register,
  );
}

// ── Shared form body ──────────────────────────────────────────────────────────

class _FormBody extends StatelessWidget {
  final TextEditingController? nameCtrl;
  final TextEditingController  emailCtrl;
  final TextEditingController  passwordCtrl;
  final bool     loading;
  final bool     obscure;
  final String?  error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final String   submitLabel;

  const _FormBody({
    this.nameCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.loading,
    required this.obscure,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.submitLabel,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (nameCtrl != null) ...[
            _Field(
              controller: nameCtrl!,
              label:       L10n.s.displayName,
              hint:        L10n.s.nicknamePlaceholder,
              icon:        Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
          ],

          _Field(
            controller:      emailCtrl,
            label:           'Email',
            hint:            'you@example.com',
            icon:            Icons.email_outlined,
            keyboardType:    TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          _Field(
            controller:      passwordCtrl,
            label:           L10n.s.password,
            hint:            '••••••••',
            icon:            Icons.lock_outline_rounded,
            obscure:         obscure,
            textInputAction: TextInputAction.done,
            onSubmitted:     (_) => onSubmit(),
            suffix: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: context.textSecondary,
                size: 20,
              ),
              onPressed: onToggleObscure,
            ),
          ),

          if (error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:        Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: Colors.red.withAlpha(80)),
              ),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ],

          const SizedBox(height: 24),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: loading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5,
                      ),
                    )
                  : Text(submitLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Reusable field ────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final String                hint;
  final IconData              icon;
  final bool                  obscure;
  final TextInputType?        keyboardType;
  final TextInputAction?      textInputAction;
  final void Function(String)? onSubmitted;
  final Widget?               suffix;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure        = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color:      context.textSecondary,
            fontSize:   12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller:      controller,
          obscureText:     obscure,
          keyboardType:    keyboardType,
          textInputAction: textInputAction,
          onSubmitted:     onSubmitted,
          style:           TextStyle(color: context.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText:    hint,
            prefixIcon:  Icon(icon, size: 20, color: context.textSecondary),
            suffixIcon:  suffix,
            filled:      true,
            fillColor:   isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   BorderSide(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:   BorderSide(color: context.accentColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}