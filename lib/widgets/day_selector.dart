import 'package:flutter/material.dart';
import '../models/city.dart';
import '../theme/app_theme.dart';
import '../l10n/strings.dart';

extension _IterableX<T> on List<T> {
  List<R> mapIndexed<R>(R Function(int i, T e) fn) {
    final result = <R>[];
    for (var i = 0; i < length; i++) result.add(fn(i, this[i]));
    return result;
  }
}

/// Horizontal scrollable day tabs shown at the top of Home / Restaurant profile screens.
/// Shows Mon–Sun with a dot indicator if today, greyed out if no data.
class DaySelector extends StatelessWidget {
  final List<WeekDay> days;
  final String        selectedDate;
  final void Function(String date) onDaySelected;
  final Color         accent;

  const DaySelector({
    super.key,
    required this.days,
    required this.selectedDate,
    required this.onDaySelected,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox(height: 48);
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: days.mapIndexed((i, day) {
            final selected = day.date == selectedDate;
            final label    = _dayLabel(day);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left:  i == 0              ? 0 : 3,
                  right: i == days.length - 1 ? 0 : 3,
                ),
                child: GestureDetector(
                  onTap: () => onDaySelected(day.date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: selected ? accent : context.bg2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? accent : context.border,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color:      selected ? Colors.black : context.textSecondary,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                            fontSize:   12,
                          ),
                        ),
                        if (day.isToday) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 5, height: 5,
                            decoration: BoxDecoration(
                              color: selected ? Colors.black54 : accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _dayLabel(WeekDay day) {
    final weekday = DateTime.parse(day.date).weekday; // 1=Mon … 7=Sun
    final s = L10n.s;
    return switch (weekday) {
      1 => s.mon,
      2 => s.tue,
      3 => s.wed,
      4 => s.thu,
      5 => s.fri,
      6 => s.sat,
      _ => s.sun,
    };
  }
}