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

## Password recovery

When `API_BASE_URL` is empty, the app uses an in-memory demo service. It accepts
the seeded demo accounts, displays the generated 6-digit code in the app instead
of sending email, and expires codes after 10 minutes. A successful reset updates
the mock account password for the current app session.

With a backend configured, the app expects:

- `POST /auth/forgot-password` with `{"email":"..."}`. The backend should send a
  short-lived verification code by email and return a success message. Do not
  return the verification code in the response.
- `POST /auth/reset-password` with
  `{"email":"...","code":"...","newPassword":"..."}`. The backend must enforce
  code validity, expiry, and one-time use, then securely hash and save the new
  password. Return a JSON response with a 2xx status to complete the reset.

The app validates password complexity and confirmation before submitting. Code
validation and password persistence remain server responsibilities in production.
