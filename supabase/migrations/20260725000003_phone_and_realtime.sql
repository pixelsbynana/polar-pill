-- Polar Pill — phone numbers + realtime
--
-- The "Call Mum" / "Call a family member" buttons deep-link into the Phone
-- app, which needs a number per family member (not in the original column
-- list; added here as an MVP assumption).
alter table public.family_members add column phone text;

-- Live dashboard updates: let Supabase Realtime broadcast dose confirmations
-- and new alerts to subscribed caregiver clients.
alter publication supabase_realtime add table public.dose_logs;
alter publication supabase_realtime add table public.alerts;
