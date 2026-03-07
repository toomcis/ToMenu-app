// models/city.dart

// Represents a city returned by /api/cities
class City {
  final int    id;
  final String name;
  final String slug;
  final String url;
  // distance in km from user's location — set after GPS lookup
  double? distanceKm;

  City({
    required this.id,
    required this.name,
    required this.slug,
    required this.url,
    this.distanceKm,
  });

  factory City.fromJson(Map<String, dynamic> j) => City(
    id:   j['id'],
    name: j['name'],
    slug: j['slug'],
    url:  j['url'],
  );
}

// Represents one day in the /api/{city}/week response
class WeekDay {
  final String date;      // YYYY-MM-DD
  final bool   hasData;
  final int    itemCount;

  WeekDay({required this.date, required this.hasData, required this.itemCount});

  factory WeekDay.fromJson(Map<String, dynamic> j) => WeekDay(
    date:      j['date'],
    hasData:   j['has_data'] ?? false,
    itemCount: j['item_count'] ?? 0,
  );

  // returns e.g. "Mon", "Tue" from the date string
  String get dayLabel {
    final d = DateTime.parse(date);
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[d.weekday - 1];
  }

  // returns e.g. "03/06"
  String get shortDate {
    final parts = date.split('-');
    return '${parts[1]}/${parts[2]}';
  }

  bool get isToday {
    final today = DateTime.now();
    final d     = DateTime.parse(date);
    return d.year == today.year && d.month == today.month && d.day == today.day;
  }
}