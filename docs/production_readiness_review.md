# Production Readiness Review

Report date: 2026-06-23

## Executive Summary

The current codebase is not production-ready. The most urgent blockers are security and release configuration issues: backend secrets are tracked in Git, backend/admin APIs are effectively public, social login trusts client-supplied identity values, and Android release builds are still configured with the template application id and debug signing.

This report is documentation-only. It does not change source code, app interfaces, schemas, dependencies, Git history, or deployment configuration.

## Review Method

The review covered the Flutter client, Node/Express backend, mobile build configuration, repository hygiene, tests, and release readiness. Three read-only sub-agents reviewed separate areas:

- Backend/API/security: `backend/server.js`, `backend/models`, `backend/middleware`, uploads, auth, validation, dependencies.
- Flutter client/runtime quality: `lib/`, auth/session flow, endpoints, maps, OBD, appointments, documents, async lifecycle, state management.
- Release/config hygiene: `pubspec.yaml`, Android/iOS config, README/docs, tracked assets, secrets, tests, CI readiness.

Local checks performed during planning:

- `flutter analyze` - failed with 2 current analyzer errors and many warnings/infos.
- `npm test` in `backend/` - failed because the test script is still a placeholder.
- `npm audit --omit=dev` in `backend/` - reported 3 vulnerabilities.
- Tracked-file inspection - confirmed `backend/.env`, `backend/node_modules`, and uploaded documents are tracked.

## Immediate Production Blockers

1. Rotate the exposed MongoDB and JWT secrets immediately, remove `backend/.env` from Git history, and move secrets into deployment/CI secret stores.
2. Add backend authentication, role checks, and ownership checks before exposing the API to real users.
3. Replace client-trusted Google/Facebook login with server-side provider token verification.
4. Fix Android release identity/signing before any production build.
5. Remove public unauthenticated document uploads and public user document serving.
6. Resolve current build/analyzer failures and add meaningful test/CI coverage.

## Prioritized Findings

