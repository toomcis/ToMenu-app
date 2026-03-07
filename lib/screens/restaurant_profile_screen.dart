import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/client.dart';
import '../models/city.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../theme/app_theme.dart';
import '../l10n/strings.dart';
import '../widgets/menu_item_detail.dart';
import '../widgets/app_logo.dart';
import '../widgets/day_selector.dart';

class RestaurantProfileScreen extends StatefulWidget {
  final String  restaurantName;
  final String  restaurantSlug;
  final String  citySlug;
  final String  cityName;
  final bool    delivery;
  final String? address;
  final String? initialDate;   // date passed from home screen

  const RestaurantProfileScreen({
    super.key,
    required this.restaurantName,
    required this.restaurantSlug,
    required this.citySlug,
    required this.cityName,
    required this.delivery,
    this.address,
    this.initialDate,
  });

  @override
  State<RestaurantProfileScreen> createState() => _RestaurantProfileScreenState();
}

class _RestaurantProfileScreenState extends State<RestaurantProfileScreen> {
  bool        _loading = true;
  String?     _error;
  Restaurant? _restaurant;
  String?     _filterType;
  List<WeekDay> _weekDays = [];
  late String   _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? _todayIso();
    _loadWeek();
    _load();
  }

  Future<void> _loadWeek() async {
    try {
      final result = await ApiClient.instance.getWeek(widget.citySlug);
      if (mounted) setState(() => _weekDays = result.data);
    } catch (_) {}
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; _filterType = null; });
    try {
      final result = await ApiClient.instance.getRestaurantMenu(
        widget.citySlug, widget.restaurantSlug,
        date: _selectedDate,
      );
      if (mounted) setState(() { _restaurant = result.data; _loading = false; });
      if (result.serverFailed && result.data == null) {
        if (mounted) setState(() { _error = L10n.s.couldNotLoadRestaurant; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  static String _todayIso() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  List<MenuItem> get _filteredItems {
    final items = _restaurant?.menu ?? [];
    if (_filterType == null) return items;
    return items.where((i) => i.type == _filterType).toList();
  }

  int _countType(String type) =>
      (_restaurant?.menu ?? []).where((i) => i.type == type).length;

  // opens the address in the native maps app
  Future<void> _openMaps(String address) async {
    final encoded = Uri.encodeComponent(address);
    // Try geo: first — Android pops up a chooser (Google Maps, Waze, etc.)
    final geoUri = Uri.parse('geo:0,0?q=$encoded');
    try {
      final launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {}
    // Fallback: open Google Maps in the browser / GMaps app
    final webUri = Uri.parse('https://maps.google.com/?q=$encoded');
    try {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // opens the native phone dialer
  Future<void> _callRestaurant() async {
    final phone = _restaurant?.phone;
    if (phone == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.bg1,
        title: Text(L10n.s.callRestaurant, style: TextStyle(color: context.textPrimary)),
        content: Text(phone, style: TextStyle(color: context.textSecondary, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L10n.s.cancel, style: TextStyle(color: context.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(L10n.s.callConfirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final r      = _restaurant;
    final hasPhone = r?.phone != null && r!.phone!.isNotEmpty;

    return Scaffold(
      backgroundColor: context.bgColor,
      // floating call button — only shown if phone number exists
      floatingActionButton: hasPhone
          ? FloatingActionButton.extended(
              onPressed: _callRestaurant,
              backgroundColor: accent,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.call_rounded),
              label: Text(L10n.s.callNow, style: const TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          // ── Header ──
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: context.bg1,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textPrimary, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: context.bg1,
                // center content vertically, with top padding for the app bar
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // logo / avatar — uses AppLogo if asset loads, else letter
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accent.withAlpha(50)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Center(child: AppLogo(size: 36)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(children: [
                            Flexible(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  widget.restaurantName,
                                  style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ),
                            // verified badge — ready for future API support
                            if (r?.info?.contains('verified') ?? false) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.verified_rounded, color: accent, size: 18),
                            ],
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.location_on_rounded, color: context.textSecondary, size: 13),
                            const SizedBox(width: 3),
                            Text(widget.cityName, style: TextStyle(color: context.textSecondary, fontSize: 12)),
                            if (widget.delivery) ...[
                              const SizedBox(width: 10),
                              Text('🛵', style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 3),
                              Text(L10n.s.delivery, style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ]),
                          if (widget.address != null) ...[
                            const SizedBox(height: 2),
                            GestureDetector(
                              onTap: () => _openMaps(widget.address!),
                              child: Row(children: [
                                Icon(Icons.map_outlined, color: context.accentColor, size: 11),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    widget.address!,
                                    style: TextStyle(
                                      color: context.accentColor,
                                      fontSize: 11,
                                      decoration: TextDecoration.underline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]),
                            ),
                          ],
                          if (r?.phone != null) ...[
                            const SizedBox(height: 2),
                            Row(children: [
                              Icon(Icons.phone_rounded, color: context.textSecondary, size: 12),
                              const SizedBox(width: 4),
                              Text(r!.phone!, style: TextStyle(color: context.textSecondary, fontSize: 11)),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottom: (_loading || _error != null) ? null : PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: _TypeFilterBar(
                filterType:   _filterType,
                soupCount:    _countType('soup'),
                mainCount:    _countType('main'),
                dessertCount: _countType('dessert'),
                accent: accent,
                onSelected: (t) => setState(() => _filterType = t),
              ),
            ),
          ),

          // ── Day selector ──
          if (_weekDays.isNotEmpty)
            SliverPersistentHeader(
              pinned: true,
              delegate: _DaySelectorDelegate(
                days: _weekDays,
                selectedDate: _selectedDate,
                onDaySelected: (date) {
                  setState(() => _selectedDate = date);
                  _load();
                },
                accent: accent,
              ),
            ),

          // ── Info strip ──
          if (!_loading && _error == null && r?.info != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.bg1,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.border),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, color: context.textSecondary, size: 15),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r!.info!, style: TextStyle(color: context.textSecondary, fontSize: 12))),
                ]),
              ).animate().fadeIn(duration: 300.ms),
            ),

          // ── Menu items ──
          if (_loading)
            SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2)),
            )
          else if (_error != null)
            SliverFillRemaining(child: _ErrorView(error: _error!, onRetry: _load))
          else if (_filteredItems.isEmpty)
            SliverFillRemaining(
              child: Center(child: Text(L10n.s.noItemsInCategory,
                  style: TextStyle(color: context.textSecondary, fontSize: 14))),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _MenuItemCard(
                  item:       _filteredItems[i],
                  isLast:     i == _filteredItems.length - 1,
                  phone:      r?.phone,
                  onCall:     hasPhone ? _callRestaurant : null,
                ).animate(delay: (i * 30).ms).fadeIn(duration: 250.ms),
                childCount: _filteredItems.length,
              ),
            ),

          // padding so FAB doesn't cover last item
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }
}

// ── Type filter tabs ──────────────────────────────────────────────────────────

class _TypeFilterBar extends StatelessWidget {
  final String?  filterType;
  final int      soupCount;
  final int      mainCount;
  final int      dessertCount;
  final Color    accent;
  final void Function(String?) onSelected;

  const _TypeFilterBar({
    required this.filterType,
    required this.soupCount,
    required this.mainCount,
    required this.dessertCount,
    required this.accent,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.bg1,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _Tab(label: L10n.s.allItems,     count: soupCount + mainCount + dessertCount, selected: filterType == null,      accent: accent,        onTap: () => onSelected(null)),
          const SizedBox(width: 8),
          _Tab(label: L10n.s.soup,    count: soupCount,    selected: filterType == 'soup',    accent: Colors.orange, onTap: () => onSelected('soup')),
          const SizedBox(width: 8),
          _Tab(label: L10n.s.main,    count: mainCount,    selected: filterType == 'main',    accent: accent,        onTap: () => onSelected('main')),
          if (dessertCount > 0) ...[
            const SizedBox(width: 8),
            _Tab(label: L10n.s.dessert, count: dessertCount, selected: filterType == 'dessert', accent: Colors.pink,  onTap: () => onSelected('dessert')),
          ],
        ]),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label; final int count; final bool selected; final Color accent; final VoidCallback onTap;
  const _Tab({required this.label, required this.count, required this.selected, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withAlpha(25) : context.bg2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? accent : context.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(color: selected ? accent : context.textSecondary,
              fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: selected ? accent.withAlpha(40) : context.bg3,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: TextStyle(color: selected ? accent : context.textSecondary,
                fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

// ── Tappable menu item card ───────────────────────────────────────────────────

class _MenuItemCard extends StatelessWidget {
  final MenuItem      item;
  final bool          isLast;
  final String?       phone;
  final VoidCallback? onCall;

  const _MenuItemCard({required this.item, required this.isLast, this.phone, this.onCall});

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
      _         => item.type ?? '',
    };

    return GestureDetector(
      onTap: () => showMenuItemDetail(context, item, phone: phone),
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 6, 16, isLast ? 6 : 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.bg1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48, padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(color: typeColor.withAlpha(20), borderRadius: BorderRadius.circular(6)),
              child: Text(typeLabel, textAlign: TextAlign.center,
                  style: TextStyle(color: typeColor, fontSize: 9, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (item.name != null)
                  Text(item.name!, style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                if (item.description != null && item.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.description!, style: TextStyle(color: context.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ]),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (item.priceEur != null || item.menuPrice != null)
                Text(
                  '${(item.priceEur ?? item.menuPrice)!.toStringAsFixed(2)} €'
                  '${item.priceEur == null ? '*' : ''}',   // asterisk = estimated price
                  style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 4),
              Icon(Icons.chevron_right_rounded, color: context.textSecondary, size: 16),
            ]),
          ],
        ),
      ),
    );
  }

  void _showItemDetail(BuildContext context, Color typeColor, String typeLabel) {
    final accent   = context.accentColor;
    final hasPrice = item.priceEur != null || item.menuPrice != null;
    final isEstimated = hasPrice && item.priceEur == null; // only menuPrice available

    showModalBottomSheet(
      context: context,
      backgroundColor: context.bg1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            // drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: context.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // type badge + name
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(typeLabel, style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 10),

            if (item.name != null)
              Text(item.name!, style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),

            if (item.description != null && item.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.description!, style: TextStyle(color: context.textSecondary, fontSize: 14)),
            ],

            const SizedBox(height: 20),
            Divider(color: context.border),
            const SizedBox(height: 16),

            // ── Details grid ──
            if (hasPrice)
              _DetailRow(
                icon: Icons.euro_rounded,
                label: L10n.s.price,
                value: '${(item.priceEur ?? item.menuPrice)!.toStringAsFixed(2)} €${isEstimated ? ' *' : ''}',
                valueColor: accent,
                // asterisk tap shows popup
                onValueTap: isEstimated ? () => _showPriceDisclaimer(context) : null,
              ),

            if (item.weight != null) ...[
              const SizedBox(height: 12),
              _DetailRow(icon: Icons.monitor_weight_outlined, label: L10n.s.weight, value: item.weight!),
            ],

            if (item.allergens.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber_rounded, color: context.textSecondary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(L10n.s.allergens, style: TextStyle(color: context.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: item.allergens.map((a) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange.withAlpha(60)),
                        ),
                        child: Text('$a', style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
                      )).toList(),
                    ),
                  ]),
                ),
              ]),
            ],

            if (item.nutrition != null && item.nutrition!.kcal != null) ...[
              const SizedBox(height: 12),
              _DetailRow(icon: Icons.local_fire_department_rounded, label: L10n.s.calories,
                  value: '${item.nutrition!.kcal!.toStringAsFixed(0)} kcal'),
              if (item.nutrition!.proteinG != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const SizedBox(width: 28),
                  _NutritionChip(label: L10n.s.protein, value: '${item.nutrition!.proteinG!.toStringAsFixed(0)}g'),
                  const SizedBox(width: 8),
                  if (item.nutrition!.fatG != null)
                    _NutritionChip(label: L10n.s.fat, value: '${item.nutrition!.fatG!.toStringAsFixed(0)}g'),
                  const SizedBox(width: 8),
                  if (item.nutrition!.carbsG != null)
                    _NutritionChip(label: L10n.s.carbs, value: '${item.nutrition!.carbsG!.toStringAsFixed(0)}g'),
                ]),
              ],
            ],

            const SizedBox(height: 24),

            // ── Call button — only if phone number is known ──
            if (onCall != null)
              FilledButton.icon(
                onPressed: onCall,
                icon: const Icon(Icons.call_rounded),
                label: Text(L10n.s.callNow, style: const TextStyle(fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPriceDisclaimer(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.bg1,
        title: Row(children: [
          Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Text(L10n.s.estimatedPrice, style: TextStyle(color: context.textPrimary, fontSize: 16)),
        ]),
        content: Text(
          L10n.s.estimatedPriceNote,
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.s.gotIt),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color?   valueColor;
  final VoidCallback? onValueTap;

  const _DetailRow({required this.icon, required this.label, required this.value, this.valueColor, this.onValueTap});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: context.textSecondary, size: 18),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: context.textSecondary, fontSize: 13)),
      const Spacer(),
      GestureDetector(
        onTap: onValueTap,
        child: Text(
          value,
          style: TextStyle(
            color: valueColor ?? context.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            decoration: onValueTap != null ? TextDecoration.underline : null,
          ),
        ),
      ),
    ]);
  }
}

class _NutritionChip extends StatelessWidget {
  final String label;
  final String value;
  const _NutritionChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.border),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: context.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        Text(label, style: TextStyle(color: context.textSecondary, fontSize: 10)),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error; final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.wifi_off_rounded, size: 48, color: context.textSecondary),
      const SizedBox(height: 16),
      Text(L10n.s.couldNotLoadRestaurant, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(error, style: TextStyle(color: context.textSecondary, fontSize: 12), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      FilledButton(onPressed: onRetry, child: Text(L10n.s.tryAgain)),
    ]),
  ));
}

class _DaySelectorDelegate extends SliverPersistentHeaderDelegate {
  final List<WeekDay> days;
  final String        selectedDate;
  final void Function(String) onDaySelected;
  final Color         accent;

  const _DaySelectorDelegate({
    required this.days,
    required this.selectedDate,
    required this.onDaySelected,
    required this.accent,
  });

  @override double get minExtent => 48;
  @override double get maxExtent => 48;

  @override
  bool shouldRebuild(_DaySelectorDelegate old) =>
      old.selectedDate != selectedDate || old.days.length != days.length;

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