# DR.Cars API Endpoint Inventory

This document covers the HTTP endpoints exposed by the active backend in `backend/server.js`, the backend endpoints called by the Flutter client, and the third-party HTTP endpoints used directly by the app.

Base URLs currently used by the app:

- Central backend client: `AuthService.baseUrl`
- Android default: `https://drcars-fyp-production.up.railway.app`
- iOS/default desktop default: `http://localhost:5000`
- Documents service hard-code: `https://drcars-fyp-production.up.railway.app`
- Service-center signup hard-code: `https://drcars-fyp-production.up.railway.app`
- Ratings screen hard-code: `http://10.0.2.2:5000/api`
- 3D model server default: `https://drcars-fyp-production.up.railway.app`

## Backend Environment

The Express server listens on:

```text
process.env.PORT || 5000
```

Required environment:

- `MONGO_URI`: MongoDB connection string.
- `JWT_SECRET`: JWT signing key.
- `BASE_URL`: optional public URL used when returning uploaded document URLs.

## Backend Endpoints Exposed by `server.js`

### System and static assets

| Method | Endpoint | Parameters | Body | Purpose |
|---|---|---|---|---|
| `GET` | `/` | none | none | Health/basic server response: `Dr.Cars Backend Running`. |
| `GET` | `/models/:filename` | path: `filename` | none | Proxies a GLB model from GitHub Releases and returns it as `model/gltf-binary`. Used by the 3D viewer via `/models/{model}.glb`. |
| `GET` | `/documents/:filename` | path: `filename` | none | Serves uploaded document images from `backend/public/documents`. Registered through `express.static`. |
| `POST` | `/documents/upload` | multipart field: `photo` | multipart file upload | Saves the uploaded file to `public/documents` and returns `{ url }`. |

### Authentication and user account endpoints

| Method | Endpoint | Parameters | Body | Purpose |
|---|---|---|---|---|
| `POST` | `/user` | none | `name`, `email`, `username`, `password`, `userType`, `address`, `contact`, `createdAt` | Creates a user. Requires `name`, `email`, and `password`; hashes password; defaults `userType` to `Vehicle Owner`. |
| `POST` | `/login` | none | `email`, `password` | Logs in using email or username in the `email` field. Returns JWT token, user object, and `userType`. |
| `POST` | `/register` | none | `name`, `email`, `password` | Legacy/basic registration route. Creates a user with hashed password. |
| `GET` | `/user/email/:email` | path: `email` | none | Finds one user by email. |
| `GET` | `/user/username/:username` | path: `username` | none | Checks/fetches a user by username. Returns `{ exists: true, ...user }` or 404 with `{ exists: false }`. |
| `PUT` | `/user/:email` | path: `email` | any user fields | Updates a user by email. |
| `POST` | `/reset-password` | none | `input` | Finds a user by email or username and returns a success message. It does not currently send a real email or reset token. |
| `POST` | `/logout` | none | none | Returns a logout success message. No token invalidation is performed. |
| `GET` | `/users/:id` | path: `id` as Mongo ObjectId or `uid` | none | Finds a user by `_id` or `uid`. |
| `POST` | `/users` | none | any user-like fields | Creates a user. If email already exists, updates selected fields and returns existing user. |
| `PUT` | `/users/:id` | path: `id` as Mongo ObjectId or `uid` | any user fields | Updates a user by `_id` or `uid`. |
| `DELETE` | `/users/:id` | path: `id` as Mongo ObjectId or `uid` | none | Deletes a user by `_id` or `uid`. |
| `PATCH` | `/users/:id/password` | path: `id` as Mongo ObjectId or `uid` | `currentPassword`, `newPassword` | Verifies current password, hashes and saves the new password. |
| `POST` | `/auth/google` | none | `googleId`, `email`, `name`, `photoUrl` | Logs in or creates a vehicle-owner user from Google profile data. Returns token, `isNewUser`, and user. |
| `POST` | `/auth/facebook` | none | `facebookId`, `email`, `name`, `photoUrl` | Logs in or creates a vehicle-owner user from Facebook profile data. Returns token, `isNewUser`, and user. |

### Vehicle endpoints

