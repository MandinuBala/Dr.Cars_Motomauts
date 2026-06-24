# Customer Mobile App Implementation Sequence

This guide is written for an AI agent implementing a customer-only Android/mobile app against the existing Motornauts API.

Do not modify the Motornauts backend for this integration unless a gap is explicitly promoted later. The mobile app must adapt to the existing tenant-scoped API.

## 0. Implementation Rules

- Build only customer-facing behavior.
- Do not implement staff, platform, service-center admin, fleet, or webhook flows.
- Do not call `/admin`, `/platform`, `/webhooks`, or staff-only paths.
- Use the existing `/api/v1/t/{tenantSlug}/...` API shape.
- Use Motornauts IDs as primary keys after the first response.
- Never log or persist OTP codes, session cookies, signed URLs, payment tokens, feedback tokens, or provider handoff fields outside secure short-lived storage.

## 1. App Configuration

Create a configuration module with:

- `API_BASE_URL`: base API URL without trailing slash, for example `https://api.example.com/api/v1`.
- `TENANT_SLUG`: default tenant slug for the build, for example `isira-motors-demo`.
- `REQUEST_TIMEOUT_SECONDS`: default 30.
- `ENABLE_SSE_TIMELINE`: default false for first implementation.
- `ENABLE_PAYMENT_CUSTOM_TAB`: default true.

Implementation requirements:

- Normalize `API_BASE_URL` by removing trailing slashes.
- Build tenant paths with URL encoding:

```text
{API_BASE_URL}/t/{urlEncodedTenantSlug}/...
```

- Keep environment switching explicit for development, staging, and production.
- Do not use the DR.Cars Railway URL or `localhost:5000` defaults.

## 2. HTTP Client And Storage

Create one Motornauts API client.

Client behavior:

- Default headers:
  - `Accept: application/json`
  - `Content-Type: application/json` for JSON bodies
- Preserve and send cookies from Motornauts responses.
- Parse JSON envelopes as `{ data: ... }`.
- Parse normalized errors as `{ error, message, messageKey, details, requestId }`.
- Expose typed errors to screens:
  - `Unauthenticated`
  - `Forbidden`
  - `NotFound`
  - `ValidationProblem`
  - `RateLimited`
  - `ServerError`
  - `NetworkError`

Secure storage:

- Store customer session cookies in Android secure storage or a hardened cookie jar.
- Store tenant slug and non-sensitive cached tenant profile normally.
- Do not store signed upload/download URLs beyond the active screen session.

## 3. Tenant Bootstrap

Implement before login.

Flow:

1. Read configured `TENANT_SLUG`.
2. Call `GET /t/{tenantSlug}/public-profile`.
3. Call `GET /t/{tenantSlug}/public-profile/logo` if the profile indicates logo should be shown or if the UI needs a logo fallback.
4. Cache the public profile and logo cache metadata.
5. If tenant profile fails with not-found/forbidden, stop and show tenant unavailable.

Acceptance criteria:

- Login screen shows the tenant name/branding from Motornauts, not hard-coded DR.Cars branding.
- The app does not proceed with an unknown tenant.
- The app never offers a global service-center picker as a replacement for tenant bootstrap.

## 4. Self-Registration

Use when the customer is new to the tenant.

Flow:

1. Call `GET /t/{tenantSlug}/customer-self-registration`.
2. If unavailable, show "registration unavailable; contact service center".
3. Collect customer details:
   - first name
   - last name
   - email
   - phone
   - optional address line 1
   - optional address line 2
   - optional city
4. Collect vehicle details:
   - registration number
   - vehicle type
   - make
   - model
   - year
   - fuel type
   - transmission
   - current mileage
   - optional chassis number
   - optional engine number
   - optional nickname
5. Require explicit terms acceptance.
6. Submit `POST /t/{tenantSlug}/customer-self-registration-requests`.
7. Show submitted/pending state with the returned request ID and status.

DR.Cars mapping:

- `vehicleNumber` or `plateNumber` -> `registrationNumber`.
- `brand`, `selectedBrand` -> `make`, using the Motornauts allowed vehicle maker catalog.
- `mileage` -> `currentMileage`.
- DR.Cars account creation -> Motornauts registration request, not immediate login.

Acceptance criteria:

- The submit button is disabled until terms are accepted.
- The request ID is not treated as a login session.
- Validation errors are shown next to fields.

## 5. OTP Login

Use Motornauts customer OTP auth for all customer sessions.

Flow:

1. Customer selects `EMAIL` or `SMS` channel.
2. Call `POST /t/{tenantSlug}/customer-auth/otp/request` with:
   - `channel`
   - `email` when channel is `EMAIL`
   - `phone` when channel is `SMS`
