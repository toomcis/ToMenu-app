// All UI strings in one place.
// Adding a new language = add a new _Strings subclass at the bottom.
// Adding a new string = add to AppStrings abstract class + all subclasses.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Supported languages ───────────────────────────────────────────────────────

enum AppLanguage {
  system,
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
    'en' => AppLanguage.en,
    'sk' => AppLanguage.sk,
    'cs' => AppLanguage.cs,
    _    => AppLanguage.system,
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

  // Search day picker sheet
  String get dayPickerTitle;
  String get dayPickerSubtitle;
  String get today;
  String get filterAndSort;
  String get filterReset;
  String get filterApply;
  String get filterPrice;
  String get filterWeight;
  String get filterDayOfWeek;
  String get filterSort;

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

  // Auth — login / register
  String get login;
  String get register;
  String get logout;
  String get logoutConfirm;
  String get password;
  String get displayName;
  String get fillAllFields;
  String get passwordTooShort;
  String get continueAsGuest;
  String get signInOrRegister;
  String get freeAccount;
  String get premiumAccount;
  String get freePerks;
  String get premiumPerks;
  String get confirm;
  String get enable;
  String get manage;
  String get goBack;

  // Auth — profile editing
  String get editProfile;
  String get save;
  String get displayNameHint;
  String get nicknameHandleHint;
  String get nicknameLabel;
  String get nicknameHelp;
  String get addNickname;
  String get nameChangeHint;
  String nameChangeCooldown(int days);
  String get daysRemaining;

  // Auth — badges
  String get verified;
  String get unverified;
  String get emailVerified;
  String get emailNotVerified;

  // Auth — email verification
  String get verifyEmail;
  String get verifyEmailPrompt;
  String verifyEmailSent(String email);
  String get verify;
  String get resendCode;
  String get resendEmail;
  String get codeSent;
  String get verificationSent;

  // Auth — password reset
  String get forgotPassword;
  String get forgotPasswordHint;
  String get sendResetLink;
  String get resetEmailSent;
  String get resetEmailSentHint;
  String resetCodeSent(String email);
  String get newPassword;
  String get sendCode;
  String get resetPassword;
  String get passwordResetSuccess;

  // Auth — 2FA TOTP
  String get twoFactor;
  String get twoFactorSetupTitle;
  String get twoFactorSetupHint;
  String get twoFactorScanTitle;
  String get twoFactorScanHint;
  String get twoFactorSecretHint;
  String get twoFactorStart;
  String get twoFactorEnterCode;
  String get twoFactorConfirm;
  String get twoFactorEnabled;
  String get twoFactorEnabledHint;
  String get twoFactorDisable;
  String get twoFactorDisableHint;
  String get twoFactorDisabled;
  String get twoFactorActive;
  String get twoFactorCodeHint;
  String get enterTwoFactorCode;
  String get totpHint;
  String get enterTotpCode;
  String get back;
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
      final locale = Localizations.localeOf(context);
      final code   = locale.languageCode;
      if (code == 'sk') return AppLanguage.sk;
      if (code == 'cs') return AppLanguage.cs;
    } catch (_) {}
    return AppLanguage.en;
  }
}

// ── English ───────────────────────────────────────────────────────────────────