| Method | Endpoint | Parameters | Body | Purpose |
|---|---|---|---|---|
| `POST` | `/vehicles` | none | `userId` or `uid`, `brand`, `model`, `year`, `plateNumber`, `vehicleNumber`, `selectedBrand`, `selectedModel`, `vehicleType`, `mileage`, `vehiclePhotoUrl` | Creates a vehicle record. Uses `userId || uid`; uses `vehicleNumber || plateNumber`. |
| `GET` | `/vehicles/number/:vehicleNumber` | path: `vehicleNumber` | none | Finds one vehicle by vehicle number. |
| `GET` | `/vehicles/:uid` | path: `uid` as user id or uid | none | Finds one vehicle by linked user id, resolving user `_id` as fallback. |
| `PUT` | `/vehicles/by-user/:uid` | path: `uid` as user id or uid | vehicle fields | Upserts a vehicle record for a user. |

### Service-center discovery and requests

| Method | Endpoint | Parameters | Body | Purpose |
|---|---|---|---|---|
| `GET` | `/service-centers` | query: optional `city` | none | Returns users with role `Service Center`; if `city` is provided, filters by user city/branch and accepted service-center requests. |
| `GET` | `/api/service/check` | query: `field`, `value` | none | Legacy duplicate check for service-center signup. Supported fields are `email`, `username`, and `serviceCenterName`. Returns `{ exists }`. |
| `POST` | `/api/service/request` | none | `serviceCenterName`, `email`, `password`, `ownerName`, `nic`, `regNumber`, `address`, `contact`, `notes`, `username`, `city` | Creates a pending service-center registration request after duplicate checks. |
| `GET` | `/service-center-requests` | query: optional `status` | none | Admin listing of service-center requests. Excludes `passwordHash`. |
| `POST` | `/service-center-requests/accept/:id` | path: request `id` | none | Accepts a request, creates or updates a `Service Center` user, and marks request accepted. |
| `PUT` | `/service-center-requests/reject/:id` | path: request `id` | none | Marks a request as rejected. |
| `PUT` | `/service-center-requests/restore/:id` | path: request `id` | none | Restores a rejected request to pending. |
| `DELETE` | `/service-center-requests/:id` | path: request `id` | none | Deletes a service-center request. |
| `GET` | `/service-center-status/:email` | path: `email` | none | Checks whether an email has an approved service-center user or an existing request. |

### Appointment endpoints

| Method | Endpoint | Parameters | Body | Purpose |
|---|---|---|---|---|
| `GET` | `/appointments/vehicle/:vehicleNumber` | path: `vehicleNumber` | none | Lists appointments for a vehicle number, newest first. |
| `GET` | `/appointments/service-center/:serviceCenterUid` | path: `serviceCenterUid`; query: optional `status` | none | Lists appointments assigned to a service center. Can filter by status. |
| `POST` | `/appointments` | none | `vehicleNumber`, `vehicleModel`, `serviceTypes`, `branch`, `date`, `time`, `Contact`, `userId`, `serviceCenterUid`, `status` | Creates an appointment. Schema requires `vehicleNumber`; status defaults to `pending`. |
| `GET` | `/appointments/count` | query: optional `start`, `end`, `serviceCenterUid` | none | Counts appointments in a date range, optionally for one service center. |
| `PATCH` | `/appointments/:id/status` | path: appointment `id` | `status` | Updates appointment status. Allowed values: `pending`, `accepted`, `rejected`, `vehicle_received`. |
| `DELETE` | `/appointments/:id` | path: appointment `id` | none | Deletes an appointment. |

### Service receipt endpoints

| Method | Endpoint | Parameters | Body | Purpose |
|---|---|---|---|---|
| `POST` | `/service-receipts` | none | `vehicleNumber`, `previousOilChange`, `currentMileage`, `nextServiceDate`, `services`, `status`, `serviceCenterId`, `"Service Center Name"` | Creates a service receipt. `services` is a map of service name to price. |
| `GET` | `/service-receipts/vehicle/:vehicleNumber` | path: `vehicleNumber` | none | Lists receipts for a vehicle, newest first. |
| `GET` | `/service-receipts/service-center/:serviceCenterId` | path: `serviceCenterId`; query: optional `status`, `vehicleNumber` | none | Lists receipts for one service center with optional status and vehicle filters. |
| `PATCH` | `/service-receipts/:id/status` | path: receipt `id` | `status` | Updates receipt status. If status becomes `finished`, creates one `ServiceRecord` per service item in the receipt. |
| `DELETE` | `/service-receipts/:id` | path: receipt `id` | none | Deletes a service receipt. |

