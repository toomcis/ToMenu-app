import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Developer Screen
// Add to settings screen:
//
//   ListTile(
//     leading: const Icon(Icons.developer_mode_rounded, color: Colors.orange),
//     title: const Text('Developer menu'),
//     trailing: const Icon(Icons.chevron_right_rounded),
//     onTap: () => Navigator.of(context).push(
//       MaterialPageRoute(builder: (_) => const DeveloperScreen()),
//     ),
//   ),
// ─────────────────────────────────────────────────────────────────────────────

class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});
  @override State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen> {
  // ── Time override ──────────────────────────────────────────────────────────
  // Lets you fake "current time" for testing cooldowns, expiries, etc.
  // Usage elsewhere in the app:
  //   final now = DevTools.now;   ← returns overridden time or DateTime.now()
  DateTime? _fakeNow;
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();

  // ── FCM token ──────────────────────────────────────────────────────────────
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('dev_fake_now');
    if (saved != null) {
      final dt = DateTime.tryParse(saved);
      if (dt != null) {
        setState(() {
          _fakeNow = dt;
          _dateCtrl.text = '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
          _timeCtrl.text = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
        });
      }
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (mounted) setState(() => _fcmToken = token);
    } catch (_) {}
  }

  Future<void> _setFakeTime() async {
    final dateParts = _dateCtrl.text.trim().split('-');
    final timeParts = _timeCtrl.text.trim().split(':');
    if (dateParts.length != 3 || timeParts.length != 2) {
      _snack('Format: YYYY-MM-DD and HH:MM', error: true);
      return;
    }
    try {
      final dt = DateTime(
        int.parse(dateParts[0]), int.parse(dateParts[1]), int.parse(dateParts[2]),
        int.parse(timeParts[0]), int.parse(timeParts[1]),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dev_fake_now', dt.toIso8601String());
      DevTools._fakeNow = dt;
      setState(() => _fakeNow = dt);
      _snack('Time set to $dt');
    } catch (_) {
      _snack('Invalid date/time', error: true);
    }
  }

  Future<void> _clearFakeTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dev_fake_now');
    DevTools._fakeNow = null;
    setState(() { _fakeNow = null; _dateCtrl.clear(); _timeCtrl.clear(); });
    _snack('Time override cleared — using real time');
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  void dispose() { _dateCtrl.dispose(); _timeCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final card   = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final text   = isDark ? Colors.white : Colors.black87;
    final sub    = isDark ? Colors.white54 : Colors.black45;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        title: Row(children: [
          const Icon(Icons.developer_mode_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Text('Developer menu', style: TextStyle(color: text, fontSize: 17)),
        ]),
        iconTheme: IconThemeData(color: text),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Warning banner ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withAlpha(80)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Dev tools only. These settings affect app behaviour.',
                style: TextStyle(color: Colors.orange.shade300, fontSize: 12),
              )),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Time override ────────────────────────────────────────────────
          _Section(
            title: 'Time override',
            subtitle: 'Fake the current time for testing cooldowns, expiry etc.',
            card: card, text: text, sub: sub,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_fakeNow != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withAlpha(60)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.access_time_rounded, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text('Active: $_fakeNow', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _dateCtrl,
                    style: TextStyle(color: text, fontSize: 13),
                    keyboardType: TextInputType.datetime,
                    decoration: _inputDeco('Date (YYYY-MM-DD)', isDark),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _timeCtrl,
                    style: TextStyle(color: text, fontSize: 13),
                    keyboardType: TextInputType.datetime,
                    decoration: _inputDeco('HH:MM', isDark),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                ElevatedButton(
                  onPressed: _setFakeTime,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Set time', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                if (_fakeNow != null)
                  OutlinedButton(
                    onPressed: _clearFakeTime,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Clear', style: TextStyle(fontSize: 13)),
                  ),
              ]),
            ]),
          ),
          const SizedBox(height: 16),

          // ── FCM token ────────────────────────────────────────────────────
          _Section(
            title: 'FCM push token',
            subtitle: 'Copy to test push notifications manually.',
            card: card, text: text, sub: sub,
            child: _fcmToken != null
                ? GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _fcmToken!));
                      _snack('FCM token copied');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        Expanded(child: Text(
                          _fcmToken!,
                          style: TextStyle(color: sub, fontSize: 11, fontFamily: 'monospace'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        )),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 14, color: sub),
                      ]),
                    ),
                  )
                : Text('Not available — Firebase not initialized or no token yet.',
                    style: TextStyle(color: sub, fontSize: 12)),
          ),
          const SizedBox(height: 16),

          // ── More sections can go here ────────────────────────────────────
          // e.g. "Skip onboarding", "Reset first-launch flags", "Crash test"

          const SizedBox(height: 40),
          Center(child: Text('🛠️  More tools can be added here',
              style: TextStyle(color: sub, fontSize: 12))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint, bool isDark) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontSize: 12),
    filled: true,
    fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.orange, width: 1.5),
    ),
  );
}

class _Section extends StatelessWidget {
  final String     title;
  final String     subtitle;
  final Widget     child;
  final Color      card, text, sub;
  const _Section({required this.title, required this.subtitle, required this.child,
                  required this.card, required this.text, required this.sub});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(subtitle, style: TextStyle(color: sub, fontSize: 11)),
      const SizedBox(height: 14),
      child,
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DevTools — global helper, use anywhere in the app
// ─────────────────────────────────────────────────────────────────────────────

class DevTools {
  DevTools._();

  static DateTime? _fakeNow;

  /// Use this instead of DateTime.now() anywhere you want testable time.
  static DateTime get now => _fakeNow ?? DateTime.now();

  /// Call once on app start to restore any saved time override.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('dev_fake_now');
    if (saved != null) _fakeNow = DateTime.tryParse(saved);
  }
}