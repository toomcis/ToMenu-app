import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../api/client.dart';
import '../models/menu_item.dart';
import '../theme/app_theme.dart';
import '../l10n/strings.dart';
import 'restaurant_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus      = FocusNode();

  bool _loading     = true;
  bool _initialLoad = true;

  List<_ResultGroup> _results = [];

  // ── Multi-day cache ───────────────────────────────────────────────────────
  // Key 0 = today (whatever weekday it actually is).
  // Key 1–5 = Mon–Fri of the current calendar week.
  // On init we fetch key 0 immediately, then silently prefetch 1–5 in background.
  // Switching to a weekday is instant if cached, or shows a spinner while fetching.
  final Map<int, List<MenuItem>> _dayCache   = {};
  final Set<int>                 _dayLoading = {};
  int                            _activeWeekday = 0; // 0 = today

  List<MenuItem> get _allItems => _dayCache[_activeWeekday] ?? [];

  // ── Filter state ──────────────────────────────────────────────────────────
  double  _priceMin          = 0;
  double  _priceMax          = 20;
  double  _priceRangeMin     = 0;
  double  _priceRangeMax     = 20;
  bool    _priceFilterActive = false;

  double  _weightMin          = 0;
  double  _weightMax          = 1000;
  double  _weightRangeMin     = 0;
  double  _weightRangeMax     = 1000;
  bool    _weightFilterActive = false;

  int?      _selectedWeekday; // null = today; 1=Mon … 5=Fri
  bool      _dayPicked = false;  // true once user has explicitly chosen a day
  _SortMode _sortMode = _SortMode.none;

  bool get _anyFilterActive =>
      _priceFilterActive || _weightFilterActive ||
      _selectedWeekday != null || _sortMode != _SortMode.none;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchDay(0, isInit: true).then((_) => _prefetchWeekdays());
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Date helpers ──────────────────────────────────────────────────────────

  static String _isoFor(int weekday) {
    final now = DateTime.now();
    if (weekday == 0) {
      return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    }
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final target = monday.add(Duration(days: weekday - 1));
    return '${target.year}-${target.month.toString().padLeft(2,'0')}-${target.day.toString().padLeft(2,'0')}';
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────

  Future<void> _fetchDay(int weekday, {bool isInit = false}) async {
    if (_dayLoading.contains(weekday)) return;
    _dayLoading.add(weekday);

    final isVisible = weekday == _activeWeekday || isInit;
    if (isVisible && mounted) {
      setState(() {
        _loading     = true;
        _initialLoad = isInit;
      });
    }

    try {
      await ApiClient.instance.init();
      final citiesResult = await ApiClient.instance.getCities();
      final cities       = citiesResult.data;
      final allItems     = <MenuItem>[];
      final date         = _isoFor(weekday);

      for (final city in cities) {
        try {
          final menuResult = await ApiClient.instance.getMenu(
            city.slug,
            date: date,
            limit: 200,
          );
          final page = menuResult.data;
          for (final item in page.results) {
            item.citySlug = city.slug;
            item.cityName = city.name;
          }
          allItems.addAll(page.results);
        } catch (_) {}
      }

      if (!mounted) return;
      _dayCache[weekday] = allItems;
    } catch (_) {
      if (!mounted) return;
      _dayCache.putIfAbsent(weekday, () => []);
    } finally {
      _dayLoading.remove(weekday);
    }

    if (!mounted) return;

    // Only update UI if this is the currently active day or the init load
    if (weekday == _activeWeekday || isInit) {
      _recomputeBounds();
      setState(() {
        _loading     = false;
        _initialLoad = false;
      });
      _filter(_controller.text.trim());
    }
  }

  void _prefetchWeekdays() {
    for (int d = 1; d <= 5; d++) {
      _fetchDay(d);
    }
  }

  void _recomputeBounds() {
    double maxPrice  = 20;
    double maxWeight = 1000;
    for (final item in _allItems) {
      final p = item.priceEur ?? item.menuPrice ?? 0;
      if (p > maxPrice) maxPrice = p;
      final w = _parseWeight(item.weight);
      if (w != null && w > maxWeight) maxWeight = w;
    }
    maxPrice  = ((maxPrice  / 5).ceil()  * 5).toDouble();
    maxWeight = ((maxWeight / 100).ceil() * 100).toDouble();

    _priceMin       = 0; _priceMax       = maxPrice;
    _priceRangeMin  = 0; _priceRangeMax  = maxPrice;
    _weightMin      = 0; _weightMax      = maxWeight;
    _weightRangeMin = 0; _weightRangeMax = maxWeight;
  }

  // ── Day picker on search tap ──────────────────────────────────────────────

  Future<void> _showDayPicker() async {
    // Only show if user hasn't picked a day yet
    debugPrint('[DayPicker] onTap fired — _dayPicked=$_dayPicked');
    if (_dayPicked) return;
    // Prevent keyboard from opening behind the sheet
    _focus.unfocus();

    final accent = context.accentColor;
    const labels = ['Today', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.bg1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: ctx.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Which day are you looking for?',
                  style: TextStyle(
                    color: ctx.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 4),
              Text('Pick a day to search its menu',
                  style: TextStyle(color: ctx.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              Row(
                children: List.generate(6, (i) {
                  // i=0 → today (weekday 0), i=1..5 → Mon–Fri
                  final day        = i; // 0=today, 1=Mon…5=Fri
                  final isCurrent  = (day == 0)
                      ? _activeWeekday == 0
                      : _activeWeekday == day;
                  final isCached   = _dayCache.containsKey(day);
                  final isToday    = day == 0;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 5 ? 6 : 0),
                      child: GestureDetector(
                        onTap: () {
                          _selectDay(day);
                          Navigator.of(ctx).pop();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? accent.withAlpha(25)
                                : context.bg2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent ? accent : context.border,
                              width: isCurrent ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                labels[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isCurrent
                                      ? accent
                                      : context.textPrimary,
                                  fontSize:   isToday ? 11 : 12,
                                  fontWeight: isCurrent
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              if (!isCached && !isToday) ...[
                                const SizedBox(height: 3),
                                SizedBox(
                                  width: 8, height: 8,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: isCurrent
                                        ? accent
                                        : context.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectDay(int weekday) {
    final changed = weekday != _activeWeekday;
    setState(() {
      _activeWeekday   = weekday;
      _selectedWeekday = weekday == 0 ? null : weekday;
      _dayPicked       = true;
      debugPrint('[DayPicker] _dayPicked set to TRUE');
    });
    if (!changed) return;
    if (_dayCache.containsKey(weekday)) {
      _recomputeBounds();
      _filter(_controller.text.trim());
    } else {
      _fetchDay(weekday);
    }
  }

  // ── Filter / sort ─────────────────────────────────────────────────────────

  void _onQueryChanged() {
    if (_initialLoad) return;
    _filter(_controller.text.trim());
  }

  void _filter(String rawQuery) {
    var items = List<MenuItem>.from(_allItems);

    if (_priceFilterActive) {
      items = items.where((item) {
        final p = item.priceEur ?? item.menuPrice;
        if (p == null) return false;
        return p >= _priceRangeMin && p <= _priceRangeMax;
      }).toList();
    }

    if (_weightFilterActive) {
      items = items.where((item) {
        final w = _parseWeight(item.weight);
        if (w == null) return false;
        return w >= _weightRangeMin && w <= _weightRangeMax;
      }).toList();
    }

    if (rawQuery.isNotEmpty) {
      final query = _normalize(rawQuery);
      items = items.where((item) =>
          _normalize(item.searchableText).contains(query)).toList();
    }

    switch (_sortMode) {
      case _SortMode.priceAsc:
        items.sort((a, b) => (a.priceEur ?? a.menuPrice ?? double.infinity)
            .compareTo(b.priceEur ?? b.menuPrice ?? double.infinity));
        break;
      case _SortMode.priceDesc:
        items.sort((a, b) => (b.priceEur ?? b.menuPrice ?? -1.0)
            .compareTo(a.priceEur ?? a.menuPrice ?? -1.0));
        break;
      case _SortMode.weightAsc:
        items.sort((a, b) => (_parseWeight(a.weight) ?? double.infinity)
            .compareTo(_parseWeight(b.weight) ?? double.infinity));
        break;
      case _SortMode.weightDesc:
        items.sort((a, b) => (_parseWeight(b.weight) ?? -1.0)
            .compareTo(_parseWeight(a.weight) ?? -1.0));
        break;
      case _SortMode.nameAsc:
        items.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
        break;
      case _SortMode.nameDesc:
        items.sort((a, b) => (b.name ?? '').compareTo(a.name ?? ''));
        break;
      case _SortMode.none:
        break;
    }

    final groups = <String, _ResultGroup>{};
    for (final item in items) {
      final key =
          '${item.citySlug}__${item.restaurantSlug ?? item.restaurantName}';
      if (!groups.containsKey(key)) {
        groups[key] = _ResultGroup(
          restaurantName: item.restaurantName ?? 'Unknown',
          restaurantSlug: item.restaurantSlug ?? '',
          cityName:       item.cityName ?? '',
          citySlug:       item.citySlug ?? '',
          delivery:       item.delivery ?? false,
          address:        item.address,
          items:          [],
          matchQuery:     rawQuery,
          initialDate:    _activeWeekday != 0 ? _isoFor(_activeWeekday) : null,
        );
      }
      groups[key]!.items.add(item);
    }

    setState(() => _results = groups.values.toList());
  }

  void _resetFilters() {
    setState(() {
      _priceFilterActive  = false;
      _weightFilterActive = false;
      _selectedWeekday    = null;
      _activeWeekday      = 0;
      _dayPicked          = false;
      _sortMode           = _SortMode.none;
    });
    _recomputeBounds();
    _filter(_controller.text.trim());
    Navigator.of(context).pop();
  }

  // ── Filter sheet ──────────────────────────────────────────────────────────

  void _showFilterSheet() {
    double    localPriceMin     = _priceRangeMin;
    double    localPriceMax     = _priceRangeMax;
    bool      localPriceActive  = _priceFilterActive;
    double    localWeightMin    = _weightRangeMin;
    double    localWeightMax    = _weightRangeMax;
    bool      localWeightActive = _weightFilterActive;
    int?      localWeekday      = _selectedWeekday;
    _SortMode localSort         = _sortMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.bg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final accent = ctx.accentColor;

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            builder: (_, scrollController) => Column(
              children: [
                // ── Scrollable area ─────────────────────────────────────
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 36, height: 4,
                          decoration: BoxDecoration(
                            color: ctx.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Header
                      Row(children: [
                        Text('Filter & Sort',
                            style: TextStyle(
                              color:      ctx.textPrimary,
                              fontSize:   18,
                              fontWeight: FontWeight.w700,
                            )),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setLocal(() {
                            localPriceMin     = _priceMin;
                            localPriceMax     = _priceMax;
                            localPriceActive  = false;
                            localWeightMin    = _weightMin;
                            localWeightMax    = _weightMax;
                            localWeightActive = false;
                            localWeekday      = null;
                            localSort         = _SortMode.none;
                          }),
                          child: Text('Reset',
                              style: TextStyle(
                                  color: ctx.textSecondary, fontSize: 13)),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // ── Price ──────────────────────────────────────────
                      _FilterSection(
                        title: 'Price (€)',
                        icon: Icons.euro_rounded,
                        active: localPriceActive,
                        onToggle: (v) => setLocal(() => localPriceActive = v),
                        accent: accent,
                        child: localPriceActive
                            ? Column(children: [
                                const SizedBox(height: 8),
                                Row(children: [
                                  Text('${localPriceMin.toStringAsFixed(2)} €',
                                      style: TextStyle(
                                          color:      accent,
                                          fontWeight: FontWeight.w600,
                                          fontSize:   13)),
                                  const Spacer(),
                                  Text('${localPriceMax.toStringAsFixed(2)} €',
                                      style: TextStyle(
                                          color:      accent,
                                          fontWeight: FontWeight.w600,
                                          fontSize:   13)),
                                ]),
                                RangeSlider(
                                  values: RangeValues(
                                      localPriceMin, localPriceMax),
                                  min: _priceMin,
                                  max: _priceMax,
                                  divisions: ((_priceMax - _priceMin) * 4)
                                      .round()
                                      .clamp(1, 200),
                                  activeColor:   accent,
                                  inactiveColor: accent.withAlpha(40),
                                  onChanged: (v) => setLocal(() {
                                    localPriceMin = v.start;
                                    localPriceMax = v.end;
                                  }),
                                ),
                              ])
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Weight ─────────────────────────────────────────
                      _FilterSection(
                        title: 'Weight (g)',
                        icon: Icons.monitor_weight_outlined,
                        active: localWeightActive,
                        onToggle: (v) =>
                            setLocal(() => localWeightActive = v),
                        accent: accent,
                        child: localWeightActive
                            ? Column(children: [
                                const SizedBox(height: 8),
                                Row(children: [
                                  Text(
                                      '${localWeightMin.toStringAsFixed(0)} g',
                                      style: TextStyle(
                                          color:      accent,
                                          fontWeight: FontWeight.w600,
                                          fontSize:   13)),
                                  const Spacer(),
                                  Text(
                                      '${localWeightMax.toStringAsFixed(0)} g',
                                      style: TextStyle(
                                          color:      accent,
                                          fontWeight: FontWeight.w600,
                                          fontSize:   13)),
                                ]),
                                RangeSlider(
                                  values: RangeValues(
                                      localWeightMin, localWeightMax),
                                  min: _weightMin,
                                  max: _weightMax,
                                  divisions:
                                      ((_weightMax - _weightMin) / 50)
                                          .round()
                                          .clamp(1, 100),
                                  activeColor:   accent,
                                  inactiveColor: accent.withAlpha(40),
                                  onChanged: (v) => setLocal(() {
                                    localWeightMin = v.start;
                                    localWeightMax = v.end;
                                  }),
                                ),
                              ])
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Weekday ────────────────────────────────────────
                      _FilterSection(
                        title: 'Day of week',
                        icon: Icons.calendar_today_rounded,
                        active: localWeekday != null,
                        onToggle: (v) => setLocal(() {
                          if (v) {
                            final wd = DateTime.now().weekday;
                            localWeekday = wd <= 5 ? wd : 1;
                          } else {
                            localWeekday = null;
                          }
                        }),
                        accent: accent,
                        child: localWeekday != null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(
                                  children: List.generate(5, (i) {
                                    final day      = i + 1;
                                    final selected = localWeekday == day;
                                    final isCached =
                                        _dayCache.containsKey(day);
                                    const labels = [
                                      'Mon', 'Tue', 'Wed', 'Thu', 'Fri'
                                    ];
                                    return Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                            right: i < 4 ? 6 : 0),
                                        child: GestureDetector(
                                          onTap: () => setLocal(() =>
                                              localWeekday =
                                                  selected ? null : day),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 180),
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    vertical: 8),
                                            decoration: BoxDecoration(
                                              color: selected
                                                  ? accent.withAlpha(25)
                                                  : ctx.bg1,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: selected
                                                    ? accent
                                                    : ctx.border,
                                                width: selected ? 1.5 : 1,
                                              ),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  labels[i],
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: selected
                                                        ? accent
                                                        : ctx.textSecondary,
                                                    fontSize: 12,
                                                    fontWeight: selected
                                                        ? FontWeight.w700
                                                        : FontWeight.w400,
                                                  ),
                                                ),
                                                // Tiny spinner while day is still loading
                                                if (!isCached) ...[
                                                  const SizedBox(height: 3),
                                                  SizedBox(
                                                    width: 8, height: 8,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 1.5,
                                                      color: selected
                                                          ? accent
                                                          : ctx.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Sort ───────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:        ctx.bg2,
                          borderRadius: BorderRadius.circular(14),
                          border:       Border.all(color: ctx.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.sort_rounded, color: accent, size: 18),
                              const SizedBox(width: 10),
                              Text('Sort',
                                  style: TextStyle(
                                    color:      ctx.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize:   14,
                                  )),
                            ]),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: _SortMode.values
                                  .where((m) => m != _SortMode.none)
                                  .map((mode) {
                                final sel = localSort == mode;
                                return GestureDetector(
                                  onTap: () => setLocal(() => localSort =
                                      sel ? _SortMode.none : mode),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? accent.withAlpha(25)
                                          : ctx.bg1,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                          color: sel ? accent : ctx.border),
                                    ),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(mode.icon,
                                              size:  13,
                                              color: sel
                                                  ? accent
                                                  : ctx.textSecondary),
                                          const SizedBox(width: 5),
                                          Text(mode.label,
                                              style: TextStyle(
                                                color: sel
                                                    ? accent
                                                    : ctx.textSecondary,
                                                fontSize:   12,
                                                fontWeight: sel
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              )),
                                        ]),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // ── Sticky Apply button (always visible) ─────────────────
                Container(
                  padding: EdgeInsets.fromLTRB(
                    24, 12, 24,
                    12 +
                        MediaQuery.of(ctx).viewInsets.bottom +
                        MediaQuery.of(ctx).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: ctx.bg1,
                    border: Border(top: BorderSide(color: ctx.border)),
                  ),
                  child: FilledButton(
                    onPressed: () {
                      final weekdayChanged = localWeekday != _selectedWeekday;
                      setState(() {
                        _priceRangeMin      = localPriceMin;
                        _priceRangeMax      = localPriceMax;
                        _priceFilterActive  = localPriceActive;
                        _weightRangeMin     = localWeightMin;
                        _weightRangeMax     = localWeightMax;
                        _weightFilterActive = localWeightActive;
                        _selectedWeekday    = localWeekday;
                        _activeWeekday      = localWeekday ?? 0;
                        _sortMode           = localSort;
                      });
                      Navigator.of(context).pop();
                      if (weekdayChanged) {
                        final target = localWeekday ?? 0;
                        if (_dayCache.containsKey(target)) {
                          _recomputeBounds();
                          _filter(_controller.text.trim());
                        } else {
                          // Not cached yet — fetch it (rare, only if opened very fast)
                          _fetchDay(target);
                        }
                      } else {
                        _filter(_controller.text.trim());
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      minimumSize:
                          const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Apply Filters',
                        style:
                            TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _normalize(String input) {
    const from = 'áäčďéěíľĺňóôöšťúůüýžÁÄČĎÉĚÍĽĹŇÓÔÖŠŤÚŮÜÝŽ';
    const to   = 'aacdeeilllnooossttuuuyzAACDEEILLLNOOOSTTUUUYZ';
    var result = input.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result;
  }

  static double? _parseWeight(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final lower = raw.toLowerCase().replaceAll(' ', '');
    final gMatch = RegExp(r'(\d+(?:\.\d+)?)g').firstMatch(lower);
    if (gMatch != null) return double.tryParse(gMatch.group(1)!);
    final kgMatch = RegExp(r'(\d+(?:\.\d+)?)kg').firstMatch(lower);
    if (kgMatch != null) {
      final kg = double.tryParse(kgMatch.group(1)!);
      if (kg != null) return kg * 1000;
    }
    return double.tryParse(lower.replaceAll(RegExp(r'[^\d.]'), ''));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  style: TextStyle(color: context.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: _initialLoad
                        ? L10n.s.searchLoading
                        : L10n.s.searchHint,
                    prefixIcon: _loading
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: accent),
                            ),
                          )
                        : Icon(Icons.search_rounded,
                            color: context.textSecondary, size: 20),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded,
                                color: context.textSecondary, size: 18),
                            onPressed: () {
                              _controller.clear();
                              _filter('');
                            },
                          )
                        : null,
                  ),
                  enabled: !_initialLoad,
                  onTap: _initialLoad ? null : _showDayPicker,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _initialLoad ? null : _showFilterSheet,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: _anyFilterActive
                        ? accent.withAlpha(30)
                        : context.bg2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _anyFilterActive ? accent : context.border,
                      width: _anyFilterActive ? 1.5 : 1,
                    ),
                  ),
                  child: Stack(children: [
                    Center(
                      child: Icon(Icons.tune_rounded,
                          color: _anyFilterActive
                              ? accent
                              : context.textSecondary,
                          size: 20),
                    ),
                    if (_anyFilterActive)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          width: 7, height: 7,
                          decoration: BoxDecoration(
                              color: accent, shape: BoxShape.circle),
                        ),
                      ),
                  ]),
                ),
              ),
            ]),
          ),

          // ── Active chips ──
          if (_anyFilterActive)
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (_priceFilterActive)
                    _ActiveChip(
                      label:
                          '${_priceRangeMin.toStringAsFixed(2)}–${_priceRangeMax.toStringAsFixed(2)} €',
                      accent: accent,
                      onRemove: () {
                        setState(() => _priceFilterActive = false);
                        _filter(_controller.text.trim());
                      },
                    ),
                  if (_weightFilterActive)
                    _ActiveChip(
                      label:
                          '${_weightRangeMin.toStringAsFixed(0)}–${_weightRangeMax.toStringAsFixed(0)} g',
                      accent: accent,
                      onRemove: () {
                        setState(() => _weightFilterActive = false);
                        _filter(_controller.text.trim());
                      },
                    ),
                  if (_selectedWeekday != null)
                    _ActiveChip(
                      label: const [
                        'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
                      ][_selectedWeekday! - 1],
                      accent: accent,
                      onRemove: () {
                        setState(() {
                          _selectedWeekday = null;
                          _activeWeekday   = 0;
                          _dayPicked       = false;
                        });
                        _recomputeBounds();
                        _filter(_controller.text.trim());
                      },
                    ),
                  if (_sortMode != _SortMode.none)
                    _ActiveChip(
                      label: _sortMode.label,
                      accent: accent,
                      onRemove: () {
                        setState(() => _sortMode = _SortMode.none);
                        _filter(_controller.text.trim());
                      },
                    ),
                ],
              ),
            ),

          // ── Status line ──
          if (!_initialLoad &&
              (_controller.text.isNotEmpty || _anyFilterActive))
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _results.isEmpty
                      ? L10n.s.noResults
                      : L10n.s.dishCount(
                          _results.fold(0, (s, g) => s + g.items.length),
                          _results.length),
                  style: TextStyle(
                      color: context.textSecondary, fontSize: 12),
                ).animate().fadeIn(duration: 200.ms),
              ),
            ),

          // ── Results ──
          Expanded(
            child: _initialLoad
                ? _LoadingPrompt(accent: accent)
                : _results.isEmpty &&
                        _controller.text.isEmpty &&
                        !_anyFilterActive
                    ? _EmptyPrompt(totalItems: _allItems.length)
                    : _results.isEmpty
                        ? const _NoResultsView()
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: _results.length,
                            itemBuilder: (context, i) =>
                                _SearchResultCard(group: _results[i])
                                    .animate(delay: (i * 30).ms)
                                    .fadeIn(duration: 250.ms)
                                    .slideY(begin: 0.04, end: 0),
                          ),
          ),
        ]),
      ),
    );
  }
}

