import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../l10n/strings.dart';
import 'settings_screen.dart';
import 'main_shell.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nicknameController = TextEditingController();
  bool    _saved    = false;
  String? _pfpPath; // local file path for profile picture

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nicknameController.text = prefs.getString('nickname') ?? '';
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
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
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

  @override
  Widget build(BuildContext context) {
    final accent   = context.accentColor;
    final nickname = _nicknameController.text;
    final initial  = nickname.isNotEmpty ? nickname[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text(L10n.s.profile),
        backgroundColor: context.bg1,
        // settings icon ONLY in top right — no duplicate banner below
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
                child: Stack(
                  children: [
                    // the circle avatar
                    GestureDetector(
                      onTap: _pickPfp,
                      child: Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withAlpha(30),
                          border: Border.all(color: accent.withAlpha(80), width: 2),
                          image: _pfpPath != null
                              ? DecorationImage(
                                  image: FileImage(File(_pfpPath!)),
                                  fit: BoxFit.cover,
                                )
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
                    // small camera badge
                    Positioned(
                      bottom: 0, right: 0,
                      child: GestureDetector(
                        onTap: _pickPfp,
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.bgColor, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

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
                  hintText: L10n.s.nicknamePlaceholder,
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
              Text(
                L10n.s.nicknameHint,
                style: TextStyle(color: context.textSecondary, fontSize: 12),
              ),

              const SizedBox(height: 32),

              // ── App version ──
              const Spacer(),
              Center(
                child: Text(L10n.s.version,
                    style: TextStyle(color: context.textSecondary, fontSize: 11)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}