-- Features v31: shareable sticker packs.
-- Apply after features_v30.sql.
-- Each pack gets a short name. Link: /s/<name>
-- Others install it; the owner can delete a sticker or the whole pack.

alter table public.sticker_packs
  add column if not exists short_name text;

create unique index if not exists sticker_packs_short_name_uq
  on public.sticker_packs (lower(short_name));

create table if not exists public.sticker_pack_installs (
  user_id uuid not null references public.profiles(id) on delete cascade,
  pack_id uuid not null references public.sticker_packs(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, pack_id)
);

alter table public.sticker_pack_installs enable row level security;

create or replace function public.make_sticker_short_name(p_title text, p_pack_id uuid)
returns text
language plpgsql
as $$
declare
  v_base text;
  v_name text;
  n int := 0;
begin
  v_base := lower(regexp_replace(coalesce(p_title, ''), '[^a-zA-Z0-9]+', '_', 'g'));
  v_base := trim(both '_' from v_base);
  v_base := left(v_base, 24);
  if char_length(v_base) < 3 then
    v_base := 'pack_' || substr(replace(p_pack_id::text, '-', ''), 1, 6);
  end if;

  v_name := left(v_base, 32);
  while exists (
    select 1 from public.sticker_packs
    where lower(short_name) = lower(v_name)
      and id <> p_pack_id
  ) loop
    n := n + 1;
    if n > 50 then
      raise exception 'Could not make a pack name';
    end if;
    v_name := left(left(v_base, 24) || '_' || n::text, 32);
  end loop;
  return v_name;
end;
$$;

do $$
declare
  r record;
begin
  for r in
    select id
    from public.sticker_packs
    where short_name is null
    order by created_at
  loop
    update public.sticker_packs
    set short_name = public.make_sticker_short_name(title, id)
    where id = r.id;
  end loop;
end $$;

alter table public.sticker_packs
  drop constraint if exists sticker_packs_short_name_fmt;
alter table public.sticker_packs
  add constraint sticker_packs_short_name_fmt
  check (short_name ~ '^[a-z0-9_]{3,32}$');

alter table public.sticker_packs
  alter column short_name set not null;

create or replace function public.sticker_packs_assign_short_name()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.short_name is null or btrim(new.short_name) = '' then
    if new.id is null then
      new.id := gen_random_uuid();
    end if;
    new.short_name := public.make_sticker_short_name(new.title, new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists sticker_packs_assign_short_name on public.sticker_packs;
create trigger sticker_packs_assign_short_name
  before insert on public.sticker_packs
  for each row execute function public.sticker_packs_assign_short_name();

create or replace function public.create_my_sticker_pack(p_title text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text := btrim(coalesce(p_title, ''));
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if char_length(v_title) < 1 or char_length(v_title) > 40 then
    raise exception 'Title must be 1–40 characters';
  end if;
  if (select count(*) from public.sticker_packs where owner_id = auth.uid()) >= 20 then
    raise exception 'Pack limit is 20';
  end if;

  insert into public.sticker_packs (owner_id, title)
  values (auth.uid(), v_title)
  returning id into v_id;

  update public.sticker_packs
  set short_name = public.make_sticker_short_name(v_title, v_id)
  where id = v_id;

  return v_id;
end;
$$;

create or replace function public.list_my_sticker_packs()
returns table (
  id uuid,
  title text,
  short_name text,
  is_owner boolean,
  stickers jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.title,
    p.short_name,
    (p.owner_id = auth.uid()) as is_owner,
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'image_url', s.image_url,
          'position', s.position
        )
        order by s.position
      )
      from public.stickers s
      where s.pack_id = p.id
    ), '[]'::jsonb) as stickers
  from public.sticker_packs p
  where p.owner_id = auth.uid()
     or exists (
       select 1 from public.sticker_pack_installs i
       where i.pack_id = p.id and i.user_id = auth.uid()
     )
  order by (p.owner_id = auth.uid()) desc, p.created_at desc;
$$;

create or replace function public.install_sticker_pack(p_short_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := lower(btrim(coalesce(p_short_name, '')));
  v_pack uuid;
  v_owner uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if v_name !~ '^[a-z0-9_]{3,32}$' then
    raise exception 'Bad pack name';
  end if;

  select id, owner_id into v_pack, v_owner
  from public.sticker_packs
  where lower(short_name) = v_name;

  if v_pack is null then
    raise exception 'Pack not found';
  end if;
  if v_owner = auth.uid() then
    return v_pack;
  end if;
  if not exists (select 1 from public.stickers where pack_id = v_pack) then
    raise exception 'Pack is empty';
  end if;

  insert into public.sticker_pack_installs (user_id, pack_id)
  values (auth.uid(), v_pack)
  on conflict do nothing;

  return v_pack;
end;
$$;

create or replace function public.delete_my_sticker(p_sticker_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.stickers s
  using public.sticker_packs p
  where s.id = p_sticker_id
    and s.pack_id = p.id
    and p.owner_id = auth.uid();

  if not found then
    raise exception 'Sticker not found';
  end if;
end;
$$;

create or replace function public.delete_my_sticker_pack(p_pack_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.sticker_packs
  where id = p_pack_id and owner_id = auth.uid();

  if not found then
    raise exception 'Pack not found';
  end if;
end;
$$;

revoke all on function public.make_sticker_short_name(text, uuid) from public;
revoke all on function public.sticker_packs_assign_short_name() from public;
revoke all on function public.list_my_sticker_packs() from public;
revoke all on function public.install_sticker_pack(text) from public;
revoke all on function public.delete_my_sticker(uuid) from public;
revoke all on function public.delete_my_sticker_pack(uuid) from public;

grant execute on function public.list_my_sticker_packs() to authenticated;
grant execute on function public.install_sticker_pack(text) to authenticated;
grant execute on function public.delete_my_sticker(uuid) to authenticated;
grant execute on function public.delete_my_sticker_pack(uuid) to authenticated;
grant execute on function public.create_my_sticker_pack(text) to authenticated;