### Service record endpoints

| Method | Endpoint | Parameters | Body | Purpose |
|---|---|---|---|---|
| `POST` | `/service-records` | none | `userId`, `vehicleNumber`, `currentMileage`, `serviceMileage`, `serviceProvider`, `serviceCost`, `serviceType`, `oilType`, `notes`, `date` | Creates a service history record. |
| `GET` | `/service-records/user/:userId` | path: user id or uid | none | Lists service records by user id, with fallback lookup through matching user ids and vehicle number. |

### Feedback endpoints

| Method | Endpoint | Parameters | Body | Purpose |
|---|---|---|---|---|
| `GET` | `/feedbacks` | query: optional `serviceCenterId` | none | Lists feedback, optionally filtered by service center. |

There is no active backend route for creating feedback. The Flutter ratings screen currently calls `POST /api/feedbacks`, which is not implemented in `server.js`.

### Vehicle document endpoints

| Method | Endpoint | Parameters | Body | Purpose |
|---|---|---|---|---|
| `POST` | `/vehicle-documents` | none | `userId`, `type`, `label`, `documentNumber`, `vehiclePlate`, `issueDate`, `expiryDate`, `photoUrl` | Creates a license/insurance document record. `type` must be `license` or `insurance`; `expiryDate` is required. |
| `GET` | `/vehicle-documents/:userId` | path: `userId` | none | Lists all documents for a user, sorted by expiry date. |
| `DELETE` | `/vehicle-documents/:id` | path: document `id` | none | Deletes a vehicle document record. |

## Backend Endpoints Called by Flutter

### Central `AuthService` calls

| Method | Endpoint | Called from | Purpose |
|---|---|---|---|
| `POST` | `/login` | `AuthService.login()` | Email/username login. |
| `GET` | `/user/email/:email` | login fallback, profile lookup | Fetch user by email. |
| `GET` | `/user/username/:username` | login fallback, username checks | Fetch/check user by username. |
| `POST` | `/user` | signup, Google profile completion, account creation | Create user. |
| `PUT` | `/user/:email` | Google account link/update | Update by email. |
| `POST` | `/logout` | logout | Clear backend session placeholder and local prefs. |
| `GET` | `/vehicles/:uid` | dashboard/profile/notifications | Get current user's vehicle. |
| `GET` | `/users/:id` | current-user resolution, owner/service-center lookups | Get user by id or uid. |
| `POST` | `/auth/google` | Google login | Backend social auth. |
| `POST` | `/auth/facebook` | Facebook login | Backend social auth. |
| `GET` | `/service-centers?city=...` | appointment booking | Find service centers by city. |
| `GET` | `/vehicles/number/:vehicleNumber` | service owner lookup | Find vehicle by number. |
| `POST` | `/users` | helper method | Create/update user by id-style payload. |
| `PUT` | `/users/:id` | helper method | Update user by id/uid. |
| `DELETE` | `/users/:id` | helper method | Delete user by id/uid. |
| `PUT` | `/vehicles/by-user/:uid` | profile/owner workflow | Upsert user vehicle. |
| `PATCH` | `/users/:id/password` | password change | Change password. |
| `GET` | `/service-center-status/:email` | service-center account status | Check request/approval state. |
| `POST` | `/reset-password` | sign-in screen | Request password reset message. |

### Appointment calls

| Method | Endpoint | Called from | Purpose |
|---|---|---|---|
| `GET` | `/appointments/count?start=...&end=...` | owner appointment booking | Count appointments for selected day. |
| `GET` | `/appointments/service-center/:serviceCenterUid` | owner booking and service-center dashboard | Load bookings for capacity/status views. |
| `GET` | `/appointments/service-center/:serviceCenterUid?status=...` | service-center appointment tabs | Load appointments by status. |
| `POST` | `/appointments` | owner appointment booking | Create new appointment. |
| `GET` | `/appointments/vehicle/:vehicleNumber` | owner notification/dashboard | Load vehicle appointments. |
| `PATCH` | `/appointments/:id/status` | service center and owner notifications | Accept/reject/vehicle-received update. |
| `DELETE` | `/appointments/:id` | owner notifications | Delete appointment. |

