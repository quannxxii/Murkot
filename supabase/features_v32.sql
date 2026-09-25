-- Features v32: preview a shared sticker pack before installing it.
-- Apply after features_v31.sql.
-- Link /s/<name> shows the pack; "Добавить стикеры" calls install_sticker_pack.

create or replace function public.get_sticker_pack(p_short_name text)
returns table (
  id uuid,
  title text,
  short_name text,
  is_owner boolean,
  is_installed boolean,
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
    (auth.uid() is not null and p.owner_id = auth.uid()) as is_owner,
    (
      auth.uid() is not null
      and exists (
        select 1 from public.sticker_pack_installs i
        where i.pack_id = p.id and i.user_id = auth.uid()
      )
    ) as is_installed,
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
  where lower(p.short_name) = lower(btrim(coalesce(p_short_name, '')))
    and exists (select 1 from public.stickers s where s.pack_id = p.id)
  limit 1;
$$;

revoke all on function public.get_sticker_pack(text) from public;
grant execute on function public.get_sticker_pack(text) to anon, authenticated;
