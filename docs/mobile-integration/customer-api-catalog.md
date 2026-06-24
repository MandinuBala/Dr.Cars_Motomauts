# Customer API Catalog

This catalog lists the existing customer and public Motornauts APIs that a tenant-scoped mobile app can use without backend changes.

Base path:

```text
{API_BASE_URL}/api/v1
```

Tenant path prefix:

```text
/t/{tenantSlug}
```

Unless a route explicitly says otherwise, JSON responses use `{ "data": ... }`.

## 1. Tenant Bootstrap

Use these before login to show tenant branding and decide whether the customer app can continue.

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/t/{tenantSlug}/public-profile` | Public | Load public tenant name, slug, customer-facing brand/settings, and tenant availability. |
| `GET` | `/t/{tenantSlug}/public-profile/logo` | Public | Load active tenant logo image bytes. This route is not JSON. |

Mobile behavior:

- Fail closed if the tenant cannot be resolved.
- Cache tenant profile and logo with normal HTTP cache semantics.
- Do not infer a tenant from DR.Cars service-center IDs.

## 2. Customer Self-Registration

Use this when the customer does not yet have an approved customer profile for the tenant.

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/t/{tenantSlug}/customer-self-registration` | Public | Check whether public self-registration is enabled and get tenant terms copy. |
| `POST` | `/t/{tenantSlug}/customer-self-registration-requests` | Public | Submit a tenant-scoped customer and vehicle registration request. |

Important request fields for submit:

- Customer: `firstName`, `lastName`, `email`, `phone`, optional address fields, `termsAccepted`, `marketingConsent`.
- Vehicle: `registrationNumber`, `vehicleType`, `make`, `model`, `year`, `fuelType`, `transmission`, `currentMileage`, optional chassis/engine/nickname fields.
- Motornauts expects Sri Lankan phone formatting and canonical vehicle make values.

Mobile behavior:

- Show the tenant terms before submission.
- Do not immediately assume the customer can log in; approval can be an operator workflow.
- Store the request ID only for local display. It is not a login credential.

## 3. Customer OTP Authentication

Use this for all customer sessions. Do not implement DR.Cars password/JWT login for Motornauts customers.

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `POST` | `/t/{tenantSlug}/customer-auth/otp/request` | Public | Request an email or SMS OTP challenge. |
| `POST` | `/t/{tenantSlug}/customer-auth/otp/resend` | Public | Resend a challenge by `challengeId`. |
| `POST` | `/t/{tenantSlug}/customer-auth/otp/verify` | Public | Verify the 6-digit OTP. On success, the server sets the customer session cookie. |
| `GET` | `/t/{tenantSlug}/customer-auth/session` | Customer cookie | Get the current customer session. |
| `POST` | `/t/{tenantSlug}/customer-auth/logout` | Customer cookie | End the customer session and clear the cookie. |

Mobile behavior:

- Persist the returned cookie in secure storage or a secure cookie jar.
- Send the cookie on later tenant customer requests.
- Treat `401` as session expired and restart OTP login.
- The Clerk development OTP from local testing is not production behavior.

## 4. Customer Profile

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/t/{tenantSlug}/customers/me` | Customer cookie | Load the signed-in customer's profile. |
| `PATCH` | `/t/{tenantSlug}/customers/me` | Customer cookie | Update customer profile fields. |

Editable fields:

- `firstName`
- `lastName`
- `phone`
- `addressLine1`
- `addressLine2`
- `city`

Mobile behavior:

- Use the returned `tenantCustomerId` or equivalent customer ID from profile/session data as the customer anchor for vehicle creation.
- Do not expose staff-only customer search/list APIs in the mobile app.

## 5. Vehicles

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/t/{tenantSlug}/vehicles` | Customer cookie | List vehicles visible to the customer. |
| `GET` | `/t/{tenantSlug}/vehicles/summary` | Customer cookie | Load vehicle summary counts/statuses. |
| `POST` | `/t/{tenantSlug}/vehicles` | Customer cookie | Create a customer vehicle. |
| `GET` | `/t/{tenantSlug}/vehicles/{vehicleId}` | Customer cookie | Load one vehicle. |
| `PATCH` | `/t/{tenantSlug}/vehicles/{vehicleId}` | Customer cookie | Update allowed vehicle fields. |

Create fields:

- `tenantCustomerId`
- `registrationNumber`
- `vehicleType`
- `make`
- `model`
- `year`
- `fuelType`
- `transmission`
- `currentMileage`
- optional `chassisNumber`, `engineNumber`, `nickname`, `ownershipStatus`

Mobile behavior:

- Map DR.Cars `vehicleNumber` or `plateNumber` to Motornauts `registrationNumber`.
- Store `vehicleId` as the primary key for later calls.
- Expect verification statuses and safe not-found behavior for unauthorized/cross-tenant IDs.

## 6. Vehicle Documents

Documents use a three-step private upload flow. There is no direct multipart document endpoint.

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/t/{tenantSlug}/vehicles/{vehicleId}/documents` | Customer cookie | List documents for a vehicle. |
| `POST` | `/t/{tenantSlug}/vehicles/{vehicleId}/documents/upload-intents` | Customer cookie | Create a signed upload intent and pending document record. |
| `POST` | `/t/{tenantSlug}/vehicles/{vehicleId}/documents/{documentId}/complete-upload` | Customer cookie | Tell the API to verify the uploaded object. |
| `POST` | `/t/{tenantSlug}/vehicles/{vehicleId}/documents/{documentId}/view-url` | Customer cookie | Get short-lived inline access URL. |
| `POST` | `/t/{tenantSlug}/vehicles/{vehicleId}/documents/{documentId}/download-url` | Customer cookie | Get short-lived attachment access URL. |

Upload intent request fields:

- `documentType`: `REGISTRATION_CERTIFICATE`, `INSURANCE`, `REVENUE_LICENSE`, `EMISSION_TEST`, or `OTHER`.
- `fileName`
- `mimeType`: `application/pdf`, `image/jpeg`, `image/png`, or `image/webp`.
- `fileSizeBytes`
- optional `checksumSha256`

Mobile upload sequence:

1. Call `upload-intents`.
2. Upload the file directly to the returned signed upload URL with the returned headers.
3. Call `complete-upload`.
4. Poll/list documents until the document is available, or show processing/quarantine/failure state.
5. Call `view-url` or `download-url` only when the document is available.

## 7. Appointments And Booking

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/t/{tenantSlug}/appointments/booking-options` | Customer cookie | Load allowed branches and service packages for booking. |
| `GET` | `/t/{tenantSlug}/appointments/availability` | Customer cookie | Check slots for `branchId`, `servicePackageId`, `from`, and `to`. |
| `GET` | `/t/{tenantSlug}/appointments` | Customer cookie | List the customer's appointments. |
| `POST` | `/t/{tenantSlug}/appointments` | Customer cookie | Create a customer booking. |
| `GET` | `/t/{tenantSlug}/appointments/{appointmentId}` | Customer cookie | Load appointment details. |
| `PATCH` | `/t/{tenantSlug}/appointments/{appointmentId}/status` | Customer cookie | Submit a customer-permitted status transition where allowed by backend policy. |

Create booking fields:

- `vehicleId`
- `branchId`
- `servicePackageId`
- `requestedStartAt`
- optional `requestedEndAt`
- optional `mileageAtBooking`
- optional `customerNotes`
- optional `complaints`
- `idempotencyKey`

Mobile behavior:

- Always call booking options before rendering branch/service selectors.
- Always call availability before booking.
- Generate a stable idempotency key per attempted booking submission.
- Map DR.Cars service center selection to the selected tenant branch, not a global `serviceCenterUid`.

## 8. Customer Dashboard

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/t/{tenantSlug}/portal/dashboard/summary` | Customer cookie | Load a customer portal summary covering vehicles, appointments, active service state, and approval/payment indicators. |

Mobile behavior:

- Use this as the home screen aggregation.
- If it fails, fall back to individual list calls rather than showing stale data as current.

## 9. Repair Orders And Timeline

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/t/{tenantSlug}/repair-orders` | Customer cookie | List customer-visible repair orders. |
| `GET` | `/t/{tenantSlug}/repair-orders/{repairOrderId}` | Customer cookie | Load customer-visible repair-order detail. |
| `GET` | `/t/{tenantSlug}/repair-orders/{repairOrderId}/timeline` | Customer cookie | Load customer-visible timeline events. |
| `GET` | `/t/{tenantSlug}/repair-orders/{repairOrderId}/timeline/stream` | Customer cookie | SSE stream for timeline events. |

Mobile behavior:

- Implement normal polling first with the timeline list endpoint.
- Add SSE as an enhancement when the Android networking stack supports it reliably.
- Use the `Last-Event-ID` header when reconnecting to SSE.
- Do not display internal notes, staff-only handoff state, raw provider state, private object keys, or readiness metadata.

