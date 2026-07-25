-- Polar Pill — missed-dose sweep
--
-- Every 5 minutes: flip pending dose_logs more than 30 minutes overdue to
-- 'missed' and raise an alert for each. Caregiver clients receive the new
-- alerts row via Supabase Realtime (enabled in migration 0003) and surface
-- a notification + the "Check in on [Name]" screen.

create or replace function public.sweep_missed_doses()
returns integer
language plpgsql
security definer set search_path = public
as $$
declare
    inserted_count integer;
begin
    with flipped as (
        update public.dose_logs
        set status = 'missed'
        where status = 'pending'
          and scheduled_for < now() - interval '30 minutes'
        returning id, medication_id, scheduled_for
    ),
    inserted as (
        insert into public.alerts (family_member_id, dose_log_id, message)
        select
            m.family_member_id,
            f.id,
            coalesce(fm.relationship_label, 'Your family member')
                || ' hasn''t confirmed their ' || m.name || ' yet.'
        from flipped f
        join public.medications m on m.id = f.medication_id
        join public.family_members fm on fm.id = m.family_member_id
        returning id
    )
    select count(*) into inserted_count from inserted;

    return inserted_count;
end;
$$;

-- Run the sweep every 5 minutes.
create extension if not exists pg_cron;

select cron.schedule(
    'sweep-missed-doses',
    '*/5 * * * *',
    $$select public.sweep_missed_doses()$$
);
