import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/fyp_service.dart';
import '../theme/app_theme.dart';

// ── Preference pill data ──────────────────────────────────────────────────────

class _PillOption {
  final String tag;
  final String labelSk;
  final String emoji;
  const _PillOption(this.tag, this.labelSk, this.emoji);
}

const _kPills = [
  _PillOption('vegetarian',  'Vegetariánske',   '🥦'),
  _PillOption('meat',        'Mäsové',          '🥩'),
  _PillOption('healthy',     'Zdravé',          '🥗'),
  _PillOption('fried',       'Vyprážané',       '🍟'),
  _PillOption('spicy',       'Pikantné',        '🌶️'),
  _PillOption('sweet',       'Sladké',          '🍰'),
  _PillOption('soup',        'Polievky',        '🍲'),
  _PillOption('pasta',       'Cestoviny',       '🍝'),
  _PillOption('grill',       'Grilované',       '🔥'),
  _PillOption('fish',        'Ryby',            '🐟'),
  _PillOption('burger',      'Burgre',          '🍔'),
  _PillOption('asian',       'Ázijská kuchyňa', '🍜'),
];

// ── Shared prefs key ──────────────────────────────────────────────────────────

const _kOnboardingDone = 'fyp_onboarding_done';

class OnboardingFlow extends StatefulWidget {
  /// Called after onboarding completes or is skipped.
  final VoidCallback onDone;