class _EnStrings extends AppStrings {
  @override String get appName              => 'ToMenu';
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
  @override String get dayPickerTitle       => 'Which day are you looking for?';
  @override String get dayPickerSubtitle    => 'Pick a day to search its menu';
  @override String get today               => 'Today';
  @override String get filterAndSort       => 'Filter & Sort';
  @override String get filterReset         => 'Reset';
  @override String get filterApply         => 'Apply Filters';
  @override String get filterPrice         => 'Price (€)';
  @override String get filterWeight        => 'Weight (g)';
  @override String get filterDayOfWeek    => 'Day of week';
  @override String get filterSort          => 'Sort';
  @override String get delivery            => 'Delivery';
  @override String get allItems            => 'All';
  @override String get soup                => 'Soup';
  @override String get main                => 'Main';
  @override String get dessert             => 'Dessert';
  @override String get couldNotLoadRestaurant => 'Could not load restaurant';
  @override String get noItemsInCategory   => 'No items in this category';
  @override String get price               => 'Price';
  @override String get weight              => 'Weight';
  @override String get allergens           => 'Allergens';
  @override String get calories            => 'Calories';
  @override String get protein             => 'Protein';
  @override String get fat                 => 'Fat';
  @override String get carbs               => 'Carbs';
  @override String get callNow             => 'Call now';
  @override String get callRestaurant      => 'Call restaurant?';
  @override String get callConfirm         => 'Call';
  @override String get cancel              => 'Cancel';
  @override String get estimatedPrice      => 'Estimated price';
  @override String get estimatedPriceNote  => 'This restaurant doesn\'t have prices officially stated. Please check their social media or official website before ordering!';
  @override String get gotIt               => 'Got it';
  @override String get profile             => 'Profile';
  @override String get nickname            => 'Nickname';
  @override String get nicknamePlaceholder => 'e.g. Jano, Zuzka...';
  @override String get nicknameHint        => 'Used for personalized greetings.';
  @override String get appSettings         => 'App Settings';
  @override String get version             => 'ToMenu v1.0.0';
  @override String get settings            => 'Settings';
  @override String get appearance          => 'Appearance';
  @override String get darkMode            => 'Dark mode';
  @override String get accentColor         => 'Accent color';
  @override String get customColor         => 'Custom color';
  @override String get notifications       => 'Notifications';
  @override String get dailyReminder       => 'Daily lunch reminder';
  @override String get dailyReminderOn     => 'You\'ll get a reminder at 10:30 AM every day to check today\'s menus.';
  @override String get dailyReminderOff    => 'Opt in to get a daily nudge at 10:30 AM.';
  @override String get advanced            => 'Advanced';
  @override String get apiUrl              => 'API URL';
  @override String get apiUrlWarning       => 'Changing this may break the app.';
  @override String get resetToDefault      => 'Reset to default';
  @override String get language            => 'Language';
  @override String get tagline             => 'ToMenu — TO menu ktoré potrebuješ.';
  @override String get serverUnreachable        => 'Server unreachable';
  @override String get serverUnreachableBanner  => 'Server could not be reached! Showing cached data.';
  @override String get serverUnreachableDetail  => 'Could not connect to the ToMenu server. The data shown may not be up to date.';
  @override String get cacheFrom                => 'Cached on';
  @override String get cacheInvalidNote         => 'Cache has been flagged as invalid. Pull to refresh when the server is back online.';
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
  @override String get login                    => 'Log in';
  @override String get register                 => 'Register';
  @override String get logout                   => 'Log out';
  @override String get logoutConfirm            => 'Are you sure you want to log out?';
  @override String get password                 => 'Password';
  @override String get displayName              => 'Display name';
  @override String get fillAllFields            => 'Please fill in all required fields';
  @override String get passwordTooShort         => 'Password must be at least 8 characters';
  @override String get continueAsGuest          => 'Continue as guest';
  @override String get signInOrRegister         => 'Sign in or register';
  @override String get freeAccount              => 'Free account';
  @override String get premiumAccount           => 'Premium account';
  @override String get freePerks               => 'Browse menus, search, filter, save favourites';
  @override String get premiumPerks            => 'Everything in Free + personalised feed, taste profile, early access';
  @override String get confirm                 => 'Confirm';
  @override String get enable                  => 'Enable';
  @override String get manage                  => 'Manage';
  @override String get goBack                  => 'Go back';
  @override String get editProfile              => 'Edit profile';
  @override String get save                     => 'Save';
  @override String get displayNameHint          => 'Your name';
  @override String get nicknameHandleHint       => 'Your unique @handle — letters, numbers, underscore';
  @override String get nicknameLabel           => 'Handle';
  @override String get nicknameHelp            => 'This is how others will find you. Can be changed any time.';
  @override String get addNickname              => '+ Add @handle';
  @override String get nameChangeHint          => 'Display name can only be changed once per week';
  @override String nameChangeCooldown(int d)    => 'Name can be changed again in $d day${d == 1 ? '' : 's'}';
  @override String get daysRemaining           => 'days remaining';
  @override String get verified                 => 'Verified';
  @override String get unverified               => 'Unverified';
  @override String get emailVerified           => 'Email verified';
  @override String get emailNotVerified        => 'Email not verified';
  @override String get verifyEmail              => 'Verify email';
  @override String get verifyEmailPrompt        => 'Tap to verify your email address';
  @override String verifyEmailSent(String e)    => 'We sent a 6-digit code to $e';
  @override String get verify                   => 'Verify';
  @override String get resendCode               => 'Resend code';
  @override String get resendEmail             => 'Resend email';
  @override String get codeSent                 => 'Code sent!';
  @override String get verificationSent        => 'Verification email sent';
  @override String get forgotPassword           => 'Forgot password';
  @override String get forgotPasswordHint       => 'Enter your email and we\'ll send you a reset code';
  @override String get sendResetLink           => 'Send reset link';
  @override String get resetEmailSent          => 'Reset email sent';
  @override String get resetEmailSentHint      => 'Check your inbox and enter the 6-digit code below';
  @override String resetCodeSent(String e)      => 'Reset code sent to $e. Enter it below.';
  @override String get newPassword              => 'New password';
  @override String get sendCode                 => 'Send code';
  @override String get resetPassword            => 'Reset password';
  @override String get passwordResetSuccess     => 'Password reset — please log in again';
  @override String get twoFactor               => 'Two-factor auth';
  @override String get twoFactorSetupTitle     => 'Set up two-factor auth';
  @override String get twoFactorSetupHint      => 'Add an extra layer of security to your account';
  @override String get twoFactorScanTitle      => 'Scan the QR code';
  @override String get twoFactorScanHint       => 'Open your authenticator app (Google Authenticator, Authy…) and scan the QR code below';
  @override String get twoFactorSecretHint     => 'Can\'t scan? Enter this key manually:';
  @override String get twoFactorStart          => 'Set up 2FA';
  @override String get twoFactorEnterCode      => 'Enter the 6-digit code from your app to confirm';
  @override String get twoFactorConfirm        => 'Confirm & enable';
  @override String get twoFactorEnabled        => '2FA enabled';
  @override String get twoFactorEnabledHint    => 'Your account is protected with two-factor authentication';
  @override String get twoFactorDisable        => 'Disable 2FA';
  @override String get twoFactorDisableHint    => 'Enter your authenticator code to disable 2FA';
  @override String get twoFactorDisabled       => '2FA disabled';
  @override String get twoFactorActive         => '2FA active';
  @override String get twoFactorCodeHint       => 'Enter the 6-digit code from your authenticator app';
  @override String get enterTwoFactorCode      => 'Two-factor authentication';
  @override String get enterTotpCode            => 'Two-factor authentication';
  @override String get totpHint                 => 'Enter the 6-digit code from your authenticator app';
  @override String get back                     => 'Back';
}

