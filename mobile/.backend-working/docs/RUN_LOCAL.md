# Run locally

## Docker Compose

1. Copy `.env.example` to `.env` and set local values for all required secrets/database variables. Never commit `.env`.
2. Start the database and backend:

   ```sh
   docker compose up --build
   ```

3. Check that the backend is healthy:

   ```sh
   curl -fsS http://localhost:8080/api/health
   ```

   Expected response:

   ```json
   {"status":"ok"}
   ```

The first dev-profile startup seeds the development accounts and sample events. Uploaded covers are stored in the named `ticketmaster_uploads` volume.

To audit ticket-type event assignments in MariaDB:

```sql
SELECT tt.id AS ticket_type_id,
       tt.name AS ticket_type_name,
       tt.event_id,
       e.title AS event_title,
       tt.price,
       tt.total_quantity,
       tt.quantity_sold
FROM ticket_types tt
JOIN events e ON e.id = tt.event_id
ORDER BY tt.event_id, tt.price, tt.id;
```

## Demo payments

Demo payments are enabled by default for the Docker Compose `dev` profile. To disable them, set `APP_DEMO_PAYMENT_ENABLED=false` in `.env` and recreate the backend:

```sh
docker compose up --build --force-recreate backend
```

To re-enable demo payments, set `APP_DEMO_PAYMENT_ENABLED=true` or remove that override and recreate the backend. The demo endpoint is not registered outside the `dev` profile, regardless of this setting.

The application still requires valid PayChangu credentials for real checkouts; the demo endpoint does not require gateway calls. Configure the sandbox secret key and public callback/return URLs as `PAYCHANGU_SECRET_KEY`, `PAYCHANGU_CALLBACK_URL`, and `PAYCHANGU_RETURN_URL`. `PAYCHANGU_BASE_URL` defaults to `https://api.paychangu.com`; a test API key selects PayChangu's test mode. If webhooks are enabled in the PayChangu dashboard, set `PAYCHANGU_WEBHOOK_SECRET` to the dashboard's webhook secret and configure `POST /api/payments/webhook`; webhooks are rejected while the secret is unset.

## Run tests locally

Use JDK 17 for the project test suite. Newer JDKs may encounter Byte Buddy compatibility failures.

```sh
./mvnw clean test
```

On Windows PowerShell, use:

```powershell
.\mvnw.cmd clean test
```
