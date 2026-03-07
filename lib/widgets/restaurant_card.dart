import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';
import '../theme/app_theme.dart';
import '../l10n/strings.dart';

// Card shown on the Home screen for each restaurant.
// Shows name, address, delivery badge, and a preview of menu items.
// Tap to expand full menu.

class RestaurantCard extends StatefulWidget {
  final Restaurant restaurant;
  final String     citySlug;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.citySlug,
  });

  @override
  State<RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends State<RestaurantCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r      = widget.restaurant;
    final accent = context.accentColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color:        context.bg1,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: context.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────────
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // avatar / initial
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color:        accent.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color:      accent,
                          fontWeight: FontWeight.w700,
                          fontSize:   18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // name + address
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: TextStyle(
                            color:      context.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize:   15,
                          ),
                        ),
                        if (r.address != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            r.address!,
                            style: TextStyle(
                              color:    context.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines:  1,
                            overflow:  TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // badges + chevron
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (r.delivery)
                        _Badge(label: '🛵 Delivery', color: accent),
                      const SizedBox(width: 8),
                      if (r.menuPrice != null)
                        _Badge(
                          label: '${r.menuPrice!.toStringAsFixed(2)} €',
                          color: context.textSecondary,
                        ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns:    _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: context.textSecondary,
                          size:  20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded menu ─────────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve:    Curves.easeInOut,
            child: _expanded
                ? Column(
                    children: [
                      Divider(color: context.border, height: 1),
                      ...r.menu.map((item) => _MenuItemRow(item: item)),
                      const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: color.withAlpha(60), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:      color,
          fontSize:   10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final MenuItem item;
  const _MenuItemRow({required this.item});

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // type badge
          Container(
            width:   48,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color:        typeColor.withAlpha(20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              typeLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:      typeColor,
                fontSize:   9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // name + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.name != null)
                  Text(
                    item.name!,
                    style: TextStyle(
                      color:      context.textPrimary,
                      fontSize:   13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (item.description != null && item.description!.isNotEmpty)
                  Text(
                    item.description!,
                    style: TextStyle(color: context.textSecondary, fontSize: 11),
                    maxLines:  2,
                    overflow:  TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // price
          if (item.priceEur != null || item.menuPrice != null) ...[
            const SizedBox(width: 8),
            Text(
              '${(item.priceEur ?? item.menuPrice)!.toStringAsFixed(2)} €',
              style: TextStyle(
                color:      context.textPrimary,
                fontSize:   13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}