### Service receipt and service record calls

| Method | Endpoint | Called from | Purpose |
|---|---|---|---|
| `POST` | `/service-receipts` | service receipt confirmation page | Create receipt for vehicle. |
| `GET` | `/service-receipts/vehicle/:vehicleNumber` | owner dashboard and receipt notifications | Load receipts by vehicle. |
| `GET` | `/service-receipts/service-center/:serviceCenterId` | service-center menu/history | Load receipts by service center. |
| `GET` | `/service-receipts/service-center/:serviceCenterId?status=...` | service receipts page | Load receipts by status. |
| `GET` | `/service-receipts/service-center/:serviceCenterId?vehicleNumber=...&status=finished` | service info screen | Load completed service history for a vehicle at a center. |
| `PATCH` | `/service-receipts/:id/status` | owner receipt notifications and service receipts page | Confirm/reject/finish receipt. |
| `DELETE` | `/service-receipts/:id` | service receipts page | Delete rejected receipt. |
| `GET` | `/service-records/user/:userId` | owner/service history pages | Load service records. |
| `POST` | `/service-records` | manual service record page | Create service record. |

### Service-center request/admin calls

| Method | Endpoint | Called from | Purpose |
|---|---|---|---|
| `GET` | `/api/service/check?field=...&value=...` | service-center signup | Duplicate checks. |
| `POST` | `/api/service/request` | service-center signup | Submit service-center approval request. |
| `GET` | `/service-center-requests?status=pending` | admin pending page | List pending requests. |
| `GET` | `/service-center-requests?status=rejected` | admin rejected page | List rejected requests. |
| `POST` | `/service-center-requests/accept/:id` | admin pending page | Accept request. |
| `PUT` | `/service-center-requests/reject/:id` | admin pending page | Reject request. |
| `PUT` | `/service-center-requests/restore/:id` | admin rejected page | Restore rejected request. |
| `DELETE` | `/service-center-requests/:id` | admin rejected page | Delete request. |

### Document calls

| Method | Endpoint | Called from | Purpose |
|---|---|---|---|
| `POST` | `/documents/upload` | `DocumentService.uploadPhoto()` | Multipart image upload using field `photo`. |
| `POST` | `/vehicle-documents` | `DocumentService.addDocument()` | Save document metadata. |
| `GET` | `/vehicle-documents/:userId` | `DocumentService.getDocuments()` | Load user documents. |
| `DELETE` | `/vehicle-documents/:id` | `DocumentService.deleteDocument()` | Delete document. |

## Client Calls That Do Not Match Active Backend

| Method | Endpoint used by client | Current status | Impact |
|---|---|---|---|
| `POST` | `/api/feedbacks` | Not defined in `server.js`. | Rating submission fails. |
| `GET` | `/api/feedbacks` | Not defined in `server.js`; backend has `GET /feedbacks` instead. | Rating list fails from current ratings screen. |
| `GET` | `/api/feedbacks?serviceCenterId=...` | Not defined in `server.js`; backend has `GET /feedbacks?serviceCenterId=...`. | Filtered rating list fails from current ratings screen. |
| `POST` | `/google/link` | Not defined in active `server.js`; stale code exists in unmounted `backend/models/auth.js`. | `AuthService.linkGoogleAccount()` would fail if called. |
| `POST` | `/google/complete` | Not defined in active `server.js`; stale code exists in unmounted `backend/models/auth.js`. | `AuthService.completeGoogleProfile()` would fail if called. |

## Stale or Unmounted Backend Code

`backend/models/auth.js` appears to be an older standalone backend file. It is not imported by `server.js`, so its routes are not active in the running backend.

Problems in that file:

