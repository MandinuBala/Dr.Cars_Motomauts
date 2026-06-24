# Security Review: Dr.Cars_Motomauts

## Scope

Deep repository security scan of the Dr.Cars_Motomauts Flutter application and Node/Express backend at the launched scan revision. The scan used four independent discovery passes, centralized validation, and attack-path calibration.

- Scan mode: deep_repository
- Target kind: git_worktree
- Target ID: target_sha256_157892c036b427a4a72d3c65d5de65dc9eba786bc7ea21bbe428c09cb27e9bfc
- Revision: 8266ebff562be3606f0264306550d3121d379786
- Snapshot digest: codex-security-snapshot/v1:sha256:d9245f1672cd450d65e2e3e0ab3b98403bc0556b7b784d97869e725c17e96582
- Inventory strategy: repository
- Included paths: .
- Excluded paths: none
- Runtime or test status: No live Railway backend, production database, or external identity provider calls were exercised. Validation used static repository traces and local npm audit evidence.
- Artifacts reviewed: artifacts/02_discovery/deep_review_input.jsonl, artifacts/deep_merge/canonical_candidate_inventory.md, artifacts/04_reconciliation/deduped_candidates.jsonl, backend/server.js, backend/models/\*.js, backend/middleware/middleware.js, lib/auth/auth_service.dart, lib/admin/requests/\*.dart, lib/service/document_service.dart, backend/package.json, backend/package-lock.json, android/app/build.gradle.kts
- Scan context: The Codex Security app selected revision 8266ebff562be3606f0264306550d3121d379786. The local checkout later moved to 7f05208adb97245053ac96b9d084a224c6f88d55, so remediation in the app is unavailable for this scan. Committed source changes between those revisions were limited to .gitignore and docs, not the reviewed backend/app code.

Limitations and exclusions:
- Committed secret values and API key values are redacted from scan artifacts and report prose.
- No live exploit requests were sent to the Railway deployment or MongoDB database.
- Provider-side Google/Firebase key restrictions and production reverse-proxy controls were not available in the repository.
- The working tree contains unrelated user changes; they were not reverted and are not treated as remediation for this scan.

### Scan Summary

| Field | Value |
| --- | --- |
| Reportable findings | 16 |
| Severity mix | critical: 3, high: 10, medium: 2, low: 1 |
| Confidence mix | high: 15, medium: 1 |
| Coverage | complete |
| Validation mode | Static code trace with local dependency audit. |

Canonical artifacts: `scan-manifest.json`, `findings.json`, and `coverage.json`. This report is a deterministic projection of those files.

## Threat Model

The application consists of a Flutter mobile/client app and a Node/Express backend backed by MongoDB. The backend is the main trust boundary: it issues JWTs, stores user, vehicle, appointment, service, receipt, feedback, and document records, and is contacted by mobile clients over HTTP.

### Assets

- User accounts, password hashes, JWT signing material, and social-login bindings.
- MongoDB data for users, service-center requests, vehicles, appointments, receipts, service records, feedback, and vehicle documents.
- Uploaded document photos and public API-origin document URLs.
- Android release artifacts and signing identity.
- Google/Firebase API quota and configuration.

### Trust Boundaries

- Unauthenticated internet/mobile clients to Express API routes.
- Vehicle owners and service centers to each other's objects.
- Service-center applicants to admin-only approval workflows.
- Client-side identity provider profile data to backend-issued application JWTs.
- Repository/build configuration to production credentials and release artifacts.

### Attacker Capabilities

- Send arbitrary HTTP requests to the configured backend origin.
- Modify mobile client traffic and omit client-side UI restrictions.
- Guess or enumerate emails, usernames, user ids, vehicle numbers, service-center ids, and Mongo ObjectIds exposed by public APIs.
- Upload multipart files to public upload routes when reachable.
- Obtain repository or build artifact contents if source control or distribution leaks.

### Security Objectives

- Authenticate and authorize all protected object reads/writes on the backend.
- Never issue application sessions from unverified identity-provider assertions.
- Protect secrets and release signing keys outside source control.
- Keep uploaded files and sensitive document metadata scoped to authorized users.
- Prevent unauthenticated abuse of login and upload surfaces.

### Assumptions

- Express routes in backend/server.js are reachable as deployed unless an out-of-repository reverse proxy adds controls.
- Flutter client role checks are not security boundaries because attackers can call backend routes directly.
- MongoDB and identity-provider live behavior was not tested during this scan.

## Findings

