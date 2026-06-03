# BockStore UI

BockStore UI is a Flutter marketplace app built to connect users with apps in a store-style interface. It is designed as a simple client for browsing apps, signing in, viewing app details, and managing favorites.

## Project overview

This app includes:

- A landing `HomeScreen` with app listings and search
- `AuthProvider` for login, register, logout, and session restore
- User profile image upload support with `image_picker`
- Wishlist saved locally with `shared_preferences`
- App activity and recent updates from a backend API
- Admin screens for uploading apps, viewing logs, and managing apps
- Dark theme styling using custom theme classes

The app uses a backend API configured in `lib/config/api_config.dart`.

## Main features

- Browse and search apps
- View app details
- Login and register users
- Upload profile image from gallery
- Save wishlist items locally
- Track recent user activity
- Handle network calls with `dio` and `http`
- Launch URLs and open downloaded files
- Support device info and permissions

## Packages used

- `flutter`
- `provider`
- `dio`
- `http`
- `image_picker`
- `file_picker`
- `share_plus`
- `shared_preferences`
- `permission_handler`
- `device_info_plus`
- `url_launcher`
- `open_filex`
- `intl`
- `crypto`
- `path_provider`
- `path`

## Folder structure

- `lib/main.dart` - app entry point
- `lib/screens/` - UI screens
- `lib/providers/` - state management classes
- `lib/services/` - backend and utility services
- `lib/config/` - API config and helpers
- `lib/models/` - data models
- `lib/theme/` - custom theme colors and styles
- `lib/widgets/` - reusable UI components
- `lib/utils/` - helper utilities

## Setup

1. Install Flutter and confirm it is on your PATH.
2. Open `c:\Users\nagta\BockStoreUI` in your editor.
3. Run:

```bash
flutter pub get
```

4. Start the app on an emulator or device:

```bash
flutter run
```

## Running tests

If there are tests in the `test/` folder, run:

```bash
flutter test
```

## GitHub push steps

If you have not pushed this project yet, do this:

```bash
git init
git add .
git commit -m "Initial commit"
```

Link the repo (replace your values):

```bash
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
```

Push to GitHub:

```bash
git branch -M main
git push -u origin main
```

## Notes for future work

- Update `lib/config/api_config.dart` if the API URL changes.
- Keep backend endpoints in sync with the UI screens.
- Add more tests when new features are added.
- Use meaningful commit messages like `Add login flow` or `Fix wishlist logic`.
