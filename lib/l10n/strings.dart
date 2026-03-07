// All UI strings in one place.
// Adding a new language = add a new _Strings subclass at the bottom.
// Adding a new string = add to AppStrings abstract class + all subclasses.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Supported languages ───────────────────────────────────────────────────────

enum AppLanguage {
  system,   // follow phone language
  en,
  sk,
  cs;

  String get label => switch (this) {
    AppLanguage.system => 'System default',
    AppLanguage.en     => 'English',
    AppLanguage.sk     => 'Slovenčina',
    AppLanguage.cs     => 'Čeština',
  };

  String get code => switch (this) {
    AppLanguage.system => 'system',
    AppLanguage.en     => 'en',
    AppLanguage.sk     => 'sk',
    AppLanguage.cs     => 'cs',
  };

  static AppLanguage fromCode(String code) => switch (code) {
    'en'     => AppLanguage.en,
    'sk'     => AppLanguage.sk,
    'cs'     => AppLanguage.cs,
    _        => AppLanguage.system,
  };
}

// ── Abstract base ─────────────────────────────────────────────────────────────

abstract class AppStrings {
  // App
  String get appName;

  // Greetings
  String get greetingMorning;
  String get greetingLunch;
  String get greetingAfternoon;
  String get greetingEvening;

  // Home screen
  String get loadingMenus;
  String get noMenusForDay;
  String get tryDifferentDay;
  String get couldNotLoadMenus;
  String get tryAgain;
  String get kmAway;
  String get dishes;

  // Day labels
  String get mon;
  String get tue;
  String get wed;
  String get thu;
  String get fri;
  String get sat;
  String get sun;

  // Search screen
  String get searchHint;
  String get searchLoading;
  String get searchReady;
  String get searchAcrossAllCities;
  String get searchTip;
  String get noResults;
  String get tryDifferentSpelling;
  String dishCount(int dishes, int restaurants);

  // Restaurant profile
  String get delivery;
  String get allItems;
  String get soup;
  String get main;
  String get dessert;
  String get couldNotLoadRestaurant;
  String get noItemsInCategory;

  // Menu item detail
  String get price;
  String get weight;
  String get allergens;
  String get calories;
  String get protein;
  String get fat;
  String get carbs;
  String get callNow;
  String get callRestaurant;
  String get callConfirm;
  String get cancel;
  String get estimatedPrice;
  String get estimatedPriceNote;
  String get gotIt;

  // Profile screen
  String get profile;
  String get nickname;
  String get nicknamePlaceholder;
  String get nicknameHint;
  String get appSettings;
  String get version;

  // Settings screen
  String get settings;
  String get appearance;
  String get darkMode;
  String get accentColor;
  String get customColor;
  String get notifications;
  String get dailyReminder;
  String get dailyReminderOn;
  String get dailyReminderOff;
  String get advanced;
  String get apiUrl;
  String get apiUrlWarning;
  String get resetToDefault;
  String get language;
  String get tagline;

  // Cache / offline
  String get serverUnreachable;
  String get serverUnreachableBanner;
  String get serverUnreachableDetail;
  String get cacheFrom;
  String get cacheInvalidNote;
  String get cacheSettings;
  String get cacheEnabled;
  String get cacheCities;
  String get cacheMenus;
  String get cacheRestaurants;
  String get cacheWeek;
  String get cacheClearAll;
  String get cacheClearMenus;
  String get cacheSize;
  String get cacheCleared;
}

// ── Resolver ──────────────────────────────────────────────────────────────────

class L10n {
  static AppStrings _current = _EnStrings();

  static AppStrings get s => _current;

  static Future<void> init(BuildContext context) async {
    final prefs    = await SharedPreferences.getInstance();
    final saved    = prefs.getString('language') ?? 'system';
    final language = AppLanguage.fromCode(saved);
    _current = _resolve(language, context);
  }

