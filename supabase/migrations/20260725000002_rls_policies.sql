-- Polar Pill — Row Level Security
--
-- Access model:
--   * A user can always access rows tied to their own family_member rows
--     (patients read/write their own meds and dose logs).
--   * A user can access data of family members in any family they belong to
--     or created (caregivers linked via family_members).
--   * Nothing is visible across families.
--
-- Helper functions are SECURITY DEFINER so policies can consult
-- family_members without recursive RLS evaluation.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- True if the current user created the family or has an accepted membership in it.
create or replace function public.is_in_family(target_family uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
    select exists (
        select 1 from public.families f
        where f.id = target_family and f.created_by = auth.uid()
    )
    or exists (
        select 1 from public.family_members fm
        where fm.family_id = target_family and fm.profile_id = auth.uid()
    );
$$;

-- True if the current user is the member themselves, or is in the member's family.
create or replace function public.can_access_family_member(target_member uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
    select exists (
        select 1 from public.family_members fm
        where fm.id = target_member
          and (fm.profile_id = auth.uid() or public.is_in_family(fm.family_id))
    );
$$;

-- True if the current user may access the medication's patient.
create or replace function public.can_access_medication(target_medication uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
    select exists (
        select 1 from public.medications m
        where m.id = target_medication
          and public.can_access_family_member(m.family_member_id)
    );
$$;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;

create policy "profiles: read own or same-family" on public.profiles
    for select using (
        id = auth.uid()
        or exists (
            select 1
            from public.family_members mine
            join public.family_members theirs on theirs.family_id = mine.family_id
            where mine.profile_id = auth.uid() and theirs.profile_id = profiles.id
        )
    );

create policy "profiles: insert own" on public.profiles
    for insert with check (id = auth.uid());

create policy "profiles: update own" on public.profiles
    for update using (id = auth.uid());

-- ---------------------------------------------------------------------------
-- families
-- ---------------------------------------------------------------------------
alter table public.families enable row level security;

create policy "families: read own family" on public.families
    for select using (public.is_in_family(id));

create policy "families: create" on public.families
    for insert with check (created_by = auth.uid());

create policy "families: creator updates" on public.families
    for update using (created_by = auth.uid());

create policy "families: creator deletes" on public.families
    for delete using (created_by = auth.uid());

-- ---------------------------------------------------------------------------
-- family_members
-- ---------------------------------------------------------------------------
alter table public.family_members enable row level security;

create policy "family_members: read own family" on public.family_members
    for select using (
        profile_id = auth.uid() or public.is_in_family(family_id)
    );

create policy "family_members: family adds members" on public.family_members
    for insert with check (public.is_in_family(family_id));

create policy "family_members: family updates members" on public.family_members
    for update using (
        profile_id = auth.uid() or public.is_in_family(family_id)
    );

create policy "family_members: family removes members" on public.family_members
    for delete using (public.is_in_family(family_id));

-- Invite acceptance: the invitee is not in the family yet, so RLS would block
-- them from seeing the row. This RPC runs as definer and claims the invite.
create or replace function public.accept_family_invite(code text)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
    member_id uuid;
begin
    update public.family_members
    set profile_id = auth.uid(),
        accepted_at = now()
    where invite_code = code
      and accepted_at is null
    returning id into member_id;

    if member_id is null then
        raise exception 'Invalid or already-used invite code';
    end if;

    return member_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- medications
-- ---------------------------------------------------------------------------
alter table public.medications enable row level security;

create policy "medications: patient or family reads" on public.medications
    for select using (public.can_access_family_member(family_member_id));

create policy "medications: patient or family inserts" on public.medications
    for insert with check (public.can_access_family_member(family_member_id));

create policy "medications: patient or family updates" on public.medications
    for update using (public.can_access_family_member(family_member_id));

create policy "medications: patient or family deletes" on public.medications
    for delete using (public.can_access_family_member(family_member_id));

-- ---------------------------------------------------------------------------
-- dose_logs
-- ---------------------------------------------------------------------------
alter table public.dose_logs enable row level security;

create policy "dose_logs: patient or family reads" on public.dose_logs
    for select using (public.can_access_medication(medication_id));

create policy "dose_logs: patient or family inserts" on public.dose_logs
    for insert with check (public.can_access_medication(medication_id));

create policy "dose_logs: patient or family updates" on public.dose_logs
    for update using (public.can_access_medication(medication_id));

-- ---------------------------------------------------------------------------
-- ai_summaries — read-only for clients; written by the Edge Function
-- (service role bypasses RLS).
-- ---------------------------------------------------------------------------
alter table public.ai_summaries enable row level security;

create policy "ai_summaries: patient or family reads" on public.ai_summaries
    for select using (public.can_access_family_member(family_member_id));

-- ---------------------------------------------------------------------------
-- alerts — created by the missed-dose sweep (service role / definer function);
-- clients can read and acknowledge them.
-- ---------------------------------------------------------------------------
alter table public.alerts enable row level security;

create policy "alerts: patient or family reads" on public.alerts
    for select using (public.can_access_family_member(family_member_id));

create policy "alerts: family acknowledges" on public.alerts
    for update using (public.can_access_family_member(family_member_id));