// ── Sort mode ─────────────────────────────────────────────────────────────────

enum _SortMode {
  none, priceAsc, priceDesc, weightAsc, weightDesc, nameAsc, nameDesc;

  String get label => switch (this) {
    _SortMode.none       => '',
    _SortMode.priceAsc   => 'Price ↑',
    _SortMode.priceDesc  => 'Price ↓',
    _SortMode.weightAsc  => 'Weight ↑',
    _SortMode.weightDesc => 'Weight ↓',
    _SortMode.nameAsc    => 'A → Z',
    _SortMode.nameDesc   => 'Z → A',
  };

  IconData get icon => switch (this) {
    _SortMode.priceAsc   => Icons.arrow_upward_rounded,
    _SortMode.priceDesc  => Icons.arrow_downward_rounded,
    _SortMode.weightAsc  => Icons.arrow_upward_rounded,
    _SortMode.weightDesc => Icons.arrow_downward_rounded,
    _SortMode.nameAsc    => Icons.sort_by_alpha_rounded,
    _SortMode.nameDesc   => Icons.sort_by_alpha_rounded,
    _SortMode.none       => Icons.sort_rounded,
  };
}

// ── Filter section ────────────────────────────────────────────────────────────

class _FilterSection extends StatelessWidget {
  final String             title;
  final IconData           icon;
  final bool               active;
  final ValueChanged<bool> onToggle;
  final Color              accent;
  final Widget?            child;

