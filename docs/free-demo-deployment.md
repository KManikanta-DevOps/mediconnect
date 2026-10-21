# Free cloud demo deployment

This guide deploys the demo branch to Render Free and uses the existing Neon PostgreSQL project. It is not a production healthcare deployment.

## Services

- `mediconnect-demo-web`: static React/Vite frontend
- `mediconnect-demo-auth-api`: demo-only patient login and JWT issuer
- `mediconnect-demo-appointments-api`: appointment records in Neon
- `mediconnect-demo-records-api`: small PDF reports stored in Neon

## Before you deploy

1. Confirm the Neon project is the intended demo database and has no data you need to preserve. The migration relies on SQLAlchemy `create_all` to create the appointment and report tables when the services start.
2. In Render, create a Blueprint from this repository and select branch `free-demo-migration`.
3. When prompted for `DATABASE_URL`, paste the Neon connection string for the `production` branch. Use the pooled connection string if Neon provides one. Keep it private; never commit it.
4. Set the same strong random `LOCAL_JWT_SECRET` on the auth, appointments, and records services. Render's environment group generates a shared secret for new Blueprint deployments; if Render prompts for per-service values, use the same secret on all three.
5. Review the frontend API URLs after the services are created. If Render assigns different public URLs, update `VITE_AUTH_API_URL`, `VITE_APPOINTMENTS_API_URL`, and `VITE_RECORDS_API_URL` on the static site, then redeploy it.

## Free tier caveats

- Render free web services sleep after 15 minutes without inbound traffic and can take about a minute to wake.
- Render provides 750 free instance-hours per workspace each month; all active free web services share this allowance. If you run out, free services may be suspended until the next month.
- Render free services have ephemeral filesystems. This demo stores small PDF content in Neon instead, capped at 5 MB per upload. Watch the Neon free storage and compute limits.
- The notification worker is intentionally not deployed. SQS/SES delivery is disabled for this demo; booking still succeeds without reminders.
- The frontend is configured for public demo login. Any visitor can obtain a patient-role token for a test email. This is not production authentication or patient-data protection.
- Do not use real patient, medical, or personally identifiable data. This configuration is for a demo only and is not a HIPAA-compliant environment.

## Validation checklist

- `https://<auth-service-url>/health` returns `{"status":"ok"}`
- `https://<appointments-service-url>/health` returns `{"status":"ok"}`
- `https://<records-service-url>/health` returns `{"status":"ok"}`
- Login using a fictional email, book an appointment, refresh the appointment list, upload a small sample PDF, and check Render logs for errors.
- If a service returns 500, check its logs and verify `DATABASE_URL` is set correctly and contains Neon SSL settings.