  static Future<void> setLanguage(AppLanguage language, BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language.code);
    _current = _resolve(language, context);
  }

  static Future<AppLanguage> getSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return AppLanguage.fromCode(prefs.getString('language') ?? 'system');
  }

  static AppStrings _resolve(AppLanguage language, BuildContext context) {
    final lang = language == AppLanguage.system
        ? _detectSystemLanguage(context)
        : language;

    return switch (lang) {
      AppLanguage.sk => _SkStrings(),
      AppLanguage.cs => _CsStrings(),
      _              => _EnStrings(),
    };
  }

  static AppLanguage _detectSystemLanguage(BuildContext context) {
    try {
      final locale = View.of(context).platformDispatcher.locale;
      final code   = locale.languageCode;
      if (code == 'sk') return AppLanguage.sk;
      if (code == 'cs') return AppLanguage.cs;
    } catch (_) {}
    return AppLanguage.en;
  }
}

// ── English ───────────────────────────────────────────────────────────────────

class _EnStrings extends AppStrings {
  @override String get appName              => 'Namenu+';
  @override String get greetingMorning      => 'Good morning';
  @override String get greetingLunch        => 'Lunch time?';
  @override String get greetingAfternoon    => 'Good afternoon';
  @override String get greetingEvening      => 'Good evening';
  @override String get loadingMenus         => 'Loading menus...';
  @override String get noMenusForDay        => 'No menus for this day';
  @override String get tryDifferentDay      => 'Try a different day above';
  @override String get couldNotLoadMenus    => 'Could not load menus';
  @override String get tryAgain             => 'Try again';
  @override String get kmAway              => 'km away';
  @override String get dishes              => 'dishes';
  @override String get mon => 'Mon';
  @override String get tue => 'Tue';
  @override String get wed => 'Wed';
  @override String get thu => 'Thu';
  @override String get fri => 'Fri';
  @override String get sat => 'Sat';
  @override String get sun => 'Sun';
  @override String get searchHint           => 'Search dishes or restaurants...';
  @override String get searchLoading        => 'Loading menus...';
  @override String get searchReady          => 'Search will be ready in a moment';
  @override String get searchAcrossAllCities => 'Search across all cities';
  @override String get searchTip            => 'Try "rezeň", "pizza", or a restaurant name';
  @override String get noResults            => 'No matches found';
  @override String get tryDifferentSpelling => 'Try a different spelling';
  @override String dishCount(int d, int r)  => '$d dishes in $r restaurants';
  @override String get delivery             => 'Delivery';
  @override String get allItems             => 'All';
  @override String get soup                 => 'Soup';
  @override String get main                 => 'Main';
  @override String get dessert              => 'Dessert';
  @override String get couldNotLoadRestaurant => 'Could not load restaurant';
  @override String get noItemsInCategory    => 'No items in this category';
  @override String get price                => 'Price';
  @override String get weight               => 'Weight';
  @override String get allergens            => 'Allergens';
  @override String get calories             => 'Calories';
  @override String get protein              => 'Protein';
  @override String get fat                  => 'Fat';
  @override String get carbs                => 'Carbs';
  @override String get callNow              => 'Call now';
  @override String get callRestaurant       => 'Call restaurant?';
  @override String get callConfirm          => 'Call';
  @override String get cancel               => 'Cancel';
  @override String get estimatedPrice       => 'Estimated price';
  @override String get estimatedPriceNote   => 'This restaurant doesn\'t have prices officially stated. Please check their social media or official website before ordering!';
  @override String get gotIt                => 'Got it';
  @override String get profile              => 'Profile';
  @override String get nickname             => 'Nickname';
  @override String get nicknamePlaceholder  => 'e.g. Jano, Zuzka...';
  @override String get nicknameHint         => 'Used for personalized greetings. Future versions may use this for notifications.';
  @override String get appSettings          => 'App Settings';
  @override String get version              => 'namenu+ v1.0.0';
  @override String get settings             => 'Settings';
  @override String get appearance           => 'Appearance';
  @override String get darkMode             => 'Dark mode';
  @override String get accentColor          => 'Accent color';
  @override String get customColor          => 'Custom color';
  @override String get notifications        => 'Notifications';
  @override String get dailyReminder        => 'Daily lunch reminder';
  @override String get dailyReminderOn      => 'You\'ll get a reminder at 10:30 AM every day to check today\'s menus.';
  @override String get dailyReminderOff     => 'Opt in to get a daily nudge at 10:30 AM.';
  @override String get advanced             => 'Advanced';
  @override String get apiUrl               => 'API URL';
  @override String get apiUrlWarning        => 'Changing this may break the app.';
  @override String get resetToDefault       => 'Reset to default';
  @override String get language             => 'Language';
  @override String get tagline              => 'namenu+ — lunch menus, simplified.';
  @override String get serverUnreachable        => 'Server unreachable';
  @override String get serverUnreachableBanner  => 'Server could not be reached! Showing cached data.';
  @override String get serverUnreachableDetail  => 'Could not connect to the namenu+ server. The data shown may not be up to date.';
  @override String get cacheFrom                => 'Cached on';
  @override String get cacheInvalidNote         => 'Cache has been flagged as invalid (not up to date). Pull to refresh when the server is back online.';
  @override String get cacheSettings            => 'Cache & Offline';
  @override String get cacheEnabled             => 'Enable caching';
  @override String get cacheCities              => 'Cache city list';
  @override String get cacheMenus               => 'Cache menus';
  @override String get cacheRestaurants         => 'Cache restaurant profiles';
  @override String get cacheWeek                => 'Cache week availability';
  @override String get cacheClearAll            => 'Clear all cache';
  @override String get cacheClearMenus          => 'Clear menu cache';
  @override String get cacheSize                => 'Cache size';
  @override String get cacheCleared             => 'Cache cleared';
}

