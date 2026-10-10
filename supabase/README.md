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
- `send_email_code` sends multipart plain-text and full-document HTML emails.
  The visible sender name is `SMTP_FROM_NAME` at the authenticated `SMTP_USER` mailbox.
  The mailbox stays `SMTP_USER`; `SMTP_FROM_NAME` only changes the name Outlook shows.
  Signup verification, password reset, and account deletion each use distinct
  subjects and instructions; all retain the existing 10-minute code expiry.
- Configure `PROJECT_URL`, `SERVICE_ROLE_KEY`, `SMTP_HOST`, `SMTP_PORT`,
  `SMTP_USER`, and `SMTP_PASS` as Edge Function secrets. `SMTP_HOST` and
  `SMTP_PORT` default to `smtp.gmail.com` and `465`.
- `SMTP_USER` must be the complete sending mailbox address and `SMTP_PASS` its
  permitted SMTP credential.
- Never include the service-role key in the Flutter app or a client `.env`.

## Experience ratings

- After a user's first successful reservation request, and then every tenth
  request after that (requests 11, 21, and so on), the app offers an optional
  five-star experience rating.
- Submitted ratings are linked to the user's reservation in
  `public.user_experience_ratings`. Database functions verify ownership and
  eligibility; direct client table access is disabled by row-level security.
- Apply `migrations/0012_user_experience_ratings.sql` to the `security_db`
  project before deploying the app changes.

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
