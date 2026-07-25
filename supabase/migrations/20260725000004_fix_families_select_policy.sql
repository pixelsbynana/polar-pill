-- Polar Pill — fix: creating a family and returning it in one statement
--
-- INSERT ... RETURNING applies the SELECT policy to the new row. The
-- is_in_family() helper is STABLE, so it evaluates against the statement's
-- snapshot — which doesn't yet contain the row being inserted — and the
-- RETURNING check fails with "new row violates row-level security policy".
--
-- Checking created_by = auth.uid() directly on the row (no subquery) fixes
-- the self-created case; is_in_family() still covers membership.

drop policy "families: read own family" on public.families;

create policy "families: read own family" on public.families
    for select using (
        created_by = auth.uid()
        or public.is_in_family(id)
    );