// ── Slovak ────────────────────────────────────────────────────────────────────

class _SkStrings extends AppStrings {
  @override String get appName              => 'Namenu+';
  @override String get greetingMorning      => 'Dobré ráno';
  @override String get greetingLunch        => 'Čas na obed?';
  @override String get greetingAfternoon    => 'Dobré poludnie';
  @override String get greetingEvening      => 'Dobrý večer';
  @override String get loadingMenus         => 'Načítavam jedálne lístky...';
  @override String get noMenusForDay        => 'Pre tento deň nie sú k dispozícii ponuky';
  @override String get tryDifferentDay      => 'Skús iný deň vyššie';
  @override String get couldNotLoadMenus    => 'Nepodarilo sa načítať jedálne lístky';
  @override String get tryAgain             => 'Skúsiť znova';
  @override String get kmAway              => 'km odtiaľto';
  @override String get dishes              => 'jedál';
  @override String get mon => 'Pon';
  @override String get tue => 'Uto';
  @override String get wed => 'Str';
  @override String get thu => 'Štv';
  @override String get fri => 'Pia';
  @override String get sat => 'Sob';
  @override String get sun => 'Ned';
  @override String get searchHint           => 'Hľadaj jedlá alebo reštaurácie...';
  @override String get searchLoading        => 'Načítavam ponuky...';
  @override String get searchReady          => 'Vyhľadávanie bude za chvíľu pripravené';
  @override String get searchAcrossAllCities => 'Prehľadaj všetky mestá';
  @override String get searchTip            => 'Skús "rezeň", "pizza" alebo názov reštaurácie';
  @override String get noResults            => 'Žiadne výsledky';
  @override String get tryDifferentSpelling => 'Skús iný pravopis';
  @override String dishCount(int d, int r)  => '$d jedál v $r reštauráciách';
  @override String get delivery             => 'Donáška';
  @override String get allItems             => 'Všetko';
  @override String get soup                 => 'Polievka';
  @override String get main                 => 'Hlavné';
  @override String get dessert              => 'Dezert';
  @override String get couldNotLoadRestaurant => 'Nepodarilo sa načítať reštauráciu';
  @override String get noItemsInCategory    => 'V tejto kategórii nie sú žiadne položky';
  @override String get price                => 'Cena';
  @override String get weight               => 'Hmotnosť';
  @override String get allergens            => 'Alergény';
  @override String get calories             => 'Kalórie';
  @override String get protein              => 'Bielkoviny';
  @override String get fat                  => 'Tuky';
  @override String get carbs                => 'Sacharidy';
  @override String get callNow              => 'Zavolať';
  @override String get callRestaurant       => 'Zavolať do reštaurácie?';
  @override String get callConfirm          => 'Zavolať';
  @override String get cancel               => 'Zrušiť';
  @override String get estimatedPrice       => 'Odhadovaná cena';
  @override String get estimatedPriceNote   => 'Táto reštaurácia nemá oficiálne uvedené ceny. Pred objednávkou si skontroluj ich sociálne siete alebo oficiálnu webstránku!';
  @override String get gotIt                => 'Rozumiem';
  @override String get profile              => 'Profil';
  @override String get nickname             => 'Prezývka';
  @override String get nicknamePlaceholder  => 'napr. Jano, Zuzka...';
  @override String get nicknameHint         => 'Používa sa na personalizované pozdravy. V budúcich verziách môže byť použité na notifikácie.';
  @override String get appSettings          => 'Nastavenia aplikácie';
  @override String get version              => 'namenu+ v1.0.0';
  @override String get settings             => 'Nastavenia';
  @override String get appearance           => 'Vzhľad';
  @override String get darkMode             => 'Tmavý režim';
  @override String get accentColor          => 'Farba zvýraznenia';
  @override String get customColor          => 'Vlastná farba';
  @override String get notifications        => 'Notifikácie';
  @override String get dailyReminder        => 'Denná pripomienka obeda';
  @override String get dailyReminderOn      => 'Každý deň o 10:30 dostaneš pripomienku pozrieť si dnešné menu.';
  @override String get dailyReminderOff     => 'Zapni si dennú pripomienku o 10:30.';
  @override String get advanced             => 'Pokročilé';
  @override String get apiUrl               => 'URL adresa API';
  @override String get apiUrlWarning        => 'Zmena tejto hodnoty môže spôsobiť nefunkčnosť aplikácie.';
  @override String get resetToDefault       => 'Obnoviť predvolené';
  @override String get language             => 'Jazyk';
  @override String get tagline              => 'namenu+ — obedové menu, jednoducho.';
  @override String get serverUnreachable        => 'Server nedostupný';
  @override String get serverUnreachableBanner  => 'Server je nedostupný! Zobrazujú sa uložené dáta.';
  @override String get serverUnreachableDetail  => 'Nepodarilo sa pripojiť na server namenu+. Zobrazené dáta nemusia byť aktuálne.';
  @override String get cacheFrom                => 'Uložené';
  @override String get cacheInvalidNote         => 'Vyrovnávacia pamäť je neaktuálna. Po obnovení servera potiahnite nadol na aktualizáciu.';
  @override String get cacheSettings            => 'Vyrovnávacia pamäť';
  @override String get cacheEnabled             => 'Povoliť cache';
  @override String get cacheCities              => 'Cache zoznam miest';
  @override String get cacheMenus               => 'Cache jedálne lístky';
  @override String get cacheRestaurants         => 'Cache profily reštaurácií';
  @override String get cacheWeek                => 'Cache dostupnosť týždňa';
  @override String get cacheClearAll            => 'Vymazať všetko';
  @override String get cacheClearMenus          => 'Vymazať cache menu';
  @override String get cacheSize                => 'Veľkosť cache';
  @override String get cacheCleared             => 'Cache vymazaná';
}

