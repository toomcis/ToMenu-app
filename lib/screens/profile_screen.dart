import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../l10n/strings.dart';
import '../services/auth_service.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _pfpPath;

  @override
  void initState() {
    super.initState();
    _loadPfp();
    AuthService.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() { if (mounted) setState(() {}); }

  Future<void> _loadPfp() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _pfpPath = prefs.getString('pfp_path'));
  }

  Future<void> _pickPfp() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85,
    );
    if (picked == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pfp_path', picked.path);
    if (mounted) setState(() => _pfpPath = picked.path);
  }

  void _openSettings() {
    MainShell.of(context).hideBottomBar();
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const SettingsScreen(),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    )).then((_) { if (mounted) MainShell.of(context).showBottomBar(); });
  }

  void _openLogin() {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const LoginScreen(),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    ));
  }

  Future<void> _confirmDisable2FA(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _Disable2FADialog(),
    );
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.bg1,
        title: Text(L10n.s.logout, style: TextStyle(color: context.textPrimary)),
        content: Text(L10n.s.logoutConfirm, style: TextStyle(color: context.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text(L10n.s.cancel, style: TextStyle(color: context.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text(L10n.s.logout, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) await AuthService.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final auth   = AuthService.instance;

    final initial = auth.isLoggedIn
        ? auth.user!.displayLabel[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text(L10n.s.profile),
        backgroundColor: context.bg1,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: context.textSecondary),
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 28),

              // ── Avatar ──
              Stack(children: [
                GestureDetector(
                  onTap: _pickPfp,
                  child: Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withAlpha(30),
                      border: Border.all(color: accent.withAlpha(80), width: 2),
                      image: _pfpPath != null
                          ? DecorationImage(image: FileImage(File(_pfpPath!)), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _pfpPath == null
                        ? Center(child: Text(initial,
                            style: TextStyle(color: accent, fontSize: 38, fontWeight: FontWeight.w700)))
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: GestureDetector(
                    onTap: _pickPfp,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: accent, shape: BoxShape.circle,
                        border: Border.all(color: context.bgColor, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.black),
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 16),

              // ── Name display or sign-in prompt ──
              if (auth.isLoggedIn) ...[
                _NameSection(user: auth.user!),
              ] else ...[
                Center(
                  child: GestureDetector(
                    onTap: _openLogin,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color:        accent.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                        border:       Border.all(color: accent.withAlpha(60)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.login_rounded, size: 16, color: accent),
                        const SizedBox(width: 8),
                        Text(L10n.s.signInOrRegister,
                            style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ── Account info cards (logged in only) ──
              if (auth.isLoggedIn) ...[
                _InfoCard(
                  icon: auth.user!.emailVerified
                      ? Icons.verified_rounded
                      : Icons.mail_outline_rounded,
                  iconColor: auth.user!.emailVerified ? accent : Colors.orange,
                  title: auth.user!.email,
                  subtitle: auth.user!.emailVerified
                      ? L10n.s.emailVerified
                      : L10n.s.emailNotVerified,
                  trailing: auth.user!.emailVerified ? null : TextButton(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: context.bg1,
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (_) => _VerifyEmailSheet(email: auth.user!.email),
                    ),
                    child: Text(L10n.s.verifyEmail, style: TextStyle(color: Colors.orange, fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 10),
                _InfoCard(
                  icon: auth.user!.totpEnabled
                      ? Icons.security_rounded
                      : Icons.shield_outlined,
                  iconColor: auth.user!.totpEnabled ? accent : context.textSecondary,
                  title: L10n.s.twoFactor,
                  subtitle: auth.user!.totpEnabled ? L10n.s.twoFactorEnabled : L10n.s.twoFactorDisabled,
                  trailing: auth.user!.totpEnabled
                      ? TextButton(
                          onPressed: () => _confirmDisable2FA(context),
                          child: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
                        )
                      : TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TwoFactorScreen()),
                          ).then((_) { if (mounted) setState(() {}); }),
                          child: Text(L10n.s.enable, style: TextStyle(color: accent, fontSize: 12)),
                        ),
                ),
                const SizedBox(height: 24),

                // ── Linked accounts ──────────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Linked accounts',
                    style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ),
                const SizedBox(height: 10),
                _LinkedAccountsSection(onChanged: () => setState(() {})),

                const SizedBox(height: 32),
                TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 18),
                  label: Text(L10n.s.logout, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              ],

              const SizedBox(height: 24),
              Text(L10n.s.version, style: TextStyle(color: context.textSecondary, fontSize: 11)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Name section with inline editing ─────────────────────────────────────────

class _NameSection extends StatefulWidget {
  final AuthUser user;
  const _NameSection({ required this.user });

  @override
  State<_NameSection> createState() => _NameSectionState();
}

class _NameSectionState extends State<_NameSection> {
  bool _editing = false;
  final _displayNameCtrl = TextEditingController();
  final _nicknameCtrl    = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _displayNameCtrl.text = widget.user.displayName ?? '';
    _nicknameCtrl.text    = widget.user.nickname    ?? '';
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final dn = _displayNameCtrl.text.trim();
    final handle = _nicknameCtrl.text.trim();
    if (dn.isEmpty) {
      setState(() => _error = 'Display name is required');
      return;
    }
    if (handle.isEmpty) {
      setState(() => _error = 'Handle is required');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final result = await AuthService.instance.updateProfile(
      displayName: _displayNameCtrl.text,
      nickname:    _nicknameCtrl.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.success) {
      setState(() => _editing = false);
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final user   = AuthService.instance.user ?? widget.user;

    if (!_editing) {
      // ── Display mode ──
      return Column(children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          // big label
          Text(
            user.displayLabel,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () { _reset(); setState(() => _editing = true); },
            child: Icon(Icons.edit_rounded, size: 18, color: context.textSecondary),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          user.handle ?? '@—',
          style: TextStyle(
            color: user.handle != null ? context.textSecondary : Colors.orange,
            fontSize: 13,
          ),
        ),
      ]);
    }

    // ── Edit mode ──
    final cooldown = user.nicknameCooldownDays;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Display name field — visible name, not unique, always changeable
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          L10n.s.displayName,
          style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _displayNameCtrl,
          maxLength: 32,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Ján Novák',
            counterStyle: TextStyle(color: context.textSecondary, fontSize: 10),
            helperText: 'What others see. Not unique. Can be changed any time.',
            helperStyle: TextStyle(color: context.textSecondary, fontSize: 11),
          ),
        ),
      ]),
      const SizedBox(height: 16),

      // Handle field — unique, searchable, 7-day cooldown
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          L10n.s.nicknameLabel,
          style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _nicknameCtrl,
          enabled: cooldown == null,
          maxLength: 24,
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            prefixText: '@',
            prefixStyle: TextStyle(color: context.textSecondary, fontSize: 15),
            hintText: 'yourhandle',
            counterStyle: TextStyle(color: context.textSecondary, fontSize: 10),
            helperText: cooldown != null
                ? L10n.s.nameChangeCooldown(cooldown)
                : 'Unique. Letters, numbers, _ . - allowed. How others find you.',
            helperStyle: TextStyle(
              color: cooldown != null ? Colors.orange : context.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
      ]),

      if (_error != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withAlpha(80)),
          ),
          child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ),
      ],

      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _saving ? null : () => setState(() { _editing = false; _error = null; }),
            child: Text(L10n.s.cancel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent, foregroundColor: Colors.white,
            ),
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(L10n.s.save),
          ),
        ),
      ]),
    ]);
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   title;
  final String   subtitle;
  final Widget?  trailing;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0)),
      ),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,    style: TextStyle(color: context.textPrimary,   fontSize: 14, fontWeight: FontWeight.w500)),
          Text(subtitle, style: TextStyle(color: context.textSecondary, fontSize: 12)),
        ])),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

