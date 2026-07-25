-- Polar Pill — drop the unused is_remote flag from family_members
-- (the "Lives remotely" concept was removed from the product).

-- ensure_self_membership references the column — recreate it first.
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

    insert into public.family_members (family_id, profile_id, relationship_label)
    values (fam_id, auth.uid(), 'Me')
    on conflict do nothing;

    select * into member
    from public.family_members
    where profile_id = auth.uid()
    order by created_at
    limit 1;
    return member;
end;
$$;

alter table public.family_members drop column is_remote;
