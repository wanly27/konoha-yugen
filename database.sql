-- КОНОХА: схема голосования
-- Перед запуском замени Минато Намикадзе на имя основного кандидата,
-- если хочешь предложить другого. То же имя укажи в config.js.

create extension if not exists pgcrypto;

create table if not exists public.election_settings (
  id boolean primary key default true check (id = true),
  featured_candidate text not null,
  voting_open boolean not null default true
);

insert into public.election_settings (id, featured_candidate, voting_open)
values (true, 'Минато Намикадзе', true)
on conflict (id) do update
set featured_candidate = excluded.featured_candidate;

create table if not exists public.votes (
  id uuid primary key default gen_random_uuid(),
  nickname text not null check (char_length(trim(nickname)) between 3 and 24),
  nickname_normalized text generated always as (lower(trim(nickname))) stored,
  candidate_type text not null check (candidate_type in ('featured', 'custom')),
  candidate_name text not null check (char_length(trim(candidate_name)) between 1 and 60),
  created_at timestamptz not null default now(),
  constraint votes_one_per_nickname unique (nickname_normalized)
);

-- Проверка кандидата и статуса голосования выполняется внутри БД.
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
    (p_type = 'custom' and p_name <> featured_candidate
      and char_length(trim(p_name)) between 1 and 60)
  )
  from public.election_settings where id = true;
$$;

revoke all on function public.vote_is_valid(text, text) from public;
grant execute on function public.vote_is_valid(text, text) to anon, authenticated;

-- Нельзя отправить произвольное имя как "основного" кандидата.
alter table public.votes enable row level security;
alter table public.election_settings enable row level security;

drop policy if exists "Public can submit valid votes" on public.votes;
create policy "Public can submit valid votes"
on public.votes
for insert
to anon, authenticated
with check (public.vote_is_valid(candidate_type, candidate_name));

-- Посетителям запрещено читать голоса и настройки.
revoke all on public.votes from anon, authenticated;
grant insert (nickname, candidate_type, candidate_name) on public.votes to anon, authenticated;
revoke all on public.election_settings from anon, authenticated;

-- Если ранее создавались открытые политики чтения, удалите их вручную
-- в Supabase Dashboard -> Authentication -> Policies.
-- Результаты смотрите только в Supabase Dashboard / SQL Editor.

-- Закрыть голосование:
-- update public.election_settings set voting_open = false where id = true;
--
-- Открыть снова:
-- update public.election_settings set voting_open = true where id = true;
--
-- Подсчёт голосов (запускать организатору в SQL Editor):
-- select candidate_name, candidate_type, count(*) as votes
-- from public.votes
-- group by candidate_name, candidate_type
-- order by votes desc, candidate_name;
