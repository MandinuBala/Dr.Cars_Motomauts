# Motornauts Customer Mobile Integration

This folder documents how a customer-only Android or mobile app can use the existing Motornauts API without changing the Motornauts codebase.

The integration is tenant-scoped. A mobile app must know the target `tenantSlug` before calling customer APIs. Motornauts is not exposed as a global service-center marketplace API for this integration.

## Files

- `customer-api-catalog.md` - human-readable customer and public API catalog grouped by workflow.
- `customer-mobile-openapi.yaml` - OpenAPI 3.1 customer/mobile Swagger file for the existing endpoints.
- `mobile-app-implementation-sequence.md` - detailed implementation sequence for an AI agent building the mobile app.
- `gaps.md` - customer-app gaps and DR.Cars features that are not feasible without backend work.

## Base URL

All API paths use the global prefix:

```text
{API_BASE_URL}/api/v1
```

Local default:

```text
http://localhost:4000/api/v1
```

Tenant example:

```text
http://localhost:4000/api/v1/t/isira-motors-demo/customer-auth/otp/request
```

## Auth Model

Motornauts customer mobile integration has three access modes:

- Public tenant routes: no login required, but still tenant-host and `tenantSlug` validated.
- Customer session routes: use the customer portal OTP flow and persist the returned HTTP-only session cookie.
- Tokenized public routes: use short public tokens for flows such as payment requests and feedback links.

Do not use the old DR.Cars password/JWT/social-login model for customers. Staff/platform Clerk auth is intentionally out of scope for this customer app.

## Response Shape

Most JSON responses use:

```json
{
  "data": {}
}
```

Errors use the normalized API error shape:

```json
{
  "error": "validation_problem",
  "message": "Request validation failed.",
  "messageKey": "errors.validationProblem",
  "details": {},
  "requestId": "req_..."
}
```

The public logo endpoint is the exception: it returns image bytes with image content headers instead of JSON.

## Tenant Model

Every customer workflow must be scoped to a tenant:

```text
/api/v1/t/{tenantSlug}/...
```

The mobile app must treat Motornauts IDs as canonical:

- Use `tenantCustomerId`, `vehicleId`, `branchId`, `servicePackageId`, `appointmentId`, `repairOrderId`, `estimateId`, and `invoiceId`.
- Do not use DR.Cars `uid`, `serviceCenterUid`, or `vehicleNumber` as primary API identifiers.
- Keep `registrationNumber` only as a vehicle attribute and search/display value.

## Security Rules For Mobile

- Store the customer session cookie in platform secure storage.
- Never log OTP codes, session cookies, payment tokens, feedback tokens, signed URLs, or document upload URLs.
- Never send provider secrets, raw payment callbacks, private object keys, or signed URL contents to analytics/crash reporting.
- Treat signed upload/download URLs as short-lived secrets.
- Prefer opening payment provider handoff in a browser/custom tab unless the provider integration explicitly supports safe in-app submission.

## Source References

This documentation is based on the customer/public controllers under:

- `apps/api/src/modules/customer-auth`
- `apps/api/src/modules/customer-self-registration`
- `apps/api/src/modules/tenant-configuration`
- `apps/api/src/modules/customers`
- `apps/api/src/modules/vehicles`
- `apps/api/src/modules/documents`
- `apps/api/src/modules/appointments`
- `apps/api/src/modules/dashboards`
- `apps/api/src/modules/repair-orders`
- `apps/api/src/modules/realtime`
- `apps/api/src/modules/estimates`
- `apps/api/src/modules/generated-artifacts`
- `apps/api/src/modules/invoices`
- `apps/api/src/modules/payments`
- `apps/api/src/modules/feedback`
- `apps/api/src/modules/compliance`
