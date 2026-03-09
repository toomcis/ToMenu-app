import 'package:flutter/material.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import '../api/client.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../l10n/strings.dart';
import '../services/cache_service.dart';
import 'developer_screen.dart';
import '../widgets/notification_prefs_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiUrlController = TextEditingController();
  bool _apiUrlEdited = false;
  bool _apiUrlSaved  = false;
  AppLanguage _selectedLanguage = AppLanguage.system;

  bool _cacheEnabled            = true;
  bool _cacheCitiesEnabled      = true;
  bool _cacheMenusEnabled       = true;
  bool _cacheRestaurantsEnabled = true;
  bool _cacheWeekEnabled        = true;
  int  _cacheSizeKb             = 0;
  bool _cacheCleared            = false;

  static const _defaultUrl = 'https://api.tomenu.sk';

  @override
  void initState() {
    super.initState();
    _apiUrlController.text = ApiClient.instance.currentApiUrl;
    _apiUrlController.addListener(() {
      setState(() => _apiUrlEdited =
          _apiUrlController.text.trim() != ApiClient.instance.currentApiUrl);
    });
    _loadLanguage();
    _loadCacheSettings();
  }

  Future<void> _loadLanguage() async {
    final lang = await L10n.getSavedLanguage();
    if (mounted) setState(() => _selectedLanguage = lang);
  }

  Future<void> _loadCacheSettings() async {
    final cache = CacheService.instance;
    final enabled     = await cache.isCacheEnabled();
    final cities      = await cache.isCityListCacheEnabled();
    final menus       = await cache.isMenuCacheEnabled();
    final restaurants = await cache.isRestaurantCacheEnabled();
    final week        = await cache.isWeekCacheEnabled();
    final sizeKb      = await cache.estimateSizeKb();
    if (mounted) setState(() {
      _cacheEnabled            = enabled;
      _cacheCitiesEnabled      = cities;
      _cacheMenusEnabled       = menus;
      _cacheRestaurantsEnabled = restaurants;
      _cacheWeekEnabled        = week;
      _cacheSizeKb             = sizeKb;
    });
  }

  Future<void> _clearAllCache() async {
    await CacheService.instance.clearAll();
    setState(() { _cacheSizeKb = 0; _cacheCleared = true; });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _cacheCleared = false);
  }

  Future<void> _clearMenuCache() async {
    await CacheService.instance.clearMenuCache();
    final sizeKb = await CacheService.instance.estimateSizeKb();
    setState(() { _cacheSizeKb = sizeKb; _cacheCleared = true; });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _cacheCleared = false);
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveApiUrl() async {
    final url = _apiUrlController.text.trim();
    if (url.isEmpty) return;
    await ApiClient.instance.setApiUrl(url);
    setState(() { _apiUrlEdited = false; _apiUrlSaved = true; });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _apiUrlSaved = false);
  }

  Future<void> _resetApiUrl() async {
    await ApiClient.instance.resetApiUrl();
    _apiUrlController.text = _defaultUrl;
    setState(() => _apiUrlEdited = false);
  }

  Future<void> _changeLanguage(AppLanguage lang) async {
    final appState = ToMenuApp.of(context);
    await L10n.setLanguage(lang, context);
    appState.setLanguage(lang);
    if (mounted) setState(() => _selectedLanguage = lang);
  }

  @override
  Widget build(BuildContext context) {
    final appState = ToMenuApp.of(context);
    final accent   = context.accentColor;
    final isDark   = context.isDark;
    final s        = L10n.s;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bg1,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(s.settings, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // ── Language ──
            _SectionHeader(label: s.language),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.language_rounded,
              label: s.language,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  ...AppLanguage.values.map((lang) {
                    final selected = _selectedLanguage == lang;
                    return GestureDetector(
                      onTap: () => _changeLanguage(lang),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color:  selected ? accent.withAlpha(20) : context.bg2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? accent : context.border),
                        ),
                        child: Row(children: [
                          Text(_langFlag(lang), style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              lang.label,
                              style: TextStyle(
                                color:      selected ? accent : context.textPrimary,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                fontSize:   14,
                              ),
                            ),
                          ),
                          if (selected) Icon(Icons.check_rounded, color: accent, size: 18),
                        ]),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Appearance ──
            _SectionHeader(label: s.appearance),
            const SizedBox(height: 12),

            _SettingsTile(
              icon: Icons.dark_mode_rounded,
              label: s.darkMode,
              trailing: Switch(
                value: isDark,
                onChanged: (v) => appState.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
                activeColor: accent,
              ),
            ),

            const SizedBox(height: 12),

            _SettingsTile(
              icon: Icons.palette_rounded,
              label: s.accentColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  Row(
                    children: AppTheme.presetAccents.map((color) {
                      final selected = accent.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => appState.setAccentColor(color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width:  selected ? 34 : 28,
                          height: selected ? 34 : 28,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color:  color,
                            shape:  BoxShape.circle,
                            border: Border.all(
                              color: selected ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: selected ? [
                              BoxShadow(color: color.withAlpha(100), blurRadius: 8),
                            ] : [],
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon:  Icon(Icons.colorize_rounded, color: accent, size: 16),
                    label: Text(s.customColor, style: TextStyle(color: accent, fontSize: 13)),
                    onPressed: () => _showColorPicker(context, appState, accent),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Notifications ──
            _SectionHeader(label: s.notifications),
            const SizedBox(height: 12),
            const NotificationPrefsTile(),

            const SizedBox(height: 28),

            // ── Cache & Offline ──
            _SectionHeader(label: s.cacheSettings),
            const SizedBox(height: 12),

            _SettingsTile(
              icon: Icons.storage_rounded,
              label: s.cacheEnabled,
              trailing: Switch(
                value: _cacheEnabled,
                onChanged: (v) async {
                  await CacheService.instance.setCacheEnabled(v);
                  setState(() => _cacheEnabled = v);
                },
                activeColor: accent,
              ),
              child: _cacheEnabled ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  _CacheToggleRow(label: s.cacheCities,      value: _cacheCitiesEnabled,      onChanged: (v) async { await CacheService.instance.setCategoryEnabled('cache_cities_enabled', v);     setState(() => _cacheCitiesEnabled = v);      }, accent: accent),
                  _CacheToggleRow(label: s.cacheMenus,       value: _cacheMenusEnabled,       onChanged: (v) async { await CacheService.instance.setCategoryEnabled('cache_menu_enabled', v);        setState(() => _cacheMenusEnabled = v);       }, accent: accent),
                  _CacheToggleRow(label: s.cacheRestaurants, value: _cacheRestaurantsEnabled, onChanged: (v) async { await CacheService.instance.setCategoryEnabled('cache_restaurant_enabled', v);  setState(() => _cacheRestaurantsEnabled = v); }, accent: accent),
                  _CacheToggleRow(label: s.cacheWeek,        value: _cacheWeekEnabled,        onChanged: (v) async { await CacheService.instance.setCategoryEnabled('cache_week_enabled', v);        setState(() => _cacheWeekEnabled = v);        }, accent: accent),
                  const SizedBox(height: 12),
                  Divider(color: context.border),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.folder_outlined, color: context.textSecondary, size: 15),
                    const SizedBox(width: 8),
                    Text('${s.cacheSize}: $_cacheSizeKb KB',
                        style: TextStyle(color: context.textSecondary, fontSize: 12)),
                    if (_cacheCleared) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.check_circle_rounded, color: accent, size: 14),
                      const SizedBox(width: 4),
                      Text(s.cacheCleared, style: TextStyle(color: accent, fontSize: 12)),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clearMenuCache,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: BorderSide(color: context.border),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.delete_sweep_rounded, size: 16, color: context.textSecondary),
                          const SizedBox(height: 4),
                          Text(s.cacheClearMenus, style: TextStyle(color: context.textSecondary, fontSize: 11), textAlign: TextAlign.center),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clearAllCache,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.red),
                          const SizedBox(height: 4),
                          Text(s.cacheClearAll, style: const TextStyle(color: Colors.red, fontSize: 11), textAlign: TextAlign.center),
                        ]),
                      ),
                    ),
                  ]),
                ],
              ) : null,
            ),

            const SizedBox(height: 28),

            // ── Advanced ──
            _SectionHeader(label: s.advanced),
            const SizedBox(height: 12),

            _SettingsTile(
              icon: Icons.api_rounded,
              label: s.apiUrl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:  Colors.orange.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withAlpha(60)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.apiUrlWarning,
                            style: TextStyle(color: Colors.orange.shade700, fontSize: 12)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _apiUrlController,
                    style: TextStyle(color: context.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: _defaultUrl,
                      isDense: true,
                      suffixIcon: _apiUrlSaved
                          ? Icon(Icons.check_circle_rounded, color: accent, size: 18)
                          : _apiUrlEdited
                              ? IconButton(
                                  icon: Icon(Icons.save_rounded, color: accent, size: 18),
                                  onPressed: _saveApiUrl,
                                )
                              : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon:  Icon(Icons.restart_alt_rounded, color: context.textSecondary, size: 16),
                    label: Text(s.resetToDefault, style: TextStyle(color: context.textSecondary, fontSize: 13)),
                    onPressed: _resetApiUrl,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Developer menu ──
            _SettingsTile(
              icon: Icons.developer_mode_rounded,
              label: 'Developer menu',
              trailing: Icon(Icons.chevron_right_rounded, color: context.textSecondary, size: 20),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeveloperScreen()),
              ),
            ),

            const SizedBox(height: 40),
            Center(
              child: Text(s.tagline,
                  style: TextStyle(color: context.textSecondary, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  String _langFlag(AppLanguage lang) => switch (lang) {
    AppLanguage.system => '🌐',
    AppLanguage.en     => '🇬🇧',
    AppLanguage.sk     => '🇸🇰',
    AppLanguage.cs     => '🇨🇿',
  };

  void _showColorPicker(BuildContext context, dynamic appState, Color current) {
    Color picked = current;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.bg1,
        title: Text('Pick a color', style: TextStyle(color: context.textPrimary)),
        content: ColorPicker(
          color: current,
          onColorChanged: (c) => picked = c,
          pickersEnabled: const {ColorPickerType.wheel: true, ColorPickerType.primary: true},
          enableShadesSelection: false,
          hasBorder: false,
          borderRadius: 10,
          heading:    const SizedBox.shrink(),
          subheading: const SizedBox.shrink(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.s.cancel, style: TextStyle(color: context.textSecondary)),
          ),
          FilledButton(
            onPressed: () { appState.setAccentColor(picked); Navigator.pop(context); },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: TextStyle(color: context.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final Widget?       trailing;
  final Widget?       child;
  final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.label, this.trailing, this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.bg1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: context.accentColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
              ),
              if (trailing != null) trailing!,
            ]),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

class _CacheToggleRow extends StatelessWidget {
  final String             label;
  final bool               value;
  final ValueChanged<bool> onChanged;
  final Color              accent;
  const _CacheToggleRow({required this.label, required this.value, required this.onChanged, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: context.textSecondary, fontSize: 13))),
        Switch(value: value, onChanged: onChanged, activeColor: accent, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ]),
    );
  }
}