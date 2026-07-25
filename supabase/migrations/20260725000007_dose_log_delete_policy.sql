-- Polar Pill — allow cleaning up pending dose logs
--
-- When a medication's schedule is edited, the app deletes today's
-- still-PENDING log so a stale entry at the old time doesn't linger and get
-- falsely swept as "missed". Taken/missed logs are history and stay
-- protected — only pending rows may be deleted.

create policy "dose_logs: patient or family deletes pending" on public.dose_logs
    for delete using (
        public.can_access_medication(medication_id)
        and status = 'pending'
    );
