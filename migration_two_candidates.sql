-- Миграция для уже существующей базы голосования.
-- Запусти ОДИН РАЗ в Supabase -> SQL Editor.
-- Существующие записи votes не удаляются и не изменяются.
-- Старые голоса с candidate_type='featured' остаются голосами за Юки Учиха.

alter table public.election_settings
  add column if not exists second_candidate text;

update public.election_settings
set second_candidate = 'Рю Сенджу'
where second_candidate is null;

alter table public.election_settings
  alter column second_candidate set default 'Рю Сенджу',
  alter column second_candidate set not null;

-- Обновляем название первого кандидата без сброса статуса голосования.
update public.election_settings
set featured_candidate = 'Юки Учиха'
where id = true;

alter table public.votes
  add column if not exists steam_id text;

-- Старые строки без SteamID остаются в базе; новые голоса проверяются RLS
-- и уникальным индексом. Дубли SteamID среди существующих строк нужно
-- устранить вручную, если индекс не создастся.
create unique index if not exists votes_one_per_steam_id
  on public.votes (steam_id) where steam_id is not null;

alter table public.votes
  drop constraint if exists votes_candidate_type_check;

alter table public.votes
  add constraint votes_candidate_type_check
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

-- Проверка результатов:
-- select candidate_name, candidate_type, count(*) as votes
-- from public.votes
-- group by candidate_name, candidate_type
-- order by votes desc, candidate_name;
