-- Features v27: match restart, community groups, edited message preview

-- Reset passes so feed can restart with people you haven't matched yet.
create or replace function public.reset_match_passes()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  delete from public.match_swipes
  where swiper_id = auth.uid()
    and liked = false;
end;
$$;

revoke all on function public.reset_match_passes() from public;
grant execute on function public.reset_match_passes() to authenticated;

-- Make a group/channel a public community (visible on Board → Communities).
create or replace function public.set_conversation_community(
  p_conversation_id uuid,
  p_as_community boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if not public.is_conversation_admin(p_conversation_id) then
    raise exception 'not an admin';
  end if;

  update public.conversations
  set is_public = p_as_community,
      is_featured = p_as_community
  where id = p_conversation_id
    and type in ('group', 'channel');
end;
$$;

revoke all on function public.set_conversation_community(uuid, boolean) from public;
grant execute on function public.set_conversation_community(uuid, boolean) to authenticated;

-- Keep conversation list preview in sync when the latest message is edited.
create or replace function public.touch_conversation_preview()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  preview text;
  sender_login text;
  latest_id uuid;
begin
  if tg_op = 'INSERT' and not new.is_deleted_for_all then
    select login into sender_login from public.profiles where id = new.sender_id;
    preview := case
      when new.type = 'text' then left(new.content, 200)
      when new.type = 'voice' then '🎤 Голосовое'
      when new.type = 'video' then '🎬 Видео'
      when new.type = 'image' then '📷 Фото'
      when new.type = 'music' then '🎵 Музыка'
      when new.type = 'sticker' then '🎭 Стикер'
      when new.type = 'emoji' then '😀 Эмодзи'
      when new.type = 'gif' then 'GIF'
      when new.type = 'file' then '📎 Файл'
      else left(new.content, 200)
    end;

    update public.conversations
    set last_message = preview,
        last_message_sender = sender_login,
        last_activity = new.created_at
    where id = new.conversation_id;
  elsif tg_op = 'UPDATE'
    and not new.is_deleted_for_all
    and (
      new.content is distinct from old.content
      or new.is_edited is distinct from old.is_edited
      or new.is_deleted_for_all is distinct from old.is_deleted_for_all
    )
  then
    select m.id into latest_id
    from public.messages m
    where m.conversation_id = new.conversation_id
      and not coalesce(m.is_deleted_for_all, false)
    order by m.created_at desc
    limit 1;

    if latest_id = new.id then
      select login into sender_login from public.profiles where id = new.sender_id;
      preview := case
        when new.type = 'text' then left(new.content, 200)
        when new.type = 'voice' then '🎤 Голосовое'
        when new.type = 'video' then '🎬 Видео'
        when new.type = 'image' then '📷 Фото'
        when new.type = 'music' then '🎵 Музыка'
        when new.type = 'sticker' then '🎭 Стикер'
        when new.type = 'emoji' then '😀 Эмодзи'
        when new.type = 'gif' then 'GIF'
        when new.type = 'file' then '📎 Файл'
        else left(new.content, 200)
      end;

      update public.conversations
      set last_message = preview,
          last_message_sender = sender_login
      where id = new.conversation_id;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists messages_touch_conversation on public.messages;
create trigger messages_touch_conversation
  after insert or update on public.messages
  for each row execute function public.touch_conversation_preview();
