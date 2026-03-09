import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/client.dart';
import '../models/city.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../theme/app_theme.dart';
import '../l10n/strings.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/menu_item_detail.dart';
import '../widgets/day_selector.dart';
import '../widgets/stale_cache_banner.dart';
import '../services/cache_service.dart';
import 'restaurant_profile_screen.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  bool _loading = true;
  String? _error;
  bool _serverFailed  = false;
  bool _isStaleCache  = false;
  String? _cacheDate;

  List<City>       _cities       = [];
  List<WeekDay>    _weekDays     = [];
  String           _selectedDate = _todayIso();
  List<_CityGroup> _cityGroups   = [];
  String?          _nickname;

  @override
  void initState() {
    super.initState();
    _init();
  }

  static String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  Future<void> _init() async {
    await ApiClient.instance.init();
    await _loadNickname();
    await _loadCities();
    if (_cities.isNotEmpty) {
      await _loadWeek();
      await _loadRestaurants();
    }
  }

  Future<void> _loadNickname() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _nickname = prefs.getString('nickname'));
  }

  Future<void> _loadCities() async {
    try {
      final result    = await ApiClient.instance.getCities();
      final sorted    = await _sortCitiesByDistance(result.data);
      final cacheDate = await CacheService.instance.getLastCacheDate();
      if (mounted) setState(() {
        _cities       = sorted;
        _serverFailed = result.serverFailed;
        _isStaleCache = result.isStale;
        _cacheDate    = cacheDate;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<List<City>> _sortCitiesByDistance(List<City> cities) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return cities;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 5));

      const cityCoords = <String, List<double>>{
        'levice':           [48.2139, 18.6025],
        'nove-zamky':       [47.9856, 18.1628],
        'zlate-moravce':    [48.3840, 18.3999],
        'zarnovica':        [48.4862, 18.7156],
        'zvolen':           [48.5742, 19.1266],
        'ziar-nad-hronom':  [48.5855, 18.8538],
        'banska-stiavnica': [48.4593, 18.8979],
      };

      for (final city in cities) {
        final coords = cityCoords[city.slug];
        if (coords != null) {
          city.distanceKm = Geolocator.distanceBetween(
            pos.latitude, pos.longitude, coords[0], coords[1],
          ) / 1000;
        }
      }
      cities.sort((a, b) {
        if (a.distanceKm == null && b.distanceKm == null) return 0;
        if (a.distanceKm == null) return 1;
        if (b.distanceKm == null) return -1;
        return a.distanceKm!.compareTo(b.distanceKm!);
      });
    } catch (_) {}
    return cities;
  }

  Future<void> _loadWeek() async {
    if (_cities.isEmpty) return;
    try {
      final result = await ApiClient.instance.getWeek(_cities.first.slug);
      if (mounted) setState(() => _weekDays = result.data);
    } catch (_) {}
  }

  Future<void> _loadRestaurants() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final groups = <_CityGroup>[];

      for (final city in _cities) {
        final result = await ApiClient.instance.getMenu(
          city.slug,
          date: _selectedDate,
          limit: 200,
        );
        final page = result.data;
        if (result.serverFailed && mounted) {
          setState(() { _serverFailed = true; _isStaleCache = result.isStale; });
        }

        if (page.results.isEmpty) continue;

        final Map<String, _RestaurantData> byRestaurant = {};
        for (final item in page.results) {
          final key = item.restaurantSlug ?? item.restaurantName ?? 'unknown';
          byRestaurant.putIfAbsent(key, () => _RestaurantData(
            name:     item.restaurantName ?? 'Unknown',
            slug:     item.restaurantSlug ?? key,
            delivery: item.delivery ?? false,
            address:  item.address,
            items:    [],
          ));
          byRestaurant[key]!.items.add(item);
        }

        final restaurants = byRestaurant.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        groups.add(_CityGroup(city: city, restaurants: restaurants));
      }

      if (mounted) setState(() { _cityGroups = groups; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _onDaySelected(String date) {
    setState(() => _selectedDate = date);
    _loadRestaurants();
  }

  int get _totalItems {
    int count = 0;
    for (final g in _cityGroups) {
      if (_cityGroups.length > 1) count++;
      count += g.restaurants.length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final accent   = context.accentColor;
    final greeting = _buildGreeting();

    return Scaffold(
      backgroundColor: context.bgColor,
      body: RefreshIndicator(
        color: accent,
        onRefresh: () async {
          await _loadCities();
          await _loadWeek();
          await _loadRestaurants();
        },
        child: CustomScrollView(
          slivers: [
            if (_serverFailed && _isStaleCache)
              SliverToBoxAdapter(
                child: StaleCacheBanner(
                  cacheDate: _cacheDate,
                  onRetry: () async {
                    await _loadCities();
                    await _loadWeek();
                    await _loadRestaurants();
                  },
                ),
              ),

            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: context.bg1,
              surfaceTintColor: Colors.transparent,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.s.appName,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    greeting,
                    style: TextStyle(color: context.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),

            SliverPersistentHeader(
              pinned: true,
              delegate: _DaySelectorDelegate(
                days: _weekDays,
                selectedDate: _selectedDate,
                onDaySelected: _onDaySelected,
                accent: accent,
                bg: context.bg1,
                border: context.border,
              ),
            ),

            if (_loading)
              const SliverFillRemaining(child: _LoadingView())
            else if (_error != null)
              SliverFillRemaining(child: _ErrorView(error: _error!, onRetry: _loadRestaurants))
            else if (_cityGroups.isEmpty)
              const SliverFillRemaining(child: _EmptyView())
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    int cursor = 0;
                    for (final group in _cityGroups) {
                      if (_cityGroups.length > 1) {
                        if (index == cursor) return _CityHeader(group: group);
                        cursor++;
                      }
                      for (int i = 0; i < group.restaurants.length; i++) {
                        if (index == cursor) {
                          return RestaurantDataCard(
                            data: group.restaurants[i],
                            citySlug: group.city.slug,
                            cityName: group.city.name,
                            selectedDate: _selectedDate,
                          ).animate(delay: (i * 40).ms).fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
                        }
                        cursor++;
                      }
                    }
                    return null;
                  },
                  childCount: _totalItems,
                ),
              ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
    );
  }

  String _buildGreeting() {
    final hour = DateTime.now().hour;
    final name = (_nickname != null && _nickname!.isNotEmpty) ? ', $_nickname' : '';
    if (hour < 11) return '${L10n.s.greetingMorning}$name 🌅';
    if (hour < 14) return '${L10n.s.greetingLunch.replaceAll("?", "")}$name? 🍽';
    if (hour < 18) return '${L10n.s.greetingAfternoon}$name ☀️';
    return '${L10n.s.greetingEvening}$name 🌙';
  }
}

class _CityGroup {
  final City                  city;
  final List<_RestaurantData> restaurants;
  _CityGroup({required this.city, required this.restaurants});
}

class _RestaurantData {
  final String         name;
  final String         slug;
  final bool           delivery;
  final String?        address;
  final List<MenuItem> items;
  String? photoUrl;
  bool    verified = false;

  _RestaurantData({
    required this.name,
    required this.slug,
    required this.delivery,
    this.address,
    required this.items,
    this.photoUrl,
  });
}

// ── RestaurantDataCard ────────────────────────────────────────────────────────

class RestaurantDataCard extends StatefulWidget {
  final _RestaurantData data;
  final String citySlug;
  final String cityName;
  final String selectedDate;

  const RestaurantDataCard({
    super.key,
    required this.data,
    required this.citySlug,
    required this.cityName,
    required this.selectedDate,
  });

  @override
  State<RestaurantDataCard> createState() => _RestaurantDataCardState();
}

class _RestaurantDataCardState extends State<RestaurantDataCard> {
  bool _expanded = false;

  void _openProfile() {
    final r = widget.data;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RestaurantProfileScreen(
        restaurantName: r.name,
        restaurantSlug: r.slug,
        citySlug:       widget.citySlug,
        cityName:       widget.cityName,
        delivery:       r.delivery,
        address:        r.address,
        initialDate:    widget.selectedDate,
      ),
    ));
  }

  Future<void> _openMaps(String address) async {
    final encoded = Uri.encodeComponent(address);
    final geoUri  = Uri.parse('geo:0,0?q=$encoded');
    try {
      if (await launchUrl(geoUri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    final webUri = Uri.parse('https://maps.google.com/?q=$encoded');
    try { await launchUrl(webUri, mode: LaunchMode.externalApplication); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r      = widget.data;
    final accent = context.accentColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: context.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border, width: 1),
        image: r.photoUrl != null
            ? DecorationImage(
                image: NetworkImage(r.photoUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(context.bg1.withAlpha(210), BlendMode.srcOver),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              GestureDetector(
                onTap: _openProfile,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                      style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: GestureDetector(
                  onTap: _openProfile,
                  behavior: HitTestBehavior.opaque,
                  child: Row(children: [
                    Flexible(
                      child: Text(
                        r.name,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (r.verified) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.verified_rounded, color: accent, size: 15),
                    ],
                  ]),
                ),
              ),

              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                behavior: HitTestBehavior.opaque,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (r.delivery) _Badge(label: '🛵', color: accent),
                  const SizedBox(width: 6),
                  Text(
                    '${r.items.length} ${L10n.s.dishes}',
                    style: TextStyle(color: context.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: context.textSecondary, size: 20),
                  ),
                ]),
              ),
            ]),
          ),

          // ── Expanded ──
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(color: context.border, height: 1),
                      if (r.address != null)
                        GestureDetector(
                          onTap: () => _openMaps(r.address!),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                            child: Row(children: [
                              Icon(Icons.map_outlined, color: accent, size: 13),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  r.address!,
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ...r.items.map((item) => _MenuItemRow(item: item)),
                      const SizedBox(height: 10),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:  color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final MenuItem item;
  final String?  phone;
  const _MenuItemRow({required this.item, this.phone});

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final typeColor = switch (item.type) {
      'soup'    => Colors.orange,
      'main'    => accent,
      'dessert' => Colors.pink,
      _         => context.textSecondary,
    };
    final typeLabel = switch (item.type) {
      'soup'    => L10n.s.soup,
      'main'    => L10n.s.main,
      'dessert' => L10n.s.dessert,
      _         => item.type,
    };

    return GestureDetector(
      onTap: () => showMenuItemDetail(context, item, phone: phone),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: typeColor.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                typeLabel,
                textAlign: TextAlign.center,
                style: TextStyle(color: typeColor, fontSize: 9, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.name != null)
                    Text(item.name!,
                        style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                  if (item.description != null && item.description!.isNotEmpty)
                    Text(item.description!,
                        style: TextStyle(color: context.textSecondary, fontSize: 11),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (item.priceEur != null || item.menuPrice != null) ...[
              const SizedBox(width: 8),
              Text(
                '${(item.priceEur ?? item.menuPrice)!.toStringAsFixed(2)} €',
                style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CityHeader extends StatelessWidget {
  final _CityGroup group;
  const _CityHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(children: [
        Text(group.city.name,
            style: TextStyle(color: context.accentColor, fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1)),
        if (group.city.distanceKm != null) ...[
          const SizedBox(width: 8),
          Text('${group.city.distanceKm!.toStringAsFixed(0)} ${L10n.s.kmAway}',
              style: TextStyle(color: context.textSecondary, fontSize: 11)),
        ],
      ]),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: context.accentColor, strokeWidth: 2),
      const SizedBox(height: 16),
      Text(L10n.s.loadingMenus, style: TextStyle(color: context.textSecondary, fontSize: 13)),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.wifi_off_rounded, size: 48, color: context.textSecondary),
      const SizedBox(height: 16),
      Text(L10n.s.couldNotLoadMenus, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(error, style: TextStyle(color: context.textSecondary, fontSize: 12), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      FilledButton(onPressed: onRetry, child: Text(L10n.s.tryAgain)),
    ])),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🍽', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 16),
      Text(L10n.s.noMenusForDay, style: TextStyle(color: context.textSecondary, fontSize: 14)),
      const SizedBox(height: 8),
      Text(L10n.s.tryDifferentDay, style: TextStyle(color: context.textSecondary, fontSize: 12)),
    ]),
  );
}

class _DaySelectorDelegate extends SliverPersistentHeaderDelegate {
  final List<WeekDay> days;
  final String        selectedDate;
  final void Function(String) onDaySelected;
  final Color         accent;
  final Color         bg;
  final Color         border;

  const _DaySelectorDelegate({
    required this.days,
    required this.selectedDate,
    required this.onDaySelected,
    required this.accent,
    required this.bg,
    required this.border,
  });

  @override double get minExtent => 48;
  @override double get maxExtent => 48;

  @override
  bool shouldRebuild(_DaySelectorDelegate old) =>
      old.selectedDate != selectedDate ||
      old.days.length != days.length ||
      old.accent != accent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return DaySelector(
      days: days,
      selectedDate: selectedDate,
      onDaySelected: onDaySelected,
      accent: accent,
    );
  }
}