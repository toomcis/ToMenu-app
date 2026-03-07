import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../api/client.dart';
import '../models/city.dart';
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

  bool   _loading     = true;
  bool   _initialLoad = true;

  // all items fetched from ALL cities — loaded fully before any search runs
  List<MenuItem> _allItems = [];
  List<_ResultGroup> _results = [];

  @override
  void initState() {
    super.initState();
    _fetchAll();
    // listener only triggers filter — never during initial load
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Fetch ALL cities completely before making results available.
  // This prevents the race condition where partial results show mid-load.
  Future<void> _fetchAll() async {
    if (mounted) setState(() { _loading = true; _initialLoad = true; });
    try {
      await ApiClient.instance.init();
      final citiesResult = await ApiClient.instance.getCities();
      final cities = citiesResult.data;
      final allItems = <MenuItem>[];

      // fetch all cities — await each one fully before moving on
      for (final city in cities) {
        try {
          final menuResult = await ApiClient.instance.getMenu(city.slug, limit: 200);
          final page = menuResult.data;
          for (final item in page.results) {
            item.citySlug = city.slug;
            item.cityName = city.name;
          }
          allItems.addAll(page.results);
        } catch (_) {
          // skip cities that fail, don't abort everything
        }
      }

      if (!mounted) return;
      // set ALL items at once — only now is search available
      setState(() {
        _allItems    = allItems;
        _loading     = false;
        _initialLoad = false;
      });

      // if user already typed something while loading, run filter now
      if (_controller.text.trim().isNotEmpty) {
        _filter(_controller.text.trim());
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _initialLoad = false; });
    }
  }

  void _onQueryChanged() {
    // don't filter while still loading — avoids partial results
    if (_initialLoad) return;
    _filter(_controller.text.trim());
  }

  void _filter(String rawQuery) {
    if (rawQuery.isEmpty) {
      setState(() => _results = []);
      return;
    }

    final query = _normalize(rawQuery);

    final matched = _allItems.where((item) {
      return _normalize(item.searchableText).contains(query);
    }).toList();

    // group by restaurant (city slug + restaurant slug)
    final groups = <String, _ResultGroup>{};
    for (final item in matched) {
      final key = '${item.citySlug}__${item.restaurantSlug ?? item.restaurantName}';
      if (!groups.containsKey(key)) {
        groups[key] = _ResultGroup(
          restaurantName: item.restaurantName ?? 'Unknown',
          restaurantSlug: item.restaurantSlug ?? '',
          cityName:       item.cityName ?? '',
          citySlug:       item.citySlug ?? '',
          delivery:       item.delivery ?? false,
          address:        item.address,
          items:          [],
          matchQuery:     rawQuery, // pass original for highlighting
        );
      }
      groups[key]!.items.add(item);
    }

    setState(() => _results = groups.values.toList());
  }

  String _normalize(String input) {
    const from = 'áäčďéěíľĺňóôöšťúůüýžÁÄČĎÉĚÍĽĹŇÓÔÖŠŤÚŮÜÝŽ';
    const to   = 'aacdeeilllnooossttuuuyzAACDEEILLLNOOOSTTUUUYZ';
    var result = input.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                          ),
                        )
                      : Icon(Icons.search_rounded, color: context.textSecondary, size: 20),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: context.textSecondary, size: 18),
                          onPressed: () { _controller.clear(); _filter(''); },
                        )
                      : null,
                ),
                // disable typing while loading to avoid confusion
                enabled: !_initialLoad,
              ),
            ),

            // ── Status line ──
            if (!_initialLoad && _controller.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _results.isEmpty
                        ? L10n.s.noResults
                        : L10n.s.dishCount(_results.fold(0, (s, g) => s + g.items.length), _results.length),
                    style: TextStyle(color: context.textSecondary, fontSize: 12),
                  ).animate().fadeIn(duration: 200.ms),
                ),
              ),

            // ── Results ──
            Expanded(
              child: _initialLoad
                  ? _LoadingPrompt(accent: accent)
                  : _results.isEmpty && _controller.text.isEmpty
                      ? _EmptyPrompt(totalItems: _allItems.length)
                      : _results.isEmpty
                          ? _NoResultsView()
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: _results.length,
                              itemBuilder: (context, i) => _SearchResultCard(
                                group: _results[i],
                              ).animate(delay: (i * 30).ms).fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0),
                            ),
            ),
          ],
        ),
      ),
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

  _ResultGroup({
    required this.restaurantName,
    required this.restaurantSlug,
    required this.cityName,
    required this.citySlug,
    required this.delivery,
    this.address,
    required this.items,
    required this.matchQuery,
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
        ),
      )),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.bg1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // restaurant header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // highlight restaurant name if it matches
                      _HighlightedText(
                        text:           group.restaurantName,
                        query:          query,
                        style:          TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                        highlightColor: accent,
                      ),
                      Text(group.cityName,
                          style: TextStyle(color: context.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                if (group.delivery)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accent.withAlpha(60)),
                    ),
                    child: Text('🛵 ${L10n.s.delivery}',
                        style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: context.textSecondary, size: 18),
              ],
            ),

            const SizedBox(height: 10),

            // matched dishes
            ...group.items.take(5).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _HighlightedText(
                      text:           item.name ?? item.raw ?? '',
                      query:          query,
                      style:          TextStyle(color: context.textPrimary, fontSize: 13),
                      highlightColor: accent,
                    ),
                  ),
                  if (item.priceEur != null || item.menuPrice != null)
                    Text(
                      '${(item.priceEur ?? item.menuPrice)!.toStringAsFixed(2)} €',
                      style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            )),

            // "and X more" if there are many items
            if (group.items.length > 5)
              Text(
                '+ ${group.items.length - 5} ${L10n.s.dishes}',
                style: TextStyle(color: context.textSecondary, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }
}

// Highlights the matching substring in accent color, diacritic-insensitive
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

    // make sure we don't go out of bounds on the original string
    final end = (idx + query.length).clamp(0, text.length);

    return RichText(
      text: TextSpan(children: [
        if (idx > 0)
          TextSpan(text: text.substring(0, idx), style: style),
        TextSpan(
          text: text.substring(idx, end),
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

// ── Empty / loading states ────────────────────────────────────────────────────

class _LoadingPrompt extends StatelessWidget {
  final Color accent;
  const _LoadingPrompt({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: accent, strokeWidth: 2),
        const SizedBox(height: 16),
        Text(L10n.s.searchLoading, style: TextStyle(color: context.textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        Text(L10n.s.searchReady, style: TextStyle(color: context.textSecondary, fontSize: 11)),
      ]),
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  final int totalItems;
  const _EmptyPrompt({required this.totalItems});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🔍', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        Text(L10n.s.searchAcrossAllCities, style: TextStyle(color: context.textSecondary, fontSize: 14)),
        const SizedBox(height: 6),
        Text(
          '$totalItems ${L10n.s.dishes} — ${L10n.s.searchTip}',
          style: TextStyle(color: context.textSecondary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

class _NoResultsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('😕', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 16),
        Text(L10n.s.noResults, style: TextStyle(color: context.textSecondary, fontSize: 14)),
        const SizedBox(height: 6),
        Text(L10n.s.tryDifferentSpelling, style: TextStyle(color: context.textSecondary, fontSize: 12)),
      ]),
    );
  }
}