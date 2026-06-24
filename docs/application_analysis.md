# DR.Cars Application Analysis

## Executive Summary

DR.Cars is a Flutter mobile application backed by a Node.js/Express API and MongoDB. The app is role based:

- Vehicle Owner: vehicle profile, service history, appointments, maps, documents, 3D viewer, OBD2 diagnostics.
- Service Center: owner lookup, service intake, appointments, service receipts, completed service records.
- App Admin: service-center request approval, rejected request management, warning-light database, ratings view.

The application is not currently ready for Android or iOS production deployment. Local checks found compile/analyzer errors, Android build failure caused by `flutter_bluetooth_serial`, iOS CocoaPods deployment-target failure, missing native iOS configuration, release signing gaps, hard-coded backend/API hosts, route mismatches, and tracked secret/generated/vendor files.

## Repository Layout

```text
.
|-- lib/                         Flutter app source
|   |-- auth/                    sign-in, sign-up, social auth, auth API service
|   |-- user/                    vehicle-owner dashboard, profile, documents, 3D viewer
|   |-- service/                 service-center screens and service workflows
|   |-- admin/                   admin dashboards, request queues, warning database
|   |-- appointments/            owner booking and service-center appointment queues
|   |-- map/                     Google Maps and Places integration
|   |-- obd/                     Bluetooth OBD2 screen
|   |-- l10n/                    in-code translations
|   |-- providers/               locale state
|   |-- theme/                   shared app theme
|   `-- widgets/                 shared bottom navigation
|-- backend/                     Express/MongoDB backend
|   |-- server.js                active backend entry point and route definitions
|   |-- models/                  Mongoose schemas
|   |-- middleware/              JWT middleware, currently not wired into server.js
|   |-- public/documents/        uploaded document images
|   `-- node_modules/            vendored dependencies currently tracked in Git
|-- android/                     native Android Flutter project
|-- ios/                         native iOS Flutter project
|-- assets/                      app logo, HTML 3D viewer, bundled GLB asset
|-- images/                      vehicle/warning/location imagery
|-- web/, linux/, macos/, windows/ desktop/web Flutter targets
`-- test/                        default Flutter counter test, not aligned to this app
```

## Application Runtime Flow

The app starts in `lib/main.dart`.

1. `main()` initializes Flutter bindings, document notification services, OneSignal, persisted theme mode, and locale state.
2. `MyApp` builds a `MaterialApp` using `buildAppTheme()` from `lib/theme/app_theme.dart`.
3. `AuthCheck` calls `AuthService.getCurrentUser()`.
4. `AuthService` reads `SharedPreferences` keys such as `currentUserId`, `currentUserEmail`, and `currentUserType`.
5. If needed, it calls the backend to resolve the user by email or id.
6. Role routing selects:
   - `DashboardScreen` for `Vehicle Owner`
   - `HomeScreen` for `Service Center`
   - `ServiceCenterApprovalPage` for `App Admin`
   - `Welcome` for unknown/unauthenticated users

There is no centralized state-management library. State is mostly local `StatefulWidget` state plus `SharedPreferences`, `ValueNotifier` objects for theme/locale, and ad hoc backend fetches.

## Frontend Architecture

### Authentication and roles

`lib/auth/auth_service.dart` is the main backend API client. It handles:

- username/email password login
- user creation and updates
- current-user persistence
- Google and Facebook login handoff to backend
- vehicle lookup/upsert helpers
- service-center status lookup
- password reset request

Important behavior:

- `AuthService.baseUrl` can be overridden at compile time with `--dart-define=API_BASE_URL=...`.
- Android defaults to `https://drcars-fyp-production.up.railway.app`.
- iOS, macOS, Windows, Linux, and web default to `http://localhost:5000`, which is not deployable for a real device build.
- Some screens bypass `AuthService.baseUrl` and hard-code production Railway or Android emulator URLs.

### Vehicle owner flow

Vehicle-owner features live mainly under `lib/user/`, `lib/appointments/`, `lib/map/`, `lib/service/`, and `lib/obd/`.

Main capabilities:

- Dashboard with vehicle summary, upcoming maintenance calculation, receipt/appointment summaries.
- Vehicle profile setup and update through `PUT /vehicles/by-user/:uid`.
- Appointment booking through service-center selection by city and `POST /appointments`.
- Receipt notifications and confirmation/rejection through service receipt status updates.
- Service records list and manual record creation.
- Document scanning/upload through ML Kit OCR, image picker, and `vehicle-documents` backend routes.
- 3D vehicle viewer in a local WebView asset that loads model files from the backend model endpoint.
- Nearby service-center maps through Google Maps, Google Places, and Directions APIs.
- OBD2 screen using Bluetooth Serial.