// ── Slovak ────────────────────────────────────────────────────────────────────

class _SkStrings extends AppStrings {
  @override String get appName              => 'ToMenu';
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
  @override String get dayPickerTitle       => 'Ktorý deň hľadáš?';
  @override String get dayPickerSubtitle    => 'Vyber deň, ktorého menu chceš prehľadať';
  @override String get today               => 'Dnes';
  @override String get filterAndSort       => 'Filter & Zoradenie';
  @override String get filterReset         => 'Resetovať';
  @override String get filterApply         => 'Použiť filtre';
  @override String get filterPrice         => 'Cena (€)';
  @override String get filterWeight        => 'Hmotnosť (g)';
  @override String get filterDayOfWeek    => 'Deň v týždni';
  @override String get filterSort          => 'Zoradenie';
  @override String get delivery            => 'Donáška';
  @override String get allItems            => 'Všetko';
  @override String get soup                => 'Polievka';
  @override String get main                => 'Hlavné';
  @override String get dessert             => 'Dezert';
  @override String get couldNotLoadRestaurant => 'Nepodarilo sa načítať reštauráciu';
  @override String get noItemsInCategory   => 'V tejto kategórii nie sú žiadne položky';
  @override String get price               => 'Cena';
  @override String get weight              => 'Hmotnosť';
  @override String get allergens           => 'Alergény';
  @override String get calories            => 'Kalórie';
  @override String get protein             => 'Bielkoviny';
  @override String get fat                 => 'Tuky';
  @override String get carbs               => 'Sacharidy';
  @override String get callNow             => 'Zavolať';
  @override String get callRestaurant      => 'Zavolať do reštaurácie?';
  @override String get callConfirm         => 'Zavolať';
  @override String get cancel              => 'Zrušiť';
  @override String get estimatedPrice      => 'Odhadovaná cena';
  @override String get estimatedPriceNote  => 'Táto reštaurácia nemá oficiálne uvedené ceny. Pred objednávkou si skontroluj ich sociálne siete alebo oficiálnu webstránku!';
  @override String get gotIt               => 'Rozumiem';
  @override String get profile             => 'Profil';
  @override String get nickname            => 'Prezývka';
  @override String get nicknamePlaceholder => 'napr. Jano, Zuzka...';
  @override String get nicknameHint        => 'Používa sa na personalizované pozdravy.';
  @override String get appSettings         => 'Nastavenia aplikácie';
  @override String get version             => 'ToMenu v1.0.0';
  @override String get settings            => 'Nastavenia';
  @override String get appearance          => 'Vzhľad';
  @override String get darkMode            => 'Tmavý režim';
  @override String get accentColor         => 'Farba zvýraznenia';
  @override String get customColor         => 'Vlastná farba';
  @override String get notifications       => 'Notifikácie';
  @override String get dailyReminder       => 'Denná pripomienka obeda';
  @override String get dailyReminderOn     => 'Každý deň o 10:30 dostaneš pripomienku pozrieť si dnešné menu.';
  @override String get dailyReminderOff    => 'Zapni si dennú pripomienku o 10:30.';
  @override String get advanced            => 'Pokročilé';
  @override String get apiUrl              => 'URL adresa API';
  @override String get apiUrlWarning       => 'Zmena tejto hodnoty môže spôsobiť nefunkčnosť aplikácie.';
  @override String get resetToDefault      => 'Obnoviť predvolené';
  @override String get language            => 'Jazyk';
  @override String get tagline             => 'ToMenu — TO menu ktoré potrebuješ.';
  @override String get serverUnreachable        => 'Server nedostupný';
  @override String get serverUnreachableBanner  => 'Server je nedostupný! Zobrazujú sa uložené dáta.';
  @override String get serverUnreachableDetail  => 'Nepodarilo sa pripojiť na server ToMenu. Zobrazené dáta nemusia byť aktuálne.';
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
  @override String get login                    => 'Prihlásiť sa';
  @override String get register                 => 'Registrovať sa';
  @override String get logout                   => 'Odhlásiť sa';
  @override String get logoutConfirm            => 'Naozaj sa chceš odhlásiť?';
  @override String get password                 => 'Heslo';
  @override String get displayName              => 'Zobrazované meno';
  @override String get fillAllFields            => 'Vyplň všetky povinné polia';
  @override String get passwordTooShort         => 'Heslo musí mať aspoň 8 znakov';
  @override String get continueAsGuest          => 'Pokračovať ako hosť';
  @override String get signInOrRegister         => 'Prihlásiť sa alebo registrovať';
  @override String get freeAccount              => 'Bezplatný účet';
  @override String get premiumAccount           => 'Prémiový účet';
  @override String get freePerks               => 'Prehliadaj menu, hľadaj, filtruj, ukladaj obľúbené';
  @override String get premiumPerks            => 'Všetko z Free + personalizovaný feed, chuťový profil, skorý prístup';
  @override String get confirm                 => 'Potvrdiť';
  @override String get enable                  => 'Povoliť';
  @override String get manage                  => 'Spravovať';
  @override String get goBack                  => 'Späť';
  @override String get editProfile              => 'Upraviť profil';
  @override String get save                     => 'Uložiť';
  @override String get displayNameHint          => 'Tvoje meno';
  @override String get nicknameHandleHint       => 'Tvoj jedinečný @handle — písmená, čísla, podčiarknutie';
  @override String get nicknameLabel           => 'Handle';
  @override String get nicknameHelp            => 'Takto ťa nájdu ostatní. Môžeš zmeniť kedykoľvek.';
  @override String get addNickname              => '+ Pridať @handle';
  @override String get nameChangeHint          => 'Zobrazované meno môžeš zmeniť raz za týždeň';
  @override String nameChangeCooldown(int d)    => 'Meno môžeš zmeniť o $d ${d == 1 ? 'deň' : d < 5 ? 'dni' : 'dní'}';
  @override String get daysRemaining           => 'dní zostáva';
  @override String get verified                 => 'Overený';
  @override String get unverified               => 'Neoverený';
  @override String get emailVerified           => 'Email overený';
  @override String get emailNotVerified        => 'Email nie je overený';
  @override String get verifyEmail              => 'Overiť email';
  @override String get verifyEmailPrompt        => 'Klepni a over svoju emailovú adresu';
  @override String verifyEmailSent(String e)    => 'Poslali sme 6-ciferný kód na $e';
  @override String get verify                   => 'Overiť';
  @override String get resendCode               => 'Poslať kód znova';
  @override String get resendEmail             => 'Odoslať email znova';
  @override String get codeSent                 => 'Kód odoslaný!';
  @override String get verificationSent        => 'Overovací email odoslaný';
  @override String get forgotPassword           => 'Zabudnuté heslo';
  @override String get forgotPasswordHint       => 'Zadaj email a pošleme ti kód na obnovenie hesla';
  @override String get sendResetLink           => 'Poslať odkaz na obnovenie';
  @override String get resetEmailSent          => 'Email na obnovenie odoslaný';
  @override String get resetEmailSentHint      => 'Skontroluj svoju doručenú poštu a zadaj 6-ciferný kód nižšie';
  @override String resetCodeSent(String e)      => 'Kód na obnovenie bol odoslaný na $e. Zadaj ho nižšie.';
  @override String get newPassword              => 'Nové heslo';
  @override String get sendCode                 => 'Poslať kód';
  @override String get resetPassword            => 'Obnoviť heslo';
  @override String get passwordResetSuccess     => 'Heslo obnovené — prihlás sa znova';
  @override String get twoFactor               => 'Dvojfaktorové overenie';
  @override String get twoFactorSetupTitle     => 'Nastaviť dvojfaktorové overenie';
  @override String get twoFactorSetupHint      => 'Pridaj ďalšiu vrstvu ochrany svojho účtu';
  @override String get twoFactorScanTitle      => 'Naskenuj QR kód';
  @override String get twoFactorScanHint       => 'Otvor autentifikačnú aplikáciu (Google Authenticator, Authy…) a naskenuj QR kód nižšie';
  @override String get twoFactorSecretHint     => 'Nemôžeš skenovať? Zadaj tento kľúč ručne:';
  @override String get twoFactorStart          => 'Nastaviť 2FA';
  @override String get twoFactorEnterCode      => 'Zadaj 6-ciferný kód z aplikácie na potvrdenie';
  @override String get twoFactorConfirm        => 'Potvrdiť a povoliť';
  @override String get twoFactorEnabled        => '2FA povolené';
  @override String get twoFactorEnabledHint    => 'Tvoj účet je chránený dvojfaktorovým overením';
  @override String get twoFactorDisable        => 'Vypnúť 2FA';
  @override String get twoFactorDisableHint    => 'Zadaj kód z autentifikačnej aplikácie na vypnutie 2FA';
  @override String get twoFactorDisabled       => '2FA vypnuté';
  @override String get twoFactorActive         => '2FA aktívne';
  @override String get twoFactorCodeHint       => 'Zadaj 6-ciferný kód z autentifikačnej aplikácie';
  @override String get enterTwoFactorCode      => 'Dvojfaktorové overenie';
  @override String get enterTotpCode            => 'Dvojfaktorové overenie';
  @override String get totpHint                 => 'Zadaj 6-ciferný kód z autentifikačnej aplikácie';
  @override String get back                     => 'Späť';
}

