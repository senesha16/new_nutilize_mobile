# Supabase backend for NUtilize

NUtilize uses Supabase Edge Functions for account registration, email OTPs,
password resets, account deletion, Android update checks, and issue reports.
Issue screenshots are uploaded to the `reports` Storage bucket and linked to
rows in `public.reservation_issues`.

## Email OTP behavior

- `send_email_code` checks both `public.users` and Supabase Auth before sending
  a registration code.
- `verify_email_code` validates signup and password-reset codes without
  consuming them; the operation that completes registration or reset consumes
  the code.
- Configure `PROJECT_URL`, `SERVICE_ROLE_KEY`, `SMTP_HOST`, `SMTP_PORT`,
  `SMTP_USER`, `SMTP_PASS`, and `SMTP_FROM` as Edge Function secrets.
- Never include the service-role key in the Flutter app or a client `.env`.

## Deploy functions

Log in to Supabase CLI, then deploy the functions to the intended project:

```powershell
supabase login
supabase functions deploy register_user send_email_code verify_email_code reset_user_password delete_account app_update_policy --project-ref <project-ref> --use-api
supabase functions deploy submit_issue_report --project-ref <project-ref> --no-verify-jwt --use-api
```

`submit_issue_report` performs its own session validation, uploads the optional
image, and inserts the report using server-side credentials. Other functions
retain the target project's JWT verification setting.

## Reservation timeout and overdue lifecycle

Apply `migrations/0011_reservation_timeout_overdue.sql` to enable the
one-minute, set-based lifecycle job. It stores times as Philippine local time:
pending approvals become `Timed Out` at the reservation start, approved
reservations become `To Return` at the event end, and unresolved returns become
`Overdue` exactly 24 hours after the event end. New room and item reservations
are checked against that exact overdue deadline by a database trigger, even if
the scheduled status update has not run yet. Marking a reservation `returned`
releases the account lock.