// ── 2FA Screen ────────────────────────────────────────────────────────────────

class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final _codeCtrl  = TextEditingController();
  TwoFASetup? _setup;
  bool        _loading = false;
  String?     _error;
  bool        _success = false;

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

  Future<void> _startSetup() async {
    setState(() => _loading = true);
    final setup = await AuthService.instance.setup2FA();
    if (!mounted) return;
    setState(() { _setup = setup; _loading = false; });
  }

  Future<void> _verifyAndEnable() async {
    setState(() { _loading = true; _error = null; });
    final result = await AuthService.instance.verify2FA(_codeCtrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      // Brief success flash then pop back to profile
      setState(() => _success = true);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() => _error = result.error);
    }
  }

  Future<void> _disable() async {
    setState(() { _loading = true; _error = null; });
    final result = await AuthService.instance.disable2FA(_codeCtrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent  = context.accentColor;
    final enabled = AuthService.instance.user?.totpEnabled ?? false;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(title: Text(L10n.s.twoFactor), backgroundColor: context.bg1),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: enabled ? _disableView(accent) : _setupView(accent),
        ),
      ),
    );
  }

  Widget _setupView(Color accent) {
    if (_success) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_rounded, color: accent, size: 64),
        const SizedBox(height: 16),
        Text(L10n.s.twoFactorEnabled, style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(L10n.s.twoFactorEnabledHint, style: TextStyle(color: context.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white),
          child: Text(L10n.s.gotIt),
        ),
      ]));
    }

    if (_setup == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shield_outlined, color: context.textSecondary, size: 56),
        const SizedBox(height: 16),
        Text(L10n.s.twoFactorSetupTitle, style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(L10n.s.twoFactorSetupHint, style: TextStyle(color: context.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _startSetup,
            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(L10n.s.twoFactorStart),
          ),
        ),
      ]));
    }

    // Show QR / secret + code entry
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(L10n.s.twoFactorScanTitle, style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(L10n.s.twoFactorScanHint, style: TextStyle(color: context.textSecondary, fontSize: 13)),
      const SizedBox(height: 20),

      // QR code
      Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(
            data: _setup!.otpauthUri,
            version: QrVersions.auto,
            size: 200,
            backgroundColor: Colors.white,
          ),
        ),
      ),
      const SizedBox(height: 16),

      // Manual entry secret
      Text(L10n.s.twoFactorSecretHint, style: TextStyle(color: context.textSecondary, fontSize: 12), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: _setup!.secret));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Secret key copied'), duration: Duration(seconds: 2)),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(children: [
            Expanded(
              child: SelectableText(
                _setup!.secret,
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14, letterSpacing: 2),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.copy_rounded, size: 16, color: Colors.white.withAlpha(120)),
          ]),
        ),
      ),
      const SizedBox(height: 24),

      Text(L10n.s.twoFactorEnterCode, style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextField(
        controller: _codeCtrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        autofocus: false,
        style: TextStyle(color: context.textPrimary, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(counterText: '', hintText: '000000'),
        onSubmitted: (_) => _verifyAndEnable(),
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
      ],
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: _loading ? null : _verifyAndEnable,
        style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14)),
        child: _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(L10n.s.twoFactorConfirm),
      ),
      const SizedBox(height: 24),
    ]));
  }

  Widget _disableView(Color accent) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Icon(Icons.security_rounded, color: accent, size: 48),
      const SizedBox(height: 16),
      Text(L10n.s.twoFactorActive, style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(L10n.s.twoFactorDisableHint, style: TextStyle(color: context.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: 32),
      Text(L10n.s.twoFactorEnterCode, style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),
      TextField(
        controller: _codeCtrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.textPrimary, fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w700),
        decoration: InputDecoration(counterText: '', hintText: '000000'),
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
      ],
      const Spacer(),
      OutlinedButton(
        onPressed: _loading ? null : _disable,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2))
            : Text(L10n.s.twoFactorDisable),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Email verification bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _VerifyEmailSheet extends StatefulWidget {
  final String email;
  const _VerifyEmailSheet({required this.email});
  @override State<_VerifyEmailSheet> createState() => _VerifyEmailSheetState();
}