3. Store returned `challengeId` in volatile screen state.
4. Customer enters 6-digit code.
5. Call `POST /t/{tenantSlug}/customer-auth/otp/verify` with:
   - `challengeId`
   - `code`
6. Persist the returned session cookie from the response.
7. Call `GET /t/{tenantSlug}/customer-auth/session` to confirm session state.
8. Route to customer home.

Resend:

- Call `POST /t/{tenantSlug}/customer-auth/otp/resend` with `challengeId`.
- Rate-limit UI resend button locally.

Logout:

- Call `POST /t/{tenantSlug}/customer-auth/logout`.
- Clear local cookie/session state even if the network call fails.

Acceptance criteria:

- The app survives restart with the stored session cookie.
- `401` clears session and returns to OTP login.
- The app never sends DR.Cars password credentials to Motornauts.

## 6. Customer Home And Profile

After login:

1. Call `GET /t/{tenantSlug}/portal/dashboard/summary`.
2. Call `GET /t/{tenantSlug}/customers/me`.
3. Store the returned customer profile and canonical customer ID.
4. Render home cards for:
   - active appointments
   - active repair orders
   - pending approvals
   - invoices/payment state
   - vehicles

Profile edit:

1. Load current profile.
2. Submit `PATCH /t/{tenantSlug}/customers/me` with only changed fields.
3. Refresh profile from the server after success.

Acceptance criteria:

- Customer profile data is tenant-scoped.
- The app does not expose customer search/list screens.
- Stale dashboard data is visibly refreshed or marked stale.

## 7. Vehicle Garage

List:

1. Call `GET /t/{tenantSlug}/vehicles`.
2. Call `GET /t/{tenantSlug}/vehicles/summary` for summary badges.
3. Store `vehicleId` for each vehicle.

Create:

1. Require `tenantCustomerId` from profile/session.
2. Submit `POST /t/{tenantSlug}/vehicles`.
3. Refresh list after success.

Update:

1. Open `GET /t/{tenantSlug}/vehicles/{vehicleId}`.
2. Submit `PATCH /t/{tenantSlug}/vehicles/{vehicleId}` with changed fields.
3. Refresh the vehicle detail.

Acceptance criteria:

- `registrationNumber` is display/search metadata, not the primary key.
- All later calls use `vehicleId`.
- The app handles verification pending/rejected/request-more-info states if returned.

## 8. Document Uploads

Implement exactly as a signed upload flow.

Flow:

1. Customer chooses a document image/PDF.
2. Determine:
   - `documentType`
   - `fileName`
   - `mimeType`
   - `fileSizeBytes`
   - optional SHA-256 checksum
3. Call `POST /t/{tenantSlug}/vehicles/{vehicleId}/documents/upload-intents`.
4. Receive:
   - `document`
   - `upload.url`
   - optional `upload.headers`
   - upload expiry timestamp
5. Upload the file bytes directly to `upload.url` using the returned headers and required method.
6. Call `POST /t/{tenantSlug}/vehicles/{vehicleId}/documents/{documentId}/complete-upload` with `{}`.
7. Refresh `GET /t/{tenantSlug}/vehicles/{vehicleId}/documents`.
8. Show status:
   - pending upload
   - quarantined/processing
   - available
   - failed verification
   - expired

View/download:

1. Call `view-url` for inline preview.
2. Call `download-url` for attachment download.
3. Open the returned signed URL immediately.
4. Re-request URL when expired.

Acceptance criteria:

- No multipart upload is sent to the API server.
- Signed upload/download URLs are not written to logs.
- Failed verification shows a retry path.

## 9. Booking Flow

Flow:

1. Ensure customer has at least one vehicle.
2. Call `GET /t/{tenantSlug}/appointments/booking-options`.
3. Render branch and service package choices from API data.
4. Customer selects:
   - vehicle
   - branch
   - service package
   - requested date/time
   - optional notes/complaints
5. Call `GET /t/{tenantSlug}/appointments/availability` with:
   - `branchId`
   - `servicePackageId`
   - `from`
   - `to`
6. Customer picks an available slot.
7. Generate stable `idempotencyKey` for the submit attempt.
8. Call `POST /t/{tenantSlug}/appointments`.
9. Refresh `GET /t/{tenantSlug}/appointments`.

DR.Cars mapping:

- `serviceCenterUid` -> not used; tenant is already selected.
- DR.Cars `branch` -> Motornauts `branchId`.
- DR.Cars `serviceTypes` -> Motornauts `servicePackageId`.
- DR.Cars `date` + `time` -> ISO `requestedStartAt`.

