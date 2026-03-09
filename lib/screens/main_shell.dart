import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'list_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import 'fyp_feed_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static MainShellState of(BuildContext context) {
    return context.findAncestorStateOfType<MainShellState>()!;
  }

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int  _currentIndex = 0;
  bool _hideBottomBar = false;

  void hideBottomBar()          => setState(() => _hideBottomBar = true);
  void showBottomBar()          => setState(() => _hideBottomBar = false);
  void navigateTo(int index)    => setState(() => _currentIndex = index);

  final List<Widget> _screens = const [
    FypFeedScreen(),
    ListScreen(),
    SearchScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _hideBottomBar ? null : _BottomBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        accent: accent,
      ).animate().slideY(
        begin: 1, end: 0,
        duration: 300.ms,
        curve: Curves.easeOut,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int    currentIndex;
  final void Function(int) onTap;
  final Color  accent;

  const _BottomBar({
    required this.currentIndex,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF111111) : Colors.white;
    final border = isDark ? const Color(0xFF242424) : const Color(0xFFE0E0E0);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 1)),
        boxShadow: [
          BoxShadow(
            color:     Colors.black.withAlpha(isDark ? 60 : 20),
            blurRadius: 20,
            offset:    const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded,   label: 'Home',    selected: currentIndex == 0, accent: accent, onTap: () => onTap(0)),
              _NavItem(icon: Icons.list_rounded,   label: 'List',    selected: currentIndex == 1, accent: accent, onTap: () => onTap(1)),
              _NavItem(icon: Icons.search_rounded,  label: 'Search',  selected: currentIndex == 2, accent: accent, onTap: () => onTap(2)),
              _NavItem(icon: Icons.person_rounded,  label: 'Profile', selected: currentIndex == 3, accent: accent, onTap: () => onTap(3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         selected;
  final Color        accent;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final inactive = isDark ? const Color(0xFF888888) : const Color(0xFF999999);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? accent : inactive, size: 24),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize:   10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color:      selected ? accent : inactive,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}