  const _FilterSection({
    required this.title,
    required this.icon,
    required this.active,
    required this.onToggle,
    required this.accent,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        active ? accent.withAlpha(10) : context.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: active ? accent.withAlpha(80) : context.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: active ? accent : context.textSecondary, size: 18),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                color:      active ? context.textPrimary : context.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize:   14,
              )),
          const Spacer(),
          Switch(
            value:                 active,
            onChanged:             onToggle,
            activeColor:           accent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
        if (child != null) child!,
      ]),
    );
  }
}

// ── Active chip ───────────────────────────────────────────────────────────────

class _ActiveChip extends StatelessWidget {
  final String       label;
  final Color        accent;
  final VoidCallback onRemove;
  const _ActiveChip(
      {required this.label, required this.accent, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        accent.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: accent.withAlpha(80)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                color: accent, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(width: 5),
        GestureDetector(
          onTap: onRemove,
          child: Icon(Icons.close_rounded, color: accent, size: 13),
        ),
      ]),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _ResultGroup {
  final String         restaurantName;
  final String         restaurantSlug;
  final String         cityName;
  final String         citySlug;
  final bool           delivery;
  final String?        address;
  final List<MenuItem> items;
  final String         matchQuery;
  final String?        initialDate;

  _ResultGroup({
    required this.restaurantName,
    required this.restaurantSlug,
    required this.cityName,
    required this.citySlug,
    required this.delivery,
    this.address,
    required this.items,
    required this.matchQuery,
    this.initialDate,
  });
}

// ── Cards ─────────────────────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  final _ResultGroup group;
  const _SearchResultCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final query  = group.matchQuery;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RestaurantProfileScreen(
          restaurantName: group.restaurantName,
          restaurantSlug: group.restaurantSlug,
          citySlug:       group.citySlug,
          cityName:       group.cityName,
          delivery:       group.delivery,
          address:        group.address,
          initialDate:    group.initialDate,
        ),
      )),
      child: Container(
        margin:  const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        context.bg1,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: context.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HighlightedText(
                      text:           group.restaurantName,
                      query:          query,
                      style:          TextStyle(
                          color:      context.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize:   14),
                      highlightColor: accent,
                    ),
                    Text(group.cityName,
                        style: TextStyle(
                            color: context.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              if (group.delivery)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        accent.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                    border:       Border.all(color: accent.withAlpha(60)),
                  ),
                  child: Text('🛵 ${L10n.s.delivery}',
                      style: TextStyle(
                          color:      accent,
                          fontSize:   10,
                          fontWeight: FontWeight.w600)),
                ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: context.textSecondary, size: 18),
            ]),
            const SizedBox(height: 10),
            ...group.items.take(5).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _HighlightedText(
                      text:           item.name ?? item.raw ?? '',
                      query:          query,
                      style:          TextStyle(
                          color: context.textPrimary, fontSize: 13),
                      highlightColor: accent,
                    ),
                  ),
                  if (item.priceEur != null || item.menuPrice != null)
                    Text(
                      '${(item.priceEur ?? item.menuPrice)!.toStringAsFixed(2)} €',
                      style: TextStyle(
                          color:      context.textPrimary,
                          fontSize:   13,
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            )),
            if (group.items.length > 5)
              Text('+ ${group.items.length - 5} ${L10n.s.dishes}',
                  style: TextStyle(
                      color: context.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String    text;
  final String    query;
  final TextStyle style;
  final Color     highlightColor;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightColor,
  });

  String _norm(String s) {
    const from = 'áäčďéěíľĺňóôöšťúůüýžÁÄČĎÉĚÍĽĹŇÓÔÖŠŤÚŮÜÝŽ';
    const to   = 'aacdeeilllnooossttuuuyzAACDEEILLLNOOOSTTUUUYZ';
    var r = s.toLowerCase();
    for (var i = 0; i < from.length; i++) r = r.replaceAll(from[i], to[i]);
    return r;
  }

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty || text.isEmpty) return Text(text, style: style);
    final normText  = _norm(text);
    final normQuery = _norm(query);
    final idx = normText.indexOf(normQuery);
    if (idx < 0) return Text(text, style: style);
    final end = (idx + query.length).clamp(0, text.length);
    return RichText(
      text: TextSpan(children: [
        if (idx > 0) TextSpan(text: text.substring(0, idx), style: style),
        TextSpan(
          text:  text.substring(idx, end),
          style: style.copyWith(
            color:           highlightColor,
            fontWeight:      FontWeight.w700,
            backgroundColor: highlightColor.withAlpha(25),
          ),
        ),
        if (end < text.length)
          TextSpan(text: text.substring(end), style: style),
      ]),
    );
  }
}