### Service-center flow

Service-center features live mainly under `lib/service/` and `lib/appointments/`.

Main capabilities:

- Vehicle lookup by vehicle number.
- Owner/user lookup from the vehicle record.
- Appointment queues by status.
- Appointment accept/reject/vehicle-received transitions.
- Service receipt creation with selected services and prices.
- Receipt management for confirmed/rejected/finished states.
- Completed receipt status automatically creates service-record rows on the backend.

### Admin flow

Admin features live under `lib/admin/` and duplicated `lib/requests/` folders.

Main capabilities:

- Review pending service-center sign-up requests.
- Accept requests, which creates or updates a `Service Center` user.
- Reject, restore, or delete requests.
- View rejected requests.
- View warning-light guidance database and open YouTube searches.
- View ratings, although the current ratings screen calls non-existent `/api/feedbacks` endpoints.

### Localization and theme

- Localization is implemented in `lib/l10n/app_strings.dart` with a `ValueNotifier` in `lib/providers/locale_provider.dart`.
- Theme is centralized in `lib/theme/app_theme.dart`.
- The app uses Material widgets, Google Fonts, and custom color constants.
- Current Flutter 3.41 analysis reports compile errors in the theme file because `ThemeData.cardTheme` and `ThemeData.tabBarTheme` expect `CardThemeData?` and `TabBarThemeData?`.

## Backend Architecture

The active backend is `backend/server.js`. It is a monolithic Express application with direct route definitions and Mongoose model imports.

Backend startup:

1. Loads `dotenv`.
2. Enables global CORS with `app.use(cors())`.
3. Enables JSON parsing with `express.json()`.
4. Registers model proxy and document static routes.
5. Connects to MongoDB through `process.env.MONGO_URI`.
6. Registers all API routes.
7. Listens on `process.env.PORT || 5000`.

Required backend environment variables:

- `MONGO_URI`: MongoDB connection string.
- `JWT_SECRET`: token signing secret for login/social auth/password routes.
- `PORT`: optional server port.
- `BASE_URL`: optional public base URL used when returning uploaded document URLs.

Security notes:

- `backend/middleware/middleware.js` defines JWT verification, but the active `server.js` does not apply it to protected resources.
- Most create/update/delete routes are public if the backend is reachable.
- CORS is unrestricted.
- Passwords are hashed for normal create/login flows, but update routes accept arbitrary request bodies and could overwrite user fields if exposed.
- `backend/.env` is tracked by Git. It should not be committed with real secrets.

## Data Models

### User

Fields include `uid`, `name`, `serviceCenterName`, `email`, `username`, `password`, `address`, `contact`, `city`, `branch`, `userType`, `googleId`, `facebookId`, `photoUrl`, and `createdAt`.

### Vehicle

Fields include `userId`, `uid`, `brand`, `model`, `year`, `plateNumber`, `vehicleNumber`, `selectedBrand`, `selectedModel`, `vehicleType`, `mileage`, and `vehiclePhotoUrl`.

### Appointment

Fields include `vehicleNumber`, `vehicleModel`, `serviceTypes`, `branch`, `date`, `time`, `Contact`, `userId`, `serviceCenterUid`, and `status`. Status values are `pending`, `accepted`, `rejected`, and `vehicle_received`.

### ServiceReceipt

Fields include `vehicleNumber`, `previousOilChange`, `currentMileage`, `nextServiceDate`, `services`, `status`, `serviceCenterId`, and `"Service Center Name"`. Status values are `not confirmed`, `confirmed`, `rejected`, `finished`, and `done`.

### ServiceRecord

Fields include `userId`, `vehicleNumber`, `currentMileage`, `serviceMileage`, `serviceProvider`, `serviceCost`, `serviceType`, `oilType`, `notes`, and `date`.

### ServiceCenterRequest

Fields include `email`, `username`, `passwordHash`, `status`, `serviceCenterName`, `ownerName`, `nic`, `regNumber`, `address`, `contact`, `notes`, and `city`.

### Feedback

Fields include `serviceCenterId`, `userId`, `name`, `rating`, `feedback`, and `date`.

### VehicleDocument

Fields include `userId`, `type`, `label`, `documentNumber`, `vehiclePlate`, `issueDate`, `expiryDate`, `photoUrl`, and `createdAt`.

