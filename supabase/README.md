# Supabase Functions for NUtilize

This folder contains two Supabase Edge Functions to support email OTP verification:

- `send_email_code`: sends a 6-digit code to the user's email
- `verify_email_code`: validates the code and deletes it after use

## Setup

1. Install Supabase CLI and login:

```bash
supabase login
```

2. Create the required table in Supabase SQL editor:

```sql
CREATE TABLE email_otps (
  id bigserial PRIMARY KEY,
  email varchar NOT NULL,
  code varchar NOT NULL,
  expires_at timestamptz NOT NULL,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX ON email_otps (email);
```

3. Set secrets in Supabase CLI:

```bash
supabase secrets set SERVICE_ROLE_KEY="your-supabase-service-role-key"
supabase secrets set PROJECT_URL="https://uszlgigsuseomkwmqwan.supabase.co"
supabase secrets set SMTP_HOST="smtp.gmail.com"
supabase secrets set SMTP_PORT="465"
supabase secrets set SMTP_USER="your@gmail.com"
supabase secrets set SMTP_PASS="your-gmail-app-password"
supabase secrets set SMTP_FROM="your@gmail.com"
```

4. Deploy the functions from the repo root (for example, in your VS Code terminal):

```bash
cd c:\Users\Joshueee\new_nutilize_mobile
supabase functions deploy send_email_code
supabase functions deploy verify_email_code
```

> Note: Supabase CLI uses Docker to bundle Edge Functions. That is why it may pull a container image before deploying.

5. If your project uses a different ref, add `--project-ref <ref>` to the deploy commands.

## Notes

- Use a Gmail App Password for `SMTP_PASS` when using Gmail SMTP.
- Keep `SERVICE_ROLE_KEY` secret.
- The mobile app already calls these functions via `AuthService.sendEmailCode` and `AuthService.verifyEmailCode`.
