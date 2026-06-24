# Motornauts Customer API Mobile Migration

## Summary

The Flutter app has been migrated from the legacy DR.Cars role-based API to the tenant-scoped Motornauts customer API documented in `docs/mobile-integration/`.

Default build configuration:

- `API_BASE_URL=http://localhost:4000/api/v1`
- `TENANT_SLUG=isira-motors-demo`
- `REQUEST_TIMEOUT_SECONDS=30`
- `ENABLE_SSE_TIMELINE=false`
- `ENABLE_PAYMENT_CUSTOM_TAB=true`

All values are overridable with `--dart-define`. Android emulator users should run with `--dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1` when targeting a host-machine API.

## Added

- New Motornauts client layer under `lib/motornauts/`.
  - Tenant path builder with URL-encoded tenant slug.
  - JSON envelope parsing for `{ "data": ... }`.
  - Normalized API error mapping for unauthenticated, forbidden, not-found, validation, rate-limit, server, and network failures.
  - Secure session-cookie persistence for `motornauts_customer_session`.
  - Signed object upload support using upload intents and direct `PUT`.
  - Payload helpers for OTP, registration, profile, vehicles, documents, bookings, estimate decisions, feedback, and compliance.
  - Payment/feedback deep-link parsing.
- New customer-only Flutter UI.
  - Tenant bootstrap before login.
  - OTP login with email/SMS, verify, resend throttling, session restore, and logout.
  - Self-registration request flow with tenant terms gating.
  - Dashboard/profile summary.
  - Vehicle garage with create/edit/detail and signed document upload/view/download.
  - Booking flow using API-provided vehicles, branches, service packages, availability, and idempotency keys.
  - Appointment list/detail with server-provided status transitions only.
  - Repair-order list/detail with timeline polling.
  - Estimate detail with line-item approve/reject decisions.
  - Invoice detail and generated PDF download URL flows.
  - Payment request and feedback tokenized link screens.
  - Compliance request intake.
  - Local-only OBD and 3D placeholder screens that do not sync to Motornauts.
- Native support.
  - Android `motornauts://` and placeholder HTTPS deep-link filters.
  - iOS `motornauts` URL scheme.
  - iOS camera/photo usage descriptions for customer-selected document uploads.
  - Android local cleartext exceptions for `localhost`, `127.0.0.1`, and `10.0.2.2`.
- Tests.
  - Config/path generation, API error parsing, cookie extraction, payload compaction, idempotency keys, link parsing.
  - API client session cookie behavior, 401 clearing, and customer endpoint path coverage.
  - Widget coverage for tenant unavailable, OTP login, and registration terms gating.

## Changed

- `lib/main.dart` now starts the Motornauts customer app and no longer routes by legacy DR.Cars roles.
- `pubspec.yaml` now keeps only customer-app dependencies: HTTP, secure storage, file picker, app links, URL launcher, WebView, shared preferences, and Flutter basics.
- Android/iOS platform files were updated for the new dependency set and verified builds.
- The app now treats Motornauts IDs as canonical IDs after API responses, especially `tenantCustomerId`, `vehicleId`, `appointmentId`, `repairOrderId`, `estimateId`, and `invoiceId`.
- Payment provider handoff uses only the server-returned `providerHandoff.action`, `method`, and `fields`. The app does not construct provider payloads.

## Removed

- Legacy DR.Cars password/JWT/social-login screens and services.
- Google/Facebook sign-in dependencies and Android Facebook string resources.
- OneSignal/push dependency and initialization.
- Staff, app-admin, service-center, request-approval, and marketplace-style screens.
- Direct multipart document upload to `/documents/upload`.
- Legacy service receipt and manual service record flows.
- Hard-coded DR.Cars Railway and `localhost:5000` API defaults.
- Google Maps, geolocation, ML Kit OCR, Bluetooth OBD package usage, share, toast, old notification, and old calendar dependencies from the active app.

## Unsupported Or Local-Only

- OBD diagnostics remain local-only because the Motornauts customer API has no OBD/device endpoints.
- 3D vehicle viewing remains local-only because Motornauts does not expose a customer GLB/model-serving endpoint.
- Push notification device registration is not implemented because the customer API catalog has no push-token endpoint.
- SSE timeline streaming remains disabled by default; repair-order timeline uses polling.
- Universal/app links need a real production domain and associated-domain files. The app currently supports `motornauts://` and documents a placeholder HTTPS host for Android.

## Verification

Completed successfully:

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- `flutter build ios --simulator`

Source checks:

- Active `lib/` source no longer contains legacy `/login`, `/user`, `/users`, `/service-receipts`, `/service-records`, `/documents/upload`, `/feedbacks`, staff/admin/platform/webhook routes, social login strings, Railway URL defaults, or `localhost:5000` defaults.
- No signed URLs, session cookies, OTP codes, payment tokens, or provider fields are logged by the new source.

Build notes:

- Flutter upgraded some Android and iOS project metadata during verified builds.
- Android build emits deprecation warnings for older Gradle/AGP/Kotlin plugin versions, but the debug APK builds successfully.