// ── Czech ─────────────────────────────────────────────────────────────────────

class _CsStrings extends AppStrings {
  @override String get appName              => 'Namenu+';
  @override String get greetingMorning      => 'Dobré ráno';
  @override String get greetingLunch        => 'Čas na oběd?';
  @override String get greetingAfternoon    => 'Dobré odpoledne';
  @override String get greetingEvening      => 'Dobrý večer';
  @override String get loadingMenus         => 'Načítám jídelní lístky...';
  @override String get noMenusForDay        => 'Pro tento den nejsou k dispozici nabídky';
  @override String get tryDifferentDay      => 'Zkus jiný den výše';
  @override String get couldNotLoadMenus    => 'Nepodařilo se načíst jídelní lístky';
  @override String get tryAgain             => 'Zkusit znovu';
  @override String get kmAway              => 'km odsud';
  @override String get dishes              => 'jídel';
  @override String get mon => 'Po';
  @override String get tue => 'Út';
  @override String get wed => 'St';
  @override String get thu => 'Čt';
  @override String get fri => 'Pá';
  @override String get sat => 'So';
  @override String get sun => 'Ne';
  @override String get searchHint           => 'Hledej jídla nebo restaurace...';
  @override String get searchLoading        => 'Načítám nabídky...';
  @override String get searchReady          => 'Vyhledávání bude za chvíli připraveno';
  @override String get searchAcrossAllCities => 'Prohledej všechna města';
  @override String get searchTip            => 'Zkus "řízek", "pizza" nebo název restaurace';
  @override String get noResults            => 'Žádné výsledky';
  @override String get tryDifferentSpelling => 'Zkus jiný pravopis';
  @override String dishCount(int d, int r)  => '$d jídel v $r restauracích';
  @override String get delivery             => 'Rozvoz';
  @override String get allItems             => 'Vše';
  @override String get soup                 => 'Polévka';
  @override String get main                 => 'Hlavní';
  @override String get dessert              => 'Dezert';
  @override String get couldNotLoadRestaurant => 'Nepodařilo se načíst restauraci';
  @override String get noItemsInCategory    => 'V této kategorii nejsou žádné položky';
  @override String get price                => 'Cena';
  @override String get weight               => 'Hmotnost';
  @override String get allergens            => 'Alergeny';
  @override String get calories             => 'Kalorie';
  @override String get protein              => 'Bílkoviny';
  @override String get fat                  => 'Tuky';
  @override String get carbs                => 'Sacharidy';
  @override String get callNow              => 'Zavolat';
  @override String get callRestaurant       => 'Zavolat do restaurace?';
  @override String get callConfirm          => 'Zavolat';
  @override String get cancel               => 'Zrušit';
  @override String get estimatedPrice       => 'Odhadovaná cena';
  @override String get estimatedPriceNote   => 'Tato restaurace nemá oficiálně uvedené ceny. Před objednávkou si zkontroluj jejich sociální sítě nebo oficiální web!';
  @override String get gotIt                => 'Rozumím';
  @override String get profile              => 'Profil';
  @override String get nickname             => 'Přezdívka';
  @override String get nicknamePlaceholder  => 'např. Honza, Zuzka...';
  @override String get nicknameHint         => 'Používá se pro personalizované pozdravy. V budoucích verzích může být použito pro notifikace.';
  @override String get appSettings          => 'Nastavení aplikace';
  @override String get version              => 'namenu+ v1.0.0';
  @override String get settings             => 'Nastavení';
  @override String get appearance           => 'Vzhled';
  @override String get darkMode             => 'Tmavý režim';
  @override String get accentColor          => 'Barva zvýraznění';
  @override String get customColor          => 'Vlastní barva';
  @override String get notifications        => 'Oznámení';
  @override String get dailyReminder        => 'Denní připomínka oběda';
  @override String get dailyReminderOn      => 'Každý den v 10:30 dostaneš připomínku podívat se na dnešní menu.';
  @override String get dailyReminderOff     => 'Zapni si denní připomínku v 10:30.';
  @override String get advanced             => 'Pokročilé';
  @override String get apiUrl               => 'URL adresa API';
  @override String get apiUrlWarning        => 'Změna této hodnoty může způsobit nefunkčnost aplikace.';
  @override String get resetToDefault       => 'Obnovit výchozí';
  @override String get language             => 'Jazyk';
  @override String get tagline              => 'namenu+ — obědová menu, jednoduše.';
  @override String get serverUnreachable        => 'Server nedostupný';
  @override String get serverUnreachableBanner  => 'Server je nedostupný! Zobrazují se uložená data.';
  @override String get serverUnreachableDetail  => 'Nepodařilo se připojit k serveru namenu+. Zobrazená data nemusí být aktuální.';
  @override String get cacheFrom                => 'Uloženo';
  @override String get cacheInvalidNote         => 'Mezipaměť je neaktuální. Po obnovení serveru táhněte dolů pro aktualizaci.';
  @override String get cacheSettings            => 'Mezipaměť';
  @override String get cacheEnabled             => 'Povolit mezipaměť';
  @override String get cacheCities              => 'Mezipaměť měst';
  @override String get cacheMenus               => 'Mezipaměť jídelních lístků';
  @override String get cacheRestaurants         => 'Mezipaměť restaurací';
  @override String get cacheWeek                => 'Mezipaměť dostupnosti týdne';
  @override String get cacheClearAll            => 'Vymazat vše';
  @override String get cacheClearMenus          => 'Vymazat mezipaměť menu';
  @override String get cacheSize                => 'Velikost mezipaměti';
  @override String get cacheCleared             => 'Mezipaměť vymazána';
}