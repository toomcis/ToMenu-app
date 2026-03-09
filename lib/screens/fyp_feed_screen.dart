import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/fyp_service.dart';
import '../theme/app_theme.dart';

// ── Day selector data ─────────────────────────────────────────────────────────

class _DayEntry {
  final String label;   // 'Dnes', 'Pon', 'Ut', …
  final String date;    // 'YYYY-MM-DD'
  const _DayEntry(this.label, this.date);
}

List<_DayEntry> _buildWeekDays() {
  final now    = DateTime.now();
  final today  = DateTime(now.year, now.month, now.day);
  final labels = ['Dnes', 'Ut', 'St', 'Št', 'Pi', 'So', 'Ne', 'Pon'];
  final result = <_DayEntry>[];

  for (int i = 0; i < 7; i++) {
    final d       = today.add(Duration(days: i));
    final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    String label;
    if (i == 0) {
      label = 'Dnes';
    } else {
      const dayNames = ['Pon', 'Ut', 'St', 'Št', 'Pi', 'So', 'Ne'];
      label = dayNames[d.weekday - 1];
    }
    result.add(_DayEntry(label, dateStr));
  }
  return result;
}

// ── Feed Screen ───────────────────────────────────────────────────────────────

class FypFeedScreen extends StatefulWidget {
  const FypFeedScreen({super.key});

  @override
  State<FypFeedScreen> createState() => _FypFeedScreenState();
}

class _FypFeedScreenState extends State<FypFeedScreen> with TickerProviderStateMixin {
  final _days = _buildWeekDays();
  int _selectedDayIndex = 0;

  List<FeedItem> _deck       = [];
  List<FeedItem> _undoStack  = [];     // last swiped items for undo
  bool _loading   = true;
  bool _exhausted = false;             // true = no more items for this day

