# ToMenu App &nbsp;[![beta](https://img.shields.io/badge/status-beta-yellow)](https://tomenu.sk) [![license](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)

> The Android client for [ToMenu](https://tomenu.sk) — all Slovak restaurant lunch menus in one app.

ToMenu brings daily lunch menus from Slovak restaurants to your phone. GPS-sorted, searchable, filterable. Privacy-first, ad-free, no mandatory account.

**Download:** [tomenu.sk](https://tomenu.sk) · [Latest release APK](https://github.com/toomcis/tomenu-app/releases/latest/download/tomenu.apk)

---

## Features

- 📍 **GPS sorting** — restaurants sorted by distance, closest first
- 🔍 **Dish search** — search across all restaurants at once, diacritic-insensitive
- ⚗ **Advanced filters** — price, weight, allergens, delivery, price:portion ratio
- 🛵 **Delivery aware** — see which restaurants deliver before opening the menu
- 📅 **Full week** — browse any day's menu, not just today
- 🗺 **Maps integration** — tap any address to open in Google Maps or your local map app
- 🔔 **Smart notifications** — get notified at 10:30 when menus you like are available (opt-in)
- 🌙 **Dark / light mode** — follows system, or set manually
- 🎨 **Accent color** — pick any color, including fully custom hex
- 🌍 **EN / SK / CS** — auto-detects browser language, toggle in settings
- 📦 **Offline cache** — last loaded menus available without internet
- 🔒 **Privacy first** — no tracking, no ads, everything opt-in

---

## Building from source

### Requirements

- Flutter 3.19+
- Android SDK (API 26+)
- Java 17

### Setup

```bash
git clone https://github.com/toomcis/tomenu-app.git
cd tomenu-app

flutter pub get
flutter run
```

The app points to `https://api.tomenu.sk` by default. To use a self-hosted backend, change `ApiClient.baseUrl` in `lib/api/client.dart`.

### Building a release APK

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Project structure

```
lib/
├── main.dart
├── api/
│   └── client.dart               # ApiResult<T> wrapper, cache-first requests
├── l10n/
│   └── strings.dart              # EN / SK / CS translations
├── models/
│   ├── city.dart
│   ├── menu_item.dart
│   └── restaurant.dart
├── screens/
│   ├── main_shell.dart           # bottom nav shell
│   ├── home_screen.dart          # main feed with day selector
│   ├── search_screen.dart        # full-text dish search
│   ├── profile_screen.dart
│   ├── settings_screen.dart
│   └── restaurant_profile_screen.dart
├── services/
│   ├── cache_service.dart        # SharedPreferences offline cache
│   └── notification_service.dart
├── theme/
│   └── app_theme.dart            # dark/light + accent color theming
└── widgets/
    ├── app_logo.dart
    ├── day_selector.dart         # full-width week tab bar
    ├── menu_item_detail.dart     # bottom sheet for dish details
    ├── restaurant_card.dart
    └── stale_cache_banner.dart
```

---

## Backend

This app talks to the [ToMenu backend](https://github.com/toomcis/tomenu). The backend is open source, MIT licensed, and self-hostable via Docker.

**API base URL:** `https://api.tomenu.sk`  
**API docs:** `https://tomenu.sk/api`

---

## Contributing

PRs welcome for:

- **Translations** — improve or fix strings in `lib/l10n/strings.dart`
- **New screens** — user accounts, swipe feed, social features
- **Bug fixes** — especially edge cases in the restaurant card layout or search

Open an issue before starting anything large.

---

## License

MIT — do whatever, just don't pretend you made it.

---

*Made in Levice 🇸🇰 by [toomcis](https://toomcis.eu)*