// ── Placeholder views ─────────────────────────────────────────────────────────

class _LoadingPrompt extends StatelessWidget {
  final Color accent;
  const _LoadingPrompt({required this.accent});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: accent, strokeWidth: 2),
      const SizedBox(height: 16),
      Text(L10n.s.searchLoading,
          style: TextStyle(color: context.textSecondary, fontSize: 13)),
      const SizedBox(height: 6),
      Text(L10n.s.searchReady,
          style: TextStyle(color: context.textSecondary, fontSize: 11)),
    ]),
  );
}

class _EmptyPrompt extends StatelessWidget {
  final int totalItems;
  const _EmptyPrompt({required this.totalItems});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🔍', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 16),
      Text(L10n.s.searchAcrossAllCities,
          style: TextStyle(color: context.textSecondary, fontSize: 14)),
      const SizedBox(height: 6),
      Text('$totalItems ${L10n.s.dishes} — ${L10n.s.searchTip}',
          style: TextStyle(color: context.textSecondary, fontSize: 12),
          textAlign: TextAlign.center),
    ]),
  );
}

class _NoResultsView extends StatelessWidget {
  const _NoResultsView();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('😕', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 16),
      Text(L10n.s.noResults,
          style: TextStyle(color: context.textSecondary, fontSize: 14)),
      const SizedBox(height: 6),
      Text(L10n.s.tryDifferentSpelling,
          style: TextStyle(color: context.textSecondary, fontSize: 12)),
    ]),
  );
}