- It references `router.post(...)` without defining `router`.
- It imports `./models/User`, `./models/vehicle`, and `./middleware/middleware` from inside `backend/models`, which would resolve to incorrect paths.
- It starts its own Express app and MongoDB connection.
- It duplicates routes that already exist in `server.js`.

Treat this file as stale until it is removed or intentionally refactored into proper Express routers.

## Third-Party HTTP Endpoints Used by the App

### Google Maps and Places APIs

Defined in `lib/map/mapscreen.dart`.

| Method | Endpoint | Query parameters | Purpose |
|---|---|---|---|
| `GET` | `https://maps.googleapis.com/maps/api/place/nearbysearch/json` | `location`, `radius`, `type`, `key` | Finds nearby car repair, car dealer, gas station, and EV charging places. |
| `GET` | `https://maps.googleapis.com/maps/api/place/autocomplete/json` | `input`, `location`, `radius`, `key` | Fetches search suggestions around the user's current location. |
| `GET` | `https://maps.googleapis.com/maps/api/place/details/json` | `place_id`, `fields`, `key` | Fetches place details such as geometry, rating, phone, hours, reviews, photos, and website. |
| `GET` | `https://maps.googleapis.com/maps/api/directions/json` | `origin`, `destination`, `mode`, `key` | Fetches route polyline, distance, and duration. |
| `GET` | `https://maps.googleapis.com/maps/api/place/photo` | `maxwidth`, `photo_reference`, `key` | Loads a place photo for the selected location card. |
| Browser URL | `https://www.google.com/maps/dir/` | `api`, `destination`, `travelmode` | Opens Google Maps directions externally. |
| Browser URL | `https://www.google.com/maps/search/` | `api`, `query`/coordinates | Opens a Google Maps search externally. |

### YouTube

Defined in `lib/admin/dashboard/vehicle_dashboard.dart`.

| Method | Endpoint | Query parameters | Purpose |
|---|---|---|---|
| Browser URL | `https://www.youtube.com/results` | `search_query` | Opens YouTube search results for warning-light help topics. |

### WhatsApp

Defined in `lib/settings/settings.dart`.

| Method | Endpoint | Parameters | Purpose |
|---|---|---|---|
| Browser URL | `https://wa.me/+94772111426` | phone number in URL | Opens WhatsApp support/contact link. |

### 3D viewer script CDNs

Defined in `assets/html/car_viewer.html`.

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js` | Loads Three.js runtime in WebView. |
| `GET` | `https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/loaders/GLTFLoader.js` | Loads GLTF loader. |
| `GET` | `https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js` | Loads orbit controls. |
| `GET` | `https://cdn.jsdelivr.net/npm/meshoptimizer@0.18.1/meshopt_decoder.js` | Loads Meshopt decoder for compressed GLB files. |

### Backend upstream model fetch

Defined in `backend/server.js`.

| Method | Endpoint | Parameters | Purpose |
|---|---|---|---|
| `GET` | `https://github.com/MandinuBala/Dr.Cars-FYP/releases/download/models-v1/{filename}` | path: `filename` | The backend proxy fetches GLB model files from GitHub Releases and streams them to the app through `/models/:filename`. |

## Endpoint Security Observations

- Most backend endpoints do not require authentication.
- Admin operations such as accepting/rejecting service centers are publicly callable if the API is exposed.
- User update and delete routes are publicly callable if the API is exposed.
- CORS is globally open.
- JWTs are issued, but not enforced by active routes.
- File upload accepts any uploaded file under the `photo` field without MIME/type/size validation in the route.
- Password reset does not implement a secure token/email flow.
- API keys and OAuth client ids are hard-coded in client source/native config.

## Suggested API Cleanup

1. Move routes out of `server.js` into versioned routers, for example `/api/v1/auth`, `/api/v1/users`, `/api/v1/vehicles`.
2. Add authentication middleware and role-based authorization for admin/service-center/user-owned resources.
3. Replace duplicate `/user` and `/users` semantics with one consistent user API.
4. Implement missing feedback creation or update the ratings screen to call active routes.
5. Remove stale `backend/models/auth.js`.
6. Centralize all Flutter backend calls through one API client.
7. Add request validation for every create/update route.
8. Document response shapes and error shapes once routes stabilize.
