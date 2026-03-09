// notification_prefs_tile.dart
// Styled to match the app's _SettingsTile card design.
// Place in lib/widgets/notification_prefs_tile.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

const String _authBaseUrl = 'https://auth.tomenu.sk';

class NotificationPrefsTile extends StatefulWidget {
  const NotificationPrefsTile({super.key});

  @override
  State<NotificationPrefsTile> createState() => _NotificationPrefsTileState();
}

class _NotificationPrefsTileState extends State<NotificationPrefsTile> {
  bool   _enabled = false;
  String _time    = '10:30';
  bool   _loading = true;
  bool   _saving  = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await AuthService.instance.getToken();
    if (token == null) { setState(() => _loading = false); return; }
    try {
      final res = await http.get(
        Uri.parse('$_authBaseUrl/auth/notify-prefs'),
        headers: { 'Authorization': 'Bearer $token' },
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() {
          _enabled = body['notify_enabled'] as bool? ?? false;
          _time    = body['notify_time']    as String? ?? '10:30';
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save({ bool? enabled, String? time }) async {
    setState(() => _saving = true);
    final token = await AuthService.instance.getToken();
    if (token == null) { setState(() => _saving = false); return; }
    try {
      final body = <String, dynamic>{};
      if (enabled != null) body['notify_enabled'] = enabled;
      if (time    != null) body['notify_time']    = time;
      await http.patch(
        Uri.parse('$_authBaseUrl/auth/notify-prefs'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type':  'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
    setState(() => _saving = false);
  }

  Future<void> _pickTime() async {
    final parts  = _time.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour:   int.tryParse(parts[0]) ?? 10,
        minute: int.tryParse(parts[1]) ?? 30,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final newTime =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() => _time = newTime);
    await _save(time: newTime);
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row with switch ──
          Row(
            children: [
              Icon(Icons.notifications_rounded, color: accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Daily lunch reminder',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (_loading)
                SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                )
              else
                Switch(
                  value: _enabled,
                  onChanged: _saving ? null : (val) {
                    setState(() => _enabled = val);
                    _save(enabled: val);
                  },
                  activeColor: accent,
                ),
            ],
          ),

          // ── Subtitle ──
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 2),
            child: Text(
              'Get notified when lunch menus are ready',
              style: TextStyle(color: context.textSecondary, fontSize: 12),
            ),
          ),

          // ── Time picker — only visible when enabled ──
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _enabled
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                Divider(color: context.border, height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: context.textSecondary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reminder time',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'When should we notify you?',
                            style: TextStyle(color: context.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _saving
                        ? SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                          )
                        : GestureDetector(
                            onTap: _pickTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: accent.withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: accent.withAlpha(60)),
                              ),
                              child: Text(
                                _time,
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}