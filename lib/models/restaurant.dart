import 'menu_item.dart';

// Represents a restaurant with its menu items

class Restaurant {
  final int     id;
  final String  name;
  final String  slug;
  final String? address;
  final String? phone;
  final bool    delivery;
  final String? info;
  final int?    itemCount;
  final double? menuPrice;
  final List<MenuItem> menu;

  // city info — set when loaded
  String? citySlug;
  String? cityName;

  Restaurant({
    required this.id,
    required this.name,
    required this.slug,
    this.address,
    this.phone,
    required this.delivery,
    this.info,
    this.itemCount,
    this.menuPrice,
    required this.menu,
    this.citySlug,
    this.cityName,
  });

  factory Restaurant.fromJson(Map<String, dynamic> j) => Restaurant(
    id:        j['id'],
    name:      j['name'] ?? '',
    slug:      j['slug'] ?? '',
    address:   j['address'],
    phone:     j['phone'],
    delivery:  j['delivery'] == 1 || j['delivery'] == true,
    info:      j['info'],
    itemCount: j['item_count'],
    menuPrice: (j['menu_price'] as num?)?.toDouble(),
    menu: (j['menu'] as List? ?? []).map((i) => MenuItem.fromJson(i)).toList(),
  );

  // normalized for search
  String get searchableText {
    return name.toLowerCase().replaceAll(_diacriticPattern, '');
  }

  static final _diacriticPattern = RegExp('[áäčďéěíľĺňóôöšťúůüýž]');
}