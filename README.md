# Ours — private shared finance portal

A mobile-first financial home for two people, built as a dependency-free web app.

## Run locally

Open `index.html` directly, or serve the folder with any static server. The demo access code is `2026`.

The app includes finance tracking, debts and repayments, savings goals, planning, customers, projects, work entries, invoices, invoice payments, search, reports, JSON export, and downloadable PDF invoices. It starts with an empty workspace—there is no demo financial data.

## Supabase setup

1. Create a Supabase project and open its SQL Editor.
2. Run `supabase/schema.sql`.
3. Create the Joey and Grace users in Supabase Authentication.
4. Create one row in `workspaces`, then add both user IDs to `workspace_members`.
5. Copy `config.example.js` to `config.js`.
6. Add the project URL, anon key, and workspace UUID to `config.js`.

`config.js` is ignored by Git. Never put the Supabase service-role key in this web application. The public anon key is protected by the included Row Level Security policies.

## Production boundary

Without Supabase configuration, records remain functional and persist locally in the browser. With Supabase configured and an authenticated session, changes are synchronized to the private shared workspace. Production deployment should also add automated backups and an append-only audit log.
