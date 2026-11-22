-- КОНОХА: схема голосования для новой установки.
-- Для уже работающей базы используй migration_two_candidates.sql,
-- чтобы сохранить ранее записанные голоса.

create extension if not exists pgcrypto;

create table if not exists public.election_settings (
  id boolean primary key default true check (id = true),
  featured_candidate text not null,
  second_candidate text not null default 'Рю Сенджу',
  voting_open boolean not null default true
);

alter table public.election_settings
  add column if not exists second_candidate text;
update public.election_settings
  set second_candidate = 'Рю Сенджу'
  where second_candidate is null;
alter table public.election_settings
  alter column second_candidate set default 'Рю Сенджу',
  alter column second_candidate set not null;

insert into public.election_settings
  (id, featured_candidate, second_candidate, voting_open)
values
  (true, 'Юки Учиха', 'Рю Сенджу', true)
on conflict (id) do nothing;

create table if not exists public.votes (
  id uuid primary key default gen_random_uuid(),
  nickname text not null check (char_length(trim(nickname)) between 3 and 24),
  nickname_normalized text generated always as (lower(trim(nickname))) stored,
  steam_id text not null,
  candidate_type text not null check (candidate_type in ('featured', 'second', 'custom')),
  candidate_name text not null check (char_length(trim(candidate_name)) between 1 and 60),
  created_at timestamptz not null default now(),
  constraint votes_one_per_nickname unique (nickname_normalized),
  constraint votes_one_per_steam_id unique (steam_id)
);

-- Поддержка существующей таблицы, если она была создана старой версией.
alter table public.votes add column if not exists steam_id text;
create unique index if not exists votes_one_per_steam_id
  on public.votes (steam_id) where steam_id is not null;

alter table public.votes drop constraint if exists votes_candidate_type_check;
alter table public.votes add constraint votes_candidate_type_check
  check (candidate_type in ('featured', 'second', 'custom'));

create or replace function public.vote_is_valid(
  p_type text, p_name text
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select voting_open and (
    (p_type = 'featured' and p_name = featured_candidate)
    or
    (p_type = 'second' and p_name = second_candidate)
    or
    (p_type = 'custom' and char_length(trim(p_name)) between 1 and 60)
  )
  from public.election_settings where id = true;
$$;

revoke all on function public.vote_is_valid(text, text) from public;
grant execute on function public.vote_is_valid(text, text) to anon, authenticated;

alter table public.votes enable row level security;
alter table public.election_settings enable row level security;

drop policy if exists "Public can submit valid votes" on public.votes;
create policy "Public can submit valid votes"
on public.votes
for insert
to anon, authenticated
with check (
  public.vote_is_valid(candidate_type, candidate_name)
  and nickname is not null
  and char_length(trim(nickname)) between 3 and 24
  and steam_id is not null
);

revoke all on public.votes from anon, authenticated;
grant insert (nickname, steam_id, candidate_type, candidate_name)
  on public.votes to anon, authenticated;
revoke all on public.election_settings from anon, authenticated;

-- Подсчёт голосов (запускать организатору в Supabase SQL Editor):
-- select candidate_name, candidate_type, count(*) as votes
-- from public.votes
-- group by candidate_name, candidate_type
-- order by votes desc, candidate_name;
