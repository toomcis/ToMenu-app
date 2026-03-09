import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../l10n/strings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  @override
  void initState()  { super.initState(); _tabs = TabController(length: 2, vsync: this); }
  @override
  void dispose()    { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 48),
          Text('ToMenu', style: TextStyle(color: accent, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1)),
          const SizedBox(height: 6),
          Text(L10n.s.tagline, style: TextStyle(color: context.textSecondary, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 40),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabs,
              indicator:            BoxDecoration(color: accent, borderRadius: BorderRadius.circular(10)),
              indicatorSize:        TabBarIndicatorSize.tab,
              dividerColor:         Colors.transparent,
              labelColor:           Colors.white,
              unselectedLabelColor: context.textSecondary,
              labelStyle:           const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: [Tab(text: L10n.s.login), Tab(text: L10n.s.register)],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: TabBarView(controller: _tabs, children: const [_LoginForm(), _RegisterForm()])),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(L10n.s.continueAsGuest, style: TextStyle(color: context.textSecondary, fontSize: 13)),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

// ── Login form ────────────────────────────────────────────────────────────────

class _LoginForm extends StatefulWidget {
  const _LoginForm();
  @override State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _totpCtrl     = TextEditingController();
  bool    _loading       = false;
  bool    _googleLoading = false;
  bool    _obscure       = true;
  bool    _needs2FA      = false;
  String? _error;

  @override
  void dispose() { _emailCtrl.dispose(); _passwordCtrl.dispose(); _totpCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final totp     = _needs2FA ? _totpCtrl.text.trim() : null;
    if (email.isEmpty || password.isEmpty) { setState(() => _error = L10n.s.fillAllFields); return; }
    setState(() { _loading = true; _error = null; });
    final result = await AuthService.instance.login(email, password, totpCode: totp);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      Navigator.of(context).pop();
    } else if (result.requires2FA) {
      setState(() { _needs2FA = true; _error = null; });
    } else {
      setState(() => _error = result.error);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() { _googleLoading = true; _error = null; });
    final result = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);
    if (result.success) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = result.error);
    }
  }

  void _forgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ForgotPasswordSheet(prefillEmail: _emailCtrl.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        if (!_needs2FA) ...[
          _Field(controller: _emailCtrl, label: 'Email', hint: 'you@example.com',
              icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next),
          const SizedBox(height: 16),
          _Field(
            controller: _passwordCtrl, label: L10n.s.password, hint: '••••••••',
            icon: Icons.lock_outline_rounded, obscure: _obscure,
            textInputAction: TextInputAction.done, onSubmitted: (_) => _submit(),
            suffix: IconButton(
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: context.textSecondary, size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgotPassword,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(L10n.s.forgotPassword, style: TextStyle(color: accent, fontSize: 12)),
            ),
          ),
        ] else ...[
          Icon(Icons.security_rounded, color: accent, size: 48),
          const SizedBox(height: 12),
          Text(L10n.s.enterTwoFactorCode, style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(L10n.s.twoFactorCodeHint, style: TextStyle(color: context.textSecondary, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextField(
            controller: _totpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            autofocus: true,
            style: TextStyle(color: context.textPrimary, fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(counterText: '', hintText: '000000'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() { _needs2FA = false; _totpCtrl.clear(); _error = null; }),
            child: Text(L10n.s.goBack, style: TextStyle(color: context.textSecondary, fontSize: 12)),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withAlpha(80)),
            ),
            child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        ],

        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
                backgroundColor: accent, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(_needs2FA ? L10n.s.confirm : L10n.s.login,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),

        if (!_needs2FA) ...[
          const SizedBox(height: 20),
          const _OrDivider(),
          const SizedBox(height: 20),
          _GoogleButton(loading: _googleLoading, onPressed: _googleSignIn),
        ],

        const SizedBox(height: 24),
      ]),
    );
  }
}

// ── Register form ─────────────────────────────────────────────────────────────

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();
  @override State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool    _loading       = false;
  bool    _googleLoading = false;
  bool    _obscure       = true;
  String? _error;

  @override
  void dispose() { _nameCtrl.dispose(); _emailCtrl.dispose(); _passwordCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) { setState(() => _error = L10n.s.fillAllFields); return; }
    if (password.length < 8)               { setState(() => _error = L10n.s.passwordTooShort); return; }
    setState(() { _loading = true; _error = null; });
    final result = await AuthService.instance.register(email, password, displayName: _nameCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) { Navigator.of(context).pop(); }
    else { setState(() => _error = result.error); }
  }

  Future<void> _googleSignIn() async {
    setState(() { _googleLoading = true; _error = null; });
    final result = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);
    if (result.success) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Field(controller: _nameCtrl, label: L10n.s.displayName, hint: L10n.s.nicknamePlaceholder,
            icon: Icons.person_outline_rounded, textInputAction: TextInputAction.next),
        const SizedBox(height: 16),
        _Field(controller: _emailCtrl, label: 'Email', hint: 'you@example.com',
            icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next),
        const SizedBox(height: 16),
        _Field(
          controller: _passwordCtrl, label: L10n.s.password, hint: '••••••••',
          icon: Icons.lock_outline_rounded, obscure: _obscure,
          textInputAction: TextInputAction.done, onSubmitted: (_) => _submit(),
          suffix: IconButton(
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: context.textSecondary, size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Colors.red.withAlpha(25), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withAlpha(80))),
            child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        ],

        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(L10n.s.register, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),

        const SizedBox(height: 20),
        const _OrDivider(),
        const SizedBox(height: 20),
        _GoogleButton(loading: _googleLoading, onPressed: _googleSignIn),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ── "or continue with" divider ────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Divider(color: context.border, thickness: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('or continue with', style: TextStyle(color: context.textSecondary, fontSize: 12)),
      ),
      Expanded(child: Divider(color: context.border, thickness: 1)),
    ]);
  }
}

