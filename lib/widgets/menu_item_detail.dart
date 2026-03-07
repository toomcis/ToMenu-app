import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/menu_item.dart';
import '../theme/app_theme.dart';
import '../l10n/strings.dart';

// Shared bottom sheet for showing full dish details.
// Used from both home_screen and restaurant_profile_screen.

void showMenuItemDetail(BuildContext context, MenuItem item, {String? phone}) {
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

  final hasPrice    = item.priceEur != null || item.menuPrice != null;
  final isEstimated = hasPrice && item.priceEur == null;

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

          // type badge
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(typeLabel,
                  style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),

          if (item.name != null)
            Text(item.name!,
                style: TextStyle(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),

          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item.description!,
                style: TextStyle(color: context.textSecondary, fontSize: 14)),
          ],

          const SizedBox(height: 20),
          Divider(color: context.border),
          const SizedBox(height: 16),

          // price
          if (hasPrice)
            _DetailRow(
              icon: Icons.euro_rounded,
              label: L10n.s.price,
              value: '${(item.priceEur ?? item.menuPrice)!.toStringAsFixed(2)} €${isEstimated ? ' *' : ''}',
              valueColor: accent,
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
                      child: Text('$a',
                          style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
                    )).toList(),
                  ),
                ]),
              ),
            ]),
          ],

          if (item.nutrition != null && item.nutrition!.kcal != null) ...[
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.local_fire_department_rounded,
              label: L10n.s.calories,
              value: '${item.nutrition!.kcal!.toStringAsFixed(0)} kcal',
            ),
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

          // call button — only shown if phone number exists
          if (phone != null && phone.isNotEmpty)
            FilledButton.icon(
              onPressed: () => _callRestaurant(context, phone),
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

Future<void> _callRestaurant(BuildContext context, String phone) async {
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

void _showPriceDisclaimer(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: context.bg1,
      title: Row(children: [
        const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
        const SizedBox(width: 8),
        Text(L10n.s.estimatedPrice, style: TextStyle(color: context.textPrimary, fontSize: 16)),
      ]),
      content: Text(
        L10n.s.estimatedPriceNote,
        style: TextStyle(color: context.textSecondary, fontSize: 13),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(L10n.s.gotIt)),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final String        value;
  final Color?        valueColor;
  final VoidCallback? onValueTap;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.onValueTap,
  });

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