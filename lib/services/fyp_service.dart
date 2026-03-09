import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

const String _authBaseUrl = 'https://auth.tomenu.sk';

// ── Models ────────────────────────────────────────────────────────────────────

class FeedItem {
  final String name;
  final String restaurantName;
  final String restaurantSlug;
  final String citySlug;
  final double? price;
  final String? priceFormatted;
  final String? weight;
  final List<String> tags;
  final List<int> allergens;
  final bool delivery;

  const FeedItem({
    required this.name,
    required this.restaurantName,
    required this.restaurantSlug,
    required this.citySlug,
    this.price,
    this.priceFormatted,
    this.weight,
    required this.tags,
    required this.allergens,
    required this.delivery,
  });

  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
    name:             j['name']             as String,
    restaurantName:   j['restaurant_name']  as String? ?? j['restaurant_slug'] as String,
    restaurantSlug:   j['restaurant_slug']  as String,
    citySlug:         j['city_slug']        as String? ?? 'levice',
    price:            (j['price'] as num?)?.toDouble(),
    priceFormatted:   j['price_formatted']  as String?,
    weight:           j['weight']           as String?,
    tags:             List<String>.from(j['tags'] ?? []),
    allergens:        List<int>.from(j['allergens'] ?? []),
    delivery:         (j['delivery'] as bool?) ?? false,
  );

  String get displayPrice {
    if (priceFormatted != null) return priceFormatted!;
    if (price != null) return '${price!.toStringAsFixed(2)} €';
    return '';
  }
}

class OnboardingRestaurant {
  final String slug;
  final String name;
  final String city;
  final String? address;
  final String? district;
  final bool delivery;

  const OnboardingRestaurant({
    required this.slug,
    required this.name,
    required this.city,
    this.address,
    this.district,
    required this.delivery,
  });

  factory OnboardingRestaurant.fromJson(Map<String, dynamic> j) =>
      OnboardingRestaurant(
        slug:     j['slug']     as String,
        name:     j['name']     as String,
        city:     j['city']     as String,
        address:  j['address']  as String?,
        district: j['district'] as String?,
        delivery: (j['delivery'] as bool?) ?? false,
      );
}

// ── Service ───────────────────────────────────────────────────────────────────

class FypService {
  FypService._();
  static final instance = FypService._();

  Future<Map<String, String>> _authHeaders() async {
    final token = await AuthService.instance.getToken();
    if (token == null) return {};
    return {
      'Authorization': 'Bearer $token',
      'Content-Type':  'application/json',
    };
  }

  // ── Feed ──────────────────────────────────────────────────────────────────

  /// Returns ranked feed items for [city] on [date] (YYYY-MM-DD).
  /// Returns empty list if user is not authenticated (guest mode — caller
  /// should fall back to the regular menu API).
  Future<({List<FeedItem> items, String date, bool empty})> getFeed({
    String? city,
    String? date,
    int limit = 20,
  }) async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return (items: <FeedItem>[], date: date ?? '', empty: false);

    final params = <String, String>{'limit': '$limit'};
    if (city != null) params['city'] = city;
    if (date != null) params['date'] = date;

    final uri = Uri.parse('$_authBaseUrl/fyp/feed').replace(queryParameters: params);
    final res  = await http.get(uri, headers: headers);
    if (res.statusCode != 200) return (items: <FeedItem>[], date: date ?? '', empty: false);

