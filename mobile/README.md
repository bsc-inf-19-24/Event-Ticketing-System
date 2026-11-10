# mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Offline ticket storage

Downloaded tickets are stored in the application's SQLite database, including
their event details, price, status, QR data, and download date. Ticket IDs are
unique, and downloaded tickets remain available after the app is closed and
reopened. Tickets saved by earlier versions in local preferences are imported
into SQLite the first time the database is opened.
## Server connection and authentication

The app connects to `http://10.0.2.2:8080` by default (the Android emulator's
host-machine address). Override it with `--dart-define=API_BASE_URL=https://...`
or change it in **Profile > Settings > Server connection**. Enter the server
origin without an `/api` suffix. Requests time out after 15 seconds and report a
retryable connection message when the server cannot be reached.

The app uses these backend routes:

- `POST /api/auth/register` with name, email, password, and role
  (`CUSTOMER`, `ORGANIZER`, or `VALIDATOR`).
- `POST /api/auth/login` with email and password. Login and registration return
  `token` (or `accessToken`) and `refreshToken`.
- `POST /api/auth/google` with `{"idToken":"..."}` and
  `GET /api/auth/qr/{text}` returning a PNG image.
- `POST /api/auth/refresh` with `{"refreshToken":"..."}`.
- `GET /api/customers/me` to restore the current session.
- `PUT /api/customers/me` to update the current profile.
- `POST /api/auth/forgot-password` with `{"email":"..."}`. The backend should
  send a short-lived verification code by email and must not return the code.
- `POST /api/auth/reset-password` with
  `{"email":"...","code":"...","newPassword":"..."}`. The backend must enforce
  code validity, expiry, and one-time use, then securely hash and save the new
  password.

Access and refresh tokens are stored in platform secure storage. Expired access
tokens are refreshed once and the original request is retried. Logging out clears
both tokens. Set `--dart-define=USE_FAKE_AUTH=true` only to use the in-memory
demo accounts and password-reset flow instead of the server.

The app validates password complexity and confirmation before submitting. Code
validation and password persistence remain server responsibilities in production.

## Google sign-in

Login and signup use `google_sign_in` to obtain a Google ID token, then exchange
it with the configured backend using `POST /auth/google` and
`{"idToken":"..."}`. The backend must validate the token with Google, create or
find the account, and return the same JSON shape as `POST /auth/login`, including
a non-empty `token` (or `accessToken`). The Google ID token must not be used as
the application session token.

### Configure the backend Google client ID

Pass your backend's Google **Web application OAuth client ID** as
`GOOGLE_SERVER_CLIENT_ID` when launching the app. This makes Google issue an ID
token for the audience your backend validates. Replace the placeholder below
with the client ID from your backend/Google Cloud configuration:

```sh
flutter run \
  --dart-define=API_BASE_URL=https://your-api.example.com \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

For iOS, also pass the iOS OAuth client ID as `GOOGLE_CLIENT_ID`. Android uses
the package name and signing-certificate SHA-1 registration described below.
These are public OAuth client IDs; never put a client secret in the Flutter app.

In Google Cloud Console, register the Android app using its package name
(`com.example.mobile`) and signing-certificate SHA-1 fingerprints. For iOS,
configure an iOS OAuth client and its reversed-client-ID URL scheme. Native
Google Sign-In uses these platform registrations rather than a custom web
redirect URI. Google sign-in requires a configured backend because the mock
service cannot verify Google identity tokens. Never include the OAuth client
secret in the Flutter app.

## Orders, payments, and offline tickets

The demo launch profile uses sample events and fake payments. To test against
the Docker backend, start the container and select **Ticket Master - Real API
(USB device)** from `.vscode/launch.json`. For a USB-connected Android device,
first run:

```sh
adb reverse tcp:8080 tcp:8080
```

The emulator profile uses `http://10.0.2.2:8080`; that address is not for a
physical Android device. The real profile disables fake authentication,
payments, and tickets. It also disables demo payment confirmation and local
ticket fallback. For command-line use, pass the same `--dart-define` values from
the profile and set `API_BASE_URL` to the reachable backend origin.

The known order routes are `POST /api/orders`, `GET /api/orders/my`, and
`GET /api/orders/{id}`. The app submits event ID, ticket-type ID, and quantity,
but never submits a price; the server must calculate the total. The payment
initiation and demo-confirmation routes and response fields are provisional and
documented in
[`lib/features/payment/CONTRACT_ASSUMPTIONS.md`](./lib/features/payment/CONTRACT_ASSUMPTIONS.md).
Confirm them with the backend team before production use. PayChangu credentials
must remain on the server.

Android and iOS open the returned HTTPS checkout URL in an in-app WebView;
browser and desktop platforms use the external browser. Returning to the app
does not prove payment. Tickets are saved only after the backend reports a paid
order and returns issued tickets.

The current event catalog is still static sample data and has no API adapter or
server IDs. In the real profile `USE_FAKE_EVENTS=false` hides those samples, so
real checkout needs the backend event-list contract and event/ticket-type IDs
before the UI can offer purchasable events. The app rejects missing IDs rather
than guessing them.

Tickets returned by the backend are cached per authenticated customer in SQLite
(mobile) or preferences (web), including the server QR payload. The ticket list
loads cached records first and refreshes from paid orders when online; ticket
details use the saved QR payload and remain readable offline.

`USE_FAKE_PAYMENT` is the current payment switch; the legacy
`USE_FAKE_PAYMENTS` define remains supported. `USE_FAKE_TICKETS` and
`USE_FAKE_EVENTS` independently control sample data. `ASSUME_PAYMENT_SUCCESS`
and `ALLOW_LOCAL_TICKET_FALLBACK` default to `false` and should only be enabled
for explicitly approved demo testing.

Run the mock-backed tests with `flutter test`. These validate request payloads,
HTTPS checkout URL enforcement, server-issued ticket parsing, and offline
ticket persistence without contacting the live API.

The app validates signup fields before submitting. Authentication, profile
validation, password reset, payment verification, and ticket issuance remain
server responsibilities.
