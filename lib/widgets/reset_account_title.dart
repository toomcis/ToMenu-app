// reset_account_tile.dart
// Drop-in widget for SettingsScreen — shows "Reset account" with 5-second countdown

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/fyp_service.dart';
import '../screens/onboarding_flow.dart';

class ResetAccountTile extends StatefulWidget {
  /// Called after a successful reset so parent can refresh state.
  final VoidCallback? onReset;

  const ResetAccountTile({super.key, this.onReset});

  @override
  State<ResetAccountTile> createState() => _ResetAccountTileState();
}

class _ResetAccountTileState extends State<ResetAccountTile> {
  bool _confirming = false;
  int  _countdown  = 5;
  bool _resetting  = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startConfirmation() {
    setState(() {
      _confirming = true;
      _countdown  = 5;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final next = _countdown - 1;
      if (next <= 0) {
        t.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown = next);
      }
    });
  }

  void _cancel() {
    _timer?.cancel();
    setState(() { _confirming = false; _countdown = 5; });
  }

  Future<void> _doReset() async {
    setState(() => _resetting = true);
    final ok = await FypService.instance.resetAccount();
    if (!mounted) return;

    if (ok) {
      // Also reset local onboarding flag so user sees onboarding again
      await OnboardingFlow.reset();
      widget.onReset?.call();
      setState(() { _confirming = false; _resetting = false; _countdown = 5; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Účet bol resetovaný.')),
      );
    } else {
      setState(() => _resetting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resetovanie zlyhalo. Skús znova.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_confirming) return _buildConfirmCard(colors);

    return ListTile(
      leading: Icon(Icons.restart_alt_rounded, color: colors.error),
      title:   const Text('Resetovať účet'),
      subtitle: const Text('Vymaže obľúbené reštaurácie a preferencie'),
      onTap:   _startConfirmation,
    );
  }

  Widget _buildConfirmCard(ColorScheme colors) {
    final canProceed = _countdown == 0 && !_resetting;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color:  colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: colors.onErrorContainer),
                const SizedBox(width: 8),
                Text('Naozaj resetovať?', style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color:      colors.onErrorContainer,
                  fontSize:   16,
                )),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Táto akcia vymaže:\n'
              '• Všetky obľúbené reštaurácie\n'
              '• Preferencie jedál\n'
              '• Históriu swipov\n\n'
              'Email, heslo a 2FA zostanú zachované.',
              style: TextStyle(color: colors.onErrorContainer, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Cancel
                OutlinedButton(
                  onPressed: _resetting ? null : _cancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.onErrorContainer,
                    side: BorderSide(color: colors.onErrorContainer.withOpacity(0.5)),
                  ),
                  child: const Text('Zrušiť'),
                ),
                const SizedBox(width: 12),
                // Proceed (locked for countdown)
                Expanded(
                  child: FilledButton(
                    onPressed: canProceed ? _doReset : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: canProceed ? colors.error : colors.onErrorContainer.withOpacity(0.2),
                      foregroundColor: canProceed ? colors.onError : colors.onErrorContainer.withOpacity(0.4),
                    ),
                    child: _resetting
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          _countdown > 0
                            ? 'Čakaj $_countdown s…'
                            : 'Pokračovať v resete',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// ── preference_editor.dart (same file for convenience) ───────────────────────
// PreferencePillsEditor — reusable widget used in both OnboardingFlow and ProfileScreen.
// Shows the same pill grid with current selection and a save button.

class PreferencePillsEditor extends StatefulWidget {
  final List<String> initialTags;
  final Future<void> Function(List<String> tags) onSave;

  const PreferencePillsEditor({
    super.key,
    required this.initialTags,
    required this.onSave,
  });

  @override
  State<PreferencePillsEditor> createState() => _PreferencePillsEditorState();
}

class _PillOpt {
  final String tag;
  final String label;
  final String emoji;
  const _PillOpt(this.tag, this.label, this.emoji);
}

const _pills = [
  _PillOpt('vegetarian',  'Vegetariánske',   '🥦'),
  _PillOpt('meat',        'Mäsové',          '🥩'),
  _PillOpt('healthy',     'Zdravé',          '🥗'),
  _PillOpt('fried',       'Vyprážané',       '🍟'),
  _PillOpt('spicy',       'Pikantné',        '🌶️'),
  _PillOpt('sweet',       'Sladké',          '🍰'),
  _PillOpt('soup',        'Polievky',        '🍲'),
  _PillOpt('pasta',       'Cestoviny',       '🍝'),
  _PillOpt('grill',       'Grilované',       '🔥'),
  _PillOpt('fish',        'Ryby',            '🐟'),
  _PillOpt('burger',      'Burgre',          '🍔'),
  _PillOpt('asian',       'Ázijská kuchyňa', '🍜'),
];

class _PreferencePillsEditorState extends State<PreferencePillsEditor> {
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.initialTags);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final changed = !_setEquals(_selected, Set<String>.from(widget.initialTags));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing:    10,
          runSpacing: 10,
          children: _pills.map((p) {
            final sel = _selected.contains(p.tag);
            return GestureDetector(
              onTap: () => setState(() {
                if (sel) _selected.remove(p.tag);
                else      _selected.add(p.tag);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: sel ? colors.primaryContainer : colors.surfaceContainerHigh,
                  border: Border.all(
                    color: sel ? colors.primary : Colors.transparent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text('${p.emoji}  ${p.label}', style: TextStyle(
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                  color: sel ? colors.onPrimaryContainer : colors.onSurface,
                )),
              ),
            );
          }).toList(),
        ),
        if (changed) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : () async {
                setState(() => _saving = true);
                await widget.onSave(_selected.toList());
                if (mounted) setState(() => _saving = false);
              },
              child: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Uložiť preferencie'),
            ),
          ),
        ],
      ],
    );
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}