## 10. Estimates And Customer Approval

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/t/{tenantSlug}/repair-orders/{repairOrderId}/estimates/{estimateId}` | Customer cookie | Load a customer-visible estimate. |
| `POST` | `/t/{tenantSlug}/repair-orders/{repairOrderId}/estimates/{estimateId}/decisions` | Customer cookie | Submit line-item approval/rejection decisions. |

Decision request fields:

- `estimateVersion`
- `idempotencyKey`
- `decisions[]`
- each decision has `estimateLineItemId`, `status`, and optional `note`

Mobile behavior:

- Submit all intended line-item decisions in one batch.
- Generate a stable idempotency key per approval submission.
- Refresh the estimate after a decision to show the authoritative state.

## 11. Customer PDFs

Customer routes can read document generation state and request signed download URLs. Customer routes do not generate PDFs; generation is staff/server-side.

| Document | State path | Download URL path |
|---|---|---|
| Invoice PDF | `GET /t/{tenantSlug}/portal/invoices/{invoiceId}/pdf` | `POST /t/{tenantSlug}/portal/invoices/{invoiceId}/pdf/download-url` |
| Estimate PDF | `GET /t/{tenantSlug}/repair-orders/{repairOrderId}/estimates/{estimateId}/pdf` | `POST /t/{tenantSlug}/repair-orders/{repairOrderId}/estimates/{estimateId}/pdf/download-url` |
| Inspection report PDF | `GET /t/{tenantSlug}/repair-orders/{repairOrderId}/inspections/{inspectionId}/pdf` | `POST /t/{tenantSlug}/repair-orders/{repairOrderId}/inspections/{inspectionId}/pdf/download-url` |
| Service history PDF | `GET /t/{tenantSlug}/repair-orders/{repairOrderId}/service-history/pdf` | `POST /t/{tenantSlug}/repair-orders/{repairOrderId}/service-history/pdf/download-url` |

Download request fields:

- optional `disposition`: `inline` or `attachment`; defaults to `attachment`.

Mobile behavior:

- Treat signed download URLs as short-lived secrets.
- Do not store signed URLs as durable document references.
- Re-request a download URL when expired.

## 12. Invoices

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/t/{tenantSlug}/invoices` | Customer cookie | List customer-visible invoices. |
| `GET` | `/t/{tenantSlug}/invoices/{invoiceId}` | Customer cookie | Load one customer-visible invoice. |

Mobile behavior:

- Use invoices for service-cost presentation.
- Use payment requests or provider handoff only when returned by the payment flow; do not invent provider fields.

## 13. Payment Requests

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/t/{tenantSlug}/payment-requests/{paymentRequestId}?token={token}` | Public token | Load a tokenized customer payment request and provider-safe handoff fields. |

Mobile behavior:

- Payment links are tokenized public flows. The token may arrive in a deep link fragment or query parameter from a customer message.
- Send only the token expected by the API query.
- If `providerHandoff` is present, render/open only the returned `action`, `method`, and customer-safe fields.
- Prefer browser/custom-tab handoff for provider checkout.
- Never log payment tokens, provider handoff field values, or payment URLs.

## 14. Feedback

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/t/{tenantSlug}/feedback/{token}` | Public token in path | Load a feedback request. |
| `POST` | `/t/{tenantSlug}/feedback/{token}` | Public token in path | Submit customer rating/comment. |

Submit fields:

- `rating`: integer 1 through 5.
- optional `comment`.

Mobile behavior:

- Feedback is tokenized and does not require an active customer session.
- Treat expired or already-submitted token errors as terminal user-facing states.

## 15. Customer Compliance Requests

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `POST` | `/t/{tenantSlug}/compliance-requests` | Public | Submit tenant-scoped privacy/data-protection requests. |

Common request fields:

- `requestType`
- optional `requesterType`
- optional `requesterName`
- optional `requesterEmail`
- optional `requesterPhone`
- `summary`
- `evidence`
- `sourceEntityType`
- optional `sourceEntityId`
- optional `turnstileToken`

Mobile behavior:

- Use this only for privacy/legal request intake, not general support.
- Keep evidence sanitized; do not upload private documents through this route.

## 16. Standard Error Handling

| Status | Mobile behavior |
|---|---|
| `400` | Show validation messages from `details` when present. Keep the form data. |
| `401` | Clear local session and restart OTP login. |
| `403` | Show unavailable/forbidden state. Do not reveal whether another tenant's object exists. |
| `404` | Show safe not-found state. Do not retry with guessed IDs. |
| `409` | Refresh the resource and let the customer retry the action if still valid. |
| `422` | Show field-level validation if present. |
| `429` | Back off and show a wait/retry state. |
| `5xx` | Show retry state with request ID when available. Do not expose backend internals. |

Readiness and feature-disabled states can appear as structured errors or unavailable states depending on the endpoint. Treat them as intentional product states, not generic crashes.