    final body  = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['items'] as List? ?? [])
        .map((e) => FeedItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final returnedDate = body['date'] as String? ?? date ?? '';
    final empty = items.isEmpty;
    return (items: items, date: returnedDate, empty: empty);
  }

  // ── Swipe ─────────────────────────────────────────────────────────────────

  Future<bool> swipe({
    required String itemName,
    required String restaurantSlug,
    required String citySlug,
    required String direction, // 'like' | 'dislike' | 'skip'
    List<String> tags = const [],
  }) async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return false;

    final res = await http.post(
      Uri.parse('$_authBaseUrl/fyp/swipe'),
      headers: headers,
      body: jsonEncode({
        'item_name':       itemName,
        'restaurant_slug': restaurantSlug,
        'city_slug':       citySlug,
        'direction':       direction,
        'tags':            tags,
      }),
    );
    return res.statusCode == 200;
  }

  // ── Onboarding ────────────────────────────────────────────────────────────

  Future<List<OnboardingRestaurant>> getOnboardingRestaurants({String? city}) async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return [];

    final params = <String, String>{};
    if (city != null) params['city'] = city;

    final uri = Uri.parse('$_authBaseUrl/fyp/onboarding-restaurants')
        .replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['restaurants'] as List? ?? [])
        .map((e) => OnboardingRestaurant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> submitOnboarding({
    required List<String> likedTags,
    required String citySlug,
    required List<String> favoriteRestaurantSlugs,
  }) async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return false;

    final res = await http.post(
      Uri.parse('$_authBaseUrl/fyp/onboarding'),
      headers: headers,
      body: jsonEncode({
        'liked_tags':           likedTags,
        'city_slug':            citySlug,
        'favorite_restaurants': favoriteRestaurantSlugs
            .map((s) => {'restaurant_slug': s, 'city_slug': citySlug})
            .toList(),
      }),
    );
    return res.statusCode == 200;
  }

  // ── Taste profile ─────────────────────────────────────────────────────────

  Future<({List<String> likedTags, List<String> dislikedTags})> getTaste() async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return (likedTags: <String>[], dislikedTags: <String>[]);

    final res = await http.get(Uri.parse('$_authBaseUrl/fyp/taste'), headers: headers);
    if (res.statusCode != 200) return (likedTags: <String>[], dislikedTags: <String>[]);

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      likedTags:    List<String>.from(body['liked_tags']    ?? []),
      dislikedTags: List<String>.from(body['disliked_tags'] ?? []),
    );
  }

  Future<bool> updateTaste({
    List<String>? likedTags,
    List<String>? dislikedTags,
  }) async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return false;

    final body = <String, dynamic>{};
    if (likedTags    != null) body['liked_tags']    = likedTags;
    if (dislikedTags != null) body['disliked_tags'] = dislikedTags;

    final res = await http.patch(
      Uri.parse('$_authBaseUrl/fyp/taste'),
      headers: headers,
      body: jsonEncode(body),
    );
    return res.statusCode == 200;
  }

  // ── Favorites ─────────────────────────────────────────────────────────────

  Future<List<Map<String, String>>> getFavorites() async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return [];

    final res = await http.get(Uri.parse('$_authBaseUrl/fyp/favorites'), headers: headers);
    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['favorites'] as List? ?? [])
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
  }

  Future<bool> addFavorite({required String restaurantSlug, required String citySlug}) async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return false;
    final res = await http.post(
      Uri.parse('$_authBaseUrl/fyp/favorites'),
      headers: headers,
      body: jsonEncode({'restaurant_slug': restaurantSlug, 'city_slug': citySlug}),
    );
    return res.statusCode == 200;
  }

  Future<bool> removeFavorite({required String restaurantSlug, required String citySlug}) async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return false;
    final res = await http.delete(
      Uri.parse('$_authBaseUrl/fyp/favorites'),
      headers: headers,
      body: jsonEncode({'restaurant_slug': restaurantSlug, 'city_slug': citySlug}),
    );
    return res.statusCode == 200;
  }

  // ── Reset account ─────────────────────────────────────────────────────────

  /// Clears all swipe history, favorites, taste profile and preferences.
  /// Auth, 2FA and sessions are preserved.
  Future<bool> resetAccount() async {
    final headers = await _authHeaders();
    if (headers.isEmpty) return false;

    final res = await http.post(
      Uri.parse('$_authBaseUrl/auth/reset-account'),
      headers: headers,
    );
    return res.statusCode == 200;
  }
}