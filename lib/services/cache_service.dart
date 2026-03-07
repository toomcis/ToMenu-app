import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ── CacheService ──────────────────────────────────────────────────────────────
//
// Stores everything in SharedPreferences as JSON strings.
// Key format:
//   cache:cities                         → List<City> JSON
//   cache:week:{citySlug}                → List<WeekDay> JSON
//   cache:menu:{citySlug}:{date}         → MenuPage JSON
//   cache:restaurant:{citySlug}:{slug}:{date} → Restaurant JSON
//
// Each key also has a companion timestamp key:
//   cache_ts:cities                      → ISO date string (YYYY-MM-DD)
//   cache_ts:week:{citySlug}             → ISO date string
//   etc.
//
// "Outdated" = cached on a different calendar day than today.

class CacheService {
  static final CacheService instance = CacheService._();
  CacheService._();

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<bool> isCacheEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('cache_enabled') ?? true;
  }

  Future<void> setCacheEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cache_enabled', value);
    if (!value) await clearAll();
  }

  Future<bool> isCityListCacheEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool('cache_enabled') ?? true) &&
           (prefs.getBool('cache_cities_enabled') ?? true);
  }

  Future<bool> isMenuCacheEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool('cache_enabled') ?? true) &&
           (prefs.getBool('cache_menu_enabled') ?? true);
  }

  Future<bool> isRestaurantCacheEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool('cache_enabled') ?? true) &&
           (prefs.getBool('cache_restaurant_enabled') ?? true);
  }

  Future<bool> isWeekCacheEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool('cache_enabled') ?? true) &&
           (prefs.getBool('cache_week_enabled') ?? true);
  }

  Future<void> setCategoryEnabled(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // ── Date helpers ──────────────────────────────────────────────────────────

  static String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool _isToday(String? isoDate) {
    if (isoDate == null) return false;
    return isoDate == _todayIso();
  }

  // ── Low-level read/write ──────────────────────────────────────────────────

  Future<String?> _read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('cache:$key');
  }

  Future<String?> _readTs(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('cache_ts:$key');
  }

  Future<void> _write(String key, String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cache:$key', json);
    await prefs.setString('cache_ts:$key', _todayIso());
  }

  Future<void> _delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cache:$key');
    await prefs.remove('cache_ts:$key');
  }

  // ── Cities ────────────────────────────────────────────────────────────────

  Future<CacheResult<String>> getCities() async {
    if (!await isCityListCacheEnabled()) return CacheResult.disabled();
    final ts   = await _readTs('cities');
    final data = await _read('cities');
    if (data == null) return CacheResult.miss();
    return CacheResult.hit(data, isStale: !_isToday(ts));
  }

  Future<void> setCities(String json) async {
    if (!await isCityListCacheEnabled()) return;
    await _write('cities', json);
  }

  // ── Week ──────────────────────────────────────────────────────────────────

  Future<CacheResult<String>> getWeek(String citySlug) async {
    if (!await isWeekCacheEnabled()) return CacheResult.disabled();
    final key  = 'week:$citySlug';
    final ts   = await _readTs(key);
    final data = await _read(key);
    if (data == null) return CacheResult.miss();
    return CacheResult.hit(data, isStale: !_isToday(ts));
  }

  Future<void> setWeek(String citySlug, String json) async {
    if (!await isWeekCacheEnabled()) return;
    await _write('week:$citySlug', json);
  }

  // ── Menu ──────────────────────────────────────────────────────────────────

  Future<CacheResult<String>> getMenu(String citySlug, String date) async {
    if (!await isMenuCacheEnabled()) return CacheResult.disabled();
    final key  = 'menu:$citySlug:$date';
    final ts   = await _readTs(key);
    final data = await _read(key);
    if (data == null) return CacheResult.miss();
    return CacheResult.hit(data, isStale: !_isToday(ts));
  }

  Future<void> setMenu(String citySlug, String date, String json) async {
    if (!await isMenuCacheEnabled()) return;
    await _write('menu:$citySlug:$date', json);
  }

  // ── Restaurant profile ────────────────────────────────────────────────────

  Future<CacheResult<String>> getRestaurant(String citySlug, String slug, String date) async {
    if (!await isRestaurantCacheEnabled()) return CacheResult.disabled();
    final key  = 'restaurant:$citySlug:$slug:$date';
    final ts   = await _readTs(key);
    final data = await _read(key);
    if (data == null) return CacheResult.miss();
    return CacheResult.hit(data, isStale: !_isToday(ts));
  }

  Future<void> setRestaurant(String citySlug, String slug, String date, String json) async {
    if (!await isRestaurantCacheEnabled()) return;
    await _write('restaurant:$citySlug:$slug:$date', json);
  }

  // ── Cache date info ───────────────────────────────────────────────────────

  /// Returns the date string of when cities were last cached, or null
  Future<String?> getLastCacheDate() async {
    return await _readTs('cities');
  }

  /// True if we have ANY cached data but it's from a previous calendar day
  Future<bool> hasStaleCacheOnly() async {
    final ts = await _readTs('cities');
    if (ts == null) return false;           // no cache at all
    return !_isToday(ts);                   // has cache but it's old
  }

  /// True if we have valid today's cache
  Future<bool> hasFreshCache() async {
    final ts = await _readTs('cities');
    return _isToday(ts);
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys  = prefs.getKeys().where((k) => k.startsWith('cache:') || k.startsWith('cache_ts:')).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  Future<void> clearMenuCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys  = prefs.getKeys().where((k) =>
      (k.startsWith('cache:menu:') || k.startsWith('cache_ts:menu:') ||
       k.startsWith('cache:restaurant:') || k.startsWith('cache_ts:restaurant:'))).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  /// Approximate size of cache in KB
  Future<int> estimateSizeKb() async {
    final prefs = await SharedPreferences.getInstance();
    int bytes = 0;
    for (final k in prefs.getKeys()) {
      if (k.startsWith('cache:')) {
        final v = prefs.getString(k);
        if (v != null) bytes += v.length;
      }
    }
    return (bytes / 1024).round();
  }
}

// ── CacheResult ───────────────────────────────────────────────────────────────

enum CacheStatus { hit, miss, disabled }

class CacheResult<T> {
  final CacheStatus status;
  final T?          data;
  final bool        isStale;  // true = from a previous calendar day

  const CacheResult._({required this.status, this.data, this.isStale = false});

  factory CacheResult.hit(T data, {bool isStale = false}) =>
      CacheResult._(status: CacheStatus.hit, data: data, isStale: isStale);

  factory CacheResult.miss() =>
      CacheResult._(status: CacheStatus.miss);

  factory CacheResult.disabled() =>
      CacheResult._(status: CacheStatus.disabled);

  bool get hasData  => status == CacheStatus.hit && data != null;
  bool get isMiss   => status == CacheStatus.miss;
}