## Dependencies

### Flutter dependencies

- `http`: REST calls to backend and external APIs.
- `shared_preferences`: persisted user/theme/locale state.
- `google_sign_in`, `flutter_facebook_auth`: social login.
- `google_maps_flutter`, `geolocator`, `flutter_polyline_points`: map display, location, and routes.
- `permission_handler`: runtime permissions.
- `image_picker`, `google_mlkit_text_recognition`: document photo capture and OCR.
- `webview_flutter`: embedded Three.js 3D vehicle viewer.
- `flutter_bluetooth_serial`: OBD2 Bluetooth serial connectivity.
- `flutter_local_notifications`, `timezone`, `rxdart`: local document/appointment-style notifications.
- `onesignal_flutter`: push notification SDK from a Git dependency.
- `table_calendar`: appointment calendar UI.
- `intl`: formatting/localization utilities.
- `google_fonts`, `flutter_svg`, `font_awesome_flutter`, `cupertino_icons`: UI assets/icons/fonts.
- `url_launcher`, `share_plus`, `fluttertoast`: external URL opening, sharing, toast messages.

### Backend dependencies

- `express`: HTTP server and route handling.
- `mongoose`: MongoDB object modeling.
- `bcrypt`: password hashing.
- `jsonwebtoken`: JWT generation/verification.
- `cors`: CORS middleware.
- `dotenv`: environment variable loading.
- `multer`: multipart file uploads.

## Configuration and Environment

### Frontend configuration

- `API_BASE_URL` compile-time define overrides `AuthService.baseUrl`.
- `MODEL_SERVER_URL` compile-time define overrides the 3D model server URL.
- Google Maps API key is hard-coded in Android manifest and Dart source.
- OneSignal app id is hard-coded in `main.dart`.
- Google Web client id is hard-coded in `signin.dart`.
- Several screens hard-code `https://drcars-fyp-production.up.railway.app`.
- `lib/admin/ratings/rating.dart` hard-codes `http://10.0.2.2:5000/api`.

Recommended production approach:

- Use `--dart-define=API_BASE_URL=https://your-api.example.com`.
- Use `--dart-define=MODEL_SERVER_URL=https://your-api.example.com`.
- Move public keys into platform-specific configuration and restrict keys by package name, bundle id, SHA fingerprints, and API.
- Remove localhost defaults for release builds.

### Backend configuration

- Add a `backend/.env.example` with non-secret placeholders.
- Remove real `backend/.env` from Git history and add `.env` to `.gitignore`.
- Do not track `backend/node_modules`.
- Do not track uploaded `backend/public/documents` images unless they are intentional fixtures.

## Build and Validation Results

Commands run from the repository root on this branch:

```text
flutter --version
flutter pub get
flutter analyze
flutter build apk --debug
flutter build ios --debug --no-codesign
```

Backend checks:

```text
node --version
npm --version
npm test
```

Observed results:

- Flutter SDK: 3.41.8 stable, Dart 3.11.5.
- Node.js: v22.22.3.
- npm: 10.9.8.
- `flutter pub get`: succeeded.
- `flutter analyze`: failed with 264 issues, including 2 compile-type errors:
  - `lib/theme/app_theme.dart`: `CardTheme` cannot be assigned to `CardThemeData?`.
  - `lib/theme/app_theme.dart`: `TabBarTheme` cannot be assigned to `TabBarThemeData?`.
- `flutter build apk --debug`: failed because `flutter_bluetooth_serial 0.4.0` does not define an Android namespace required by the current Android Gradle Plugin.
- `flutter build ios --debug --no-codesign`: failed because `google_maps_flutter_ios` requires a higher iOS deployment target than the project currently targets. Flutter/CocoaPods reported that the app should target at least iOS 14.0.
- `npm test`: failed because the backend package defines the default `Error: no test specified` script.

## Android Deployment Readiness

Status: not ready.

Blocking issues:

- Android build fails before producing an APK due to the `flutter_bluetooth_serial` plugin lacking a namespace under Android Gradle Plugin 8.x.
- `flutter analyze` has real compile-type errors in shared Flutter code.
- Release signing uses the debug signing config in `android/app/build.gradle.kts`.
- `applicationId` is still `com.example.dr_cars_fyp`, which is not a production app id.
- App label is still `dr_cars_fyp`.
- Several endpoints are hard-coded and inconsistent across screens.
- Ratings screen calls `/api/feedbacks`, but the active backend only exposes `GET /feedbacks`.
- The manifest enables `android:usesCleartextTraffic="true"` while `network_security_config.xml` denies cleartext traffic. This is inconsistent and should be made explicit for production.
- Broad permissions such as exact alarms, storage writes, camera, Bluetooth, and location need release justification and runtime handling review.
- API keys are hard-coded in source/manifest and should be restricted before release.

