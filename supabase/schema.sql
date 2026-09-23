-- דירוג הפסטיגלים של מאיה ומאיר: database schema for Supabase.
-- Paste the whole file into Supabase > SQL Editor and click Run.
-- BEFORE RUNNING: replace CHANGE_ME below with your family code.

-- Ratings: one row per Festigal per rater ('a' = Maya, 'b' = Meir).
create table if not exists public.reviews (
  id          text primary key,              -- '<showId>_<rater>'
  show_id     text not null,
  rater       text not null check (rater in ('a','b')),
  data        jsonb not null,                -- criteria, joke, top3, review
  updated_at  timestamptz not null default now()
);

-- Per-Festigal state that can change: watched flag and edited synopsis.
create table if not exists public.show_state (
  show_id     text primary key,
  watched     boolean not null default false,
  synopsis    text,
  updated_at  timestamptz not null default now()
);

-- The family code. Nobody can read this table from the browser.
create table if not exists public.app_secret (
  id    int primary key default 1 check (id = 1),
  code  text not null
);
insert into public.app_secret (id, code) values (1, 'CHANGE_ME')
  on conflict (id) do update set code = excluded.code;

-- Row level security: the site may read ratings and state, never write directly.
alter table public.reviews    enable row level security;
alter table public.show_state enable row level security;
alter table public.app_secret enable row level security;

drop policy if exists "read reviews" on public.reviews;
create policy "read reviews" on public.reviews for select to anon, authenticated using (true);
drop policy if exists "read state" on public.show_state;
create policy "read state" on public.show_state for select to anon, authenticated using (true);
-- app_secret has no policies, so it is unreadable from the browser.

-- Writes go through these functions, which check the family code first.
create or replace function public.check_code(p_code text)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (select 1 from app_secret where id = 1 and code = p_code);
$$;

create or replace function public.save_review(p_code text, p_show text, p_rater text, p_data jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not check_code(p_code) then raise exception 'bad_code' using errcode = '28000'; end if;
  if p_rater not in ('a','b') then raise exception 'bad_rater'; end if;
  if length(p_data::text) > 20000 then raise exception 'too_big'; end if;
  insert into reviews (id, show_id, rater, data, updated_at)
    values (p_show || '_' || p_rater, p_show, p_rater, p_data, now())
    on conflict (id) do update set data = excluded.data, updated_at = now();
  insert into show_state (show_id, watched) values (p_show, true)
    on conflict (show_id) do update set watched = true, updated_at = now();
end $$;

create or replace function public.set_watched(p_code text, p_show text, p_watched boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not check_code(p_code) then raise exception 'bad_code' using errcode = '28000'; end if;
  insert into show_state (show_id, watched) values (p_show, p_watched)
    on conflict (show_id) do update set watched = excluded.watched, updated_at = now();
end $$;

create or replace function public.set_synopsis(p_code text, p_show text, p_synopsis text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not check_code(p_code) then raise exception 'bad_code' using errcode = '28000'; end if;
  insert into show_state (show_id, synopsis) values (p_show, left(p_synopsis, 600))
    on conflict (show_id) do update set synopsis = excluded.synopsis, updated_at = now();
end $$;

revoke all on function public.check_code(text) from public;
revoke all on function public.save_review(text,text,text,jsonb) from public;
revoke all on function public.set_watched(text,text,boolean) from public;
revoke all on function public.set_synopsis(text,text,text) from public;
grant execute on function public.check_code(text) to anon, authenticated;
grant execute on function public.save_review(text,text,text,jsonb) to anon, authenticated;
grant execute on function public.set_watched(text,text,boolean) to anon, authenticated;
grant execute on function public.set_synopsis(text,text,text) to anon, authenticated;

-- Live updates: each of you sees the other's rating without refreshing.
do $$ begin
  alter publication supabase_realtime add table public.reviews, public.show_state;
exception when duplicate_object then null; end $$;

-- Carry over what was already marked on the old site.
insert into public.show_state (show_id, watched) values ('fg2010', true)
  on conflict (show_id) do nothing;
