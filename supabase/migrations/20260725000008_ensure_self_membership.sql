-- Polar Pill — idempotent family bootstrap (fixes duplicate "Me" rows)
--
-- The app previously created a family + "Me" member client-side whenever it
-- saw no members, which could race (multiple screens loading at once, or a
-- fetch during token refresh) and create duplicates on every login.
-- This replaces it with one atomic, idempotent server-side function.

-- 1. Clean up existing duplicates: keep each profile's OLDEST member row,
--    delete the rest. (Duplicate "Me" rows have no medications; the original
--    row and its data are kept.)
delete from public.family_members duplicate_row
using public.family_members kept_row
where duplicate_row.profile_id is not null
  and kept_row.profile_id = duplicate_row.profile_id
  and kept_row.created_at < duplicate_row.created_at;

-- 2. Remove families left with no members at all.
delete from public.families f
where not exists (
    select 1 from public.family_members m where m.family_id = f.id
);

-- 3. Guard rail: a profile can appear at most once per family.
create unique index if not exists family_members_family_profile_unique
    on public.family_members (family_id, profile_id)
    where profile_id is not null;

-- 4. The bootstrap function the app calls instead of inserting directly.
create or replace function public.ensure_self_membership()
returns public.family_members
language plpgsql
security definer set search_path = public
as $$
declare
    member public.family_members;
    fam_id uuid;
begin
    -- Already a member somewhere (own family or joined via invite)? Done.
    select * into member
    from public.family_members
    where profile_id = auth.uid()
    order by created_at
    limit 1;
    if found then
        return member;
    end if;

    -- Reuse a family this user created earlier, or create one.
    select id into fam_id
    from public.families
    where created_by = auth.uid()
    order by created_at
    limit 1;
    if not found then
        insert into public.families (name, created_by)
        values ('My family', auth.uid())
        returning id into fam_id;
    end if;

    insert into public.family_members (family_id, profile_id, relationship_label, is_remote)
    values (fam_id, auth.uid(), 'Me', false)
    on conflict do nothing;

    select * into member
    from public.family_members
    where profile_id = auth.uid()
    order by created_at
    limit 1;
    return member;
end;
$$;