Android-specific notes:

- `compileSdk = 36`, `minSdk = 24`.
- `targetSdk = flutter.targetSdkVersion`.
- Gradle wrapper is 8.10.2, Android Gradle Plugin is 8.7.0, Kotlin plugin is 1.8.22.
- Flutter warned that Kotlin 1.8.22 support will be dropped soon and recommends Kotlin 2.1.0 or newer.

## iOS Deployment Readiness

Status: not ready.

Blocking issues:

- iOS build fails at `pod install` because `google_maps_flutter_ios` requires a higher minimum iOS target. Set the iOS platform/deployment target to at least 14.0.
- `flutter analyze` has real compile-type errors in shared Flutter code.
- `AuthService.baseUrl` defaults iOS to `http://localhost:5000`, which will not work on a physical iPhone unless the backend is running on the device itself.
- `ios/Runner/AppDelegate.swift` does not configure a Google Maps API key.
- `ios/Runner/Info.plist` lacks privacy usage strings for capabilities used by the app, including location, camera/photo access, and Bluetooth.
- iOS social-login platform configuration appears incomplete: no URL schemes or provider-specific plist entries were found for Google Sign-In/Facebook login.
- Bundle id is still `com.example.drCarsFyp`.
- No Apple development team/signing configuration is present.
- `flutter_bluetooth_serial` is primarily an Android Bluetooth serial plugin, so OBD2 functionality is not iOS-ready as implemented.

## API and Workflow Mismatches

Important mismatches found during analysis:

- `lib/admin/ratings/rating.dart` calls `POST /api/feedbacks` and `GET /api/feedbacks`, but `backend/server.js` only defines `GET /feedbacks` and does not define feedback creation.
- `AuthService` contains methods for `POST /google/link` and `POST /google/complete`, but the active backend does not define those routes. Similar routes exist in `backend/models/auth.js`, but that file is not imported by `server.js` and appears stale.
- `backend/models/auth.js` also references `router` without declaring it and imports models with paths that would not resolve from its current folder, so it should be considered broken/unmounted code.
- `AuthService.baseUrl` is centralized, but document upload, service-center signup, ratings, and the 3D viewer each use their own hard-coded base URL.
- Password reset returns only a success message and does not actually send email or issue a reset token.

## Testing Status

- Flutter has only the default counter widget test, which does not match this app's UI.
- Backend has no test suite.
- No integration tests cover the appointment/receipt/service-record workflows.
- No API contract tests exist for Express routes.
- No deployment CI configuration was found.

## Repository Hygiene

Issues found:

- `backend/node_modules` is tracked by Git.
- `backend/.env` is tracked by Git.
- uploaded document images under `backend/public/documents` are tracked by Git.
- `analysis_output.txt`, `analysis_output_v2.txt`, and `analysis_output_v3.txt` are tracked at the repo root.
- There is no `.env.example`.

Recommended cleanup:

- Add `.env`, `node_modules/`, backend upload folders, and generated analysis files to `.gitignore`.
- Remove secrets and generated/vendor artifacts from Git tracking.
- Keep only lockfiles (`pubspec.lock`, `package-lock.json`) for reproducible installs.

## Recommended Next Steps

1. Fix Flutter 3.41 theme API errors by using the current `CardThemeData` and `TabBarThemeData` types or pinning to a compatible Flutter SDK.
2. Replace or patch `flutter_bluetooth_serial` so Android builds work with AGP 8.x namespace requirements.
3. Set production-safe `API_BASE_URL` and `MODEL_SERVER_URL` through build defines; remove hard-coded host URLs from feature screens.
4. Fix endpoint mismatches, especially ratings feedback and stale Google link/complete methods.
5. Add authentication/authorization middleware to backend write/admin routes.
6. Configure Android release signing, production application id, app label, and restricted API keys.
7. Configure iOS deployment target 14.0+, bundle id, signing team, privacy usage strings, Google Maps key, and social-login URL schemes.
8. Remove tracked secrets, vendored dependencies, and uploaded runtime files from Git.
9. Add focused tests for auth, role routing, appointment creation/status, service receipt completion, document upload, and admin request approval.