| Severity | Finding | Evidence | Impact | Recommended Remediation |
| --- | --- | --- | --- | --- |
| Critical | Backend secrets are tracked in Git. | `backend/.env:1`, `backend/.env:2` | Database credentials and JWT signing material should be treated as compromised once committed. Attackers could access data or forge sessions if the repository is shared or leaked. | Rotate the database user/password and JWT secret, purge the file from Git history, add `.env` to `.gitignore`, commit `.env.example` with placeholder names only, and load secrets from the deployment environment. |
| Critical | Backend has no enforced auth/authorization on production routes. | `backend/middleware/middleware.js:4`, `backend/server.js:915`, `backend/server.js:934`, `backend/server.js:451`, `backend/server.js:1203` | Admin approvals, user deletion, document uploads, appointments, service receipts, and user data can be accessed or mutated without a verified user. | Apply JWT middleware to protected routes, add role-based admin/service-center/owner checks, enforce ownership checks on every user-owned resource, and return 401/403 consistently. |
| Critical | Social login trusts client-supplied identity. | `backend/server.js:1079`, `backend/server.js:1126` | Any client can claim a provider id/email and receive a valid app JWT, allowing account takeover or fake account creation. | Accept provider id tokens/access tokens, verify them server-side with Google/Facebook, bind accounts only from verified provider claims, and reject unverified email/provider data. |
| Critical | Android release is signed with debug keys and still uses the template package id. | `android/app/build.gradle.kts:24`, `android/app/build.gradle.kts:26`, `android/app/build.gradle.kts:39` | Debug-signed release artifacts and `com.example` package identity are not acceptable for app store release and can break upgrades, Play signing, and trust assumptions. | Set a real application id, configure release keystore signing via ignored local properties or CI secrets, and fail release builds when signing config is missing. |
| High | Password hashes and sensitive user fields are returned by API responses. | `backend/models/User.js:9`, `backend/server.js:106`, `backend/server.js:187`, `backend/server.js:325` | User password hashes and PII can leak to clients and logs, increasing impact if any endpoint or client is compromised. | Mark password fields `select: false`, create explicit response DTOs, and never return full Mongoose user documents from public handlers. |
| High | Public document upload and serving is unsafe. | `backend/server.js:51`, `backend/server.js:57`, `backend/server.js:61`, `backend/server.js:1203` | Anyone can upload files, files have no size/type limits, original filenames are retained, and uploaded user documents are publicly served with permissive CORS. | Require auth and ownership, store files outside public Git-tracked directories, validate MIME and file signatures, set size/count limits, generate opaque filenames, strip metadata, and serve files through authorized endpoints. |
| High | Runtime and generated files are tracked. | `.gitignore:1`, tracked `backend/node_modules`, tracked `backend/public/documents` | The repository contains installed dependencies and user-uploaded documents, making clones heavy, noisy, and privacy-sensitive. It also increases review and supply-chain risk. | Add ignore rules for `.env`, `node_modules`, runtime uploads, and analysis outputs. Remove tracked runtime files from the index and regenerate dependencies from lockfiles. |
| High | Backend dependency audit reports known DoS advisories. | `backend/package.json:16`, `backend/package.json:19`, `backend/package-lock.json:845`, `backend/package-lock.json:987` | Vulnerable upload/routing/query dependencies may allow denial-of-service attacks against the backend. | Run controlled dependency upgrades, regenerate the lockfile, rerun `npm audit --omit=dev`, and add audit checks to CI. |
| High | Mass assignment allows privilege and data tampering. | `backend/server.js:75`, `backend/server.js:100`, `backend/server.js:399`, `backend/server.js:436`, `backend/server.js:530` | Clients can submit arbitrary fields such as roles, ownership ids, statuses, or other privileged data into database writes. | Add per-route allowlists and schema validation. Never accept role, owner, password hash, or privileged status fields from arbitrary clients. |
| High | Client stores tokens but does not use them for authorization. | `lib/auth/auth_service.dart:31`, `lib/auth/auth_service.dart:426`, `lib/main.dart:64` | The app persists an auth token but API calls generally do not attach `Authorization` headers, and screen access trusts local/fetched role state. | Build a central authenticated HTTP client, attach bearer tokens, handle expiry/logout, and rely on backend authorization instead of client-only role routing. |
| High | Production endpoints are inconsistent and platform-dependent. | `lib/auth/auth_service.dart:13`, `lib/service/document_service.dart:7`, `lib/auth/signup_service.dart:161`, `lib/admin/ratings/rating.dart:21` | Android, web, iOS, desktop, documents, signup, and ratings can call different hosts including localhost, Railway, or emulator-only addresses. Production builds may silently target the wrong backend. | Centralize API base URL configuration, require release `--dart-define` or flavors, remove hard-coded screen-level URLs, and fail release builds when production config is missing. |
| High | Google Maps and related client keys are embedded in the app. | `lib/map/mapscreen.dart:19`, `android/app/src/main/AndroidManifest.xml:26`, `android/app/google-services.json:93` | Client-side keys can be extracted from app bundles. If unrestricted, they can be abused for quota theft or unexpected billing. | Rotate if necessary, restrict keys by package name, signing certificate, platform, and API scope. Proxy high-cost Places/Directions calls if quota abuse is a concern. |
| High | Mobile permission/privacy release config is incomplete. | `android/app/src/main/AndroidManifest.xml:3`, `android/app/src/main/AndroidManifest.xml:14`, `ios/Runner/Info.plist:1` | Broad location, Bluetooth, camera, storage, and exact alarm permissions require clear store declarations and user-facing purpose strings. iOS builds can be rejected or crash when permissions are requested without usage descriptions. | Remove unused permissions, add iOS usage strings for camera/photos/location/Bluetooth, document exact-alarm justification, and prepare Play/App Store privacy declarations. |
| High | Backend runtime metadata is inconsistent. | `README.md:142`, `backend/package-lock.json:102`, `backend/package-lock.json:797`, `backend/package.json:6` | README says Node 18, but dependencies require a newer Node runtime. The backend has no `engines` field and test script intentionally fails. | Pin the supported Node version in `backend/package.json`, README, CI, and deployment config. Replace the placeholder test script with real tests. |
| High | Current Flutter analyzer errors block clean release validation. | `lib/theme/app_theme.dart:176`, `lib/theme/app_theme.dart:320` | `flutter analyze` fails because `CardTheme` and `TabBarTheme` are no longer assignable to the current Flutter theme data types. | Update theme usage for the installed Flutter SDK, then make `flutter analyze` a required CI check. |
| Medium | Service receipt finishing is not idempotent. | `backend/server.js:639`, `backend/server.js:654`, `backend/server.js:684`, `backend/server.js:698` | Retrying or repeating a status update to `finished` creates duplicate service history records and duplicated costs. | Create service records only on a real transition to `finished`, store source receipt ids, enforce uniqueness, and consider transactions. |
| Medium | Service-center fallback password is predictable. | `backend/server.js:945`, `backend/server.js:949`, `backend/server.js:962` | If a request lacks a stored hash, the system uses a deterministic password pattern based on username. | Remove deterministic fallback credentials. Use invite links or forced password reset flows. |
| Medium | Dead/broken duplicate backend code lives under `models`. | `backend/models/auth.js:9`, `backend/models/auth.js:18`, `backend/models/auth.js:216` | The file creates a second Express app, references an undefined `router`, and has invalid relative imports. This confuses maintainers and can break if accidentally imported. | Delete it or move valid route code into proper route modules with tests. |
| Medium | OBD polling can race and leak Bluetooth resources. | `lib/obd/OBD2.dart:469`, `lib/obd/OBD2.dart:498`, `lib/obd/OBD2.dart:1021` | Overlapping polling can complete the wrong Bluetooth command, and disposal cancels the timer but not all connection resources. | Serialize OBD commands, block overlapping polls, check `mounted` after awaits, and close connections/subscriptions in `dispose`. |
| Medium | Multiple async UI flows can update state or navigate after disposal. | `lib/auth/signin.dart:60`, `lib/auth/signin.dart:78`, `lib/user/main_dashboard.dart:66` | Users navigating away during network calls can hit runtime exceptions or unexpected navigation. | Add `if (!mounted) return` after awaited calls before `setState`, navigation, dialogs, or snackbars. |
| Medium | Map screen has lifecycle and range-crash risks. | `lib/map/mapscreen.dart:209`, `lib/map/mapscreen.dart:329` | Debounced callbacks can fire after disposal, and empty photo arrays can throw range exceptions. | Cancel debounce timers in `dispose`, check `mounted`, and guard list indexing with `isNotEmpty`. |
| Medium | Appointment capacity is enforced client-side. | `lib/appointments/appointments.dart:289`, `lib/appointments/appointments.dart:985` | Two clients can book the same slot because availability is calculated locally and not revalidated on submit. | Move slot capacity checks to the server, return conflict responses, and handle conflicts in the UI. |
| Medium | Vehicle document date parsing can crash on malformed data. | `lib/models/vehicle_document.dart:24` | `DateTime.parse` on missing or malformed backend data can crash document/profile screens. | Use `DateTime.tryParse`, tolerate missing values, and surface invalid records gracefully. |
| Medium | Driving licence data is stored only in local preferences. | `lib/user/driving_licence_screen.dart:217` | Sensitive licence details are lost on reinstall/device change and are not protected like identity data should be. | Store through an authenticated backend API or encrypted local storage with explicit sync rules. |
| Medium | Receipt and service price validation is weak. | `lib/service/conformation_receipt.dart:59`, `lib/service/conformation_receipt.dart:140` | Arbitrary strings are accepted for prices, and invalid values can silently become `0`. | Use numeric input formatters, validate non-negative values, and block submit until all selected services have valid prices. |
| Medium | Service-center duplicate checks are query-string unsafe and race-prone. | `lib/auth/signup_service.dart:158` | Raw values containing spaces, plus signs, or ampersands can produce incorrect checks, and client-side checks can race with later submissions. | Build URIs with encoded query parameters and treat backend uniqueness errors as final authority. |
| Medium | 3D model delivery is fragile and inconsistent. | `backend/server.js:28`, `assets/html/car_viewer.html:267`, `README.md:274` | Backend, viewer, and docs disagree on model paths, and local GLB files are Git LFS pointers rather than usable binaries. | Align route shape, app loader, and docs. Ensure real GLB files are available in production storage/CDN. |
| Medium | Repository and test hygiene are not production-grade. | `.gitignore:1`, `test/widget_test.dart:14`, `backend/package.json:6` | The only Flutter test is the template counter test, backend tests are absent, and generated/runtime outputs are tracked. | Add meaningful Flutter and backend tests, CI for analyze/test/audit, and clean tracked generated/runtime files. |
| Low | Localization and controller lifecycle gaps remain. | `lib/user/user_profile.dart:791`, `lib/auth/signin.dart:23`, `lib/service/service_history.dart:25` | Users may see raw localization keys, and undisposed controllers can leak resources over time. | Add missing translation keys and dispose controllers/dialog controllers consistently. |

## Verification Status

The following checks were run during planning and should be treated as the current baseline for this review:

| Check | Current Result | Notes |
| --- | --- | --- |
| `flutter analyze` | Fails | 264 total issues were reported; the release-blocking items are 2 errors in `lib/theme/app_theme.dart:176` and `lib/theme/app_theme.dart:320`. |
| `npm test` in `backend/` | Fails | `backend/package.json:6` runs `echo "Error: no test specified" && exit 1`. |
| `npm audit --omit=dev` in `backend/` | Fails | 3 vulnerabilities were reported: 2 high severity and 1 moderate severity. |
| Tracked-file inspection | Fails hygiene expectations | `backend/.env`, `backend/node_modules`, and uploaded files under `backend/public/documents` are tracked. |

## Assumptions and Limits

- This report is a findings document only. It intentionally does not fix the issues.
- Existing `docs/application_analysis.md` and `docs/api_endpoints.md` were not changed by this planned documentation update.
- Secret values and API key values are intentionally omitted from this report. The presence of `MONGO_URI` and `JWT_SECRET` in `backend/.env` is enough to require rotation.
- Secret rotation, Git history cleanup, auth hardening, dependency upgrades, mobile release signing, and CI setup should be handled as follow-up production-hardening work.