// ── Google button ─────────────────────────────────────────────────────────────

class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _GoogleButton({ required this.loading, required this.onPressed });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
          side: BorderSide(color: context.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: context.textSecondary))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(size: const Size(20, 20), painter: _GoogleLogoPainter()),
                  const SizedBox(width: 10),
                  Text('Continue with Google',
                      style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                ],
              ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // White circle background
    canvas.drawCircle(c, r, Paint()..color = Colors.white);

    final rect = Rect.fromCircle(center: c, radius: r * 0.72);
    final sw   = r * 0.48;

    void arc(double start, double sweep, Color color) {
      canvas.drawArc(rect, start, sweep, false,
          Paint()..color = color ..style = PaintingStyle.stroke ..strokeWidth = sw ..strokeCap = StrokeCap.butt);
    }

    // Blue (top-right + right)
    arc(-0.52,  1.62, const Color(0xFF4285F4));
    // Green (bottom-right)
    arc( 1.10,  1.05, const Color(0xFF34A853));
    // Yellow (bottom-left)
    arc( 2.15,  0.55, const Color(0xFFFBBC05));
    // Red (left + top-left)
    arc( 2.70,  0.90, const Color(0xFFEA4335));

    // Blue horizontal bar (crossbar of G)
    canvas.drawLine(
      Offset(c.dx, c.dy),
      Offset(c.dx + r * 0.72, c.dy),
      Paint()..color = const Color(0xFF4285F4) ..strokeWidth = sw ..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Forgot password sheet ─────────────────────────────────────────────────────

class _ForgotPasswordSheet extends StatefulWidget {
  final String prefillEmail;
  const _ForgotPasswordSheet({ required this.prefillEmail });
  @override State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final TextEditingController _ctrl;
  bool    _loading = false;
  bool    _sent    = false;
  String? _error;

  @override
  void initState()  { super.initState(); _ctrl = TextEditingController(text: widget.prefillEmail); }
  @override
  void dispose()    { _ctrl.dispose(); super.dispose(); }

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _error = null; });
    final result = await AuthService.instance.forgotPassword(_ctrl.text.trim());
    if (!mounted) return;
    setState(() { _loading = false; _sent = result.success; _error = result.error; });
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: context.textSecondary.withAlpha(80), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        if (_sent) ...[
          Icon(Icons.mark_email_read_rounded, color: accent, size: 48),
          const SizedBox(height: 12),
          Text(L10n.s.resetEmailSent, style: TextStyle(color: context.textPrimary, fontSize: 17, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(L10n.s.resetEmailSentHint, style: TextStyle(color: context.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
            child: Text(L10n.s.gotIt),
          ),
        ] else ...[
          Text(L10n.s.forgotPassword, style: TextStyle(color: context.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(L10n.s.forgotPasswordHint, style: TextStyle(color: context.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          _Field(controller: _ctrl, label: 'Email', hint: 'you@example.com',
              icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => _send()),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loading ? null : _send,
            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(L10n.s.sendResetLink),
          ),
        ],
      ]),
    );
  }
}

// ── Reusable field ────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController  controller;
  final String                 label;
  final String                 hint;
  final IconData               icon;
  final bool                   obscure;
  final TextInputType?         keyboardType;
  final TextInputAction?       textInputAction;
  final void Function(String)? onSubmitted;
  final Widget?                suffix;

  const _Field({
    required this.controller, required this.label, required this.hint, required this.icon,
    this.obscure = false, this.keyboardType, this.textInputAction, this.onSubmitted, this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.4)),
      const SizedBox(height: 6),
      TextField(
        controller: controller, obscureText: obscure,
        keyboardType: keyboardType, textInputAction: textInputAction, onSubmitted: onSubmitted,
        style: TextStyle(color: context.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 20, color: context.textSecondary),
          suffixIcon: suffix,
          filled: true,
          fillColor: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.accentColor, width: 1.5)),
        ),
      ),
    ]);
  }
}