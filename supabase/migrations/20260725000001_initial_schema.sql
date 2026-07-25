-- Polar Pill — initial schema
-- Run with `supabase db push` or paste into the Supabase SQL editor.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.user_role as enum ('patient', 'caregiver');
create type public.med_frequency as enum ('daily', 'weekly', 'custom');
create type public.dose_status as enum ('pending', 'taken', 'missed');
create type public.confirmation_method as enum ('nfc', 'qr', 'manual');
create type public.summary_period as enum ('weekly', 'monthly', 'yearly');

-- ---------------------------------------------------------------------------
-- profiles — one row per authenticated user
-- ---------------------------------------------------------------------------
create table public.profiles (
    id          uuid primary key references auth.users (id) on delete cascade,
    full_name   text not null default '',
    role        public.user_role not null default 'patient',
    avatar_url  text,
    created_at  timestamptz not null default now()
);

-- Auto-create a profile whenever a user signs up. full_name/role are read from
-- the sign-up metadata the iOS client passes to supabase.auth.signUp.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    insert into public.profiles (id, full_name, role)
    values (
        new.id,
        coalesce(new.raw_user_meta_data ->> 'full_name', ''),
        coalesce((new.raw_user_meta_data ->> 'role')::public.user_role, 'patient')
    );
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- families
-- ---------------------------------------------------------------------------
create table public.families (
    id          uuid primary key default gen_random_uuid(),
    name        text not null default 'My family',
    created_by  uuid not null references public.profiles (id) on delete cascade,
    created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- family_members — links profiles to a family.
-- Assumption: invites live on this table rather than a separate invites table
-- (MVP): a member row can exist before the invited person has an account
-- (profile_id null). Accepting the invite (by code or email match) claims the
-- row by setting profile_id + accepted_at via the accept_family_invite RPC.
-- ---------------------------------------------------------------------------
create table public.family_members (
    id                  uuid primary key default gen_random_uuid(),
    family_id           uuid not null references public.families (id) on delete cascade,
    profile_id          uuid references public.profiles (id) on delete set null,
    relationship_label  text,                       -- e.g. "Mum", "Dad"
    is_remote           boolean not null default true,
    invite_email        text,
    invite_code         text unique not null default encode(gen_random_bytes(6), 'hex'),
    accepted_at         timestamptz,
    created_at          timestamptz not null default now()
);

create index family_members_family_id_idx on public.family_members (family_id);
create index family_members_profile_id_idx on public.family_members (profile_id);

-- ---------------------------------------------------------------------------
-- medications — meds belonging to a patient (a family_member row)
-- ---------------------------------------------------------------------------
create table public.medications (
    id                  uuid primary key default gen_random_uuid(),
    family_member_id    uuid not null references public.family_members (id) on delete cascade,
    name                text not null,
    dosage              text not null default '',
    time_of_day         time not null,
    frequency           public.med_frequency not null default 'daily',
    custom_schedule     jsonb,                      -- e.g. {"weekdays": [1,3,5]} (1 = Monday)
    reminders_enabled   boolean not null default true,
    created_by          uuid references public.profiles (id) on delete set null,
    created_at          timestamptz not null default now()
);

create index medications_family_member_id_idx on public.medications (family_member_id);

-- ---------------------------------------------------------------------------
-- dose_logs — one row per scheduled dose occurrence
-- ---------------------------------------------------------------------------
create table public.dose_logs (
    id                   uuid primary key default gen_random_uuid(),
    medication_id        uuid not null references public.medications (id) on delete cascade,
    scheduled_for        timestamptz not null,
    status               public.dose_status not null default 'pending',
    confirmed_at         timestamptz,
    confirmation_method  public.confirmation_method,
    created_at           timestamptz not null default now(),
    unique (medication_id, scheduled_for)
);

create index dose_logs_medication_id_idx on public.dose_logs (medication_id);
create index dose_logs_status_scheduled_idx on public.dose_logs (status, scheduled_for);

-- ---------------------------------------------------------------------------
-- ai_summaries — cached AI-generated adherence summaries
-- ---------------------------------------------------------------------------
create table public.ai_summaries (
    id                uuid primary key default gen_random_uuid(),
    family_member_id  uuid not null references public.family_members (id) on delete cascade,
    period_type       public.summary_period not null,
    period_start      date not null,
    period_end        date not null,
    doses_taken       integer not null default 0,
    doses_scheduled   integer not null default 0,
    adherence_pct     numeric(5, 2) not null default 0,
    summary_text      text not null default '',
    generated_at      timestamptz not null default now(),
    unique (family_member_id, period_type, period_start)
);

-- ---------------------------------------------------------------------------
-- alerts — missed-dose alerts surfaced to caregivers
-- ---------------------------------------------------------------------------
create table public.alerts (
    id                uuid primary key default gen_random_uuid(),
    family_member_id  uuid not null references public.family_members (id) on delete cascade,
    dose_log_id       uuid references public.dose_logs (id) on delete cascade,
    message           text not null default '',
    acknowledged_by   uuid references public.profiles (id) on delete set null,
    acknowledged_at   timestamptz,
    created_at        timestamptz not null default now()
);

create index alerts_family_member_id_idx on public.alerts (family_member_id);
