# Privacy policy (TEMPLATE — fill the «placeholders» before publishing)

> This is a developer-prepared template, **not legal advice**. Have «Heartfulness
> legal/DPO» review it before it goes live. Both app stores require a hosted
> privacy-policy URL.

**Controller:** «Heartfulness organization legal entity»
**Contact / DPO:** «privacy@heartfulness.org»
**Last updated:** «date»

## What DhyanLog collects

| Data                                   | Why                                      | Source            |
| -------------------------------------- | ---------------------------------------- | ----------------- |
| Heartfulness ID                        | Identify the member for attendance       | Member / org DB   |
| Name, age, address, email, phone       | Member record shown in-app; OTP delivery | Org member DB     |
| Approximate location (GPS at attend)   | Match the member to a nearby session     | Device, at attend |
| Attendance records (which session)     | The app's core purpose                   | Derived in-app    |
| Crash/diagnostic data (if enabled)     | Stability (via Sentry)                   | Device            |

We do **not** sell personal data. Location is used only at the moment of giving
attendance, to match a session — it is not tracked continuously.

## How it's stored and protected

- Backend access is via a server-side function using a privileged key; the public
  app key cannot read member PII directly (Row-Level Security denies it).
- Authentication is per-user (one-time passcode now; «Heartfulness SSO» planned),
  so actions are tied to a verified identity.
- Attendance is stored as one row per session (an array of member ids), not a
  row per person.

## Retention & deletion

In-app **account deletion** removes the **app login only** (the Supabase Auth
user). The member's **org record** and **historical attendance** are owned by
Heartfulness (not created by this app) and are deliberately left intact — the
app cannot and does not delete org-owned records. This satisfies Apple's in-app
account-deletion requirement (see `docs/compliance.md`).

Still to define with legal:
- How long attendance records are retained by the organization.
- The process for a member to request erasure of their **org record**
  (out-of-band, org-owned — not something the app performs).

## Your rights

«Per applicable law (GDPR/DPDP Act/etc.) — access, correction, deletion, contact».
