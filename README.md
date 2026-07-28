# Health + API

Express authentication API for Health +. Supabase Auth securely stores credentials and hashes passwords; Postgres stores the application profile and role.

## Setup

1. Create a Supabase project and run the complete [`supabase/setup.sql`](supabase/setup.sql) file in its SQL Editor. It creates the tables, RLS policies, and the Auth trigger that automatically creates each user's profile. It can also repair profiles missing from earlier test accounts. Use [`supabase/schema.sql`](supabase/schema.sql) only for a brand-new manual setup.
2. In Supabase **Authentication → Providers → Email**, enable email/password and turn off **Confirm email**. This lets a newly registered user sign in immediately without email confirmation, and prevents signup from sending confirmation emails.
   If you keep email confirmation enabled, configure **Authentication → SMTP Settings** with a custom SMTP provider before testing at scale. Supabase's built-in email service is limited to two emails per hour across the project, so repeated signup attempts will return an email-rate-limit error.
3. Copy `.env.example` to `.env`, then add your Supabase project URL and anon key.
4. Install and run:

   ```bash
   npm install
   npm run dev
   ```

The API runs at `http://localhost:5000` by default.

## Bruno collection

This repository is also a ready-to-import [Bruno](https://www.usebruno.com/) collection. In Bruno, select **Open Collection** and choose this project folder. Select the **Local** environment, run **Login** to save its returned token automatically, then run protected requests.

For Bruno's **Import Collection** screen, select [`health-plus-api.openapi.json`](health-plus-api.openapi.json). It is a single OpenAPI JSON export containing every endpoint.

## Endpoints

| Method | Endpoint | Purpose |
| --- | --- | --- |
| POST | `/api/auth/signup` | Create a `PATIENT` or `PHARMACY` account |
| POST | `/api/auth/login` | Sign in and return Supabase access/refresh tokens |
| POST | `/api/auth/logout` | Globally revoke the authenticated user session |
| GET | `/api/auth/me` | Get the signed-in user and profile |
| GET | `/api/patient` | Example patient-only route |
| GET | `/api/pharmacy` | Example pharmacy-only route |

Send the access token to protected routes:

```http
Authorization: Bearer <accessToken>
```

Example signup body:

```json
{
  "email": "chidi@example.com",
  "password": "secure-password",
  "fullName": "Chidi Okafor",
  "phone": "+2348012345678",
  "role": "PATIENT"
}
```

Pharmacy accounts require only a pharmacy name:

```json
{
  "email": "hello@citycare.ng",
  "password": "secure-password",
  "fullName": "Ada Nwosu",
  "phone": "+2348012345678",
  "role": "PHARMACY",
  "pharmacyName": "CityCare Pharmacy"
}
```

New pharmacies are stored with `verified: false`; the future admin verification process should approve them before they appear in patient search results.

`admin` is intentionally not accepted through public sign-up. Create and promote admin users through a protected internal workflow or Supabase dashboard.