Acceptance criteria:

- Booking is impossible without selected `vehicleId`, `branchId`, and `servicePackageId`.
- Duplicate taps reuse the same idempotency key or disable the button until response.
- Availability ranges do not exceed 30 days.

## 10. Appointment List And Detail

Flow:

1. Call `GET /t/{tenantSlug}/appointments`.
2. Render upcoming, active, past, cancelled/no-show groups from server statuses.
3. Open `GET /t/{tenantSlug}/appointments/{appointmentId}` for detail.
4. Only show status actions that are explicitly supported by server responses/product copy.
5. If a status action is shown, call `PATCH /t/{tenantSlug}/appointments/{appointmentId}/status`.

Acceptance criteria:

- The app does not invent status transitions.
- `403` or workflow errors hide/disable the action and refresh the appointment.

## 11. Repair Orders And Timeline

Initial version:

1. Call `GET /t/{tenantSlug}/repair-orders`.
2. Open `GET /t/{tenantSlug}/repair-orders/{repairOrderId}` for details.
3. Call `GET /t/{tenantSlug}/repair-orders/{repairOrderId}/timeline`.
4. Poll timeline every 30 to 60 seconds while the screen is visible.

SSE enhancement:

1. Connect to `GET /t/{tenantSlug}/repair-orders/{repairOrderId}/timeline/stream`.
2. Include customer session cookie.
3. On reconnect, include `Last-Event-ID` if available.
4. Fall back to polling on network/SSE failure.

Acceptance criteria:

- Only customer-visible events are rendered.
- Internal notes and staff-only states are never displayed.
- Timeline failures do not break the rest of repair-order detail.

## 12. Estimate Approval

Flow:

1. A repair order or deep link identifies `repairOrderId` and `estimateId`.
2. Call `GET /t/{tenantSlug}/repair-orders/{repairOrderId}/estimates/{estimateId}`.
3. Render line items and customer-visible notes.
4. Customer marks each required line as approved or rejected.
5. Generate `idempotencyKey`.
6. Submit `POST /t/{tenantSlug}/repair-orders/{repairOrderId}/estimates/{estimateId}/decisions` with:
   - `estimateVersion`
   - `idempotencyKey`
   - `decisions`
7. Refresh the estimate and repair-order timeline.

Acceptance criteria:

- The app handles stale estimate version conflicts by refreshing.
- Partial line decisions are only submitted when the UI clearly allows them.
- Duplicate line item decisions are prevented before submit.

## 13. Invoices, PDFs, And Service History

Invoices:

1. Call `GET /t/{tenantSlug}/invoices`.
2. Open `GET /t/{tenantSlug}/invoices/{invoiceId}`.

Invoice PDF:

1. Call `GET /t/{tenantSlug}/portal/invoices/{invoiceId}/pdf`.
2. If available, call `POST /t/{tenantSlug}/portal/invoices/{invoiceId}/pdf/download-url`.
3. Open the signed URL.

Estimate PDF:

1. Call `GET /t/{tenantSlug}/repair-orders/{repairOrderId}/estimates/{estimateId}/pdf`.
2. If available, call `POST /t/{tenantSlug}/repair-orders/{repairOrderId}/estimates/{estimateId}/pdf/download-url`.

Inspection PDF:

1. Call `GET /t/{tenantSlug}/repair-orders/{repairOrderId}/inspections/{inspectionId}/pdf`.
2. If available, call `POST /t/{tenantSlug}/repair-orders/{repairOrderId}/inspections/{inspectionId}/pdf/download-url`.

Service history PDF:

1. Call `GET /t/{tenantSlug}/repair-orders/{repairOrderId}/service-history/pdf`.
2. If available, call `POST /t/{tenantSlug}/repair-orders/{repairOrderId}/service-history/pdf/download-url`.

Acceptance criteria:

- Signed URLs are opened immediately and re-requested on expiry.
- The app shows pending/unavailable PDF states gracefully.
- The app does not create arbitrary service records; it displays workflow-generated service history.

## 14. Payment Links And Provider Handoff

Payment requests are tokenized public flows.

Deep link handling:

1. Parse `tenantSlug`, `paymentRequestId`, and public token from link.
2. Call `GET /t/{tenantSlug}/payment-requests/{paymentRequestId}?token={token}`.
3. Render amount, status, expiry, tenant, and customer-safe instructions.
4. If response includes `providerHandoff`, open provider checkout using only:
   - `providerHandoff.action`
   - `providerHandoff.method`
   - `providerHandoff.fields`
5. Return to the app and refresh payment request status.

Rules:

- Prefer browser/custom-tab for provider checkout.
- Never construct PayHere/WebXPay fields locally.
- Never expose or log raw callbacks, provider order IDs, callback signatures, merchant secrets, hash keys, or private provider metadata.
- Treat PayHere/IPN callback state as authoritative; return/cancel pages are not proof of payment.

Acceptance criteria:

- Expired/cancelled/paid states are terminal unless the server says otherwise.
- Provider handoff is hidden when missing or not ready.
- The app refreshes after returning from external checkout.

## 15. Feedback Deep Links

Flow:

1. Parse `tenantSlug` and feedback `token` from link.
2. Call `GET /t/{tenantSlug}/feedback/{token}`.
3. Render vehicle/service context.
4. Customer selects rating 1 through 5 and optional comment.
5. Call `POST /t/{tenantSlug}/feedback/{token}`.
6. Show submitted state.

Acceptance criteria:

- Does not require active customer session.
- Expired or already-submitted tokens show a clear terminal state.
- Comments are not rendered as HTML.

## 16. Compliance Request Intake

Optional customer privacy/legal request flow.

Flow:

1. Customer opens privacy/data request screen.
2. Collect request type, requester details, summary, and optional sanitized evidence.
3. Submit `POST /t/{tenantSlug}/compliance-requests`.
4. Show receipt/reference from response.

Acceptance criteria:

- Do not use this for general support.
- Do not upload sensitive document files through this route.
- Do not mark legal/counsel review items complete in the app.

## 17. DR.Cars Feature Mapping

Use this mapping when refactoring the existing Android app:

| DR.Cars concept | Motornauts customer app replacement |
|---|---|
| `/login` password/JWT | Customer OTP request/verify/session cookie |
| `/user`, `/users` | Self-registration request, then profile via `/customers/me` |
| `uid` | Motornauts profile/customer IDs returned by API |
| `vehicleNumber` / `plateNumber` | `registrationNumber` attribute |
| Vehicle record primary key by user | `vehicleId` primary key |
| `/service-centers?city=...` | Tenant is preselected; choose `branchId` from booking options |
| `serviceTypes` array | `servicePackageId` |
| `/service-receipts` | Repair order, estimate, invoice, payment, and service-history flows |
| Manual service record creation | Not supported; service history comes from workflow evidence |
| Direct `/documents/upload` | Upload intent, direct object upload, complete upload |
| Ratings `/api/feedbacks` | Tokenized feedback request/submit |
| 3D model `/models/:filename` | Not backed by Motornauts customer API |
| OBD2 Bluetooth diagnostics | Local-only unless future backend scope is approved |

## 18. Error Handling Matrix

| Condition | Required app behavior |
|---|---|
| Network timeout | Show retry; keep local form state. |
| `400` or validation problem | Show field errors from `details`; do not clear form. |
| `401` | Clear session and route to OTP login. |
| `403` | Show unavailable/forbidden; do not reveal cross-tenant existence. |
| `404` | Show safe not-found; do not retry with guessed IDs. |
| `409` | Refresh resource; show stale-state retry. |
| `429` | Back off; disable repeated actions temporarily. |
| Signed URL expired | Request a fresh signed URL. |
| Upload verification failed | Show retry with a new upload intent. |
| Feature disabled or setup incomplete | Show module unavailable copy; do not crash. |
| Payment token expired | Show terminal expired state. |
| Feedback token expired/submitted | Show terminal feedback state. |

## 19. Suggested Build Order

1. API client, envelope parser, error parser, cookie jar.
2. Tenant bootstrap screen.
3. OTP login/session/logout.
4. Profile home and dashboard summary.
5. Vehicle list/create/update.
6. Booking options, availability, create appointment, list appointments.
7. Repair-order list/detail/timeline polling.
8. Documents upload intent and document list.
9. Estimate detail and approval decisions.
10. Invoice list/detail and PDF download URLs.
11. Payment request deep links and provider handoff.
12. Feedback deep links and submission.
13. Optional compliance request intake.
14. SSE timeline enhancement.
15. Polish offline/retry/loading states and analytics redaction.

## 20. Final Acceptance Checklist

- Customer can register or log in by OTP for one tenant.
- Customer can create and manage vehicles using Motornauts IDs.
- Customer can book an appointment from API-provided branches/services.
- Customer can see appointments, repair orders, timeline, invoices, and PDFs.
- Customer can upload documents through upload intents.
- Customer can approve/reject estimate line items.
- Customer can open payment request links and submit feedback links.
- App handles session expiry, validation errors, unavailable modules, signed URL expiry, and token expiry.
- No staff/platform/admin/fleet routes are called.
- No secrets, tokens, signed URLs, or provider handoff fields are logged.
