# Customer Mobile Integration Gaps

These are known gaps when adapting the existing DR.Cars customer app to the current Motornauts customer API without changing the Motornauts backend.

## Feasible Only By Changing The Mobile App

### Customer password/JWT/social login

Motornauts customer auth is OTP/session based. The mobile app must remove or bypass DR.Cars password login, JWT persistence, `/login`, `/register`, `/auth/google`, `/auth/facebook`, password reset, and password change flows for Motornauts customers.

Best replacement:

- Use `POST /t/{tenantSlug}/customer-auth/otp/request`.
- Use `POST /t/{tenantSlug}/customer-auth/otp/verify`.
- Persist the returned customer session cookie.

### Global service-center marketplace discovery

DR.Cars lets customers search service centers by city. Motornauts customer routes are tenant-scoped and assume the customer is interacting with one selected tenant or custom domain.

Best replacement:

- Preconfigure tenant slug per branded mobile build, or use an operator-approved tenant selection/deep-link mechanism outside the current API scope.
- Inside a tenant, choose a branch from booking options.

### Direct multipart document upload

DR.Cars uploads documents to the API server with multipart form data. Motornauts uses private object storage with upload intents.

Best replacement:

- Create upload intent.
- Upload bytes directly to the signed object URL.
- Complete upload through the API.
- Request view/download URL only after the document is available.

### DR.Cars service receipts

DR.Cars has service receipts that customers confirm/reject and service centers finish. Motornauts models the service lifecycle as repair orders, inspections, estimates, invoices, payments, delivery, and service history.

Best replacement:

- Use repair-order timeline for live state.
- Use estimate decisions for customer approval/rejection of work.
- Use invoices and payment requests for payment state.
- Use service-history PDFs or repair-order history for completed service evidence.

## Not Feasible Without Backend/Product Scope

### Arbitrary customer-created service records

Motornauts does not expose a customer endpoint to create manual service history records. Service history is generated from workflow evidence and tenant-owned repair-order operations.

Do not implement this by writing local-only records unless the product explicitly accepts that they are not Motornauts service history.

### Backend-backed OBD2 diagnostics

The DR.Cars app includes Bluetooth OBD2 behavior. Motornauts has no current customer API for OBD2 readings, diagnostic trouble codes, device pairing, or diagnostic history.

Allowed without backend work:

- Keep OBD2 as a local-only mobile utility.

Not allowed without backend work:

- Syncing OBD2 data into Motornauts.
- Attaching OBD2 data to repair orders.
- Showing OBD2 data as tenant-visible service evidence.

### 3D vehicle model serving

DR.Cars has a `/models/:filename` GLB proxy. Motornauts has no current customer vehicle model-serving endpoint.

Allowed without backend work:

- Keep bundled/local static 3D assets in the mobile app.

Not allowed without backend work:

- Expecting Motornauts to serve per-vehicle GLB files.
- Storing customer-specific vehicle model assets in Motornauts.

### Push notification device registration

This customer API catalog does not include a customer endpoint for mobile push device registration or push token lifecycle.

Allowed without backend work:

- Local notifications based on client-side reminders.
- Polling customer dashboard/appointments/repair orders.

Not allowed without backend work:

- Registering device tokens with Motornauts.
- Receiving backend-triggered customer push notifications.

### Global tenant discovery

There is no public customer endpoint for listing all active tenants or finding service centers nearby.

Allowed without backend work:

- Branded app with one configured tenant slug.
- Deep link that includes a tenant slug.

Not allowed without backend work:

- Public marketplace list of all Motornauts tenants.
- City/radius search across tenants.

## Payment Constraints

Payment provider handoff is feasible only through customer-safe fields returned by existing payment request status APIs.

Rules:

- Do not construct PayHere/WebXPay checkout payloads in the app.
- Do not store or display provider secrets, raw callback payloads, callback signatures, hash keys, private provider metadata, provider order IDs unless returned as customer-safe display data, or internal readiness evidence.
- Treat provider return/cancel pages as navigation states, not proof of payment success.
- Refresh the payment request status after provider handoff.

## Documentation Boundary

This folder intentionally does not document:

- Staff or technician mobile APIs.
- Tenant admin APIs.
- Platform APIs.
- Fleet account APIs.
- Webhooks.
- Internal provider readiness/configuration APIs.
- Database schemas or Prisma migrations.

If any of those become mobile requirements later, create a new scoped integration document instead of expanding the customer-only API surface silently.
