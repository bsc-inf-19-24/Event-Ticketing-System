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

The app validates signup fields before submitting. Authentication, profile
validation, password reset, and token issuance remain server responsibilities.