class _VerifyEmailSheetState extends State<_VerifyEmailSheet> {
  final _codeCtrl = TextEditingController();
  bool    _sent    = false;
  bool    _loading = false;
  String? _error;

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

  Future<void> _sendCode() async {
    setState(() { _loading = true; _error = null; });
    final result = await AuthService.instance.resendVerificationEmail();
    if (!mounted) return;
    setState(() { _loading = false; _sent = result.success; _error = result.error; });
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) { setState(() => _error = 'Enter the 6-digit code'); return; }
    setState(() { _loading = true; _error = null; });
    final result = await AuthService.instance.verifyEmail(widget.email, code);
    if (!mounted) return;
    setState(() { _loading = false; });
    if (result.success) {
      await AuthService.instance.refreshUser();
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return Padding(
      padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: context.textSecondary.withAlpha(80), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),

        if (!_sent) ...[
          Icon(Icons.mark_email_unread_outlined, color: Colors.orange, size: 40),
          const SizedBox(height: 12),
          Text(L10n.s.verifyEmail,
              style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('We\'ll send a verification link to\n${widget.email}',
              style: TextStyle(color: context.textSecondary, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _sendCode,
            style: ElevatedButton.styleFrom(
                backgroundColor: accent, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(L10n.s.resendEmail),
          ),
        ] else ...[
          Icon(Icons.mark_email_read_rounded, color: accent, size: 40),
          const SizedBox(height: 12),
          Text(L10n.s.verificationSent,
              style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Check your inbox and tap the link in the email,\nor enter the 6-digit code below:',
              style: TextStyle(color: context.textSecondary, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            autofocus: true,
            style: TextStyle(color: context.textPrimary, fontSize: 28,
                letterSpacing: 10, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accent, width: 1.5)),
            ),
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _verify,
            style: ElevatedButton.styleFrom(
                backgroundColor: accent, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(L10n.s.verify),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading ? null : _sendCode,
            child: Text(L10n.s.resendCode, style: TextStyle(color: context.textSecondary, fontSize: 12)),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Disable 2FA confirmation dialog with 5s countdown
// ─────────────────────────────────────────────────────────────────────────────

class _Disable2FADialog extends StatefulWidget {
  const _Disable2FADialog();
  @override State<_Disable2FADialog> createState() => _Disable2FADialogState();
}

class _Disable2FADialogState extends State<_Disable2FADialog> {
  final _codeCtrl = TextEditingController();
  int     _countdown = 5;
  bool    _loading   = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown = (_countdown - 1).clamp(0, 5));
      return _countdown > 0;
    });
  }

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

  Future<void> _disable() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) { setState(() => _error = 'Enter the 6-digit code from your authenticator app'); return; }
    setState(() { _loading = true; _error = null; });
    final result = await AuthService.instance.disable2FA(code);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _countdown == 0 && !_loading;
    return AlertDialog(
      backgroundColor: context.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        const Icon(Icons.security_rounded, color: Colors.red, size: 20),
        const SizedBox(width: 8),
        Text('Remove 2FA', style: TextStyle(color: context.textPrimary, fontSize: 17)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'This will disable two-factor authentication on your account. Enter your authenticator code to confirm.',
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          autofocus: true,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 24,
            letterSpacing: 8,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
          onSubmitted: (_) { if (canConfirm) _disable(); },
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
      ]),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: context.textSecondary)),
        ),
        ElevatedButton(
          onPressed: canConfirm ? _disable : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.red.withAlpha(60),
          ),
          child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(_countdown > 0 ? 'Yes, remove ($_countdown)' : 'Yes, remove'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Linked accounts section — Google (Facebook + GitHub placeholders)
// ─────────────────────────────────────────────────────────────────────────────

class _LinkedAccountsSection extends StatefulWidget {
  final VoidCallback onChanged;
  const _LinkedAccountsSection({required this.onChanged});
  @override State<_LinkedAccountsSection> createState() => _LinkedAccountsSectionState();
}

class _LinkedAccountsSectionState extends State<_LinkedAccountsSection> {
  List<String> _linked   = [];
  bool         _loading  = false;
  bool         _fetched  = false;

  @override
  void initState() {
    super.initState();
    _fetchProviders();
  }

  Future<void> _fetchProviders() async {
    final providers = await AuthService.instance.getLinkedProviders();
    if (!mounted) return;
    setState(() { _linked = providers; _fetched = true; });
  }

  Future<void> _connectGoogle() async {
    setState(() => _loading = true);
    final result = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      await _fetchProviders();
      widget.onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google account linked!'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to link Google'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _disconnectGoogle() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.bg1,
        title: Text('Unlink Google?', style: TextStyle(color: context.textPrimary)),
        content: Text('You can re-link it any time.', style: TextStyle(color: context.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlink', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    final result = await AuthService.instance.unlinkGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      await _fetchProviders();
      widget.onChanged();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to unlink'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_fetched) return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));

    return Column(children: [
      _ProviderTile(
        logo: _GoogleLogo(),
        name: 'Google',
        connected: _linked.contains('google'),
        loading: _loading,
        onConnect:    _connectGoogle,
        onDisconnect: _disconnectGoogle,
      ),
      const SizedBox(height: 8),
      _ProviderTile(
        logo: _ProviderIcon(Icons.facebook_rounded, const Color(0xFF1877F2)),
        name: 'Facebook',
        connected: false,
        loading: false,
        comingSoon: true,
        onConnect: () {},
        onDisconnect: () {},
      ),
      const SizedBox(height: 8),
      _ProviderTile(
        logo: _ProviderIcon(Icons.code_rounded, const Color(0xFF6e5494)),
        name: 'GitHub',
        connected: false,
        loading: false,
        comingSoon: true,
        onConnect: () {},
        onDisconnect: () {},
      ),
    ]);
  }
}

class _ProviderTile extends StatelessWidget {
  final Widget       logo;
  final String       name;
  final bool         connected;
  final bool         loading;
  final bool         comingSoon;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _ProviderTile({
    required this.logo,
    required this.name,
    required this.connected,
    required this.loading,
    required this.onConnect,
    required this.onDisconnect,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected
              ? accent.withAlpha(80)
              : Theme.of(context).dividerColor.withAlpha(40),
        ),
      ),
      child: Row(children: [
        SizedBox(width: 28, height: 28, child: logo),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            if (comingSoon)
              Text('Coming soon', style: TextStyle(color: context.textSecondary, fontSize: 11))
            else if (connected)
              Text('Connected', style: TextStyle(color: accent, fontSize: 11)),
          ]),
        ),
        if (loading)
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        else if (comingSoon)
          const SizedBox.shrink()
        else if (connected)
          TextButton(
            onPressed: onDisconnect,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('Disconnect', style: TextStyle(color: Colors.red, fontSize: 12)),
          )
        else
          TextButton(
            onPressed: onConnect,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Text('Connect', style: TextStyle(color: accent, fontSize: 12)),
          ),
      ]),
    );
  }
}

