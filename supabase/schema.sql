-- NXT Step USA – Datenbank, Rechte und Speicher
-- Einmal komplett im Supabase SQL Editor ausführen (Projekt → SQL Editor → New query → Run).
-- Kann gefahrlos erneut ausgeführt werden.

create extension if not exists pgcrypto;

-- ---------- Tabellen ----------
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.app_config (
  id int primary key default 1 check (id = 1),
  data jsonb not null default '{}'::jsonb,       -- Pathways, Profilfelder, Links für alle
  updated_at timestamptz not null default now()
);
insert into public.app_config (id) values (1) on conflict do nothing;

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete set null,   -- Login des Spielers (kann leer sein)
  email text,
  name text not null default '',
  done int not null default 0,                    -- erledigte Pathway-Schritte
  transfer boolean not null default false,        -- Transfer-Pathway?
  yt text not null default '',                    -- YouTube-Link Highlightvideo
  f jsonb not null default '{}'::jsonb,           -- Profilfelder (Schlüssel aus app_config.data.fields)
  links jsonb not null default '[]'::jsonb,       -- "Nur für dich"-Links
  raw jsonb not null default '{}'::jsonb,         -- Originalwerte aus dem Notion-Export
  docs jsonb not null default '[]'::jsonb,        -- in Notion verlinkte Dateien
  edited boolean not null default false,          -- Spieler hat selbst etwas geändert
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
drop trigger if exists players_touch on public.players;
create trigger players_touch before update on public.players for each row execute function public.touch_updated_at();
drop trigger if exists config_touch on public.app_config;
create trigger config_touch before update on public.app_config for each row execute function public.touch_updated_at();

-- ---------- Hilfsfunktionen ----------
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

create or replace function public.my_player_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.players where user_id = auth.uid() limit 1;
$$;

-- Spieler dürfen nur ihre sichtbaren Felder ändern – sonst nichts.
create or replace function public.update_my_fields(patch jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare
  pid uuid := public.my_player_id();
  vis text[];
  merged jsonb;
begin
  if pid is null then raise exception 'Kein Profil gefunden'; end if;
  select coalesce(array_agg(f->>'k'), '{}') into vis
    from public.app_config c, jsonb_array_elements(coalesce(c.data->'fields', '[]'::jsonb)) f
    where c.id = 1 and coalesce((f->>'v')::boolean, false);
  select coalesce(p.f, '{}'::jsonb) || coalesce((select jsonb_object_agg(key, to_jsonb(left(value #>> '{}', 500))) from jsonb_each(patch) where key = any(vis)), '{}'::jsonb)
    into merged from public.players p where p.id = pid;
  merged := coalesce((select jsonb_object_agg(key, value) from jsonb_each(merged) where value <> '""'::jsonb), '{}'::jsonb);
  update public.players set f = merged, edited = true where id = pid;
end $$;

-- ---------- Row Level Security ----------
alter table public.admins enable row level security;
alter table public.app_config enable row level security;
alter table public.players enable row level security;

drop policy if exists admins_read on public.admins;
create policy admins_read on public.admins for select to authenticated using (user_id = auth.uid() or public.is_admin());

drop policy if exists config_read on public.app_config;
create policy config_read on public.app_config for select to authenticated using (true);
drop policy if exists config_write on public.app_config;
create policy config_write on public.app_config for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists players_read on public.players;
create policy players_read on public.players for select to authenticated using (public.is_admin() or user_id = auth.uid());
drop policy if exists players_admin on public.players;
create policy players_admin on public.players for all to authenticated using (public.is_admin()) with check (public.is_admin());

grant execute on function public.is_admin() to authenticated;
grant execute on function public.my_player_id() to authenticated;
grant execute on function public.update_my_fields(jsonb) to authenticated;

-- ---------- Speicher: Fotos (max. 7, Originalqualität) und Dokumente ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('player-images', 'player-images', false, 26214400, array['image/jpeg','image/png','image/webp','image/heic','image/heif','image/gif']),
  ('player-docs',   'player-docs',   false, 26214400, null),
  ('player-thumbs', 'player-thumbs', false, 5242880,  array['image/jpeg'])
on conflict (id) do update set file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.image_count(pid text) returns int
language sql stable security definer set search_path = public, storage as $$
  select count(*)::int from storage.objects where bucket_id = 'player-images' and (storage.foldername(name))[1] = pid;
$$;
grant execute on function public.image_count(text) to authenticated;

drop policy if exists media_read on storage.objects;
create policy media_read on storage.objects for select to authenticated using (
  bucket_id in ('player-images','player-docs','player-thumbs')
  and (public.is_admin() or (storage.foldername(name))[1] = public.my_player_id()::text));

drop policy if exists media_insert on storage.objects;
create policy media_insert on storage.objects for insert to authenticated with check (
  bucket_id in ('player-images','player-docs','player-thumbs')
  and (public.is_admin() or (storage.foldername(name))[1] = public.my_player_id()::text)
  and (bucket_id <> 'player-images' or public.image_count((storage.foldername(name))[1]) < 7));

drop policy if exists media_update on storage.objects;
create policy media_update on storage.objects for update to authenticated using (
  bucket_id in ('player-images','player-docs','player-thumbs')
  and (public.is_admin() or (storage.foldername(name))[1] = public.my_player_id()::text));

drop policy if exists media_delete on storage.objects;
create policy media_delete on storage.objects for delete to authenticated using (
  bucket_id in ('player-images','player-docs','player-thumbs')
  and (public.is_admin() or (storage.foldername(name))[1] = public.my_player_id()::text));

-- ---------- Ersten Admin festlegen ----------
-- 1. Unter Authentication → Users → "Add user" deinen Account anlegen (Haken bei "Auto Confirm User").
-- 2. Dann diese Zeile mit deiner E-Mail ausführen:
-- insert into public.admins (user_id) select id from auth.users where email = 'deine@email.de';
