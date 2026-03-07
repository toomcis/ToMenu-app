import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';

class StaleCacheBanner extends StatelessWidget {
  final String?    cacheDate; // e.g. "2025-06-10" — shown in the info dialog
  final VoidCallback? onRetry;

  const StaleCacheBanner({super.key, this.cacheDate, this.onRetry});

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.bg1,
        title: Row(children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Text(
            L10n.s.serverUnreachable,
            style: TextStyle(
              color:      context.textPrimary,
              fontSize:   16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.s.serverUnreachableDetail,
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
            if (cacheDate != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color:        Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(color: Colors.orange.withAlpha(50)),
                ),
                child: Row(children: [
                  const Icon(Icons.history_rounded, color: Colors.orange, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    '${L10n.s.cacheFrom}: $cacheDate',
                    style: const TextStyle(
                      color:      Colors.orange,
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              L10n.s.cacheInvalidNote,
              style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () { Navigator.pop(context); onRetry!(); },
              child: Text(L10n.s.tryAgain, style: TextStyle(color: context.accentColor)),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.s.gotIt),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showInfo(context),
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color:   Colors.orange.withAlpha(230),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              L10n.s.serverUnreachableBanner,
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
        ]),
      ),
    );
  }
}