// Simple Google "G" logo painted with Canvas
class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(28, 28), painter: _GoogleLogoPainter());
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Circle segments
    final arcs = [
      (const Color(0xFF4285F4), -0.1,  1.6),
      (const Color(0xFF34A853),  1.5,  1.6),
      (const Color(0xFFFBBC05),  3.1,  0.8),
      (const Color(0xFFEA4335),  3.9,  1.5),
    ];
    for (final (color, start, sweep) in arcs) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start, sweep, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = size.width * 0.22,
      );
    }

    // White center + blue tab
    canvas.drawCircle(c, r * 0.55, Paint()..color = Colors.white);
    final tabRect = Rect.fromLTWH(c.dx - r * 0.05, c.dy - r * 0.18, r * 1.05, r * 0.36);
    canvas.drawRect(tabRect, Paint()..color = const Color(0xFF4285F4));
    canvas.drawCircle(Offset(c.dx + r * 0.55, c.dy), r * 0.18, Paint()..color = const Color(0xFF4285F4));
  }

  @override bool shouldRepaint(_) => false;
}

class _ProviderIcon extends StatelessWidget {
  final IconData icon;
  final Color    color;
  const _ProviderIcon(this.icon, this.color);
  @override
  Widget build(BuildContext context) => Icon(icon, color: color, size: 26);
}