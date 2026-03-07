import 'dart:io';
import 'package:flutter/material.dart';
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
  final _nicknameController = TextEditingController();
  bool    _saved    = false;
  String? _pfpPath;

  @override
  void initState() {
    super.initState();
    _load();
    // keep UI in sync when auth state changes
    AuthService.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final auth  = AuthService.instance;
    setState(() {
      // prefer display_name from account, fall back to locally saved nickname
      _nicknameController.text =
          auth.user?.displayName ??
          prefs.getString('nickname') ?? '';
      _pfpPath = prefs.getString('pfp_path');
    });
  }

  Future<void> _saveNickname() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', _nicknameController.text.trim());
    FocusScope.of(context).unfocus();
    setState(() => _saved = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  Future<void> _pickPfp() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512, maxHeight: 512, imageQuality: 85,
    );
    if (picked == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pfp_path', picked.path);
    if (mounted) setState(() => _pfpPath = picked.path);
  }

  void _openSettings() {
    MainShell.of(context).hideBottomBar();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SettingsScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    ).then((_) {
      if (mounted) MainShell.of(context).showBottomBar();
    });
  }

  void _openLogin() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.bg1,
        title: Text(L10n.s.logout, style: TextStyle(color: context.textPrimary)),
        content: Text(L10n.s.logoutConfirm, style: TextStyle(color: context.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L10n.s.cancel, style: TextStyle(color: context.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(L10n.s.logout, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) await AuthService.instance.logout();
  }

  @override
  Widget build(BuildContext context) {
    final accent    = context.accentColor;
    final auth      = AuthService.instance;
    final nickname  = _nicknameController.text;
    final initial   = nickname.isNotEmpty ? nickname[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text(L10n.s.profile),
        backgroundColor: context.bg1,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: context.textSecondary),
            onPressed: _openSettings,
            tooltip: L10n.s.settings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),

              // ── Avatar ──
              Center(
                child: Stack(children: [
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
                          ? Center(
                              child: Text(
                                initial,
                                style: TextStyle(color: accent, fontSize: 38, fontWeight: FontWeight.w700),
                              ),
                            )
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
              ),

              const SizedBox(height: 12),

              // ── Account badge ──
              Center(
                child: auth.isLoggedIn
                    ? Column(children: [
                        Text(
                          auth.user!.displayNameOrEmail,
                          style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle_rounded, size: 13, color: accent),
                          const SizedBox(width: 4),
                          Text(
                            auth.user!.isPremium ? L10n.s.premiumAccount : L10n.s.freeAccount,
                            style: TextStyle(color: context.textSecondary, fontSize: 12),
                          ),
                        ]),
                      ])
                    : GestureDetector(
                        onTap: _openLogin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color:        accent.withAlpha(20),
                            borderRadius: BorderRadius.circular(20),
                            border:       Border.all(color: accent.withAlpha(60)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.login_rounded, size: 16, color: accent),
                            const SizedBox(width: 6),
                            Text(
                              L10n.s.signInOrRegister,
                              style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ]),
                        ),
                      ),
              ),

              const SizedBox(height: 28),

              // ── Nickname ──
              Text(
                L10n.s.nickname,
                style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nicknameController,
                style: TextStyle(color: context.textPrimary, fontSize: 15),
                maxLength: 24,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText:     L10n.s.nicknamePlaceholder,
                  counterStyle: TextStyle(color: context.textSecondary, fontSize: 11),
                  suffixIcon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _saved
                        ? Icon(Icons.check_circle_rounded, color: accent, key: const ValueKey('check'))
                        : IconButton(
                            key: const ValueKey('save'),
                            icon: Icon(Icons.save_rounded, color: context.textSecondary),
                            onPressed: _saveNickname,
                          ),
                  ),
                ),
                onSubmitted: (_) => _saveNickname(),
              ),
              const SizedBox(height: 8),
              Text(L10n.s.nicknameHint, style: TextStyle(color: context.textSecondary, fontSize: 12)),

              const Spacer(),

              // ── Logout button (only when logged in) ──
              if (auth.isLoggedIn) ...[
                Center(
                  child: TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 18),
                    label: Text(L10n.s.logout, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              Center(
                child: Text(L10n.s.version, style: TextStyle(color: context.textSecondary, fontSize: 11)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}