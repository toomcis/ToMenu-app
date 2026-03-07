// Represents one dish from the API
class MenuItem {
  final String  type;           // "soup" | "main" | "dessert"
  final String? name;
  final String? description;
  final String? weight;
  final double? priceEur;
  final double? menuPrice;
  final List<int> allergens;
  final Nutrition? nutrition;
  final String? raw;
  // these are added when coming from /api/{city}/menu (not from restaurant detail)
  final String? restaurantName;
  final String? restaurantSlug;
  final bool?   delivery;
  final String? address;
  // which city this came from — set when aggregating multiple cities
  String? citySlug;
  String? cityName;

  MenuItem({
    required this.type,
    this.name,
    this.description,
    this.weight,
    this.priceEur,
    this.menuPrice,
    required this.allergens,
    this.nutrition,
    this.raw,
    this.restaurantName,
    this.restaurantSlug,
    this.delivery,
    this.address,
    this.citySlug,
    this.cityName,
  });

  factory MenuItem.fromJson(Map<String, dynamic> j) {
    List<int> allergens = [];
    if (j['allergens'] != null) {
      allergens = (j['allergens'] as List).map((e) => e as int).toList();
    }
    return MenuItem(
      type:           j['type'] ?? 'main',
      name:           j['name'],
      description:    j['description'],
      weight:         j['weight'],
      priceEur:       (j['price_eur'] as num?)?.toDouble(),
      menuPrice:      (j['menu_price'] as num?)?.toDouble(),
      allergens:      allergens,
      nutrition:      j['nutrition'] != null ? Nutrition.fromJson(j['nutrition']) : null,
      raw:            j['raw'],
      restaurantName: j['restaurant_name'],
      restaurantSlug: j['restaurant_slug'],
      delivery:       j['delivery'] == 1 || j['delivery'] == true,
      address:        j['address'],
    );
  }

  // normalized text for diacritic-insensitive search
  // converts "Rezeň" → "rezen" so searching "rezen" finds it
  String get searchableText {
    final combined = '${name ?? ''} ${description ?? ''} ${restaurantName ?? ''}';
    return _removeDiacritics(combined.toLowerCase());
  }

  static String _removeDiacritics(String input) {
    const from = 'áäčďéěíľĺňóôöšťúůüýžÁÄČĎÉĚÍĽĹŇÓÔÖŠŤÚŮÜÝŽ';
    const to   = 'aacdeeilllnooossttuuuyzAACDEEILLLNOOOSTTUUUYZ';
    var result = input;
    for (var i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result;
  }
}

class Nutrition {
  final double? kcal;
  final double? proteinG;
  final double? fatG;
  final double? carbsG;
  final double? fiberG;

  Nutrition({this.kcal, this.proteinG, this.fatG, this.carbsG, this.fiberG});

  factory Nutrition.fromJson(Map<String, dynamic> j) => Nutrition(
    kcal:     (j['kcal']      as num?)?.toDouble(),
    proteinG: (j['protein_g'] as num?)?.toDouble(),
    fatG:     (j['fat_g']     as num?)?.toDouble(),
    carbsG:   (j['carbs_g']   as num?)?.toDouble(),
    fiberG:   (j['fiber_g']   as num?)?.toDouble(),
  );
}

// Wrapper for the /api/{city}/menu paginated response
class MenuPage {
  final String         date;
  final int            count;
  final int            offset;
  final List<MenuItem> results;

  MenuPage({
    required this.date,
    required this.count,
    required this.offset,
    required this.results,
  });

  factory MenuPage.fromJson(Map<String, dynamic> j) => MenuPage(
    date:    j['date'] ?? '',
    count:   j['count'] ?? 0,
    offset:  j['offset'] ?? 0,
    results: (j['results'] as List? ?? []).map((i) => MenuItem.fromJson(i)).toList(),
  );
}