  // Drag state for top card
  double _dragX     = 0;
  double _dragY     = 0;
  bool   _dragging  = false;
  late AnimationController _snapController;
  late Animation<double>   _snapAnim;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 380),
    );
    _loadFeed();
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    if (!mounted) return;
    setState(() { _loading = true; _exhausted = false; });

    final date   = _days[_selectedDayIndex].date;
    final result = await FypService.instance.getFeed(date: date, limit: 20);

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.items.isEmpty) {
        _exhausted = true;
        _deck = [];
      } else {
        _exhausted = false;
        _deck = List.from(result.items);
      }
      _undoStack.clear();
    });
  }

  void _selectDay(int index) {
    if (_selectedDayIndex == index) return;
    setState(() => _selectedDayIndex = index);
    _loadFeed();
  }

  // ── Swipe logic ───────────────────────────────────────────────────────────

  void _doSwipe(String direction) {
    if (_deck.isEmpty) return;
    HapticFeedback.lightImpact();

    final item = _deck.first;
    FypService.instance.swipe(
      itemName:       item.name,
      restaurantSlug: item.restaurantSlug,
      citySlug:       item.citySlug,
      direction:      direction,
      tags:           item.tags,
    );

    _undoStack.add(item);
    if (_undoStack.length > 5) _undoStack.removeAt(0);

    setState(() {
      _deck.removeAt(0);
      _dragX    = 0;
      _dragY    = 0;
      _dragging = false;
      if (_deck.isEmpty) _exhausted = true;
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    HapticFeedback.mediumImpact();
    final item = _undoStack.removeLast();
    setState(() {
      _deck.insert(0, item);
      _exhausted = false;
    });
  }

  void _openOrder(FeedItem item) {
    // Navigate to restaurant page with item pre-selected
    // Matches the pattern used by the List screen
    Navigator.of(context).pushNamed(
      '/restaurant',
      arguments: {
        'city_slug':       item.citySlug,
        'restaurant_slug': item.restaurantSlug,
        'highlight_dish':  item.name,
      },
    );
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
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              color: colors.surface,
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ToMenu', style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: -0.5,
                      )),
                      Text('Čo dnes zješ? 🍽️', style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      )),
                    ],
                  ),
                ],
              ),
            ),
            _buildDaySelector(colors),
            Expanded(child: _buildBody(colors)),
          ],
        ),
      ),
    );
  }

  // ── Day selector ─────────────────────────────────────────────────────────

  Widget _buildDaySelector(ColorScheme colors) {
    return Container(
      height:      56,
      padding:     const EdgeInsets.symmetric(horizontal: 12),
      decoration:  BoxDecoration(
        color:  colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount:       _days.length,
        itemBuilder: (_, i) {
          final selected = i == _selectedDayIndex;
          final day      = _days[i];
          return GestureDetector(
            onTap: () => _selectDay(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin:   const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              padding:  const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected
                  ? (_exhausted ? colors.errorContainer : colors.primaryContainer)
                  : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: selected
                  ? Border.all(
                      color: _exhausted ? colors.error : colors.primary,
                      width: 1.5,
                    )
                  : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(day.label, style: TextStyle(
                    fontSize:   13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                      ? (_exhausted ? colors.onErrorContainer : colors.onPrimaryContainer)
                      : colors.onSurfaceVariant,
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody(ColorScheme colors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_exhausted) {
      return _buildEmptyState(colors);
    }
    return _buildCardStack(colors);
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🍽️', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Prehľadal/a si všetko!',
              style: TextStyle(
                fontSize:   22,
                fontWeight: FontWeight.w800,
                color:      colors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pre tento deň nie sú ďalšie jedlá.\nSkús iný deň pomocou výberu dní hore.',
              style: TextStyle(fontSize: 15, color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loadFeed,
              icon:  const Icon(Icons.refresh_rounded),
              label: const Text('Skúsiť znova'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card stack ────────────────────────────────────────────────────────────

  Widget _buildCardStack(ColorScheme colors) {
    final topItem = _deck.isNotEmpty ? _deck.first : null;

    return Column(
      children: [
        // Stack area
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background cards (static, slightly offset)
              for (int i = math.min(_deck.length - 1, 2); i >= 1; i--)
                _buildBackCard(colors, i),

              // Top draggable card
              if (topItem != null)
                _buildTopCard(colors, topItem),
            ],
          ),
        ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 20),
          child: _buildActionRow(colors, topItem),
        ),
      ],
    );
  }

  Widget _buildBackCard(ColorScheme colors, int depth) {
    if (_deck.length <= depth) return const SizedBox.shrink();
    final scale   = 1.0 - depth * 0.04;
    final offsetY = depth * 12.0;

    return Transform(
      transform: Matrix4.identity()
        ..translate(0.0, offsetY)
        ..scale(scale),
      alignment: Alignment.topCenter,
      child: _CardShell(
        colors: colors,
        item:   _deck[depth],
        dragX:  0,
        dragY:  0,
        isTop:  false,
        onOrder: () {},
      ),
    );
  }

  Widget _buildTopCard(ColorScheme colors, FeedItem item) {
    return GestureDetector(
      onPanStart: (_) {
        setState(() => _dragging = true);
        _snapController.stop();
      },
      onPanUpdate: (d) {
        setState(() {
          _dragX += d.delta.dx;
          _dragY += d.delta.dy;
        });
      },
      onPanEnd: (_) {
        _dragging = false;
        final vx = _.velocity.pixelsPerSecond.dx;
        final vy = _.velocity.pixelsPerSecond.dy;

        // Up swipe = skip (scroll upward)
        if (_dragY < -80 || vy < -600) {
          _doSwipe('skip');
          return;
        }
        // Down swipe = undo
        if (_dragY > 80 || vy > 600) {
          _undo();
          setState(() { _dragX = 0; _dragY = 0; });
          return;
        }
        // Horizontal swipes
        if (_dragX > 80 || vx > 500) {
          _doSwipe('like');
          return;
        }
        if (_dragX < -80 || vx < -500) {
          _doSwipe('dislike');
          return;
        }

        // Snap back
        final startX = _dragX;
        final startY = _dragY;
        _snapController.reset();
        _snapAnim = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: _snapController, curve: Curves.elasticOut),
        )..addListener(() {
          final t = _snapAnim.value;
          setState(() {
            _dragX = startX * (1 - t);
            _dragY = startY * (1 - t);
          });
        });
        _snapController.forward();
      },
      child: _CardShell(
        colors: colors,
        item:   item,
        dragX:  _dragX,
        dragY:  _dragY,
        isTop:  true,
        onOrder: () => _openOrder(item),
      ),
    );
  }

  Widget _buildActionRow(ColorScheme colors, FeedItem? item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Dislike
        _ActionButton(
          icon:    Icons.close_rounded,
          color:   Colors.redAccent,
          size:    64,
          onTap:   item != null ? () => _doSwipe('dislike') : null,
        ),
        const SizedBox(width: 16),

        // Undo
        _ActionButton(
          icon:    Icons.undo_rounded,
          color:   colors.onSurfaceVariant,
          size:    44,
          onTap:   _undoStack.isNotEmpty ? _undo : null,
        ),
        const SizedBox(width: 16),

        // Like
        _ActionButton(
          icon:    Icons.favorite_rounded,
          color:   colors.primary,
          size:    64,
          onTap:   item != null ? () => _doSwipe('like') : null,
        ),
      ],
    );
  }
}

// ── Card shell ────────────────────────────────────────────────────────────────

class _CardShell extends StatelessWidget {
  final ColorScheme colors;
  final FeedItem    item;
  final double      dragX;
  final double      dragY;
  final bool        isTop;
  final VoidCallback onOrder;

  const _CardShell({
    required this.colors,
    required this.item,
    required this.dragX,
    required this.dragY,
    required this.isTop,
    required this.onOrder,
  });

  @override
  Widget build(BuildContext context) {
    final rotation = isTop ? (dragX * 0.0012) : 0.0;
    final likeOp   = isTop ? (dragX /  80).clamp(0.0, 1.0) : 0.0;
    final nopeOp   = isTop ? (-dragX / 80).clamp(0.0, 1.0) : 0.0;

    return Transform(
      transform: Matrix4.identity()
        ..translate(dragX, dragY * 0.25)
        ..rotateZ(rotation),
      alignment: Alignment.center,
      child: Container(
        width:       310,
        height:      240,
        decoration: BoxDecoration(
          color:        colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border:       Border.all(color: colors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color:  colors.shadow.withOpacity(0.1),
              blurRadius:  24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Like/Nope badges
                  if (isTop) Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Opacity(opacity: nopeOp, child: _Badge(label: 'NIE', color: Colors.redAccent, angle: -0.2)),
                      Opacity(opacity: likeOp, child: _Badge(label: 'CHCEM', color: colors.primary, angle: 0.2)),
                    ],
                  ),

                  const Spacer(),

                  // Dish name
                  Text(item.name, style: TextStyle(
                    fontSize:   20,
                    fontWeight: FontWeight.w700,
                    color:      colors.onSurface,
                    height:     1.2,
                  ), maxLines: 2, overflow: TextOverflow.ellipsis),

                  const SizedBox(height: 4),

                  // Restaurant
                  Text(item.restaurantName, style: TextStyle(
                    fontSize: 13, color: colors.onSurfaceVariant,
                  ), maxLines: 1, overflow: TextOverflow.ellipsis),

                  const SizedBox(height: 12),

                  // Price + ORDER button
                  Row(
                    children: [
                      if (item.displayPrice.isNotEmpty)
                        Text(item.displayPrice, style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: colors.primary,
                        )),
                      const Spacer(),
                      if (isTop)
                        FilledButton(
                          onPressed: onOrder,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            padding:         const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                            minimumSize:     const Size(0, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('OBJEDNAŤ', style: TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          )),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  final double angle;

  const _Badge({required this.label, required this.color, required this.angle});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: color, width: 2),
        ),
        child: Text(label, style: TextStyle(
          color:         color,
          fontWeight:    FontWeight.w800,
          fontSize:      13,
          letterSpacing: 1.5,
        )),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData    icon;
  final Color       color;
  final double      size;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: Container(
          width:  size,
          height: size,
          decoration: BoxDecoration(
            shape:  BoxShape.circle,
            color:  color.withOpacity(0.1),
            border: Border.all(color: color.withOpacity(0.4), width: 2),
          ),
          child: Icon(icon, color: color, size: size * 0.42),
        ),
      ),
    );
  }
}