// ── Czech ─────────────────────────────────────────────────────────────────────

class _CsStrings extends AppStrings {
  @override String get appName              => 'ToMenu';
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
  @override String get dayPickerTitle       => 'Který den hledáš?';
  @override String get dayPickerSubtitle    => 'Vyber den, jehož menu chceš prohledat';
  @override String get today               => 'Dnes';
  @override String get filterAndSort       => 'Filtr & Řazení';
  @override String get filterReset         => 'Resetovat';
  @override String get filterApply         => 'Použít filtry';
  @override String get filterPrice         => 'Cena (€)';
  @override String get filterWeight        => 'Hmotnost (g)';
  @override String get filterDayOfWeek    => 'Den v týdnu';
  @override String get filterSort          => 'Řazení';
  @override String get delivery            => 'Rozvoz';
  @override String get allItems            => 'Vše';
  @override String get soup                => 'Polévka';
  @override String get main                => 'Hlavní';
  @override String get dessert             => 'Dezert';
  @override String get couldNotLoadRestaurant => 'Nepodařilo se načíst restauraci';
  @override String get noItemsInCategory   => 'V této kategorii nejsou žádné položky';
  @override String get price               => 'Cena';
  @override String get weight              => 'Hmotnost';
  @override String get allergens           => 'Alergeny';
  @override String get calories            => 'Kalorie';
  @override String get protein             => 'Bílkoviny';
  @override String get fat                 => 'Tuky';
  @override String get carbs               => 'Sacharidy';
  @override String get callNow             => 'Zavolat';
  @override String get callRestaurant      => 'Zavolat do restaurace?';
  @override String get callConfirm         => 'Zavolat';
  @override String get cancel              => 'Zrušit';
  @override String get estimatedPrice      => 'Odhadovaná cena';
  @override String get estimatedPriceNote  => 'Tato restaurace nemá oficiálně uvedené ceny. Před objednávkou si zkontroluj jejich sociální sítě nebo oficiální web!';
  @override String get gotIt               => 'Rozumím';
  @override String get profile             => 'Profil';
  @override String get nickname            => 'Přezdívka';
  @override String get nicknamePlaceholder => 'např. Honza, Zuzka...';
  @override String get nicknameHint        => 'Používá se pro personalizované pozdravy.';
  @override String get appSettings         => 'Nastavení aplikace';
  @override String get version             => 'ToMenu v1.0.0';
  @override String get settings            => 'Nastavení';
  @override String get appearance          => 'Vzhled';
  @override String get darkMode            => 'Tmavý režim';
  @override String get accentColor         => 'Barva zvýraznění';
  @override String get customColor         => 'Vlastní barva';
  @override String get notifications       => 'Oznámení';
  @override String get dailyReminder       => 'Denní připomínka oběda';
  @override String get dailyReminderOn     => 'Každý den v 10:30 dostaneš připomínku podívat se na dnešní menu.';
  @override String get dailyReminderOff    => 'Zapni si denní připomínku v 10:30.';
  @override String get advanced            => 'Pokročilé';
  @override String get apiUrl              => 'URL adresa API';
  @override String get apiUrlWarning       => 'Změna této hodnoty může způsobit nefunkčnost aplikace.';
  @override String get resetToDefault      => 'Obnovit výchozí';
  @override String get language            => 'Jazyk';
  @override String get tagline             => 'ToMenu — TO menu ktoré potrebuješ.';
  @override String get serverUnreachable        => 'Server nedostupný';
  @override String get serverUnreachableBanner  => 'Server je nedostupný! Zobrazují se uložená data.';
  @override String get serverUnreachableDetail  => 'Nepodařilo se připojit k serveru ToMenu. Zobrazená data nemusí být aktuální.';
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
  @override String get login                    => 'Přihlásit se';
  @override String get register                 => 'Registrovat se';
  @override String get logout                   => 'Odhlásit se';
  @override String get logoutConfirm            => 'Opravdu se chceš odhlásit?';
  @override String get password                 => 'Heslo';
  @override String get displayName              => 'Zobrazované jméno';
  @override String get fillAllFields            => 'Vyplň všechna povinná pole';
  @override String get passwordTooShort         => 'Heslo musí mít alespoň 8 znaků';
  @override String get continueAsGuest          => 'Pokračovat jako host';
  @override String get signInOrRegister         => 'Přihlásit se nebo registrovat';
  @override String get freeAccount              => 'Bezplatný účet';
  @override String get premiumAccount           => 'Prémiový účet';
  @override String get freePerks               => 'Procházej menu, hledej, filtruj, ukládej oblíbené';
  @override String get premiumPerks            => 'Vše z Free + personalizovaný feed, chuťový profil, brzký přístup';
  @override String get confirm                 => 'Potvrdit';
  @override String get enable                  => 'Povolit';
  @override String get manage                  => 'Spravovat';
  @override String get goBack                  => 'Zpět';
  @override String get editProfile              => 'Upravit profil';
  @override String get save                     => 'Uložit';
  @override String get displayNameHint          => 'Tvoje jméno';
  @override String get nicknameHandleHint       => 'Tvůj jedinečný @handle — písmena, čísla, podtržítko';
  @override String get nicknameLabel           => 'Handle';
  @override String get nicknameHelp            => 'Takto tě najdou ostatní. Lze změnit kdykoli.';
  @override String get addNickname              => '+ Přidat @handle';
  @override String get nameChangeHint          => 'Zobrazované jméno lze měnit jednou týdně';
  @override String nameChangeCooldown(int d)    => 'Jméno lze změnit za $d ${d == 1 ? 'den' : d < 5 ? 'dny' : 'dní'}';
  @override String get daysRemaining           => 'dní zbývá';
  @override String get verified                 => 'Ověřený';
  @override String get unverified               => 'Neověřený';
  @override String get emailVerified           => 'Email ověřen';
  @override String get emailNotVerified        => 'Email není ověřen';
  @override String get verifyEmail              => 'Ověřit email';
  @override String get verifyEmailPrompt        => 'Klepni a ověř svou emailovou adresu';
  @override String verifyEmailSent(String e)    => 'Poslali jsme 6místný kód na $e';
  @override String get verify                   => 'Ověřit';
  @override String get resendCode               => 'Poslat kód znovu';
  @override String get resendEmail             => 'Odeslat email znovu';
  @override String get codeSent                 => 'Kód odeslán!';
  @override String get verificationSent        => 'Ověřovací email odeslán';
  @override String get forgotPassword           => 'Zapomenuté heslo';
  @override String get forgotPasswordHint       => 'Zadej email a pošleme ti kód pro obnovení hesla';
  @override String get sendResetLink           => 'Odeslat odkaz pro obnovení';
  @override String get resetEmailSent          => 'Email pro obnovení odeslán';
  @override String get resetEmailSentHint      => 'Zkontroluj doručenou poštu a zadej 6místný kód níže';
  @override String resetCodeSent(String e)      => 'Kód pro obnovení byl odeslán na $e. Zadej ho níže.';
  @override String get newPassword              => 'Nové heslo';
  @override String get sendCode                 => 'Poslat kód';
  @override String get resetPassword            => 'Obnovit heslo';
  @override String get passwordResetSuccess     => 'Heslo obnoveno — přihlaš se znovu';
  @override String get twoFactor               => 'Dvoufaktorové ověření';
  @override String get twoFactorSetupTitle     => 'Nastavit dvoufaktorové ověření';
  @override String get twoFactorSetupHint      => 'Přidej další vrstvu ochrany svého účtu';
  @override String get twoFactorScanTitle      => 'Naskenuj QR kód';
  @override String get twoFactorScanHint       => 'Otevři autentifikační aplikaci (Google Authenticator, Authy…) a naskenuj QR kód níže';
  @override String get twoFactorSecretHint     => 'Nemůžeš skenovat? Zadej tento klíč ručně:';
  @override String get twoFactorStart          => 'Nastavit 2FA';
  @override String get twoFactorEnterCode      => 'Zadej 6místný kód z aplikace pro potvrzení';
  @override String get twoFactorConfirm        => 'Potvrdit a povolit';
  @override String get twoFactorEnabled        => '2FA povoleno';
  @override String get twoFactorEnabledHint    => 'Tvůj účet je chráněn dvoufaktorovým ověřením';
  @override String get twoFactorDisable        => 'Vypnout 2FA';
  @override String get twoFactorDisableHint    => 'Zadej kód z autentifikační aplikace pro vypnutí 2FA';
  @override String get twoFactorDisabled       => '2FA vypnuto';
  @override String get twoFactorActive         => '2FA aktivní';
  @override String get twoFactorCodeHint       => 'Zadej 6místný kód z autentifikační aplikace';
  @override String get enterTwoFactorCode      => 'Dvoufaktorové ověření';
  @override String get enterTotpCode            => 'Dvoufaktorové ověření';
  @override String get totpHint                 => 'Zadej 6místný kód z autentifikační aplikace';
  @override String get back                     => 'Zpět';
}