  const OnboardingFlow({super.key, required this.onDone});

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingDone) ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDone, true);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOnboardingDone);
  }

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pageController = PageController();
  int _page = 0;

  // Screen 1: preference pills
  final Set<String> _selectedTags = {};

  // Screen 2: favorite restaurants
  List<OnboardingRestaurant> _restaurants = [];
  final Set<String> _favSlugs = {};
  bool _loadingRestaurants = false;
  String _detectedCity = 'levice';

  // Screen 3: training swipes (5 cards)
  List<FeedItem> _trainingItems = [];
  int _trainingIndex = 0;
  bool _loadingTraining = false;
  bool _trainingDone = false;

  // Submission
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurants() async {
    setState(() => _loadingRestaurants = true);
    // Use GPS city detection via the app's existing mechanism,
    // fall back to 'levice' — the worker resolves city from user prefs too.
    final list = await FypService.instance.getOnboardingRestaurants(
      city: _detectedCity,
    );
    if (mounted) setState(() {
      _restaurants       = list;
      _loadingRestaurants = false;
    });
  }

  Future<void> _loadTrainingItems() async {
    setState(() => _loadingTraining = true);
    final result = await FypService.instance.getFeed(city: _detectedCity, limit: 10);
    if (mounted) setState(() {
      _trainingItems  = result.items;
      _loadingTraining = false;
    });
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    setState(() => _page = page);
  }

  Future<void> _next() async {
    if (_page == 0) {
      // Move to Screen 2
      _goTo(1);
    } else if (_page == 1) {
      // Move to Screen 3 — load training items
      _goTo(2);
      if (_trainingItems.isEmpty) await _loadTrainingItems();
    } else {
      // Done
      await _finish();
    }
  }

  Future<void> _skip() async {
    if (_page < 2) {
      _goTo(_page + 1);
      if (_page == 2 && _trainingItems.isEmpty) await _loadTrainingItems();
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _submitting = true);
    await FypService.instance.submitOnboarding(
      likedTags:              _selectedTags.toList(),
      citySlug:               _detectedCity,
      favoriteRestaurantSlugs: _favSlugs.toList(),
    );
    await OnboardingFlow.markCompleted();
    if (mounted) widget.onDone();
  }

  void _trainSwipe(String direction, FeedItem item) async {
    FypService.instance.swipe(
      itemName:       item.name,
      restaurantSlug: item.restaurantSlug,
      citySlug:       item.citySlug,
      direction:      direction,
      tags:           item.tags,
    );
    final next = _trainingIndex + 1;
    if (next >= 5 || next >= _trainingItems.length) {
      setState(() { _trainingDone = true; _trainingIndex = next; });
    } else {
      setState(() => _trainingIndex = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  // Back button (disabled on page 0 and page 1+)
                  if (_page > 0 && _page < 2)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => _goTo(_page - 1),
                    )
                  else
                    const SizedBox(width: 48),

                  const Spacer(),

                  // Progress dots
                  Row(
                    children: List.generate(3, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width:  _page == i ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:  _page == i ? colors.primary : colors.outline,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),

                  const Spacer(),

                  // Skip
                  TextButton(
                    onPressed: _skip,
                    child: Text('Preskočiť', style: TextStyle(color: colors.outline)),
                  ),
                ],
              ),
            ),

            // ── Pages ─────────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller:     _pageController,
                physics:        const NeverScrollableScrollPhysics(),
                onPageChanged:  (p) => setState(() => _page = p),
                children: [
                  _buildScreen1(colors),
                  _buildScreen2(colors),
                  _buildScreen3(colors),
                ],
              ),
            ),

            // ── Bottom action ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: _buildBottomButton(colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButton(ColorScheme colors) {
    if (_submitting) {
      return const Center(child: CircularProgressIndicator());
    }

    final isLast = _page == 2 && (_trainingDone || _trainingItems.isEmpty);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: _next,
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          isLast ? 'Začať prehľadávať 🎉' : 'Ďalej',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ── Screen 1: Preference pills ─────────────────────────────────────────────

  Widget _buildScreen1(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Čo máš rád/a?', style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w800, color: colors.onSurface,
          )),
          const SizedBox(height: 6),
          Text('Vyber si kategórie jedál ktoré ťa zaujímajú. Môžeš preskočiť.',
            style: TextStyle(fontSize: 15, color: colors.onSurfaceVariant)),
          const SizedBox(height: 24),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _kPills.map((p) {
                final selected = _selectedTags.contains(p.tag);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) _selectedTags.remove(p.tag);
                    else           _selectedTags.add(p.tag);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color:  selected ? colors.primaryContainer : colors.surfaceContainerHigh,
                      border: Border.all(
                        color:  selected ? colors.primary : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      '${p.emoji}  ${p.labelSk}',
                      style: TextStyle(
                        fontSize:   15,
                        fontWeight: FontWeight.w600,
                        color: selected ? colors.onPrimaryContainer : colors.onSurface,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Screen 2: Favorite restaurants ────────────────────────────────────────

  Widget _buildScreen2(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tvoje obľúbené reštaurácie', style: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w800, color: colors.onSurface,
          )),
          const SizedBox(height: 6),
          Text('Označíme ich srdcom, keď pridajú nové menu.',
            style: TextStyle(fontSize: 15, color: colors.onSurfaceVariant)),
          const SizedBox(height: 16),
          Expanded(
            child: _loadingRestaurants
              ? const Center(child: CircularProgressIndicator())
              : _restaurants.isEmpty
                ? Center(child: Text('Žiadne reštaurácie sa nenašli.',
                    style: TextStyle(color: colors.onSurfaceVariant)))
                : _buildRestaurantList(colors),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantList(ColorScheme colors) {
    // Group by district
    final grouped = <String, List<OnboardingRestaurant>>{};
    for (final r in _restaurants) {
      final key = r.district ?? '';
      grouped.putIfAbsent(key, () => []).add(r);
    }
    final keys = grouped.keys.toList()..sort();

    return ListView.builder(
      itemCount: keys.fold<int>(0, (sum, k) => sum + grouped[k]!.length + (k.isNotEmpty ? 1 : 0)),
      itemBuilder: (_, i) {
        // Flatten with headers
        int cursor = 0;
        for (final key in keys) {
          final items   = grouped[key]!;
          final hasHeader = key.isNotEmpty;
          if (hasHeader) {
            if (i == cursor) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
                child: Text(key.toUpperCase(),
                  style: TextStyle(
                    fontSize:      11,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 1.5,
                    color:         colors.primary,
                  ),
                ),
              );
            }
            cursor++;
          }
          if (i < cursor + items.length) {
            final r        = items[i - cursor];
            final selected = _favSlugs.contains(r.slug);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
              title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: r.address != null
                  ? Text(r.address!, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12))
                  : null,
              trailing: GestureDetector(
                onTap: () => setState(() {
                  if (selected) _favSlugs.remove(r.slug);
                  else           _favSlugs.add(r.slug);
                }),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    selected ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    key:   ValueKey(selected),
                    color: selected ? Colors.redAccent : colors.outline,
                    size:  26,
                  ),
                ),
              ),
            );
          }
          cursor += items.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  // ── Screen 3: Training swipes ──────────────────────────────────────────────

  Widget _buildScreen3(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('Rýchly tréning', style: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w800, color: colors.onSurface,
          )),
          const SizedBox(height: 6),
          Text('Swipni pár jedál — aplikácia sa naučí čo máš rád/a.',
            style: TextStyle(fontSize: 15, color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _loadingTraining
              ? const Center(child: CircularProgressIndicator())
              : _trainingDone || _trainingItems.isEmpty
                ? _buildTrainingDone(colors)
                : _buildTrainingCard(colors),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingDone(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🎉', style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('Hotovo!', style: TextStyle(
            fontSize:   24,
            fontWeight: FontWeight.w800,
            color:      colors.onSurface,
          )),
          const SizedBox(height: 8),
          Text('Aplikácia je pripravená odporúčať ti jedlá.',
            style: TextStyle(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingCard(ColorScheme colors) {
    final item       = _trainingItems[_trainingIndex];
    final remaining  = (5 - _trainingIndex).clamp(0, 5);

    return Column(
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: List.generate(5, (i) => Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i < _trainingIndex ? colors.primary : colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )),
          ),
        ),

        // Card
        Expanded(
          child: Center(
            child: Container(
              width:       double.infinity,
              constraints: const BoxConstraints(maxWidth: 320, maxHeight: 280),
              margin:      const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color:        colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                border:       Border.all(color: colors.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color:  colors.shadow.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.name, style: TextStyle(
                      fontSize:   20,
                      fontWeight: FontWeight.w700,
                      color:      colors.onSurface,
                    ), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(item.restaurantName, style: TextStyle(
                      fontSize: 13, color: colors.onSurfaceVariant,
                    )),
                    if (item.displayPrice.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(item.displayPrice, style: TextStyle(
                        fontSize:   16,
                        fontWeight: FontWeight.w700,
                        color:      colors.primary,
                      )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // Swipe buttons
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dislike
              _TrainingButton(
                icon:    Icons.close_rounded,
                color:   Colors.redAccent,
                size:    64,
                onTap:   () => _trainSwipe('dislike', item),
              ),
              const SizedBox(width: 28),
              // Skip
              _TrainingButton(
                icon:    Icons.skip_next_rounded,
                color:   colors.outline,
                size:    48,
                onTap:   () => _trainSwipe('skip', item),
              ),
              const SizedBox(width: 28),
              // Like
              _TrainingButton(
                icon:    Icons.favorite_rounded,
                color:   colors.primary,
                size:    64,
                onTap:   () => _trainSwipe('like', item),
              ),
            ],
          ),
        ),

        Text('$remaining zostatok', style: TextStyle(
          color: colors.onSurfaceVariant, fontSize: 13,
        )),
      ],
    );
  }
}

class _TrainingButton extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final double   size;
  final VoidCallback onTap;

  const _TrainingButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.4), width: 2),
        ),
        child: Icon(icon, color: color, size: size * 0.42),
      ),
    );
  }
}