| Finding | Severity | Confidence |
| --- | --- | --- |
| [Public user update, delete, and password-change routes can mutate arbitrary accounts](#finding-1) | critical | high |
| [Facebook login mints JWTs from unverified client-supplied identity fields](#finding-2) | critical | high |
| [Google login mints JWTs from unverified client-supplied identity fields](#finding-3) | critical | high |
| [Public appointment APIs expose and mutate arbitrary bookings](#finding-4) | high | high |
| [Tracked backend environment file exposes database credentials and the JWT signing secret](#finding-5) | high | high |
| [Public vehicle APIs allow cross-user vehicle creation, lookup, and overwrite](#finding-6) | high | high |
| [Public service-center administration routes expose and mutate approval workflow state](#finding-7) | high | high |
| [Android release builds are signed with the debug key](#finding-8) | high | high |
| [Public upload route uses a Multer version with reachable denial-of-service advisories](#finding-9) | high | high |
| [Public receipt and service-record APIs allow billing and maintenance-history tampering](#finding-10) | high | high |
| [Public document upload and vehicle-document APIs expose and mutate license/insurance records](#finding-11) | high | high |
| [Public user creation routes allow self-assigned privileged roles](#finding-12) | high | high |
| [Public user lookup routes expose full user records including password hashes](#finding-13) | high | high |
| [Login, reset, and password-change flows lack throttling and expose account/password oracles](#finding-14) | medium | high |
| [Google and Firebase API keys are embedded in client-side source without repository-visible restrictions](#finding-15) | medium | medium |
| [Public feedback listing exposes review records and user identifiers](#finding-16) | low | high |

### Confidence Scale

| Label | Meaning |
| --- | --- |
| high | Direct evidence supports the finding with no material unresolved blocker. |
| medium | Evidence supports a plausible issue, but material runtime or reachability proof remains. |
| low | Evidence is incomplete and the item is retained only for explicit follow-up. |

<a id="finding-1"></a>

### [1] Public user update, delete, and password-change routes can mutate arbitrary accounts

| Field | Value |
| --- | --- |
| Severity | critical |
| Confidence | high |
| Confidence rationale | Static route and model evidence directly supports the finding; live production/database behavior was not exercised. |
| Category | Authorization bypass / account takeover |
| CWE | CWE-862, CWE-639, CWE-284 |
| Affected lines | backend/server.js:205-213, backend/server.js:428-464, backend/server.js:1173-1195, lib/auth/auth_service.dart:145-154, lib/auth/auth_service.dart:377-401, lib/auth/auth_service.dart:421-437 |

#### Summary

public user routes accept email, uid, or ObjectId path parameters and apply request bodies to matching User records, delete matching accounts, or change passwords without requiring a bearer token or binding the target account to the caller.

#### Root Cause

The backend exposes account mutation endpoints as public routes and relies on caller-selected identifiers rather than authenticated subject-to-object binding.

**Email-keyed update mass assigns req.body** — `backend/server.js:205-213`

The route updates a user selected by email with the full request body.

```javascript
app.put("/user/:email", async (req, res) => {
  try {
    const updated = await User.findOneAndUpdate(
      { email: req.params.email },
      req.body,
      { new: true }
    );
    if (!updated) return res.status(404).json({ message: "User not found" });
    res.json(updated);
```

**ID-keyed update and delete lack an owner check** — `backend/server.js:428-464`

The routes select a user by uid/ObjectId and update/delete without authentication.

```javascript
app.put("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const updated = await User.findOneAndUpdate({ $or: filters }, req.body, {
      new: true,
    });

    if (!updated) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE USER BY ID/UID
app.delete("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const deleted = await User.findOneAndDelete({ $or: filters });
    if (!deleted) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json({ message: "User deleted" });
```

**Password change targets arbitrary ids** — `backend/server.js:1173-1195`

The password-change route resolves the path id and overwrites the selected user password after a body-supplied current password check.

```javascript
app.patch("/users/:id/password", async (req, res) => {
  try {
    const { id } = req.params;
    const { currentPassword, newPassword } = req.body;
    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const user = await User.findOne({ $or: filters });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const isMatch = await bcrypt.compare(currentPassword, user.password || "");
    if (!isMatch) {
      return res.status(400).json({ message: "Current password is incorrect" });
    }

    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();

    res.json({ message: "Password changed" });
```

#### Validation

Validated by tracing the public route, attacker-controlled request fields, missing backend guard, and resulting database or security-sensitive sink in the repository.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

**Email-keyed update mass assigns req.body** — `backend/server.js:205-213`

The route updates a user selected by email with the full request body.

```javascript
app.put("/user/:email", async (req, res) => {
  try {
    const updated = await User.findOneAndUpdate(
      { email: req.params.email },
      req.body,
      { new: true }
    );
    if (!updated) return res.status(404).json({ message: "User not found" });
    res.json(updated);
```

**ID-keyed update and delete lack an owner check** — `backend/server.js:428-464`

The routes select a user by uid/ObjectId and update/delete without authentication.

```javascript
app.put("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const updated = await User.findOneAndUpdate({ $or: filters }, req.body, {
      new: true,
    });

    if (!updated) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE USER BY ID/UID
app.delete("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const deleted = await User.findOneAndDelete({ $or: filters });
    if (!deleted) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json({ message: "User deleted" });
```

**Password change targets arbitrary ids** — `backend/server.js:1173-1195`

The password-change route resolves the path id and overwrites the selected user password after a body-supplied current password check.

```javascript
app.patch("/users/:id/password", async (req, res) => {
  try {
    const { id } = req.params;
    const { currentPassword, newPassword } = req.body;
    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const user = await User.findOne({ $or: filters });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const isMatch = await bcrypt.compare(currentPassword, user.password || "");
    if (!isMatch) {
      return res.status(400).json({ message: "Current password is incorrect" });
    }

    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();

    res.json({ message: "Password changed" });
```

Counterevidence and remaining uncertainty:
- No global Express authentication middleware is registered in backend/server.js; verifyToken exists in backend/middleware/middleware.js but is not imported or attached to these routes.

#### Dataflow

Path email/id plus JSON body -\> User.findOneAndUpdate, User.findOneAndDelete, or password hash overwrite -\> changed or deleted victim account.

- **Source:** Caller-controlled path email/id and JSON update/password body.

- **Sink:** User.findOneAndUpdate, User.findOneAndDelete, and user.password assignment.

- **Outcome:** Cross-account takeover, privilege changes, or destructive account deletion.

**Email-keyed update mass assigns req.body** — `backend/server.js:205-213`

The route updates a user selected by email with the full request body.

```javascript
app.put("/user/:email", async (req, res) => {
  try {
    const updated = await User.findOneAndUpdate(
      { email: req.params.email },
      req.body,
      { new: true }
    );
    if (!updated) return res.status(404).json({ message: "User not found" });
    res.json(updated);
```

**ID-keyed update and delete lack an owner check** — `backend/server.js:428-464`

The routes select a user by uid/ObjectId and update/delete without authentication.

```javascript
app.put("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const updated = await User.findOneAndUpdate({ $or: filters }, req.body, {
      new: true,
    });

    if (!updated) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE USER BY ID/UID
app.delete("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const deleted = await User.findOneAndDelete({ $or: filters });
    if (!deleted) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json({ message: "User deleted" });
```

**Password change targets arbitrary ids** — `backend/server.js:1173-1195`

The password-change route resolves the path id and overwrites the selected user password after a body-supplied current password check.

```javascript
app.patch("/users/:id/password", async (req, res) => {
  try {
    const { id } = req.params;
    const { currentPassword, newPassword } = req.body;
    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const user = await User.findOne({ $or: filters });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const isMatch = await bcrypt.compare(currentPassword, user.password || "");
    if (!isMatch) {
      return res.status(400).json({ message: "Current password is incorrect" });
    }

    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();

    res.json({ message: "Password changed" });
```

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** remote unauthenticated caller

- **Entry point:** Public Express route in backend/server.js

Preconditions:
- The backend is reachable at the configured API origin.
- No out-of-repository reverse proxy adds a stronger control before the route.

#### Severity

**Critical** — Critical severity is assigned because public user routes accept email, uid, or ObjectId path parameters and apply request bodies to matching User records, delete matching accounts, or change passwords without requiring a bearer token or binding the target account to the caller.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Require verifyToken on every account mutation route, compare req.user.id to the target user or require an admin role, whitelist mutable fields, and add rate limiting on password checks.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

<a id="finding-2"></a>

### [2] Facebook login mints JWTs from unverified client-supplied identity fields

| Field | Value |
| --- | --- |
| Severity | critical |
| Confidence | high |
| Confidence rationale | Static route and model evidence directly supports the finding; live production/database behavior was not exercised. |
| Category | Authentication bypass / account takeover |
| CWE | CWE-287, CWE-345 |
| Affected lines | backend/server.js:1126-1166, backend/server.js:1134-1152, lib/auth/auth_service.dart:291-307 |

#### Summary

public POST /auth/facebook accepts facebookId and email from the request body, matches an existing account by email, optionally binds the supplied facebookId, and signs an application JWT without verifying a Facebook token.

#### Root Cause

The backend treats caller-provided Facebook profile fields as proof of identity instead of validating a provider token and binding the validated subject to the local account.

**Facebook route trusts body identity** — `backend/server.js:1126-1152`

The route reads facebookId/email from req.body, finds by email/facebookId, and signs a JWT.

```javascript
app.post("/auth/facebook", async (req, res) => {
  try {
    const { facebookId, email, name, photoUrl } = req.body;

    if (!facebookId || !email) {
      return res.status(400).json({ message: "facebookId and email are required" });
    }

    let user = await User.findOne({ $or: [{ facebookId }, { email }] });
    let isNewUser = false;

    if (!user) {
      user = await User.create({
        facebookId,
        email,
        name,
        photoUrl,
        userType: "Vehicle Owner",
        createdAt: new Date(),
      });
      isNewUser = true;
    } else if (!user.facebookId) {
      user.facebookId = facebookId;
      await user.save();
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
```

**Client sends profile fields only** — `lib/auth/auth_service.dart:291-299`

The client posts profile fields, not a backend-verifiable Facebook token.

```dart
    final response = await http.post(
      Uri.parse("$baseUrl/auth/facebook"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "facebookId": facebookId,
        "email": email,
        "name": name,
        "photoUrl": photoUrl,
      }),
```

#### Validation

Validated by tracing the public route, attacker-controlled request fields, missing backend guard, and resulting database or security-sensitive sink in the repository.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

**Facebook route trusts body identity** — `backend/server.js:1126-1152`

The route reads facebookId/email from req.body, finds by email/facebookId, and signs a JWT.

```javascript
app.post("/auth/facebook", async (req, res) => {
  try {
    const { facebookId, email, name, photoUrl } = req.body;

    if (!facebookId || !email) {
      return res.status(400).json({ message: "facebookId and email are required" });
    }

    let user = await User.findOne({ $or: [{ facebookId }, { email }] });
    let isNewUser = false;

    if (!user) {
      user = await User.create({
        facebookId,
        email,
        name,
        photoUrl,
        userType: "Vehicle Owner",
        createdAt: new Date(),
      });
      isNewUser = true;
    } else if (!user.facebookId) {
      user.facebookId = facebookId;
      await user.save();
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
```

**Client sends profile fields only** — `lib/auth/auth_service.dart:291-299`

The client posts profile fields, not a backend-verifiable Facebook token.

```dart
    final response = await http.post(
      Uri.parse("$baseUrl/auth/facebook"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "facebookId": facebookId,
        "email": email,
        "name": name,
        "photoUrl": photoUrl,
      }),
```

Counterevidence and remaining uncertainty:
- No global Express authentication middleware is registered in backend/server.js; verifyToken exists in backend/middleware/middleware.js but is not imported or attached to these routes.

#### Dataflow

Attacker JSON body facebookId/email -\> POST /auth/facebook -\> User.findOne by facebookId or email -\> optional facebookId assignment -\> jwt.sign returns a session token.

- **Source:** Caller-controlled facebookId and email in POST /auth/facebook JSON.

- **Sink:** jwt.sign for the matched user.

- **Outcome:** Account takeover for any existing email that can be named in the request.

**Facebook route trusts body identity** — `backend/server.js:1126-1152`

The route reads facebookId/email from req.body, finds by email/facebookId, and signs a JWT.

```javascript
app.post("/auth/facebook", async (req, res) => {
  try {
    const { facebookId, email, name, photoUrl } = req.body;

    if (!facebookId || !email) {
      return res.status(400).json({ message: "facebookId and email are required" });
    }

    let user = await User.findOne({ $or: [{ facebookId }, { email }] });
    let isNewUser = false;

    if (!user) {
      user = await User.create({
        facebookId,
        email,
        name,
        photoUrl,
        userType: "Vehicle Owner",
        createdAt: new Date(),
      });
      isNewUser = true;
    } else if (!user.facebookId) {
      user.facebookId = facebookId;
      await user.save();
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
```

**Client sends profile fields only** — `lib/auth/auth_service.dart:291-299`

The client posts profile fields, not a backend-verifiable Facebook token.

```dart
    final response = await http.post(
      Uri.parse("$baseUrl/auth/facebook"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "facebookId": facebookId,
        "email": email,
        "name": name,
        "photoUrl": photoUrl,
      }),
```

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** remote unauthenticated caller

- **Entry point:** Public Express route in backend/server.js

Preconditions:
- The backend is reachable at the configured API origin.
- No out-of-repository reverse proxy adds a stronger control before the route.

#### Severity

**Critical** — Critical severity is assigned because public POST /auth/facebook accepts facebookId and email from the request body, matches an existing account by email, optionally binds the supplied facebookId, and signs an application JWT without verifying a Facebook token.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Verify Facebook access or ID tokens server-side, bind the provider subject to the account, and require an authenticated account-link flow before adding facebookId to an existing user.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

<a id="finding-3"></a>

### [3] Google login mints JWTs from unverified client-supplied identity fields

| Field | Value |
| --- | --- |
| Severity | critical |
| Confidence | high |
| Confidence rationale | Static route and model evidence directly supports the finding; live production/database behavior was not exercised. |
| Category | Authentication bypass / account takeover |
| CWE | CWE-287, CWE-345 |
| Affected lines | backend/server.js:1079-1119, backend/server.js:1087-1105, lib/auth/auth_service.dart:261-277 |

#### Summary

public POST /auth/google accepts googleId and email from the request body, matches an existing account by email, optionally binds the supplied googleId, and signs an application JWT without verifying a Google ID token.

#### Root Cause

The backend treats profile fields supplied by the caller as the provider assertion. The violated invariant is that a server session must be issued only after validating an identity-provider token whose subject and audience are bound to the application.

**Google route trusts body identity** — `backend/server.js:1079-1106`

The route reads googleId/email from req.body, finds by email/googleId, and signs a JWT.

```javascript
app.post("/auth/google", async (req, res) => {
  try {
    const { googleId, email, name, photoUrl } = req.body;

    if (!googleId || !email) {
      return res.status(400).json({ message: "googleId and email are required" });
    }

    let user = await User.findOne({ $or: [{ googleId }, { email }] });
    let isNewUser = false;

    if (!user) {
      user = await User.create({
        googleId,
        email,
        name,
        photoUrl,
        userType: "Vehicle Owner",
        createdAt: new Date(),
      });
      isNewUser = true;
    } else if (!user.googleId) {
      user.googleId = googleId;
      await user.save();
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
      expiresIn: "7d",
```

**Client sends profile fields only** — `lib/auth/auth_service.dart:261-269`

The client posts profile fields, not a backend-verifiable Google token.

```dart
    final response = await http.post(
      Uri.parse("$baseUrl/auth/google"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "googleId": googleId,
        "email": email,
        "name": name,
        "photoUrl": photoUrl,
      }),
```

#### Validation

Validated by tracing the public route, attacker-controlled request fields, missing backend guard, and resulting database or security-sensitive sink in the repository.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

**Google route trusts body identity** — `backend/server.js:1079-1106`

The route reads googleId/email from req.body, finds by email/googleId, and signs a JWT.

```javascript
app.post("/auth/google", async (req, res) => {
  try {
    const { googleId, email, name, photoUrl } = req.body;

    if (!googleId || !email) {
      return res.status(400).json({ message: "googleId and email are required" });
    }

    let user = await User.findOne({ $or: [{ googleId }, { email }] });
    let isNewUser = false;

    if (!user) {
      user = await User.create({
        googleId,
        email,
        name,
        photoUrl,
        userType: "Vehicle Owner",
        createdAt: new Date(),
      });
      isNewUser = true;
    } else if (!user.googleId) {
      user.googleId = googleId;
      await user.save();
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
      expiresIn: "7d",
```

**Client sends profile fields only** — `lib/auth/auth_service.dart:261-269`

The client posts profile fields, not a backend-verifiable Google token.

```dart
    final response = await http.post(
      Uri.parse("$baseUrl/auth/google"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "googleId": googleId,
        "email": email,
        "name": name,
        "photoUrl": photoUrl,
      }),
```

Counterevidence and remaining uncertainty:
- No global Express authentication middleware is registered in backend/server.js; verifyToken exists in backend/middleware/middleware.js but is not imported or attached to these routes.

#### Dataflow

Attacker JSON body googleId/email -\> POST /auth/google -\> User.findOne by googleId or email -\> optional googleId assignment -\> jwt.sign returns a session token.

- **Source:** Caller-controlled googleId and email in POST /auth/google JSON.

- **Sink:** jwt.sign for the matched user.

- **Outcome:** Account takeover for any existing email that can be named in the request.

**Google route trusts body identity** — `backend/server.js:1079-1106`

The route reads googleId/email from req.body, finds by email/googleId, and signs a JWT.

```javascript
app.post("/auth/google", async (req, res) => {
  try {
    const { googleId, email, name, photoUrl } = req.body;

    if (!googleId || !email) {
      return res.status(400).json({ message: "googleId and email are required" });
    }

    let user = await User.findOne({ $or: [{ googleId }, { email }] });
    let isNewUser = false;

    if (!user) {
      user = await User.create({
        googleId,
        email,
        name,
        photoUrl,
        userType: "Vehicle Owner",
        createdAt: new Date(),
      });
      isNewUser = true;
    } else if (!user.googleId) {
      user.googleId = googleId;
      await user.save();
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
      expiresIn: "7d",
```

**Client sends profile fields only** — `lib/auth/auth_service.dart:261-269`

The client posts profile fields, not a backend-verifiable Google token.

```dart
    final response = await http.post(
      Uri.parse("$baseUrl/auth/google"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "googleId": googleId,
        "email": email,
        "name": name,
        "photoUrl": photoUrl,
      }),
```

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** remote unauthenticated caller

- **Entry point:** Public Express route in backend/server.js

Preconditions:
- The backend is reachable at the configured API origin.
- No out-of-repository reverse proxy adds a stronger control before the route.

#### Severity

**Critical** — Critical severity is assigned because public POST /auth/google accepts googleId and email from the request body, matches an existing account by email, optionally binds the supplied googleId, and signs an application JWT without verifying a Google ID token.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Verify Google ID tokens server-side with Google libraries, bind the token subject/audience/email to the account, and refuse account linking unless the authenticated user owns the account.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

<a id="finding-4"></a>

### [4] Public appointment APIs expose and mutate arbitrary bookings

| Field | Value |
| --- | --- |
| Severity | high |
| Confidence | high |
| Confidence rationale | Static route and model evidence directly supports the finding; live production/database behavior was not exercised. |
| Category | Authorization bypass / workflow tampering |
| CWE | CWE-639, CWE-862 |
| Affected lines | backend/server.js:499-531, backend/server.js:559-594, backend/models/Appointment.js:3-22 |

#### Summary

appointment endpoints list schedules by vehicle number or service-center id and allow public creation, status changes, and deletion by appointment id without authentication or ownership checks.

#### Root Cause

Booking state is treated as public object data keyed by ids instead of protected records owned by users and service centers.

**Appointment list and create routes are public** — `backend/server.js:499-531`

The routes list by vehicle or serviceCenterUid and create appointments from req.body.

```javascript
app.get("/appointments/vehicle/:vehicleNumber", async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    const appointments = await Appointment.find({ vehicleNumber }).sort({ createdAt: -1 });
    res.json(appointments);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET APPOINTMENTS BY SERVICE CENTER (OPTIONAL STATUS FILTER)
app.get("/appointments/service-center/:serviceCenterUid", async (req, res) => {
  try {
    const { serviceCenterUid } = req.params;
    const { status } = req.query;

    const filter = { serviceCenterUid };
    if (status) {
      filter.status = status;
    }

    const appointments = await Appointment.find(filter).sort({ createdAt: 1 });
    res.json(appointments);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// CREATE APPOINTMENT
app.post("/appointments", async (req, res) => {
  try {
    const created = await Appointment.create(req.body);
    res.status(201).json(created);
```

**Appointment status and delete routes mutate by id** — `backend/server.js:559-594`

The routes update status or delete an appointment id without an auth guard.

```javascript
app.patch("/appointments/:id/status", async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!["pending", "accepted", "rejected", "vehicle_received"].includes(status)) {
      return res.status(400).json({ message: "Invalid status" });
    }

    const updated = await Appointment.findByIdAndUpdate(
      id,
      { status },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Appointment not found" });
    }

    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE APPOINTMENT
app.delete("/appointments/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await Appointment.findByIdAndDelete(id);

    if (!deleted) {
      return res.status(404).json({ message: "Appointment not found" });
    }

    res.json({ message: "Appointment deleted" });
```

**Appointment records contain schedule/contact workflow fields** — `backend/models/Appointment.js:3-22`

The model stores vehicleNumber, serviceCenterUid, Contact, date/time, and status.

```javascript
const appointmentSchema = new mongoose.Schema(
  {
    vehicleNumber: { type: String, required: true, index: true },
    vehicleModel: { type: String },
    serviceTypes: [{ type: String }],
    branch: { type: String },
    date: { type: String },
    time: { type: String },
    Contact: { type: String },
    userId: { type: String },
    serviceCenterUid: { type: String, index: true },
    status: {
      type: String,
      enum: ["pending", "accepted", "rejected","vehicle_received"],
      default: "pending",
      index: true,
    },
  },
  { timestamps: true }
);
```

#### Validation

Validated by tracing the public route, attacker-controlled request fields, missing backend guard, and resulting database or security-sensitive sink in the repository.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

**Appointment list and create routes are public** — `backend/server.js:499-531`

The routes list by vehicle or serviceCenterUid and create appointments from req.body.

```javascript
app.get("/appointments/vehicle/:vehicleNumber", async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    const appointments = await Appointment.find({ vehicleNumber }).sort({ createdAt: -1 });
    res.json(appointments);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET APPOINTMENTS BY SERVICE CENTER (OPTIONAL STATUS FILTER)
app.get("/appointments/service-center/:serviceCenterUid", async (req, res) => {
  try {
    const { serviceCenterUid } = req.params;
    const { status } = req.query;

    const filter = { serviceCenterUid };
    if (status) {
      filter.status = status;
    }

    const appointments = await Appointment.find(filter).sort({ createdAt: 1 });
    res.json(appointments);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// CREATE APPOINTMENT
app.post("/appointments", async (req, res) => {
  try {
    const created = await Appointment.create(req.body);
    res.status(201).json(created);
```

**Appointment status and delete routes mutate by id** — `backend/server.js:559-594`

The routes update status or delete an appointment id without an auth guard.

```javascript
app.patch("/appointments/:id/status", async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!["pending", "accepted", "rejected", "vehicle_received"].includes(status)) {
      return res.status(400).json({ message: "Invalid status" });
    }

    const updated = await Appointment.findByIdAndUpdate(
      id,
      { status },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Appointment not found" });
    }

    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE APPOINTMENT
app.delete("/appointments/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await Appointment.findByIdAndDelete(id);

    if (!deleted) {
      return res.status(404).json({ message: "Appointment not found" });
    }

    res.json({ message: "Appointment deleted" });
```

**Appointment records contain schedule/contact workflow fields** — `backend/models/Appointment.js:3-22`

The model stores vehicleNumber, serviceCenterUid, Contact, date/time, and status.

```javascript
const appointmentSchema = new mongoose.Schema(
  {
    vehicleNumber: { type: String, required: true, index: true },
    vehicleModel: { type: String },
    serviceTypes: [{ type: String }],
    branch: { type: String },
    date: { type: String },
    time: { type: String },
    Contact: { type: String },
    userId: { type: String },
    serviceCenterUid: { type: String, index: true },
    status: {
      type: String,
      enum: ["pending", "accepted", "rejected","vehicle_received"],
      default: "pending",
      index: true,
    },
  },
  { timestamps: true }
);
```

Counterevidence and remaining uncertainty:
- No global Express authentication middleware is registered in backend/server.js; verifyToken exists in backend/middleware/middleware.js but is not imported or attached to these routes.

#### Dataflow

Caller-selected vehicleNumber/serviceCenterUid/id/body -\> Appointment.find/create/findByIdAndUpdate/findByIdAndDelete -\> schedule disclosure or workflow mutation.

- **Source:** Caller-controlled path/query values and JSON appointment body.

- **Sink:** Appointment model reads and writes.

- **Outcome:** Disclosure of schedules/contact data and unauthorized creation, acceptance, rejection, or deletion of bookings.

**Appointment list and create routes are public** — `backend/server.js:499-531`

The routes list by vehicle or serviceCenterUid and create appointments from req.body.

```javascript
app.get("/appointments/vehicle/:vehicleNumber", async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    const appointments = await Appointment.find({ vehicleNumber }).sort({ createdAt: -1 });
    res.json(appointments);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET APPOINTMENTS BY SERVICE CENTER (OPTIONAL STATUS FILTER)
app.get("/appointments/service-center/:serviceCenterUid", async (req, res) => {
  try {
    const { serviceCenterUid } = req.params;
    const { status } = req.query;

    const filter = { serviceCenterUid };
    if (status) {
      filter.status = status;
    }

    const appointments = await Appointment.find(filter).sort({ createdAt: 1 });
    res.json(appointments);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// CREATE APPOINTMENT
app.post("/appointments", async (req, res) => {
  try {
    const created = await Appointment.create(req.body);
    res.status(201).json(created);
```

**Appointment status and delete routes mutate by id** — `backend/server.js:559-594`

The routes update status or delete an appointment id without an auth guard.

```javascript
app.patch("/appointments/:id/status", async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!["pending", "accepted", "rejected", "vehicle_received"].includes(status)) {
      return res.status(400).json({ message: "Invalid status" });
    }

    const updated = await Appointment.findByIdAndUpdate(
      id,
      { status },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Appointment not found" });
    }

    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE APPOINTMENT
app.delete("/appointments/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await Appointment.findByIdAndDelete(id);

    if (!deleted) {
      return res.status(404).json({ message: "Appointment not found" });
    }

    res.json({ message: "Appointment deleted" });
```

**Appointment records contain schedule/contact workflow fields** — `backend/models/Appointment.js:3-22`

The model stores vehicleNumber, serviceCenterUid, Contact, date/time, and status.

```javascript
const appointmentSchema = new mongoose.Schema(
  {
    vehicleNumber: { type: String, required: true, index: true },
    vehicleModel: { type: String },
    serviceTypes: [{ type: String }],
    branch: { type: String },
    date: { type: String },
    time: { type: String },
    Contact: { type: String },
    userId: { type: String },
    serviceCenterUid: { type: String, index: true },
    status: {
      type: String,
      enum: ["pending", "accepted", "rejected","vehicle_received"],
      default: "pending",
      index: true,
    },
  },
  { timestamps: true }
);
```

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** remote unauthenticated caller

- **Entry point:** Public Express route in backend/server.js

Preconditions:
- The backend is reachable at the configured API origin.
- No out-of-repository reverse proxy adds a stronger control before the route.

#### Severity

**High** — High severity is assigned because appointment endpoints list schedules by vehicle number or service-center id and allow public creation, status changes, and deletion by appointment id without authentication or ownership checks.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Require authenticated user or service-center roles for appointment reads and writes, verify vehicle/service-center ownership, and restrict status transitions to authorized service-center workflows.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

<a id="finding-5"></a>

### [5] Tracked backend environment file exposes database credentials and the JWT signing secret

| Field | Value |
| --- | --- |
| Severity | high |
| Confidence | high |
| Confidence rationale | Static route and model evidence directly supports the finding; live production/database behavior was not exercised. |
| Category | Hardcoded credentials / secret exposure |
| CWE | CWE-798, CWE-200 |
| Affected lines | backend/.env:1-2, backend/server.js:64, backend/server.js:136-138, backend/middleware/middleware.js:8-10 |

#### Summary

backend/.env is present in the repository and contains the MongoDB connection secret and JWT signing secret used by server.js and the JWT middleware; the secret values were intentionally redacted from scan artifacts.

#### Root Cause

Secrets required to access the database and sign/verify sessions are committed to the repository. The invariant is that runtime credentials must not be stored in source control.

**MongoDB URI is loaded from environment** — `backend/server.js:63-66`

The backend connects with process.env.MONGO_URI, whose value is present in the tracked .env file.

```javascript
// CONNECT TO MONGODBser
mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log("MongoDB Connected"))
  .catch(err => console.log("MongoDB connection error:", err));
```

**JWT signing uses the environment secret** — `backend/server.js:136-138`

Login tokens are signed with process.env.JWT_SECRET.

```javascript
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
      expiresIn: "7d",
    });
```

**JWT verification uses the same secret** — `backend/middleware/middleware.js:8-10`

The middleware verifies tokens with process.env.JWT_SECRET.

```javascript
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // attach user info to request
```

#### Validation

Validated by tracing the public route, attacker-controlled request fields, missing backend guard, and resulting database or security-sensitive sink in the repository.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

**MongoDB URI is loaded from environment** — `backend/server.js:63-66`

The backend connects with process.env.MONGO_URI, whose value is present in the tracked .env file.

```javascript
// CONNECT TO MONGODBser
mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log("MongoDB Connected"))
  .catch(err => console.log("MongoDB connection error:", err));
```

**JWT signing uses the environment secret** — `backend/server.js:136-138`

Login tokens are signed with process.env.JWT_SECRET.

```javascript
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
      expiresIn: "7d",
    });
```

**JWT verification uses the same secret** — `backend/middleware/middleware.js:8-10`

The middleware verifies tokens with process.env.JWT_SECRET.

```javascript
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // attach user info to request
```

Counterevidence and remaining uncertainty:
- No global Express authentication middleware is registered in backend/server.js; verifyToken exists in backend/middleware/middleware.js but is not imported or attached to these routes.

#### Dataflow

Tracked backend/.env secret -\> dotenv process.env -\> mongoose.connect and jwt.sign/jwt.verify.

- **Source:** Repository access to backend/.env.

- **Sink:** MongoDB connection and JWT signing/verification.

- **Outcome:** Credential reuse can expose database contents or allow forged application sessions if the repository leaks.

**MongoDB URI is loaded from environment** — `backend/server.js:63-66`

The backend connects with process.env.MONGO_URI, whose value is present in the tracked .env file.

```javascript
// CONNECT TO MONGODBser
mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log("MongoDB Connected"))
  .catch(err => console.log("MongoDB connection error:", err));
```

**JWT signing uses the environment secret** — `backend/server.js:136-138`

Login tokens are signed with process.env.JWT_SECRET.

```javascript
    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
      expiresIn: "7d",
    });
```

**JWT verification uses the same secret** — `backend/middleware/middleware.js:8-10`

The middleware verifies tokens with process.env.JWT_SECRET.

```javascript
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // attach user info to request
```

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** remote unauthenticated caller

- **Entry point:** Public Express route in backend/server.js

Preconditions:
- An attacker gains access to the repository, build artifact, or any place this .env file is distributed.
- The secrets have not been rotated after exposure.

#### Severity

**High** — High severity is assigned because backend/.env is present in the repository and contains the MongoDB connection secret and JWT signing secret used by server.js and the JWT middleware; the secret values were intentionally redacted from scan artifacts.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Remove backend/.env from version control, rotate the MongoDB credential and JWT secret, load secrets from a managed secret store, and add secret scanning/pre-commit controls.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

<a id="finding-6"></a>

### [6] Public vehicle APIs allow cross-user vehicle creation, lookup, and overwrite

| Field | Value |
| --- | --- |
| Severity | high |
| Confidence | high |
| Confidence rationale | Static route and model evidence directly supports the finding; live production/database behavior was not exercised. |
| Category | Authorization bypass / IDOR |
| CWE | CWE-639, CWE-862 |
| Affected lines | backend/server.js:240-257, backend/server.js:266-304, backend/server.js:471-489, backend/models/vehicle.js:3-37 |

#### Summary

vehicle endpoints accept user ids, uids, and vehicle numbers from public requests and create, disclose, or upsert vehicle records without authenticating the caller or proving ownership of the target user or vehicle.

#### Root Cause

Object ownership is selected by request parameters and body fields, not by authenticated server-side subject checks.

**Vehicle create and lookup trust request identifiers** — `backend/server.js:240-304`

The public routes create records from body userId/uid and read by vehicleNumber or uid.

```javascript
app.post("/vehicles", async (req, res) => {
  try {
    const { userId, uid, brand, model, year, plateNumber, vehicleNumber, selectedBrand, selectedModel, vehicleType, mileage, vehiclePhotoUrl } = req.body;

    const newVehicle = await Vehicle.create({
      userId: userId || uid,
      brand,
      model,
      year,
      plateNumber,
      vehicleNumber: vehicleNumber || plateNumber,
      selectedBrand,
      selectedModel,
      vehicleType,
      mileage,
      vehiclePhotoUrl,
      uid: uid || userId,
    });

    res.status(201).json(newVehicle);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET VEHICLE BY VEHICLE NUMBER
app.get("/vehicles/number/:vehicleNumber", async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    const vehicle = await Vehicle.findOne({ vehicleNumber });
    if (!vehicle) {
      return res.status(404).json({ message: "Vehicle not found" });
    }
    res.json(vehicle);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET VEHICLE BY USER IDENTIFIER
app.get("/vehicles/:uid", async (req, res) => {
  try {
    const { uid } = req.params;

    const userFilter = [{ uid }];
    if (mongoose.Types.ObjectId.isValid(uid)) {
      userFilter.push({ _id: uid });
    }

    const user = await User.findOne({ $or: userFilter });

    const vehicleFilter = [{ userId: uid }];
    if (user?._id) {
      vehicleFilter.push({ userId: user._id });
    }

    const vehicle = await Vehicle.findOne({ $or: vehicleFilter });
    if (!vehicle) {
      return res.status(404).json({ message: "Vehicle not found" });
    }

    res.json({
      ...vehicle.toObject(),
      vehicleNumber: vehicle.vehicleNumber || vehicle.plateNumber || "",
    });
```

**Vehicle upsert overwrites by caller-selected uid** — `backend/server.js:471-489`

The upsert route selects and overwrites a vehicle record using the path uid and request body.

```javascript
app.put("/vehicles/by-user/:uid", async (req, res) => {
  try {
    const { uid } = req.params;
    const userFilter = [{ uid }];
    if (mongoose.Types.ObjectId.isValid(uid)) {
      userFilter.push({ _id: uid });
    }
    const user = await User.findOne({ $or: userFilter });

    const vehicleFilter = [{ userId: uid }, { uid }];
    if (user?._id) {
      vehicleFilter.push({ userId: user._id.toString() });
      vehicleFilter.push({ userId: user._id });
    }

    const updated = await Vehicle.findOneAndUpdate(
      { $or: vehicleFilter },
      { ...req.body, uid, userId: uid },
      { new: true, upsert: true }
```

**Vehicle records contain owner linkage and vehicle metadata** — `backend/models/vehicle.js:3-37`

The model stores userId, uid, vehicleNumber, plate, brand/model, mileage, and photo URL.

```javascript
const vehicleSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true
  },
  uid: {
    type: String,
    index: true,
  },
  brand: {
    type: String,
    default: ""
  },
  model: {
    type: String,
    default: ""
  },
  year: {
    type: Number
  },
  plateNumber: {
    type: String,
    default: ""
  },
  vehicleNumber: {
    type: String,
    index: true,
  },
  selectedBrand: String,
  selectedModel: String,
  vehicleType: String,
  mileage: String,
  vehiclePhotoUrl: String,
}, { timestamps: true });
```

#### Validation

Validated by tracing the public route, attacker-controlled request fields, missing backend guard, and resulting database or security-sensitive sink in the repository.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

**Vehicle create and lookup trust request identifiers** — `backend/server.js:240-304`

The public routes create records from body userId/uid and read by vehicleNumber or uid.

```javascript
app.post("/vehicles", async (req, res) => {
  try {
    const { userId, uid, brand, model, year, plateNumber, vehicleNumber, selectedBrand, selectedModel, vehicleType, mileage, vehiclePhotoUrl } = req.body;

    const newVehicle = await Vehicle.create({
      userId: userId || uid,
      brand,
      model,
      year,
      plateNumber,
      vehicleNumber: vehicleNumber || plateNumber,
      selectedBrand,
      selectedModel,
      vehicleType,
      mileage,
      vehiclePhotoUrl,
      uid: uid || userId,
    });

    res.status(201).json(newVehicle);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET VEHICLE BY VEHICLE NUMBER
app.get("/vehicles/number/:vehicleNumber", async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    const vehicle = await Vehicle.findOne({ vehicleNumber });
    if (!vehicle) {
      return res.status(404).json({ message: "Vehicle not found" });
    }
    res.json(vehicle);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET VEHICLE BY USER IDENTIFIER
app.get("/vehicles/:uid", async (req, res) => {
  try {
    const { uid } = req.params;

    const userFilter = [{ uid }];
    if (mongoose.Types.ObjectId.isValid(uid)) {
      userFilter.push({ _id: uid });
    }

    const user = await User.findOne({ $or: userFilter });

    const vehicleFilter = [{ userId: uid }];
    if (user?._id) {
      vehicleFilter.push({ userId: user._id });
    }

    const vehicle = await Vehicle.findOne({ $or: vehicleFilter });
    if (!vehicle) {
      return res.status(404).json({ message: "Vehicle not found" });
    }

    res.json({
      ...vehicle.toObject(),
      vehicleNumber: vehicle.vehicleNumber || vehicle.plateNumber || "",
    });
```

**Vehicle upsert overwrites by caller-selected uid** — `backend/server.js:471-489`

The upsert route selects and overwrites a vehicle record using the path uid and request body.

```javascript
app.put("/vehicles/by-user/:uid", async (req, res) => {
  try {
    const { uid } = req.params;
    const userFilter = [{ uid }];
    if (mongoose.Types.ObjectId.isValid(uid)) {
      userFilter.push({ _id: uid });
    }
    const user = await User.findOne({ $or: userFilter });

    const vehicleFilter = [{ userId: uid }, { uid }];
    if (user?._id) {
      vehicleFilter.push({ userId: user._id.toString() });
      vehicleFilter.push({ userId: user._id });
    }

    const updated = await Vehicle.findOneAndUpdate(
      { $or: vehicleFilter },
      { ...req.body, uid, userId: uid },
      { new: true, upsert: true }
```

**Vehicle records contain owner linkage and vehicle metadata** — `backend/models/vehicle.js:3-37`

The model stores userId, uid, vehicleNumber, plate, brand/model, mileage, and photo URL.

```javascript
const vehicleSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true
  },
  uid: {
    type: String,
    index: true,
  },
  brand: {
    type: String,
    default: ""
  },
  model: {
    type: String,
    default: ""
  },
  year: {
    type: Number
  },
  plateNumber: {
    type: String,
    default: ""
  },
  vehicleNumber: {
    type: String,
    index: true,
  },
  selectedBrand: String,
  selectedModel: String,
  vehicleType: String,
  mileage: String,
  vehiclePhotoUrl: String,
}, { timestamps: true });
```

Counterevidence and remaining uncertainty:
- No global Express authentication middleware is registered in backend/server.js; verifyToken exists in backend/middleware/middleware.js but is not imported or attached to these routes.

#### Dataflow

Caller-selected userId/uid/vehicleNumber -\> Vehicle model create/find/findOneAndUpdate -\> cross-user vehicle data disclosure or overwrite.

- **Source:** Caller-controlled path identifiers and JSON vehicle fields.

- **Sink:** Vehicle.create, Vehicle.findOne, and Vehicle.findOneAndUpdate with upsert.

- **Outcome:** Cross-user vehicle profile disclosure and tampering.

**Vehicle create and lookup trust request identifiers** — `backend/server.js:240-304`

The public routes create records from body userId/uid and read by vehicleNumber or uid.

```javascript
app.post("/vehicles", async (req, res) => {
  try {
    const { userId, uid, brand, model, year, plateNumber, vehicleNumber, selectedBrand, selectedModel, vehicleType, mileage, vehiclePhotoUrl } = req.body;

    const newVehicle = await Vehicle.create({
      userId: userId || uid,
      brand,
      model,
      year,
      plateNumber,
      vehicleNumber: vehicleNumber || plateNumber,
      selectedBrand,
      selectedModel,
      vehicleType,
      mileage,
      vehiclePhotoUrl,
      uid: uid || userId,
    });

    res.status(201).json(newVehicle);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET VEHICLE BY VEHICLE NUMBER
app.get("/vehicles/number/:vehicleNumber", async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    const vehicle = await Vehicle.findOne({ vehicleNumber });
    if (!vehicle) {
      return res.status(404).json({ message: "Vehicle not found" });
    }
    res.json(vehicle);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET VEHICLE BY USER IDENTIFIER
app.get("/vehicles/:uid", async (req, res) => {
  try {
    const { uid } = req.params;

    const userFilter = [{ uid }];
    if (mongoose.Types.ObjectId.isValid(uid)) {
      userFilter.push({ _id: uid });
    }

    const user = await User.findOne({ $or: userFilter });

    const vehicleFilter = [{ userId: uid }];
    if (user?._id) {
      vehicleFilter.push({ userId: user._id });
    }

    const vehicle = await Vehicle.findOne({ $or: vehicleFilter });
    if (!vehicle) {
      return res.status(404).json({ message: "Vehicle not found" });
    }

    res.json({
      ...vehicle.toObject(),
      vehicleNumber: vehicle.vehicleNumber || vehicle.plateNumber || "",
    });
```

**Vehicle upsert overwrites by caller-selected uid** — `backend/server.js:471-489`

The upsert route selects and overwrites a vehicle record using the path uid and request body.

```javascript
app.put("/vehicles/by-user/:uid", async (req, res) => {
  try {
    const { uid } = req.params;
    const userFilter = [{ uid }];
    if (mongoose.Types.ObjectId.isValid(uid)) {
      userFilter.push({ _id: uid });
    }
    const user = await User.findOne({ $or: userFilter });

    const vehicleFilter = [{ userId: uid }, { uid }];
    if (user?._id) {
      vehicleFilter.push({ userId: user._id.toString() });
      vehicleFilter.push({ userId: user._id });
    }

    const updated = await Vehicle.findOneAndUpdate(
      { $or: vehicleFilter },
      { ...req.body, uid, userId: uid },
      { new: true, upsert: true }
```

**Vehicle records contain owner linkage and vehicle metadata** — `backend/models/vehicle.js:3-37`

The model stores userId, uid, vehicleNumber, plate, brand/model, mileage, and photo URL.

```javascript
const vehicleSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true
  },
  uid: {
    type: String,
    index: true,
  },
  brand: {
    type: String,
    default: ""
  },
  model: {
    type: String,
    default: ""
  },
  year: {
    type: Number
  },
  plateNumber: {
    type: String,
    default: ""
  },
  vehicleNumber: {
    type: String,
    index: true,
  },
  selectedBrand: String,
  selectedModel: String,
  vehicleType: String,
  mileage: String,
  vehiclePhotoUrl: String,
}, { timestamps: true });
```

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** remote unauthenticated caller

- **Entry point:** Public Express route in backend/server.js

Preconditions:
- The backend is reachable at the configured API origin.
- No out-of-repository reverse proxy adds a stronger control before the route.

#### Severity

**High** — High severity is assigned because vehicle endpoints accept user ids, uids, and vehicle numbers from public requests and create, disclose, or upsert vehicle records without authenticating the caller or proving ownership of the target user or vehicle.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Require authentication for vehicle APIs, bind all operations to req.user.id or an authorized service-center relationship, and reject caller-supplied ownership fields that do not match the authenticated subject.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

<a id="finding-7"></a>

### [7] Public service-center administration routes expose and mutate approval workflow state

| Field | Value |
| --- | --- |
| Severity | high |
| Confidence | high |
| Confidence rationale | Static route and model evidence directly supports the finding; live production/database behavior was not exercised. |
| Category | Authorization bypass / admin workflow tampering |
| CWE | CWE-862, CWE-269, CWE-200 |
| Affected lines | backend/server.js:813-850, backend/server.js:915-927, backend/server.js:934-986, backend/server.js:993-1042, backend/server.js:1049-1072, backend/models/ServiceCenterRequest.js:3-24 |

#### Summary

service-center request listing, accept, reject, restore, delete, duplicate-check, and status routes are public; callers can enumerate applicant details and drive admin-only onboarding state changes, including creating or upgrading Service Center accounts.

#### Root Cause

Admin workflow routes are exposed without backend authentication or role checks. The client labels them admin screens, but the server does not enforce that boundary.

**Duplicate-check endpoint enumerates user/request fields** — `backend/server.js:813-850`

The public helper checks email, username, and serviceCenterName across User and ServiceCenterRequest.

```javascript
app.get("/api/service/check", async (req, res) => {
  try {
    const field = (req.query.field || "").toString();
    const value = (req.query.value || "").toString().trim();

    if (!field || !value) {
      return res.status(400).json({ message: "field and value are required", exists: false });
    }

    const normalizedField = field.toLowerCase();
    let exists = false;

    if (normalizedField === "email") {
      const user = await User.findOne({
        $or: [{ email: value }, { Email: value }],
      });
      const request = await ServiceCenterRequest.findOne({ email: value });
      exists = !!user || !!request;
    } else if (normalizedField === "username") {
      const user = await User.findOne({
        $or: [{ username: value }, { Username: value }],
      });
      const request = await ServiceCenterRequest.findOne({ username: value });
      exists = !!user || !!request;
    } else if (normalizedField === "servicecentername") {
      const safeValue = value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const exactCI = new RegExp(`^${safeValue}$`, "i");

      const request = await ServiceCenterRequest.findOne({ serviceCenterName: exactCI });
      const user = await User.findOne({
        $or: [{ serviceCenterName: exactCI }, { name: exactCI }, { Name: exactCI }],
      });
      exists = !!user || !!request;
    } else {
      return res.status(400).json({ message: "unsupported field", exists: false });
    }

    return res.json({ exists });
```

**Request listing and accept routes lack admin auth** — `backend/server.js:915-986`

The list route returns applicant records and the accept route creates or upgrades Service Center users.

```javascript
app.get("/service-center-requests", async (req, res) => {
  try {
    const { status } = req.query;
    const query = {};

    if (status) {
      query.status = status;
    }

    const requests = await ServiceCenterRequest.find(query)
      .select("-passwordHash")
      .sort({ createdAt: -1 });
    return res.json(requests);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// ACCEPT SERVICE CENTER REQUEST (ADMIN)
app.post("/service-center-requests/accept/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const request = await ServiceCenterRequest.findById(id).select(
      "+passwordHash"
    );

    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    const fallbackPasswordHash = await bcrypt.hash(
      `${request.username}@123`,
      10
    );
    const loginPasswordHash = request.passwordHash || fallbackPasswordHash;

    // Ensure a Service Center user exists for approved requests.
    let serviceCenterUser = await User.findOne({
      $or: [{ email: request.email }, { username: request.username }],
    });

    if (!serviceCenterUser) {
      serviceCenterUser = await User.create({
        name: request.serviceCenterName || request.ownerName || "Service Center",
        serviceCenterName: request.serviceCenterName,
        email: request.email,
        username: request.username,
        password: loginPasswordHash,
        address: request.address,
        contact: request.contact,
        city: request.city,
        branch: request.city,
        userType: "Service Center",
      });
    } else {
      serviceCenterUser.userType = "Service Center";
      serviceCenterUser.serviceCenterName =
        request.serviceCenterName || serviceCenterUser.serviceCenterName;
      serviceCenterUser.city = request.city || serviceCenterUser.city;
      serviceCenterUser.branch = request.city || serviceCenterUser.branch;
      await serviceCenterUser.save();
    }

    request.status = "accepted";
    await request.save();

    return res.json({
      message: "Request accepted",
      userId: serviceCenterUser._id,
      username: request.username,
      status: request.status,
    });
```

**Reject, restore, delete, and status routes are public** — `backend/server.js:993-1072`

State-changing and status-disclosure routes operate directly on request ids or emails.

```javascript
app.put("/service-center-requests/reject/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const updated = await ServiceCenterRequest.findByIdAndUpdate(
      id,
      { status: "rejected" },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Request not found" });
    }

    return res.json({ message: "Request rejected", request: updated });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// RESTORE REJECTED REQUEST TO PENDING (ADMIN)
app.put("/service-center-requests/restore/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const updated = await ServiceCenterRequest.findByIdAndUpdate(
      id,
      { status: "pending" },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Request not found" });
    }

    return res.json({ message: "Request restored", request: updated });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// DELETE SERVICE CENTER REQUEST (ADMIN)
app.delete("/service-center-requests/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await ServiceCenterRequest.findByIdAndDelete(id);

    if (!deleted) {
      return res.status(404).json({ message: "Request not found" });
    }

    return res.json({ message: "Request deleted" });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// SERVICE CENTER REQUEST STATUS CHECK BY EMAIL
app.get("/service-center-status/:email", async (req, res) => {
  try {
    const { email } = req.params;

    const approvedUser = await User.findOne({
      $and: [
        { $or: [{ Email: email }, { email }] },
        { $or: [{ "User Type": "Service Center" }, { userType: "Service Center" }] },
      ],
    });

    if (approvedUser) {
      return res.json({
        status: "approved",
        username: approvedUser.username || "",
      });
    }

    const request = await ServiceCenterRequest.findOne({ email });
    if (!request) {
      return res.json({ status: "not-found" });
    }

    res.json({ status: request.status, username: request.username || "" });
```

#### Validation

Validated by tracing the public route, attacker-controlled request fields, missing backend guard, and resulting database or security-sensitive sink in the repository.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

**Duplicate-check endpoint enumerates user/request fields** — `backend/server.js:813-850`

The public helper checks email, username, and serviceCenterName across User and ServiceCenterRequest.

```javascript
app.get("/api/service/check", async (req, res) => {
  try {
    const field = (req.query.field || "").toString();
    const value = (req.query.value || "").toString().trim();

    if (!field || !value) {
      return res.status(400).json({ message: "field and value are required", exists: false });
    }

    const normalizedField = field.toLowerCase();
    let exists = false;

    if (normalizedField === "email") {
      const user = await User.findOne({
        $or: [{ email: value }, { Email: value }],
      });
      const request = await ServiceCenterRequest.findOne({ email: value });
      exists = !!user || !!request;
    } else if (normalizedField === "username") {
      const user = await User.findOne({
        $or: [{ username: value }, { Username: value }],
      });
      const request = await ServiceCenterRequest.findOne({ username: value });
      exists = !!user || !!request;
    } else if (normalizedField === "servicecentername") {
      const safeValue = value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const exactCI = new RegExp(`^${safeValue}$`, "i");

      const request = await ServiceCenterRequest.findOne({ serviceCenterName: exactCI });
      const user = await User.findOne({
        $or: [{ serviceCenterName: exactCI }, { name: exactCI }, { Name: exactCI }],
      });
      exists = !!user || !!request;
    } else {
      return res.status(400).json({ message: "unsupported field", exists: false });
    }

    return res.json({ exists });
```

**Request listing and accept routes lack admin auth** — `backend/server.js:915-986`

The list route returns applicant records and the accept route creates or upgrades Service Center users.

```javascript
app.get("/service-center-requests", async (req, res) => {
  try {
    const { status } = req.query;
    const query = {};

    if (status) {
      query.status = status;
    }

    const requests = await ServiceCenterRequest.find(query)
      .select("-passwordHash")
      .sort({ createdAt: -1 });
    return res.json(requests);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// ACCEPT SERVICE CENTER REQUEST (ADMIN)
app.post("/service-center-requests/accept/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const request = await ServiceCenterRequest.findById(id).select(
      "+passwordHash"
    );

    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    const fallbackPasswordHash = await bcrypt.hash(
      `${request.username}@123`,
      10
    );
    const loginPasswordHash = request.passwordHash || fallbackPasswordHash;

    // Ensure a Service Center user exists for approved requests.
    let serviceCenterUser = await User.findOne({
      $or: [{ email: request.email }, { username: request.username }],
    });

    if (!serviceCenterUser) {
      serviceCenterUser = await User.create({
        name: request.serviceCenterName || request.ownerName || "Service Center",
        serviceCenterName: request.serviceCenterName,
        email: request.email,
        username: request.username,
        password: loginPasswordHash,
        address: request.address,
        contact: request.contact,
        city: request.city,
        branch: request.city,
        userType: "Service Center",
      });
    } else {
      serviceCenterUser.userType = "Service Center";
      serviceCenterUser.serviceCenterName =
        request.serviceCenterName || serviceCenterUser.serviceCenterName;
      serviceCenterUser.city = request.city || serviceCenterUser.city;
      serviceCenterUser.branch = request.city || serviceCenterUser.branch;
      await serviceCenterUser.save();
    }

    request.status = "accepted";
    await request.save();

    return res.json({
      message: "Request accepted",
      userId: serviceCenterUser._id,
      username: request.username,
      status: request.status,
    });
```

**Reject, restore, delete, and status routes are public** — `backend/server.js:993-1072`

State-changing and status-disclosure routes operate directly on request ids or emails.

```javascript
app.put("/service-center-requests/reject/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const updated = await ServiceCenterRequest.findByIdAndUpdate(
      id,
      { status: "rejected" },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Request not found" });
    }

    return res.json({ message: "Request rejected", request: updated });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// RESTORE REJECTED REQUEST TO PENDING (ADMIN)
app.put("/service-center-requests/restore/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const updated = await ServiceCenterRequest.findByIdAndUpdate(
      id,
      { status: "pending" },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Request not found" });
    }

    return res.json({ message: "Request restored", request: updated });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// DELETE SERVICE CENTER REQUEST (ADMIN)
app.delete("/service-center-requests/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await ServiceCenterRequest.findByIdAndDelete(id);

    if (!deleted) {
      return res.status(404).json({ message: "Request not found" });
    }

    return res.json({ message: "Request deleted" });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// SERVICE CENTER REQUEST STATUS CHECK BY EMAIL
app.get("/service-center-status/:email", async (req, res) => {
  try {
    const { email } = req.params;

    const approvedUser = await User.findOne({
      $and: [
        { $or: [{ Email: email }, { email }] },
        { $or: [{ "User Type": "Service Center" }, { userType: "Service Center" }] },
      ],
    });

    if (approvedUser) {
      return res.json({
        status: "approved",
        username: approvedUser.username || "",
      });
    }

    const request = await ServiceCenterRequest.findOne({ email });
    if (!request) {
      return res.json({ status: "not-found" });
    }

    res.json({ status: request.status, username: request.username || "" });
```

Counterevidence and remaining uncertainty:
- No global Express authentication middleware is registered in backend/server.js; verifyToken exists in backend/middleware/middleware.js but is not imported or attached to these routes.

#### Dataflow

Unauthenticated request id/email/query -\> ServiceCenterRequest/User database operations -\> applicant data disclosure or approval state mutation.

- **Source:** Caller-controlled request id, status query, duplicate-check field/value, or email.

- **Sink:** ServiceCenterRequest.find/findByIdAndUpdate/findByIdAndDelete and User.create/save.

- **Outcome:** Applicant PII exposure, unauthorized denial/deletion/restoration, or unauthorized Service Center account creation.

**Duplicate-check endpoint enumerates user/request fields** — `backend/server.js:813-850`

The public helper checks email, username, and serviceCenterName across User and ServiceCenterRequest.

```javascript
app.get("/api/service/check", async (req, res) => {
  try {
    const field = (req.query.field || "").toString();
    const value = (req.query.value || "").toString().trim();

    if (!field || !value) {
      return res.status(400).json({ message: "field and value are required", exists: false });
    }

    const normalizedField = field.toLowerCase();
    let exists = false;

    if (normalizedField === "email") {
      const user = await User.findOne({
        $or: [{ email: value }, { Email: value }],
      });
      const request = await ServiceCenterRequest.findOne({ email: value });
      exists = !!user || !!request;
    } else if (normalizedField === "username") {
      const user = await User.findOne({
        $or: [{ username: value }, { Username: value }],
      });
      const request = await ServiceCenterRequest.findOne({ username: value });
      exists = !!user || !!request;
    } else if (normalizedField === "servicecentername") {
      const safeValue = value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const exactCI = new RegExp(`^${safeValue}$`, "i");

      const request = await ServiceCenterRequest.findOne({ serviceCenterName: exactCI });
      const user = await User.findOne({
        $or: [{ serviceCenterName: exactCI }, { name: exactCI }, { Name: exactCI }],
      });
      exists = !!user || !!request;
    } else {
      return res.status(400).json({ message: "unsupported field", exists: false });
    }

    return res.json({ exists });
```

**Request listing and accept routes lack admin auth** — `backend/server.js:915-986`

The list route returns applicant records and the accept route creates or upgrades Service Center users.

```javascript
app.get("/service-center-requests", async (req, res) => {
  try {
    const { status } = req.query;
    const query = {};

    if (status) {
      query.status = status;
    }

    const requests = await ServiceCenterRequest.find(query)
      .select("-passwordHash")
      .sort({ createdAt: -1 });
    return res.json(requests);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// ACCEPT SERVICE CENTER REQUEST (ADMIN)
app.post("/service-center-requests/accept/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const request = await ServiceCenterRequest.findById(id).select(
      "+passwordHash"
    );

    if (!request) {
      return res.status(404).json({ message: "Request not found" });
    }

    const fallbackPasswordHash = await bcrypt.hash(
      `${request.username}@123`,
      10
    );
    const loginPasswordHash = request.passwordHash || fallbackPasswordHash;

    // Ensure a Service Center user exists for approved requests.
    let serviceCenterUser = await User.findOne({
      $or: [{ email: request.email }, { username: request.username }],
    });

    if (!serviceCenterUser) {
      serviceCenterUser = await User.create({
        name: request.serviceCenterName || request.ownerName || "Service Center",
        serviceCenterName: request.serviceCenterName,
        email: request.email,
        username: request.username,
        password: loginPasswordHash,
        address: request.address,
        contact: request.contact,
        city: request.city,
        branch: request.city,
        userType: "Service Center",
      });
    } else {
      serviceCenterUser.userType = "Service Center";
      serviceCenterUser.serviceCenterName =
        request.serviceCenterName || serviceCenterUser.serviceCenterName;
      serviceCenterUser.city = request.city || serviceCenterUser.city;
      serviceCenterUser.branch = request.city || serviceCenterUser.branch;
      await serviceCenterUser.save();
    }

    request.status = "accepted";
    await request.save();

    return res.json({
      message: "Request accepted",
      userId: serviceCenterUser._id,
      username: request.username,
      status: request.status,
    });
```

**Reject, restore, delete, and status routes are public** — `backend/server.js:993-1072`

State-changing and status-disclosure routes operate directly on request ids or emails.

```javascript
app.put("/service-center-requests/reject/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const updated = await ServiceCenterRequest.findByIdAndUpdate(
      id,
      { status: "rejected" },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Request not found" });
    }

    return res.json({ message: "Request rejected", request: updated });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// RESTORE REJECTED REQUEST TO PENDING (ADMIN)
app.put("/service-center-requests/restore/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const updated = await ServiceCenterRequest.findByIdAndUpdate(
      id,
      { status: "pending" },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Request not found" });
    }

    return res.json({ message: "Request restored", request: updated });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// DELETE SERVICE CENTER REQUEST (ADMIN)
app.delete("/service-center-requests/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await ServiceCenterRequest.findByIdAndDelete(id);

    if (!deleted) {
      return res.status(404).json({ message: "Request not found" });
    }

    return res.json({ message: "Request deleted" });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// SERVICE CENTER REQUEST STATUS CHECK BY EMAIL
app.get("/service-center-status/:email", async (req, res) => {
  try {
    const { email } = req.params;

    const approvedUser = await User.findOne({
      $and: [
        { $or: [{ Email: email }, { email }] },
        { $or: [{ "User Type": "Service Center" }, { userType: "Service Center" }] },
      ],
    });

    if (approvedUser) {
      return res.json({
        status: "approved",
        username: approvedUser.username || "",
      });
    }

    const request = await ServiceCenterRequest.findOne({ email });
    if (!request) {
      return res.json({ status: "not-found" });
    }

    res.json({ status: request.status, username: request.username || "" });
```

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** remote unauthenticated caller

- **Entry point:** Public Express route in backend/server.js

Preconditions:
- The backend is reachable at the configured API origin.
- No out-of-repository reverse proxy adds a stronger control before the route.

#### Severity

**High** — High severity is assigned because service-center request listing, accept, reject, restore, delete, duplicate-check, and status routes are public; callers can enumerate applicant details and drive admin-only onboarding state changes, including creating or upgrading Service Center accounts.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Protect all service-center request administration routes with authenticated admin middleware, keep applicant status lookup scoped to the applicant, and separate public availability checks from sensitive request state.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

<a id="finding-8"></a>

### [8] Android release builds are signed with the debug key

| Field | Value |
| --- | --- |
| Severity | high |
| Confidence | high |
| Confidence rationale | Static route and model evidence directly supports the finding; live production/database behavior was not exercised. |
| Category | Insecure release signing / supply-chain weakness |
| CWE | CWE-321, CWE-798 |
| Affected lines | android/app/build.gradle.kts:35-40 |

#### Summary

the Android release build type explicitly uses signingConfigs.getByName(debug), so release APKs produced from this configuration are signed with the publicly known debug keystore instead of a private release signing key.

#### Root Cause

The release build violates the invariant that distributable app artifacts must be signed with a private release key controlled by the project owner.

**Release build uses debug signing config** — `android/app/build.gradle.kts:35-40`

The release block explicitly assigns the debug signing config.

```kotlin
    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
```

#### Validation

Validated by tracing the public route, attacker-controlled request fields, missing backend guard, and resulting database or security-sensitive sink in the repository.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

**Release build uses debug signing config** — `android/app/build.gradle.kts:35-40`

The release block explicitly assigns the debug signing config.

```kotlin
    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
```

Counterevidence and remaining uncertainty:
- No global Express authentication middleware is registered in backend/server.js; verifyToken exists in backend/middleware/middleware.js but is not imported or attached to these routes.

#### Dataflow

Release build task -\> release buildType signingConfig -\> debug keystore signature on distributable APK/AAB.

- **Source:** Repository build configuration.

- **Sink:** Android release signing configuration.

- **Outcome:** A release artifact can be produced with a non-private debug key, weakening update and distribution trust.

**Release build uses debug signing config** — `android/app/build.gradle.kts:35-40`

The release block explicitly assigns the debug signing config.

```kotlin
    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
```

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** attacker who can distribute or replace APKs in a channel that trusts package signatures

- **Entry point:** Android release build configuration

Preconditions:
- A release artifact is built from this Gradle configuration.
- Distribution or installation path accepts the generated artifact.

#### Severity

**High** — High severity is assigned because the Android release build type explicitly uses signingConfigs.getByName(debug), so release APKs produced from this configuration are signed with the publicly known debug keystore instead of a private release signing key.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Create a private release signing configuration backed by protected CI or local keystore secrets, remove debug signing from release builds, and fail release builds when no release signing config is present.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

<a id="finding-9"></a>

### [9] Public upload route uses a Multer version with reachable denial-of-service advisories

| Field | Value |
| --- | --- |
| Severity | high |
| Confidence | high |
| Confidence rationale | Static route and model evidence directly supports the finding; live production/database behavior was not exercised. |
| Category | Denial of service / vulnerable dependency |
| CWE | CWE-400, CWE-459 |
| Affected lines | backend/package.json:18-19, backend/package-lock.json:845-853, backend/server.js:1203 |

#### Summary

backend/package-lock.json installs multer 2.1.1, which npm audit flags for multipart denial-of-service advisories, and the unauthenticated /documents/upload route invokes documentUpload.single on attacker-controlled multipart requests.

#### Root Cause

A vulnerable multipart parser is reachable from an unauthenticated upload route without repository-visible size or abuse limits.

**Multer dependency is pinned below fixed range** — `backend/package.json:18-19`

The backend directly depends on multer.

```json
    "mongoose": "^9.2.1",
    "multer": "^2.1.1"
```

**Installed Multer version is 2.1.1** — `backend/package-lock.json:845-853`

The lockfile resolves multer 2.1.1.

```json
    "node_modules/multer": {
      "version": "2.1.1",
      "resolved": "https://registry.npmjs.org/multer/-/multer-2.1.1.tgz",
      "integrity": "sha512-mo+QTzKlx8R7E5ylSXxWzGoXoZbOsRMpyitcht8By2KHvMbf3tjwosZ/Mu/XYU6UuJ3VZnODIrak5ZrPiPyB6A==",
      "license": "MIT",
      "dependencies": {
        "append-field": "^1.0.0",
        "busboy": "^1.6.0",
        "concat-stream": "^2.0.0",
```

**Public route invokes the parser** — `backend/server.js:1203`

The upload route applies documentUpload.single to public requests.

```javascript
app.post('/documents/upload', documentUpload.single('photo'), (req, res) => {
```

#### Validation

Validated by local npm audit, which reported GHSA-72gw-mp4g-v24j and GHSA-3p4h-7m6x-2hcm against installed multer 2.1.1, and by tracing the public upload route to documentUpload.single.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

**Multer dependency is pinned below fixed range** — `backend/package.json:18-19`

The backend directly depends on multer.

```json
    "mongoose": "^9.2.1",
    "multer": "^2.1.1"
```

**Installed Multer version is 2.1.1** — `backend/package-lock.json:845-853`

The lockfile resolves multer 2.1.1.

```json
    "node_modules/multer": {
      "version": "2.1.1",
      "resolved": "https://registry.npmjs.org/multer/-/multer-2.1.1.tgz",
      "integrity": "sha512-mo+QTzKlx8R7E5ylSXxWzGoXoZbOsRMpyitcht8By2KHvMbf3tjwosZ/Mu/XYU6UuJ3VZnODIrak5ZrPiPyB6A==",
      "license": "MIT",
      "dependencies": {
        "append-field": "^1.0.0",
        "busboy": "^1.6.0",
        "concat-stream": "^2.0.0",
```

**Public route invokes the parser** — `backend/server.js:1203`

The upload route applies documentUpload.single to public requests.

```javascript
app.post('/documents/upload', documentUpload.single('photo'), (req, res) => {
```

Evidence:
- npm audit --omit=dev --json reported high and moderate Multer advisories affecting installed 2.1.1.

Counterevidence and remaining uncertainty:
- No global Express authentication middleware is registered in backend/server.js; verifyToken exists in backend/middleware/middleware.js but is not imported or attached to these routes.

#### Dataflow

Unauthenticated multipart request -\> documentUpload.single -\> vulnerable multer/busboy parsing path.

- **Source:** Caller-controlled multipart form body.

- **Sink:** Multer multipart parsing on /documents/upload.

- **Outcome:** Remote unauthenticated availability impact on the backend upload path.

**Multer dependency is pinned below fixed range** — `backend/package.json:18-19`

The backend directly depends on multer.

```json
    "mongoose": "^9.2.1",
    "multer": "^2.1.1"
```

**Installed Multer version is 2.1.1** — `backend/package-lock.json:845-853`

The lockfile resolves multer 2.1.1.

```json
    "node_modules/multer": {
      "version": "2.1.1",
      "resolved": "https://registry.npmjs.org/multer/-/multer-2.1.1.tgz",
      "integrity": "sha512-mo+QTzKlx8R7E5ylSXxWzGoXoZbOsRMpyitcht8By2KHvMbf3tjwosZ/Mu/XYU6UuJ3VZnODIrak5ZrPiPyB6A==",
      "license": "MIT",
      "dependencies": {
        "append-field": "^1.0.0",
        "busboy": "^1.6.0",
        "concat-stream": "^2.0.0",
```

**Public route invokes the parser** — `backend/server.js:1203`

The upload route applies documentUpload.single to public requests.

```javascript
app.post('/documents/upload', documentUpload.single('photo'), (req, res) => {
```

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** remote unauthenticated caller

- **Entry point:** Public Express route in backend/server.js

Preconditions:
- The backend is reachable at the configured API origin.
- No out-of-repository reverse proxy adds a stronger control before the route.

#### Severity

**High** — High severity is assigned because backend/package-lock.json installs multer 2.1.1, which npm audit flags for multipart denial-of-service advisories, and the unauthenticated /documents/upload route invokes documentUpload.single on attacker-controlled multipart requests.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Upgrade multer to a fixed version, enforce upload size/field-count limits, add route authentication or abuse throttling, and add a dependency audit gate to CI.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

<a id="finding-10"></a>

### [10] Public receipt and service-record APIs allow billing and maintenance-history tampering

| Field | Value |
| --- | --- |
| Severity | high |
| Confidence | high |
| Confidence rationale | Static route and model evidence directly supports the finding; live production/database behavior was not exercised. |
| Category | Authorization bypass / business-record tampering |
| CWE | CWE-639, CWE-862, CWE-345 |
| Affected lines | backend/server.js:601-631, backend/server.js:639-719, backend/server.js:726-790, backend/models/ServiceReceipt.js:3-20, backend/models/ServiceRecord.js:3-17 |

#### Summary

service receipt and service record endpoints are public and permit arbitrary receipt creation, lookup, status updates, deletion, service-record creation, and broad maintenance-history lookup by user id or vehicle number.

#### Root Cause

Billing and maintenance-history records cross a business integrity boundary, but the backend does not authenticate callers or verify vehicle/service-center authority before reads and writes.

**Receipt create and read routes are public** — `backend/server.js:601-631`

The routes create receipts and list receipts by vehicle or service center from public identifiers.

```javascript
app.post("/service-receipts", async (req, res) => {
  try {
    const created = await ServiceReceipt.create(req.body);
    res.status(201).json(created);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE RECEIPTS BY VEHICLE
app.get("/service-receipts/vehicle/:vehicleNumber", async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    const receipts = await ServiceReceipt.find({ vehicleNumber }).sort({ createdAt: -1 });
    res.json(receipts);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE RECEIPTS BY SERVICE CENTER
app.get("/service-receipts/service-center/:serviceCenterId", async (req, res) => {
  try {
    const { serviceCenterId } = req.params;
    const { status, vehicleNumber } = req.query;

    const query = { serviceCenterId };
    if (status) query.status = status;
    if (vehicleNumber) query.vehicleNumber = vehicleNumber;

    const receipts = await ServiceReceipt.find(query).sort({ createdAt: -1 });
```

**Receipt status can create service records** — `backend/server.js:639-719`

The status update can create ServiceRecord entries when status is finished, and delete is public.

```javascript
app.patch("/service-receipts/:id/status", async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const updated = await ServiceReceipt.findByIdAndUpdate(
      id,
      { status },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Receipt not found" });
    }

    if (status === "finished") {
      const vehicle = await Vehicle.findOne({
        vehicleNumber: updated.vehicleNumber,
      });

      let userId = vehicle?.userId?.toString() || vehicle?.uid?.toString();

      // ── Fallback: resolve canonical userId via user lookup ──────────
      if (userId) {
        const userFilters = [{ uid: userId }];
        if (mongoose.Types.ObjectId.isValid(userId)) {
          userFilters.push({ _id: userId });
        }
        const linkedUser = await User.findOne({ $or: userFilters });
        if (linkedUser) {
          userId = linkedUser._id.toString();
        }
      }

      const serviceCenterName =
        updated["Service Center Name"] || "Unknown Service Center";

      const services = updated.services
        ? Object.fromEntries(updated.services)
        : {};

      if (Object.keys(services).length === 0) {
        console.log("No services found in receipt — nothing to create");
      }

      for (const [serviceName, price] of Object.entries(services)) {
        const recordData = {
          vehicleNumber: updated.vehicleNumber, // ← ALWAYS store vehicleNumber
          currentMileage: updated.currentMileage,
          serviceMileage: updated.currentMileage,
          serviceProvider: serviceCenterName,
          serviceCost: price?.toString() || "0",
          serviceType: serviceName,
          date: updated.createdAt || new Date(),
        };

        // Only set userId if we found one — vehicleNumber is the fallback key
        if (userId) recordData.userId = userId;

        const record = await ServiceRecord.create(recordData);
        console.log("Created ServiceRecord:", record._id, "vehicleNumber:", updated.vehicleNumber);
      }
    }

    res.json(updated);
  } catch (error) {
    console.error("Error in PATCH /service-receipts/:id/status:", error);
    res.status(500).json({ error: error.message });
  }
});


// DELETE SERVICE RECEIPT
app.delete("/service-receipts/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await ServiceReceipt.findByIdAndDelete(id);
    if (!deleted) {
      return res.status(404).json({ message: "Receipt not found" });
    }
    res.json({ message: "Receipt deleted" });
```

**Service record create and lookup routes are public** — `backend/server.js:726-790`

The routes create maintenance records from req.body and read records by broad user/vehicle expansion.

```javascript
app.post("/service-records", async (req, res) => {
  try {
    const created = await ServiceRecord.create(req.body);
    res.status(201).json(created);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE RECORDS BY USER
app.get("/service-records/user/:userId", async (req, res) => {
  try {
    const { userId } = req.params;

    // ── Build userId filters ──────────────────────────────────────
    const filters = [{ userId }];

    const userFilters = [{ uid: userId }];
    if (mongoose.Types.ObjectId.isValid(userId)) {
      userFilters.push({ _id: userId });
    }

    const user = await User.findOne({ $or: userFilters });
    if (user) {
      filters.push({ userId: user._id.toString() });
      if (user.uid) filters.push({ userId: user.uid.toString() });

      // ── Email fallback: find any shell users with same email ────
      const email = user.email || user.Email;
      if (email) {
        const sameEmailUsers = await User.find({
          $or: [{ email }, { Email: email }],
        });
        for (const u of sameEmailUsers) {
          filters.push({ userId: u._id.toString() });
          if (u.uid) filters.push({ userId: u.uid.toString() });
        }
      }
    }

    // ── vehicleNumber fallback: find user's vehicle and search by it ──
    const vehicleFilters = [{ userId }];
    if (user) {
      vehicleFilters.push({ userId: user._id.toString() });
      if (user.uid) vehicleFilters.push({ userId: user.uid.toString() });
    }

    const userVehicle = await Vehicle.findOne({ $or: vehicleFilters });
    if (userVehicle?.vehicleNumber) {
      filters.push({ vehicleNumber: userVehicle.vehicleNumber });
      console.log("Also searching by vehicleNumber:", userVehicle.vehicleNumber);
    }

    // ── Remove duplicate filters ──────────────────────────────────
    const seen = new Set();
    const uniqueFilters = filters.filter((f) => {
      const key = JSON.stringify(f);
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });

    const records = await ServiceRecord.find({
      $or: uniqueFilters,
    }).sort({ createdAt: -1 });
```

#### Validation

Validated by tracing the public route, attacker-controlled request fields, missing backend guard, and resulting database or security-sensitive sink in the repository.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

**Receipt create and read routes are public** — `backend/server.js:601-631`

The routes create receipts and list receipts by vehicle or service center from public identifiers.

```javascript
app.post("/service-receipts", async (req, res) => {
  try {
    const created = await ServiceReceipt.create(req.body);
    res.status(201).json(created);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE RECEIPTS BY VEHICLE
app.get("/service-receipts/vehicle/:vehicleNumber", async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    const receipts = await ServiceReceipt.find({ vehicleNumber }).sort({ createdAt: -1 });
    res.json(receipts);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE RECEIPTS BY SERVICE CENTER
app.get("/service-receipts/service-center/:serviceCenterId", async (req, res) => {
  try {
    const { serviceCenterId } = req.params;
    const { status, vehicleNumber } = req.query;

    const query = { serviceCenterId };
    if (status) query.status = status;
    if (vehicleNumber) query.vehicleNumber = vehicleNumber;

    const receipts = await ServiceReceipt.find(query).sort({ createdAt: -1 });
```

**Receipt status can create service records** — `backend/server.js:639-719`

The status update can create ServiceRecord entries when status is finished, and delete is public.

```javascript
app.patch("/service-receipts/:id/status", async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const updated = await ServiceReceipt.findByIdAndUpdate(
      id,
      { status },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Receipt not found" });
    }

    if (status === "finished") {
      const vehicle = await Vehicle.findOne({
        vehicleNumber: updated.vehicleNumber,
      });

      let userId = vehicle?.userId?.toString() || vehicle?.uid?.toString();

      // ── Fallback: resolve canonical userId via user lookup ──────────
      if (userId) {
        const userFilters = [{ uid: userId }];
        if (mongoose.Types.ObjectId.isValid(userId)) {
          userFilters.push({ _id: userId });
        }
        const linkedUser = await User.findOne({ $or: userFilters });
        if (linkedUser) {
          userId = linkedUser._id.toString();
        }
      }

      const serviceCenterName =
        updated["Service Center Name"] || "Unknown Service Center";

      const services = updated.services
        ? Object.fromEntries(updated.services)
        : {};

      if (Object.keys(services).length === 0) {
        console.log("No services found in receipt — nothing to create");
      }

      for (const [serviceName, price] of Object.entries(services)) {
        const recordData = {
          vehicleNumber: updated.vehicleNumber, // ← ALWAYS store vehicleNumber
          currentMileage: updated.currentMileage,
          serviceMileage: updated.currentMileage,
          serviceProvider: serviceCenterName,
          serviceCost: price?.toString() || "0",
          serviceType: serviceName,
          date: updated.createdAt || new Date(),
        };

        // Only set userId if we found one — vehicleNumber is the fallback key
        if (userId) recordData.userId = userId;

        const record = await ServiceRecord.create(recordData);
        console.log("Created ServiceRecord:", record._id, "vehicleNumber:", updated.vehicleNumber);
      }
    }

    res.json(updated);
  } catch (error) {
    console.error("Error in PATCH /service-receipts/:id/status:", error);
    res.status(500).json({ error: error.message });
  }
});


// DELETE SERVICE RECEIPT
app.delete("/service-receipts/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await ServiceReceipt.findByIdAndDelete(id);
    if (!deleted) {
      return res.status(404).json({ message: "Receipt not found" });
    }
    res.json({ message: "Receipt deleted" });
```

**Service record create and lookup routes are public** — `backend/server.js:726-790`

The routes create maintenance records from req.body and read records by broad user/vehicle expansion.

```javascript
app.post("/service-records", async (req, res) => {
  try {
    const created = await ServiceRecord.create(req.body);
    res.status(201).json(created);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE RECORDS BY USER
app.get("/service-records/user/:userId", async (req, res) => {
  try {
    const { userId } = req.params;

    // ── Build userId filters ──────────────────────────────────────
    const filters = [{ userId }];

    const userFilters = [{ uid: userId }];
    if (mongoose.Types.ObjectId.isValid(userId)) {
      userFilters.push({ _id: userId });
    }

    const user = await User.findOne({ $or: userFilters });
    if (user) {
      filters.push({ userId: user._id.toString() });
      if (user.uid) filters.push({ userId: user.uid.toString() });

      // ── Email fallback: find any shell users with same email ────
      const email = user.email || user.Email;
      if (email) {
        const sameEmailUsers = await User.find({
          $or: [{ email }, { Email: email }],
        });
        for (const u of sameEmailUsers) {
          filters.push({ userId: u._id.toString() });
          if (u.uid) filters.push({ userId: u.uid.toString() });
        }
      }
    }

    // ── vehicleNumber fallback: find user's vehicle and search by it ──
    const vehicleFilters = [{ userId }];
    if (user) {
      vehicleFilters.push({ userId: user._id.toString() });
      if (user.uid) vehicleFilters.push({ userId: user.uid.toString() });
    }

    const userVehicle = await Vehicle.findOne({ $or: vehicleFilters });
    if (userVehicle?.vehicleNumber) {
      filters.push({ vehicleNumber: userVehicle.vehicleNumber });
      console.log("Also searching by vehicleNumber:", userVehicle.vehicleNumber);
    }

    // ── Remove duplicate filters ──────────────────────────────────
    const seen = new Set();
    const uniqueFilters = filters.filter((f) => {
      const key = JSON.stringify(f);
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });

    const records = await ServiceRecord.find({
      $or: uniqueFilters,
    }).sort({ createdAt: -1 });
```

Counterevidence and remaining uncertainty:
- No global Express authentication middleware is registered in backend/server.js; verifyToken exists in backend/middleware/middleware.js but is not imported or attached to these routes.

#### Dataflow

Caller-controlled receipt/record body or ids -\> ServiceReceipt/ServiceRecord model operations -\> forged or disclosed billing and maintenance records.

- **Source:** Caller-controlled vehicleNumber, serviceCenterId, receipt id, user id, and JSON bodies.

- **Sink:** ServiceReceipt and ServiceRecord create/read/update/delete operations.

- **Outcome:** Forged invoices, forged trusted maintenance history, receipt deletion, and customer/service-center data disclosure.

**Receipt create and read routes are public** — `backend/server.js:601-631`

The routes create receipts and list receipts by vehicle or service center from public identifiers.

```javascript
app.post("/service-receipts", async (req, res) => {
  try {
    const created = await ServiceReceipt.create(req.body);
    res.status(201).json(created);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE RECEIPTS BY VEHICLE
app.get("/service-receipts/vehicle/:vehicleNumber", async (req, res) => {
  try {
    const { vehicleNumber } = req.params;
    const receipts = await ServiceReceipt.find({ vehicleNumber }).sort({ createdAt: -1 });
    res.json(receipts);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE RECEIPTS BY SERVICE CENTER
app.get("/service-receipts/service-center/:serviceCenterId", async (req, res) => {
  try {
    const { serviceCenterId } = req.params;
    const { status, vehicleNumber } = req.query;

    const query = { serviceCenterId };
    if (status) query.status = status;
    if (vehicleNumber) query.vehicleNumber = vehicleNumber;

    const receipts = await ServiceReceipt.find(query).sort({ createdAt: -1 });
```

**Receipt status can create service records** — `backend/server.js:639-719`

The status update can create ServiceRecord entries when status is finished, and delete is public.

```javascript
app.patch("/service-receipts/:id/status", async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    const updated = await ServiceReceipt.findByIdAndUpdate(
      id,
      { status },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Receipt not found" });
    }

    if (status === "finished") {
      const vehicle = await Vehicle.findOne({
        vehicleNumber: updated.vehicleNumber,
      });

      let userId = vehicle?.userId?.toString() || vehicle?.uid?.toString();

      // ── Fallback: resolve canonical userId via user lookup ──────────
      if (userId) {
        const userFilters = [{ uid: userId }];
        if (mongoose.Types.ObjectId.isValid(userId)) {
          userFilters.push({ _id: userId });
        }
        const linkedUser = await User.findOne({ $or: userFilters });
        if (linkedUser) {
          userId = linkedUser._id.toString();
        }
      }

      const serviceCenterName =
        updated["Service Center Name"] || "Unknown Service Center";

      const services = updated.services
        ? Object.fromEntries(updated.services)
        : {};

      if (Object.keys(services).length === 0) {
        console.log("No services found in receipt — nothing to create");
      }

      for (const [serviceName, price] of Object.entries(services)) {
        const recordData = {
          vehicleNumber: updated.vehicleNumber, // ← ALWAYS store vehicleNumber
          currentMileage: updated.currentMileage,
          serviceMileage: updated.currentMileage,
          serviceProvider: serviceCenterName,
          serviceCost: price?.toString() || "0",
          serviceType: serviceName,
          date: updated.createdAt || new Date(),
        };

        // Only set userId if we found one — vehicleNumber is the fallback key
        if (userId) recordData.userId = userId;

        const record = await ServiceRecord.create(recordData);
        console.log("Created ServiceRecord:", record._id, "vehicleNumber:", updated.vehicleNumber);
      }
    }

    res.json(updated);
  } catch (error) {
    console.error("Error in PATCH /service-receipts/:id/status:", error);
    res.status(500).json({ error: error.message });
  }
});


// DELETE SERVICE RECEIPT
app.delete("/service-receipts/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await ServiceReceipt.findByIdAndDelete(id);
    if (!deleted) {
      return res.status(404).json({ message: "Receipt not found" });
    }
    res.json({ message: "Receipt deleted" });
```

**Service record create and lookup routes are public** — `backend/server.js:726-790`

The routes create maintenance records from req.body and read records by broad user/vehicle expansion.

```javascript
app.post("/service-records", async (req, res) => {
  try {
    const created = await ServiceRecord.create(req.body);
    res.status(201).json(created);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE RECORDS BY USER
app.get("/service-records/user/:userId", async (req, res) => {
  try {
    const { userId } = req.params;

    // ── Build userId filters ──────────────────────────────────────
    const filters = [{ userId }];

    const userFilters = [{ uid: userId }];
    if (mongoose.Types.ObjectId.isValid(userId)) {
      userFilters.push({ _id: userId });
    }

    const user = await User.findOne({ $or: userFilters });
    if (user) {
      filters.push({ userId: user._id.toString() });
      if (user.uid) filters.push({ userId: user.uid.toString() });

      // ── Email fallback: find any shell users with same email ────
      const email = user.email || user.Email;
      if (email) {
        const sameEmailUsers = await User.find({
          $or: [{ email }, { Email: email }],
        });
        for (const u of sameEmailUsers) {
          filters.push({ userId: u._id.toString() });
          if (u.uid) filters.push({ userId: u.uid.toString() });
        }
      }
    }

    // ── vehicleNumber fallback: find user's vehicle and search by it ──
    const vehicleFilters = [{ userId }];
    if (user) {
      vehicleFilters.push({ userId: user._id.toString() });
      if (user.uid) vehicleFilters.push({ userId: user.uid.toString() });
    }

    const userVehicle = await Vehicle.findOne({ $or: vehicleFilters });
    if (userVehicle?.vehicleNumber) {
      filters.push({ vehicleNumber: userVehicle.vehicleNumber });
      console.log("Also searching by vehicleNumber:", userVehicle.vehicleNumber);
    }

    // ── Remove duplicate filters ──────────────────────────────────
    const seen = new Set();
    const uniqueFilters = filters.filter((f) => {
      const key = JSON.stringify(f);
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });

    const records = await ServiceRecord.find({
      $or: uniqueFilters,
    }).sort({ createdAt: -1 });
```

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** remote unauthenticated caller

- **Entry point:** Public Express route in backend/server.js

Preconditions:
- The backend is reachable at the configured API origin.
- No out-of-repository reverse proxy adds a stronger control before the route.

#### Severity

**High** — High severity is assigned because service receipt and service record endpoints are public and permit arbitrary receipt creation, lookup, status updates, deletion, service-record creation, and broad maintenance-history lookup by user id or vehicle number.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Require authenticated owner/service-center authorization on all receipt and service-record routes, bind records to verified vehicles and service centers, and make receipt status transitions idempotent and role-checked.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

<a id="finding-11"></a>

### [11] Public document upload and vehicle-document APIs expose and mutate license/insurance records

| Field | Value |
| --- | --- |
| Severity | high |
| Confidence | high |
| Confidence rationale | Static route and model evidence directly supports the finding; live production/database behavior was not exercised. |
| Category | Unsafe file upload / authorization bypass |
| CWE | CWE-434, CWE-862, CWE-639, CWE-200 |
| Affected lines | backend/server.js:50-61, backend/server.js:1203-1206, backend/server.js:1210-1244, backend/models/VehicleDocument.js:3-13, lib/service/document_service.dart:12-20 |

#### Summary

document photo upload writes caller-supplied multipart files under a web-served /documents path, while vehicle-document APIs publicly create, list, and delete license or insurance metadata by user id or document id.

#### Root Cause

The upload path and document metadata operations lack both file-handling controls and object authorization. The API trusts caller-selected userId and file metadata at a sensitive document boundary.

**Uploaded files are stored under a static public directory** — `backend/server.js:50-61`

The server exposes /documents and writes uploads into public/documents using the original filename suffix.

```javascript
// Serve document photos statically
app.use('/documents', (req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  next();
}, express.static('public/documents'));

// Multer config for document photo uploads
const documentStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'public/documents/'),
  filename: (req, file, cb) => cb(null, `${Date.now()}_${file.originalname}`),
});
const documentUpload = multer({ storage: documentStorage });
```

**Upload route is public** — `backend/server.js:1203-1206`

The route accepts a multipart photo and returns a public URL.

```javascript
app.post('/documents/upload', documentUpload.single('photo'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  const url = `${process.env.BASE_URL || 'http://localhost:5000'}/documents/${req.file.filename}`;
  res.json({ url });
```

**Vehicle-document CRUD is public** — `backend/server.js:1210-1244`

The routes create, list, and delete vehicle-document records without auth.

```javascript
app.post('/vehicle-documents', async (req, res) => {
  try {
    const doc = await VehicleDocument.create({
      userId:         req.body.userId,
      type:           req.body.type,
      label:          req.body.label,
      documentNumber: req.body.documentNumber,
      vehiclePlate:   req.body.vehiclePlate,
      issueDate:      req.body.issueDate ? new Date(req.body.issueDate) : null,
      expiryDate:     new Date(req.body.expiryDate),
      photoUrl:       req.body.photoUrl || '',
    });
    res.status(201).json(doc);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get all documents for a user
app.get('/vehicle-documents/:userId', async (req, res) => {
  try {
    const docs = await VehicleDocument.find({ userId: req.params.userId })
      .sort({ expiryDate: 1 });
    res.json(docs);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Delete a document
app.delete('/vehicle-documents/:id', async (req, res) => {
  try {
    const { ObjectId } = require('mongoose').Types;
    await VehicleDocument.findByIdAndDelete(req.params.id);
    res.json({ success: true });
```

#### Validation

Validated by tracing the public route, attacker-controlled request fields, missing backend guard, and resulting database or security-sensitive sink in the repository.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

**Uploaded files are stored under a static public directory** — `backend/server.js:50-61`

The server exposes /documents and writes uploads into public/documents using the original filename suffix.

```javascript
// Serve document photos statically
app.use('/documents', (req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  next();
}, express.static('public/documents'));

// Multer config for document photo uploads
const documentStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'public/documents/'),
  filename: (req, file, cb) => cb(null, `${Date.now()}_${file.originalname}`),
});
const documentUpload = multer({ storage: documentStorage });
```

**Upload route is public** — `backend/server.js:1203-1206`

The route accepts a multipart photo and returns a public URL.

```javascript
app.post('/documents/upload', documentUpload.single('photo'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  const url = `${process.env.BASE_URL || 'http://localhost:5000'}/documents/${req.file.filename}`;
  res.json({ url });
```

**Vehicle-document CRUD is public** — `backend/server.js:1210-1244`

The routes create, list, and delete vehicle-document records without auth.

```javascript
app.post('/vehicle-documents', async (req, res) => {
  try {
    const doc = await VehicleDocument.create({
      userId:         req.body.userId,
      type:           req.body.type,
      label:          req.body.label,
      documentNumber: req.body.documentNumber,
      vehiclePlate:   req.body.vehiclePlate,
      issueDate:      req.body.issueDate ? new Date(req.body.issueDate) : null,
      expiryDate:     new Date(req.body.expiryDate),
      photoUrl:       req.body.photoUrl || '',
    });
    res.status(201).json(doc);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get all documents for a user
app.get('/vehicle-documents/:userId', async (req, res) => {
  try {
    const docs = await VehicleDocument.find({ userId: req.params.userId })
      .sort({ expiryDate: 1 });
    res.json(docs);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Delete a document
app.delete('/vehicle-documents/:id', async (req, res) => {
  try {
    const { ObjectId } = require('mongoose').Types;
    await VehicleDocument.findByIdAndDelete(req.params.id);
    res.json({ success: true });
```

Counterevidence and remaining uncertainty:
- No global Express authentication middleware is registered in backend/server.js; verifyToken exists in backend/middleware/middleware.js but is not imported or attached to these routes.

#### Dataflow

Multipart file or JSON document metadata -\> disk write/public URL or VehicleDocument create/find/delete -\> public document storage and license/insurance metadata exposure/tampering.

- **Source:** Caller-controlled multipart upload, userId, document metadata, and document id.

- **Sink:** Multer disk storage, express.static, VehicleDocument model operations.

- **Outcome:** Trusted-origin public file storage plus cross-user document metadata creation, disclosure, and deletion.

**Uploaded files are stored under a static public directory** — `backend/server.js:50-61`

The server exposes /documents and writes uploads into public/documents using the original filename suffix.

```javascript
// Serve document photos statically
app.use('/documents', (req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  next();
}, express.static('public/documents'));

// Multer config for document photo uploads
const documentStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, 'public/documents/'),
  filename: (req, file, cb) => cb(null, `${Date.now()}_${file.originalname}`),
});
const documentUpload = multer({ storage: documentStorage });
```

**Upload route is public** — `backend/server.js:1203-1206`

The route accepts a multipart photo and returns a public URL.

```javascript
app.post('/documents/upload', documentUpload.single('photo'), (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file uploaded' });
  const url = `${process.env.BASE_URL || 'http://localhost:5000'}/documents/${req.file.filename}`;
  res.json({ url });
```

**Vehicle-document CRUD is public** — `backend/server.js:1210-1244`

The routes create, list, and delete vehicle-document records without auth.

```javascript
app.post('/vehicle-documents', async (req, res) => {
  try {
    const doc = await VehicleDocument.create({
      userId:         req.body.userId,
      type:           req.body.type,
      label:          req.body.label,
      documentNumber: req.body.documentNumber,
      vehiclePlate:   req.body.vehiclePlate,
      issueDate:      req.body.issueDate ? new Date(req.body.issueDate) : null,
      expiryDate:     new Date(req.body.expiryDate),
      photoUrl:       req.body.photoUrl || '',
    });
    res.status(201).json(doc);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get all documents for a user
app.get('/vehicle-documents/:userId', async (req, res) => {
  try {
    const docs = await VehicleDocument.find({ userId: req.params.userId })
      .sort({ expiryDate: 1 });
    res.json(docs);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Delete a document
app.delete('/vehicle-documents/:id', async (req, res) => {
  try {
    const { ObjectId } = require('mongoose').Types;
    await VehicleDocument.findByIdAndDelete(req.params.id);
    res.json({ success: true });
```

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** remote unauthenticated caller

- **Entry point:** Public Express route in backend/server.js

Preconditions:
- The backend is reachable at the configured API origin.
- No out-of-repository reverse proxy adds a stronger control before the route.

#### Severity

**High** — High severity is assigned because document photo upload writes caller-supplied multipart files under a web-served /documents path, while vehicle-document APIs publicly create, list, and delete license or insurance metadata by user id or document id.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Authenticate upload and document metadata routes, enforce owner binding, restrict file types and sizes, store uploads outside the API origin or serve with safe content types, and authorize deletion by owner or admin role.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

<a id="finding-12"></a>

### [12] Public user creation routes allow self-assigned privileged roles

| Field | Value |
| --- | --- |
| Severity | high |
| Confidence | high |
| Confidence rationale | Static route and model evidence directly supports the finding; live production/database behavior was not exercised. |
| Category | Privilege escalation / missing authorization |
| CWE | CWE-269, CWE-862 |
| Affected lines | backend/server.js:73-106, backend/server.js:397-421, lib/auth/auth_service.dart:471-480 |

#### Summary

the public signup and raw user creation helpers persist caller-controlled role fields such as userType, allowing unauthenticated clients to create privileged Service Center or App Admin-style accounts.

#### Root Cause

Role and trust-state fields are accepted from public request bodies. The server should derive role from authenticated workflow state, not from a self-service client field.

**Signup persists caller-selected userType** — `backend/server.js:73-106`

The public signup route reads userType from req.body and stores it.

```javascript
app.post("/user", async (req, res) => {
  try {
    const { name, email, username, password, userType, address, contact, createdAt } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ message: "Name, email and password are required" });
    }

    const existingEmail = await User.findOne({ email });
    if (existingEmail) {
      return res.status(400).json({ message: "Email already in use" });
    }

    if (username) {
      const existingUsername = await User.findOne({ username });
      if (existingUsername) {
        return res.status(400).json({ message: "Username already in use" });
      }
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const newUser = await User.create({
      name,
      email,
      username,
      password: hashedPassword,
      userType: userType || "Vehicle Owner",
      address,
      contact,
      createdAt: createdAt || new Date(),
    });

    res.status(201).json({ message: "User created successfully", user: newUser });
```

**Raw user helper creates request payload directly** — `backend/server.js:397-421`

The /users helper creates User documents from a spread request payload.

```javascript
app.post("/users", async (req, res) => {
  try {
    const payload = { ...req.body };
    const email = payload.email || payload.Email;

    // ── Return existing user if email matches — prevents shell duplicates ──
    if (email) {
      const existing = await User.findOne({
        $or: [{ email }, { Email: email }],
      });
      if (existing) {
        await User.findByIdAndUpdate(existing._id, {
          $set: {
            Name: payload.Name || payload.name || existing.Name,
            Address: payload.Address || payload.address || existing.Address,
            Contact: payload.Contact || payload.contact || existing.Contact,
          },
        });
        const updated = await User.findById(existing._id);
        return res.status(200).json(updated);
      }
    }

    const created = await User.create(payload);
    res.status(201).json(created);
```

#### Validation

Validated by tracing the public route, attacker-controlled request fields, missing backend guard, and resulting database or security-sensitive sink in the repository.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

**Signup persists caller-selected userType** — `backend/server.js:73-106`

The public signup route reads userType from req.body and stores it.

```javascript
app.post("/user", async (req, res) => {
  try {
    const { name, email, username, password, userType, address, contact, createdAt } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ message: "Name, email and password are required" });
    }

    const existingEmail = await User.findOne({ email });
    if (existingEmail) {
      return res.status(400).json({ message: "Email already in use" });
    }

    if (username) {
      const existingUsername = await User.findOne({ username });
      if (existingUsername) {
        return res.status(400).json({ message: "Username already in use" });
      }
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const newUser = await User.create({
      name,
      email,
      username,
      password: hashedPassword,
      userType: userType || "Vehicle Owner",
      address,
      contact,
      createdAt: createdAt || new Date(),
    });

    res.status(201).json({ message: "User created successfully", user: newUser });
```

**Raw user helper creates request payload directly** — `backend/server.js:397-421`

The /users helper creates User documents from a spread request payload.

```javascript
app.post("/users", async (req, res) => {
  try {
    const payload = { ...req.body };
    const email = payload.email || payload.Email;

    // ── Return existing user if email matches — prevents shell duplicates ──
    if (email) {
      const existing = await User.findOne({
        $or: [{ email }, { Email: email }],
      });
      if (existing) {
        await User.findByIdAndUpdate(existing._id, {
          $set: {
            Name: payload.Name || payload.name || existing.Name,
            Address: payload.Address || payload.address || existing.Address,
            Contact: payload.Contact || payload.contact || existing.Contact,
          },
        });
        const updated = await User.findById(existing._id);
        return res.status(200).json(updated);
      }
    }

    const created = await User.create(payload);
    res.status(201).json(created);
```

Counterevidence and remaining uncertainty:
- No global Express authentication middleware is registered in backend/server.js; verifyToken exists in backend/middleware/middleware.js but is not imported or attached to these routes.

#### Dataflow

Unauthenticated JSON body with userType/role fields -\> User.create -\> privileged account used by client-side role routing.

- **Source:** Caller-controlled signup or raw user creation body.

- **Sink:** User.create with caller-controlled role fields.

- **Outcome:** Unauthorized privileged account creation and access to role-gated app workflows.

**Signup persists caller-selected userType** — `backend/server.js:73-106`

The public signup route reads userType from req.body and stores it.

```javascript
app.post("/user", async (req, res) => {
  try {
    const { name, email, username, password, userType, address, contact, createdAt } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ message: "Name, email and password are required" });
    }

    const existingEmail = await User.findOne({ email });
    if (existingEmail) {
      return res.status(400).json({ message: "Email already in use" });
    }

    if (username) {
      const existingUsername = await User.findOne({ username });
      if (existingUsername) {
        return res.status(400).json({ message: "Username already in use" });
      }
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const newUser = await User.create({
      name,
      email,
      username,
      password: hashedPassword,
      userType: userType || "Vehicle Owner",
      address,
      contact,
      createdAt: createdAt || new Date(),
    });

    res.status(201).json({ message: "User created successfully", user: newUser });
```

**Raw user helper creates request payload directly** — `backend/server.js:397-421`

The /users helper creates User documents from a spread request payload.

```javascript
app.post("/users", async (req, res) => {
  try {
    const payload = { ...req.body };
    const email = payload.email || payload.Email;

    // ── Return existing user if email matches — prevents shell duplicates ──
    if (email) {
      const existing = await User.findOne({
        $or: [{ email }, { Email: email }],
      });
      if (existing) {
        await User.findByIdAndUpdate(existing._id, {
          $set: {
            Name: payload.Name || payload.name || existing.Name,
            Address: payload.Address || payload.address || existing.Address,
            Contact: payload.Contact || payload.contact || existing.Contact,
          },
        });
        const updated = await User.findById(existing._id);
        return res.status(200).json(updated);
      }
    }

    const created = await User.create(payload);
    res.status(201).json(created);
```

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** remote unauthenticated caller

- **Entry point:** Public Express route in backend/server.js

Preconditions:
- The backend is reachable at the configured API origin.
- No out-of-repository reverse proxy adds a stronger control before the route.

#### Severity

**High** — High severity is assigned because the public signup and raw user creation helpers persist caller-controlled role fields such as userType, allowing unauthenticated clients to create privileged Service Center or App Admin-style accounts.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Make role assignment server-side only, route service-center onboarding through an authenticated admin approval path, reject privileged userType values from public requests, and whitelist accepted user fields.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

<a id="finding-13"></a>

### [13] Public user lookup routes expose full user records including password hashes

| Field | Value |
| --- | --- |
| Severity | high |
| Confidence | high |
| Confidence rationale | Static route and model evidence directly supports the finding; live production/database behavior was not exercised. |
| Category | Sensitive data exposure / missing authorization |
| CWE | CWE-200, CWE-522, CWE-862 |
| Affected lines | backend/server.js:183-198, backend/server.js:311-345, backend/models/User.js:3-19, lib/auth/auth_service.dart:81-92 |

#### Summary

public user lookup endpoints return entire User documents for email, username, id, and service-center directory queries, exposing password hashes, contact information, roles, social IDs, and service-center metadata without authentication.

#### Root Cause

The API serializes database user documents directly from public routes instead of enforcing authentication and field projection.

**Lookup routes return user documents** — `backend/server.js:183-198`

Email and username routes return full user objects.

```javascript
app.get("/user/email/:email", async (req, res) => {
  try {
    const user = await User.findOne({ email: req.params.email });
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---------------------- GET USER BY USERNAME ----------------------
app.get("/user/username/:username", async (req, res) => {
  try {
    const user = await User.findOne({ username: req.params.username });
    if (!user) return res.status(404).json({ exists: false });
    res.json({ exists: true, ...user.toObject() });
```

**ID and service-center routes return user documents** — `backend/server.js:311-345`

The id and service-center routes return User model records.

```javascript
app.get("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;

    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const user = await User.findOne({ $or: filters });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE CENTER USERS BY CITY
app.get("/service-centers", async (req, res) => {
  try {
    const city = (req.query.city || "").toString().trim();
    const cityValues = city
      ? [city, city.toLowerCase(), city.toUpperCase()]
      : [];

    const roleFilter = {
      $or: [{ userType: "Service Center" }, { "User Type": "Service Center" }],
    };

    if (!city) {
      const users = await User.find(roleFilter);
      return res.json(users);
```

**User model contains sensitive fields** — `backend/models/User.js:3-19`

The schema includes password, contact, role, and social identity fields.

```javascript
const userSchema = new mongoose.Schema({
  uid: String,
  name: String,
  serviceCenterName: String,
  email: { type: String, unique: true },
  username: { type: String, sparse: true },
  password: String,
  address: String,
  contact: String,
  city: String,
  branch: String,
  userType: String,
  googleId: { type: String, sparse: true },
  facebookId: { type: String, sparse: true },
  photoUrl: String,
  createdAt: { type: Date, default: Date.now },
});
```

#### Validation

Validated by tracing the public route, attacker-controlled request fields, missing backend guard, and resulting database or security-sensitive sink in the repository.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

**Lookup routes return user documents** — `backend/server.js:183-198`

Email and username routes return full user objects.

```javascript
app.get("/user/email/:email", async (req, res) => {
  try {
    const user = await User.findOne({ email: req.params.email });
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---------------------- GET USER BY USERNAME ----------------------
app.get("/user/username/:username", async (req, res) => {
  try {
    const user = await User.findOne({ username: req.params.username });
    if (!user) return res.status(404).json({ exists: false });
    res.json({ exists: true, ...user.toObject() });
```

**ID and service-center routes return user documents** — `backend/server.js:311-345`

The id and service-center routes return User model records.

```javascript
app.get("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;

    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const user = await User.findOne({ $or: filters });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE CENTER USERS BY CITY
app.get("/service-centers", async (req, res) => {
  try {
    const city = (req.query.city || "").toString().trim();
    const cityValues = city
      ? [city, city.toLowerCase(), city.toUpperCase()]
      : [];

    const roleFilter = {
      $or: [{ userType: "Service Center" }, { "User Type": "Service Center" }],
    };

    if (!city) {
      const users = await User.find(roleFilter);
      return res.json(users);
```

**User model contains sensitive fields** — `backend/models/User.js:3-19`

The schema includes password, contact, role, and social identity fields.

```javascript
const userSchema = new mongoose.Schema({
  uid: String,
  name: String,
  serviceCenterName: String,
  email: { type: String, unique: true },
  username: { type: String, sparse: true },
  password: String,
  address: String,
  contact: String,
  city: String,
  branch: String,
  userType: String,
  googleId: { type: String, sparse: true },
  facebookId: { type: String, sparse: true },
  photoUrl: String,
  createdAt: { type: Date, default: Date.now },
});
```

Counterevidence and remaining uncertainty:
- No global Express authentication middleware is registered in backend/server.js; verifyToken exists in backend/middleware/middleware.js but is not imported or attached to these routes.

#### Dataflow

Public path/query identifier -\> User.findOne/User.find -\> res.json(user/users).

- **Source:** Caller-controlled email, username, id, or city query.

- **Sink:** res.json of full User model documents.

- **Outcome:** PII and password-hash disclosure that can support account compromise and targeted attacks.

**Lookup routes return user documents** — `backend/server.js:183-198`

Email and username routes return full user objects.

```javascript
app.get("/user/email/:email", async (req, res) => {
  try {
    const user = await User.findOne({ email: req.params.email });
    if (!user) return res.status(404).json({ message: "User not found" });
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ---------------------- GET USER BY USERNAME ----------------------
app.get("/user/username/:username", async (req, res) => {
  try {
    const user = await User.findOne({ username: req.params.username });
    if (!user) return res.status(404).json({ exists: false });
    res.json({ exists: true, ...user.toObject() });
```

**ID and service-center routes return user documents** — `backend/server.js:311-345`

The id and service-center routes return User model records.

```javascript
app.get("/users/:id", async (req, res) => {
  try {
    const { id } = req.params;

    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const user = await User.findOne({ $or: filters });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json(user);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET SERVICE CENTER USERS BY CITY
app.get("/service-centers", async (req, res) => {
  try {
    const city = (req.query.city || "").toString().trim();
    const cityValues = city
      ? [city, city.toLowerCase(), city.toUpperCase()]
      : [];

    const roleFilter = {
      $or: [{ userType: "Service Center" }, { "User Type": "Service Center" }],
    };

    if (!city) {
      const users = await User.find(roleFilter);
      return res.json(users);
```

**User model contains sensitive fields** — `backend/models/User.js:3-19`

The schema includes password, contact, role, and social identity fields.

```javascript
const userSchema = new mongoose.Schema({
  uid: String,
  name: String,
  serviceCenterName: String,
  email: { type: String, unique: true },
  username: { type: String, sparse: true },
  password: String,
  address: String,
  contact: String,
  city: String,
  branch: String,
  userType: String,
  googleId: { type: String, sparse: true },
  facebookId: { type: String, sparse: true },
  photoUrl: String,
  createdAt: { type: Date, default: Date.now },
});
```

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** remote unauthenticated caller

- **Entry point:** Public Express route in backend/server.js

Preconditions:
- The backend is reachable at the configured API origin.
- No out-of-repository reverse proxy adds a stronger control before the route.

#### Severity

**High** — High severity is assigned because public user lookup endpoints return entire User documents for email, username, id, and service-center directory queries, exposing password hashes, contact information, roles, social IDs, and service-center metadata without authentication.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Require authentication for user lookup routes, enforce requester ownership or role checks, project only safe public fields, and never serialize password hashes or social identity bindings.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

<a id="finding-14"></a>

### [14] Login, reset, and password-change flows lack throttling and expose account/password oracles

| Field | Value |
| --- | --- |
| Severity | medium |
| Confidence | high |
| Confidence rationale | Static route and model evidence directly supports the finding; live production/database behavior was not exercised. |
| Category | Authentication throttling weakness / enumeration |
| CWE | CWE-307, CWE-203 |
| Affected lines | backend/server.js:114-137, backend/server.js:220-228, backend/server.js:1173-1195 |

#### Summary

password login, reset-password, and public password-change routes perform user existence and password checks without repository-visible rate limiting, lockout, or uniform responses; the password-change route can be used as a current-password oracle for arbitrary exposed user ids.

#### Root Cause

Authentication-sensitive checks are exposed without abuse controls, uniform responses, or authenticated subject binding for password change.

**Login returns distinct user/password failures** — `backend/server.js:114-137`

The login path performs direct user lookup and password comparison without throttling.

```javascript
app.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: "Email/username and password are required" });
    }

    // Search by email OR username
    const user = await User.findOne({
      $or: [{ email }, { username: email }]
    });

    if (!user) {
      return res.status(400).json({ message: "User not found" });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: "Invalid credentials" });
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
      expiresIn: "7d",
```

**Reset endpoint exposes user existence** — `backend/server.js:220-228`

The reset endpoint returns user not found versus reset-link-sent behavior.

```javascript
app.post("/reset-password", async (req, res) => {
  try {
    const { input } = req.body;
    const user = await User.findOne({
      $or: [{ email: input }, { username: input }]
    });
    if (!user) return res.status(404).json({ message: "User not found" });
    // In production, send a reset email here
    res.json({ message: "Password reset link sent" });
```

**Password change checks body password for arbitrary target id** — `backend/server.js:1173-1195`

The password-change endpoint can be reached without authentication and compares currentPassword for the selected user.

```javascript
app.patch("/users/:id/password", async (req, res) => {
  try {
    const { id } = req.params;
    const { currentPassword, newPassword } = req.body;
    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const user = await User.findOne({ $or: filters });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const isMatch = await bcrypt.compare(currentPassword, user.password || "");
    if (!isMatch) {
      return res.status(400).json({ message: "Current password is incorrect" });
    }

    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();

    res.json({ message: "Password changed" });
```

#### Validation

Validated by tracing the public route, attacker-controlled request fields, missing backend guard, and resulting database or security-sensitive sink in the repository.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

**Login returns distinct user/password failures** — `backend/server.js:114-137`

The login path performs direct user lookup and password comparison without throttling.

```javascript
app.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: "Email/username and password are required" });
    }

    // Search by email OR username
    const user = await User.findOne({
      $or: [{ email }, { username: email }]
    });

    if (!user) {
      return res.status(400).json({ message: "User not found" });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: "Invalid credentials" });
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
      expiresIn: "7d",
```

**Reset endpoint exposes user existence** — `backend/server.js:220-228`

The reset endpoint returns user not found versus reset-link-sent behavior.

```javascript
app.post("/reset-password", async (req, res) => {
  try {
    const { input } = req.body;
    const user = await User.findOne({
      $or: [{ email: input }, { username: input }]
    });
    if (!user) return res.status(404).json({ message: "User not found" });
    // In production, send a reset email here
    res.json({ message: "Password reset link sent" });
```

**Password change checks body password for arbitrary target id** — `backend/server.js:1173-1195`

The password-change endpoint can be reached without authentication and compares currentPassword for the selected user.

```javascript
app.patch("/users/:id/password", async (req, res) => {
  try {
    const { id } = req.params;
    const { currentPassword, newPassword } = req.body;
    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const user = await User.findOne({ $or: filters });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const isMatch = await bcrypt.compare(currentPassword, user.password || "");
    if (!isMatch) {
      return res.status(400).json({ message: "Current password is incorrect" });
    }

    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();

    res.json({ message: "Password changed" });
```

Counterevidence and remaining uncertainty:
- No global Express authentication middleware is registered in backend/server.js; verifyToken exists in backend/middleware/middleware.js but is not imported or attached to these routes.

#### Dataflow

Caller-controlled credential/email/id attempts -\> User lookup and bcrypt.compare -\> distinct responses or password update on success.

- **Source:** Caller-supplied login, reset, or password-change inputs.

- **Sink:** User lookup, bcrypt.compare, and password hash overwrite.

- **Outcome:** Account enumeration and online password guessing that can become takeover when a password guess succeeds.

**Login returns distinct user/password failures** — `backend/server.js:114-137`

The login path performs direct user lookup and password comparison without throttling.

```javascript
app.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: "Email/username and password are required" });
    }

    // Search by email OR username
    const user = await User.findOne({
      $or: [{ email }, { username: email }]
    });

    if (!user) {
      return res.status(400).json({ message: "User not found" });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: "Invalid credentials" });
    }

    const token = jwt.sign({ id: user._id }, process.env.JWT_SECRET, {
      expiresIn: "7d",
```

**Reset endpoint exposes user existence** — `backend/server.js:220-228`

The reset endpoint returns user not found versus reset-link-sent behavior.

```javascript
app.post("/reset-password", async (req, res) => {
  try {
    const { input } = req.body;
    const user = await User.findOne({
      $or: [{ email: input }, { username: input }]
    });
    if (!user) return res.status(404).json({ message: "User not found" });
    // In production, send a reset email here
    res.json({ message: "Password reset link sent" });
```

**Password change checks body password for arbitrary target id** — `backend/server.js:1173-1195`

The password-change endpoint can be reached without authentication and compares currentPassword for the selected user.

```javascript
app.patch("/users/:id/password", async (req, res) => {
  try {
    const { id } = req.params;
    const { currentPassword, newPassword } = req.body;
    const filters = [{ uid: id }];
    if (mongoose.Types.ObjectId.isValid(id)) {
      filters.push({ _id: id });
    }

    const user = await User.findOne({ $or: filters });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const isMatch = await bcrypt.compare(currentPassword, user.password || "");
    if (!isMatch) {
      return res.status(400).json({ message: "Current password is incorrect" });
    }

    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();

    res.json({ message: "Password changed" });
```

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** remote unauthenticated caller

- **Entry point:** Public Express route in backend/server.js

Preconditions:
- The backend is reachable at the configured API origin.
- No out-of-repository reverse proxy adds a stronger control before the route.

#### Severity

**Medium** — Medium severity is assigned because password login, reset-password, and public password-change routes perform user existence and password checks without repository-visible rate limiting, lockout, or uniform responses; the password-change route can be used as a current-password oracle for arbitrary exposed user ids.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Add per-account and per-IP rate limiting, lockout or risk-based delays, uniform error responses, password reset token delivery instead of state disclosure, and require authentication plus subject binding on password change.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

<a id="finding-15"></a>

### [15] Google and Firebase API keys are embedded in client-side source without repository-visible restrictions

| Field | Value |
| --- | --- |
| Severity | medium |
| Confidence | medium |
| Confidence rationale | Repository evidence supports the issue, but deployment restrictions or cloud-side controls were not verified. |
| Category | Client-side credential exposure / API key misuse risk |
| CWE | CWE-798 |
| Affected lines | lib/map/mapscreen.dart:19, android/app/src/main/AndroidManifest.xml:25-27, android/app/google-services.json:93-95 |

#### Summary

Google Maps/Places/Directions and Firebase API keys appear in mobile client files and are used from client-side requests; the repository does not contain evidence of Cloud Console API, app, or referrer restrictions for those keys.

#### Root Cause

The client embeds API keys that are expected to be public only when strongly restricted by provider-side controls; those controls are not represented in repository evidence.

#### Validation

Validated by locating key material in client files and by tracing use of the Maps/Places/Directions key in client HTTP requests. Provider-side restrictions were not checked.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

Counterevidence and remaining uncertainty:
- Google/Firebase mobile API keys are not always secrets when provider restrictions are correctly configured; that restriction state is outside the repository.

#### Dataflow

Client-embedded API key -\> mobile app bundle/source -\> Google API requests from user devices.

- **Source:** Repository/client app access to embedded API keys.

- **Sink:** Google Maps, Places, Directions, and Firebase API use.

- **Outcome:** Potential quota abuse or unauthorized API use if cloud restrictions are absent or weak.

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** remote unauthenticated caller

- **Entry point:** Public Express route in backend/server.js

Preconditions:
- Provider-side key restrictions are absent, too broad, or bypassable.

#### Severity

**Medium** — Medium severity is assigned because google Maps/Places/Directions and Firebase API keys appear in mobile client files and are used from client-side requests; the repository does not contain evidence of Cloud Console API, app, or referrer restrictions for those keys.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Rotate exposed keys where appropriate, enforce Android package/SHA and API restrictions in Google Cloud/Firebase, split keys by purpose, and monitor quota/billing alerts. Keep unrestricted service credentials out of client bundles.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

<a id="finding-16"></a>

### [16] Public feedback listing exposes review records and user identifiers

| Field | Value |
| --- | --- |
| Severity | low |
| Confidence | high |
| Confidence rationale | Static route and model evidence directly supports the finding; live production/database behavior was not exercised. |
| Category | Information disclosure / missing authorization |
| CWE | CWE-200, CWE-862 |
| Affected lines | backend/server.js:801-806, backend/models/Feedback.js:3-13, lib/admin/ratings/rating.dart:118-128 |

#### Summary

GET /feedbacks returns all feedback records when serviceCenterId is omitted and returns center-specific feedback when supplied, exposing userId, name, rating, free-text feedback, and service-center identifiers without authentication.

#### Root Cause

The route treats review records as public while the stored model includes user identifiers and names, and no authorization or field projection limits the response.

**Feedback route returns all or center-filtered records** — `backend/server.js:801-806`

The route builds an empty query when serviceCenterId is omitted and returns the records.

```javascript
app.get("/feedbacks", async (req, res) => {
  try {
    const { serviceCenterId } = req.query;
    const query = serviceCenterId ? { serviceCenterId } : {};
    const feedbacks = await Feedback.find(query).sort({ createdAt: -1 });
    res.json(feedbacks);
```

**Feedback records include user and text fields** — `backend/models/Feedback.js:3-13`

The model includes serviceCenterId, userId, name, rating, feedback, and date.

```javascript
const feedbackSchema = new mongoose.Schema(
  {
    serviceCenterId: { type: String, index: true },
    userId: String,
    name: String,
    rating: Number,
    feedback: String,
    date: String,
  },
  { timestamps: true }
);
```

#### Validation

Validated by tracing the public route, attacker-controlled request fields, missing backend guard, and resulting database or security-sensitive sink in the repository.

Validation method: Static code trace plus local dependency/config inspection. No production requests or database mutations were performed.

**Feedback route returns all or center-filtered records** — `backend/server.js:801-806`

The route builds an empty query when serviceCenterId is omitted and returns the records.

```javascript
app.get("/feedbacks", async (req, res) => {
  try {
    const { serviceCenterId } = req.query;
    const query = serviceCenterId ? { serviceCenterId } : {};
    const feedbacks = await Feedback.find(query).sort({ createdAt: -1 });
    res.json(feedbacks);
```

**Feedback records include user and text fields** — `backend/models/Feedback.js:3-13`

The model includes serviceCenterId, userId, name, rating, feedback, and date.

```javascript
const feedbackSchema = new mongoose.Schema(
  {
    serviceCenterId: { type: String, index: true },
    userId: String,
    name: String,
    rating: Number,
    feedback: String,
    date: String,
  },
  { timestamps: true }
);
```

Counterevidence and remaining uncertainty:
- No global Express authentication middleware is registered in backend/server.js; verifyToken exists in backend/middleware/middleware.js but is not imported or attached to these routes.

#### Dataflow

Optional serviceCenterId query -\> Feedback.find(query) -\> res.json(feedbacks).

- **Source:** Caller-controlled optional serviceCenterId query.

- **Sink:** Feedback.find and full JSON response.

- **Outcome:** Enumeration of service-center reviews and associated user identifiers/names.

**Feedback route returns all or center-filtered records** — `backend/server.js:801-806`

The route builds an empty query when serviceCenterId is omitted and returns the records.

```javascript
app.get("/feedbacks", async (req, res) => {
  try {
    const { serviceCenterId } = req.query;
    const query = serviceCenterId ? { serviceCenterId } : {};
    const feedbacks = await Feedback.find(query).sort({ createdAt: -1 });
    res.json(feedbacks);
```

**Feedback records include user and text fields** — `backend/models/Feedback.js:3-13`

The model includes serviceCenterId, userId, name, rating, feedback, and date.

```javascript
const feedbackSchema = new mongoose.Schema(
  {
    serviceCenterId: { type: String, index: true },
    userId: String,
    name: String,
    rating: Number,
    feedback: String,
    date: String,
  },
  { timestamps: true }
);
```

#### Reachability

The Flutter client code calls the same backend routes without Authorization headers, and Android defaults to the Railway backend URL for deployed mobile use.

- **Attacker:** remote unauthenticated caller

- **Entry point:** Public Express route in backend/server.js

Preconditions:
- The backend is reachable at the configured API origin.
- No out-of-repository reverse proxy adds a stronger control before the route.

#### Severity

**Low** — Low severity is assigned because gET /feedbacks returns all feedback records when serviceCenterId is omitted and returns center-specific feedback when supplied, exposing userId, name, rating, free-text feedback, and service-center identifiers without authentication.

Live production exploit testing, compensating edge middleware, or deployment-only controls could raise or lower this severity.

#### Remediation

Decide whether feedback is public; if not, require authentication and center/user authorization, limit fields returned to the intended public review data, and avoid exposing internal userId values.

Tests:
- Add focused backend tests that unauthenticated calls receive 401/403 and cross-user/object calls are rejected.
- Add regression tests for the exact route, object id, and role boundary involved.

Preventive controls:
- Centralize Express authentication and authorization middleware.
- Avoid trusting client-side role or object identifiers without server-side ownership checks.

## Reviewed Surfaces

| Surface | Risk Area | Outcome | Notes |
| --- | --- | --- | --- |
| Google social login | Authentication | Reported | Reported as Google login account takeover. Evidence: artifacts/05_findings/DSC-R01-003/candidate_ledger.jsonl |
| Facebook social login | Authentication | Reported | Reported as Facebook login account takeover. Evidence: artifacts/05_findings/DSC-R01-004/candidate_ledger.jsonl |
| Backend environment secrets | Secrets | Reported | Reported as tracked MongoDB and JWT secrets with values redacted. Evidence: artifacts/05_findings/DSC-R01-001/candidate_ledger.jsonl |
| User account mutation routes | Authorization | Reported | Reported for public account update, delete, and password-change paths. Evidence: artifacts/05_findings/DSC-R01-009/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-010/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-011/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-039/candidate_ledger.jsonl |
| User creation and role assignment | Authorization | Reported | Reported for public role/self-assignment through signup and raw user creation. Evidence: artifacts/05_findings/DSC-R01-005/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-006/candidate_ledger.jsonl |
| User and service-center record disclosure | Data exposure | Reported | Reported for full User document disclosures, including password hashes. Evidence: artifacts/05_findings/DSC-R01-007/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-008/candidate_ledger.jsonl |
| Service-center request workflow | Authorization | Reported | Reported for public admin workflow listing and mutations; fallback password candidate is covered here but not separately reported because current request creation stores passwordHash. Evidence: artifacts/05_findings/DSC-R01-012/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-013/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-014/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-015/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-016/candidate_ledger.jsonl, artifacts/05_findings/DSC-R02-041/candidate_ledger.jsonl |
| Vehicle records | Authorization | Reported | Reported for public vehicle create/read/upsert IDOR. Evidence: artifacts/05_findings/DSC-R01-017/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-018/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-019/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-020/candidate_ledger.jsonl |
| Appointment records | Authorization | Reported | Reported for public appointment listing, creation, status changes, and deletion. Evidence: artifacts/05_findings/DSC-R01-021/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-022/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-023/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-024/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-025/candidate_ledger.jsonl |
| Receipts and service records | Authorization | Reported | Reported for billing and maintenance-history disclosure/tampering. Evidence: artifacts/05_findings/DSC-R01-026/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-027/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-028/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-029/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-030/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-031/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-032/candidate_ledger.jsonl |
| Document upload and vehicle-document metadata | Upload and authorization | Reported | Reported for public document uploads and license/insurance metadata access. Evidence: artifacts/05_findings/DSC-R01-033/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-034/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-035/candidate_ledger.jsonl, artifacts/05_findings/DSC-R01-036/candidate_ledger.jsonl |
| Multer dependency and upload parser | Dependency vulnerability | Reported | Reported based on local npm audit and public upload reachability. Evidence: artifacts/05_findings/DSC-R02-040/candidate_ledger.jsonl |
| Android release signing | Supply chain | Reported | Reported because release uses debug signing config. Evidence: artifacts/05_findings/DSC-R01-037/candidate_ledger.jsonl |
| Client Google/Firebase API keys | Secrets/configuration | Reported | Reported with medium confidence because provider-side restrictions were not available in repository evidence. Evidence: artifacts/05_findings/DSC-R01-002/candidate_ledger.jsonl |
| Password/reset/login abuse controls | Authentication hardening | Reported | Reported for missing throttling and account/password oracle behavior. Evidence: artifacts/05_findings/DSC-R01-039/candidate_ledger.jsonl |
| Feedback listing | Data exposure | Reported | Reported as low severity because review data may be intended to be public but still exposes user identifiers without auth. Evidence: artifacts/05_findings/DSC-R03-042/candidate_ledger.jsonl |
| Vehicle model WebView injection candidate | Client-side injection | Rejected | Rejected as a final finding: the 3D WebView path is gated by a hardcoded brand/model allowlist before Car3DViewerPage is opened, so arbitrary stored vehicle strings do not reach runJavaScript through the reviewed app flow. Evidence: artifacts/05_findings/DSC-R01-038/candidate_ledger.jsonl |

## Open Questions And Follow Up

- Provider-side Google/Firebase key restrictions were not visible in the repository.
  - Follow-up prompt: Inspect the Google Cloud and Firebase projects for the keys referenced in lib/map/mapscreen.dart, android/app/src/main/AndroidManifest.xml, and android/app/google-services.json; confirm API, app package/SHA, and quota restrictions.
- Live Railway middleware or edge controls were not exercised.
  - Follow-up prompt: If a proxy or API gateway fronts the Railway app, verify whether it enforces authentication for backend/server.js protected routes before accepting any severity downgrade.
