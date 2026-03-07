import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../models/city.dart';
import '../services/cache_service.dart';

const String _defaultApiUrl = 'https://api.toomcis.eu';
const String _publicApiKey  = 'YmXsFbsNF4P4byoZkx761RvC8XreT8e7EKJMDj57fEQ';

// Result wrapper so callers know if data came from cache or server
class ApiResult<T> {
  final T     data;
  final bool  fromCache;
  final bool  isStale;    // cache is from a previous calendar day
  final bool  serverFailed; // server was unreachable / errored

  const ApiResult({
    required this.data,
    this.fromCache    = false,
    this.isStale      = false,
    this.serverFailed = false,
  });
}

class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();
  ApiClient._();

  String _baseUrl = _defaultApiUrl;
  String _apiKey  = _publicApiKey;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('api_url') ?? _defaultApiUrl;
    _apiKey  = prefs.getString('api_key') ?? _publicApiKey;
  }

  Future<void> setApiUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_url', url);
  }

  Future<void> resetApiUrl() async {
    _baseUrl = _defaultApiUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_url');
  }

  String get currentApiUrl => _baseUrl;

  // ── Raw HTTP ──────────────────────────────────────────────────────────────

  Future<dynamic> _get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final res = await http.get(uri, headers: {
      'Authorization': _apiKey,
      'Content-Type': 'application/json',
    }).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } else if (res.statusCode == 404) {
      return null;
    } else {
      throw ApiException(res.statusCode, res.body);
    }
  }

  // ── Cities ────────────────────────────────────────────────────────────────

  Future<ApiResult<List<City>>> getCities() async {
    final cache = await CacheService.instance.getCities();

    // Try server first
    try {
      final data = await _get('/api/cities');
      if (data != null) {
        final cities = (data as List).map((j) => City.fromJson(j)).toList();
        await CacheService.instance.setCities(jsonEncode(data));
        return ApiResult(data: cities);
      }
    } catch (_) {}

    // Server failed — fall back to cache
    if (cache.hasData) {
      final cities = (jsonDecode(cache.data!) as List).map((j) => City.fromJson(j)).toList();
      return ApiResult(data: cities, fromCache: true, isStale: cache.isStale, serverFailed: true);
    }

    return ApiResult(data: [], serverFailed: true);
  }

  // ── Week ──────────────────────────────────────────────────────────────────

  Future<ApiResult<List<WeekDay>>> getWeek(String citySlug) async {
    final cache = await CacheService.instance.getWeek(citySlug);

    try {
      final data = await _get('/api/$citySlug/week');
      if (data != null) {
        final days = (data as List).map((j) => WeekDay.fromJson(j)).toList();
        await CacheService.instance.setWeek(citySlug, jsonEncode(data));
        return ApiResult(data: days);
      }
    } catch (_) {}

    if (cache.hasData) {
      final days = (jsonDecode(cache.data!) as List).map((j) => WeekDay.fromJson(j)).toList();
      return ApiResult(data: days, fromCache: true, isStale: cache.isStale, serverFailed: true);
    }

    return ApiResult(data: [], serverFailed: true);
  }

  // ── Menu ──────────────────────────────────────────────────────────────────

  Future<ApiResult<MenuPage>> getMenu(
    String citySlug, {
    String? date,
    String? type,
    bool? delivery,
    double? maxPrice,
    List<int>? excludeAllergens,
    int limit = 200,
    int offset = 0,
  }) async {
    final effectiveDate = date ?? _todayIso();
    final cache = await CacheService.instance.getMenu(citySlug, effectiveDate);

    // return fresh cache immediately if available (avoids server round-trip on scroll)
    if (cache.hasData && !cache.isStale) {
      final page = MenuPage.fromJson(jsonDecode(cache.data!));
      return ApiResult(data: page, fromCache: true);
    }

    try {
      final params = <String, String>{};
      if (date != null)             params['on_date']           = date;
      if (type != null)             params['type']              = type;
      if (delivery != null)         params['delivery']          = delivery.toString();
      if (maxPrice != null)         params['max_price']         = maxPrice.toString();
      if (excludeAllergens != null && excludeAllergens.isNotEmpty)
                                    params['exclude_allergens'] = excludeAllergens.join(',');
      params['limit']  = limit.toString();
      params['offset'] = offset.toString();

      final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
      final data  = await _get('/api/$citySlug/menu?$query');

      if (data != null) {
        final page = MenuPage.fromJson(data);
        await CacheService.instance.setMenu(citySlug, effectiveDate, jsonEncode(data));
        return ApiResult(data: page);
      }
    } catch (_) {}

    // fall back to stale cache
    if (cache.hasData) {
      final page = MenuPage.fromJson(jsonDecode(cache.data!));
      return ApiResult(data: page, fromCache: true, isStale: cache.isStale, serverFailed: true);
    }

    return ApiResult(
      data: MenuPage(date: effectiveDate, count: 0, offset: offset, results: []),
      serverFailed: true,
    );
  }

  // ── Restaurant profile ────────────────────────────────────────────────────

  Future<ApiResult<Restaurant?>> getRestaurantMenu(
    String citySlug, String slug, {String? date}
  ) async {
    final effectiveDate = date ?? _todayIso();
    final cache = await CacheService.instance.getRestaurant(citySlug, slug, effectiveDate);

    // return fresh cache immediately
    if (cache.hasData && !cache.isStale) {
      final r = Restaurant.fromJson(jsonDecode(cache.data!));
      return ApiResult(data: r, fromCache: true);
    }

    try {
      final dateParam = '?on_date=$effectiveDate';
      final data = await _get('/api/$citySlug/restaurants/$slug$dateParam');
      if (data != null) {
        final r = Restaurant.fromJson(data);
        await CacheService.instance.setRestaurant(citySlug, slug, effectiveDate, jsonEncode(data));
        return ApiResult(data: r);
      }
    } catch (_) {}

    if (cache.hasData) {
      final r = Restaurant.fromJson(jsonDecode(cache.data!));
      return ApiResult(data: r, fromCache: true, isStale: cache.isStale, serverFailed: true);
    }

    return ApiResult(data: null, serverFailed: true);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}