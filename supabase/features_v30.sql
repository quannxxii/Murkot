-- Features v30: add your own stickers from the sticker panel.
-- Apply after features_v29.sql.
-- The panel calls these RPCs after uploading a picture to chat-media.

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
  return v_id;
end;
$$;

create or replace function public.add_my_sticker(p_pack_id uuid, p_image_url text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text := btrim(coalesce(p_image_url, ''));
  v_pos int;
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if v_url !~ '^https?://' then
    raise exception 'Bad sticker url';
  end if;
  if not exists (
    select 1 from public.sticker_packs
    where id = p_pack_id and owner_id = auth.uid()
  ) then
    raise exception 'Not your pack';
  end if;

  select count(*)::int into v_pos from public.stickers where pack_id = p_pack_id;
  if v_pos >= 30 then
    raise exception 'Pack is full';
  end if;

  insert into public.stickers (pack_id, image_url, position)
  values (p_pack_id, v_url, v_pos)
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.create_my_sticker_pack(text) from public;
revoke all on function public.add_my_sticker(uuid, text) from public;
grant execute on function public.create_my_sticker_pack(text) to authenticated;
grant execute on function public.add_my_sticker(uuid, text) to authenticated;
