-- Features v29: custom sticker packs via the Murkot bot.
-- Apply after features_v28.sql.
-- In the bot chat: «новый пак» → name → photos → «готово».
-- «мои паки» lists them, «удалить пак Название» removes one, «отмена» aborts.

create table if not exists public.sticker_packs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 40),
  created_at timestamptz not null default now()
);

create table if not exists public.stickers (
  id uuid primary key default gen_random_uuid(),
  pack_id uuid not null references public.sticker_packs(id) on delete cascade,
  image_url text not null,
  position int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists stickers_pack_idx
  on public.stickers (pack_id, position);

create table if not exists public.bot_flows (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  kind text not null,
  step text not null,
  pack_id uuid references public.sticker_packs(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.sticker_packs enable row level security;
alter table public.stickers enable row level security;
alter table public.bot_flows enable row level security;

drop policy if exists "Owners read own sticker packs" on public.sticker_packs;
create policy "Owners read own sticker packs"
  on public.sticker_packs for select to authenticated
  using (owner_id = auth.uid());

drop policy if exists "Owners read own stickers" on public.stickers;
create policy "Owners read own stickers"
  on public.stickers for select to authenticated
  using (
    exists (
      select 1 from public.sticker_packs p
      where p.id = pack_id and p.owner_id = auth.uid()
    )
  );

grant select on public.sticker_packs to authenticated;
grant select on public.stickers to authenticated;

create or replace function public.bot_auto_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  bot_id uuid := 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeee01';
  is_dm boolean;
  has_bot boolean;
  reply text;
  msg text;
  v_en boolean;
  v_step text;
  v_pack uuid;
  v_url text;
  v_title text;
  v_count int;
  v_names text;
begin
  if new.sender_id = bot_id then
    return new;
  end if;

  if coalesce(new.type, 'text') = 'system'
     or coalesce(new.is_deleted_for_all, false) then
    return new;
  end if;

  select (c.type = 'direct') into is_dm
  from public.conversations c
  where c.id = new.conversation_id;

  if not coalesce(is_dm, false) then
    return new;
  end if;

  select exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = new.conversation_id
      and cm.user_id = bot_id
  ) into has_bot;

  if not has_bot then
    return new;
  end if;

  select f.step, f.pack_id into v_step, v_pack
  from public.bot_flows f
  where f.user_id = new.sender_id and f.kind = 'sticker_pack';

  if coalesce(new.type, 'text') in ('image', 'sticker')
     and v_step = 'stickers'
     and v_pack is not null then
    begin
      v_url := nullif(btrim((new.content::jsonb)->>'url'), '');
    exception when others then
      v_url := null;
    end;
    if v_url is null and new.content ~ '^https?://' then
      v_url := btrim(new.content);
    end if;

    if v_url is null then
      reply := 'Это не похоже на картинку. Пришли фото ещё раз или напиши «готово».';
    else
      select count(*)::int into v_count from public.stickers where pack_id = v_pack;
      if v_count >= 30 then
        reply := 'В паке уже 30 стикеров — это максимум. Напиши «готово».';
      else
        insert into public.stickers (pack_id, image_url, position)
        values (v_pack, v_url, v_count);
        reply := 'Добавил (' || (v_count + 1)::text || '). Пришли ещё фото или напиши «готово».';
      end if;
    end if;

    insert into public.messages (conversation_id, sender_id, type, content)
    values (new.conversation_id, bot_id, 'text', reply);
    return new;
  end if;

  if coalesce(new.type, 'text') <> 'text' then
    reply := 'Пока читаю только текстовые сообщения. Напиши «помощь».';
    if exists (
      select 1
      from public.messages m
      where m.conversation_id = new.conversation_id
        and m.sender_id = bot_id
        and m.content = reply
        and m.created_at > now() - interval '20 seconds'
    ) then
      return new;
    end if;

    insert into public.messages (conversation_id, sender_id, type, content)
    values (new.conversation_id, bot_id, 'text', reply);
    return new;
  end if;

  msg := lower(btrim(coalesce(new.content, '')));
  v_en := msg ~ '[a-z]' and msg !~ '[а-яё]';

  if msg ~ '(отмена|cancel)' and v_step is not null then
    if v_pack is not null then
      delete from public.sticker_packs where id = v_pack and owner_id = new.sender_id;
    end if;
    delete from public.bot_flows where user_id = new.sender_id and kind = 'sticker_pack';
    reply := case when v_en
      then 'Pack cancelled.'
      else 'Пак отменён.'
    end;
    insert into public.messages (conversation_id, sender_id, type, content)
    values (new.conversation_id, bot_id, 'text', reply);
    return new;
  end if;

  if msg ~ '(новый пак|newpack|стикерпак)' then
    if v_pack is not null then
      delete from public.sticker_packs p
      where p.id = v_pack
        and p.owner_id = new.sender_id
        and not exists (select 1 from public.stickers s where s.pack_id = p.id);
    end if;
    if (select count(*) from public.sticker_packs where owner_id = new.sender_id) >= 20 then
      reply := 'Уже 20 паков — удали один: «удалить пак Название».';
    else
      delete from public.bot_flows where user_id = new.sender_id and kind = 'sticker_pack';
      insert into public.bot_flows (user_id, kind, step)
      values (new.sender_id, 'sticker_pack', 'name');
      reply := case when v_en then
        'Name the pack (up to 40 characters). Then send photos. Finish with «done», abort with «cancel».'
      else
        'Как назвать пак? До 40 символов. Потом присылай фото. «готово» — закончить, «отмена» — бросить.'
      end;
    end if;
    insert into public.messages (conversation_id, sender_id, type, content)
    values (new.conversation_id, bot_id, 'text', reply);
    return new;
  end if;

  if v_step = 'name' then
    v_title := btrim(coalesce(new.content, ''));
    if char_length(v_title) < 1 or char_length(v_title) > 40 then
      reply := 'Название — от 1 до 40 символов. Напиши ещё раз.';
    else
      insert into public.sticker_packs (owner_id, title)
      values (new.sender_id, v_title)
      returning id into v_pack;
      update public.bot_flows
      set step = 'stickers', pack_id = v_pack, updated_at = now()
      where user_id = new.sender_id and kind = 'sticker_pack';
      reply := 'Пак «' || v_title || '» создан. Пришли картинки по одной. Когда хватит — напиши «готово».';
    end if;
    insert into public.messages (conversation_id, sender_id, type, content)
    values (new.conversation_id, bot_id, 'text', reply);
    return new;
  end if;

  if v_step = 'stickers' and msg ~ '^(готово|done|publish)$' then
    select count(*)::int into v_count from public.stickers where pack_id = v_pack;
    if coalesce(v_count, 0) < 1 then
      reply := 'В паке ещё нет стикеров. Пришли хотя бы одну картинку.';
    else
      select title into v_title from public.sticker_packs where id = v_pack;
      delete from public.bot_flows where user_id = new.sender_id and kind = 'sticker_pack';
      reply := 'Готово: «' || coalesce(v_title, 'пак') || '», стикеров ' || v_count::text
        || '. Пак уже в панели стикеров.';
    end if;
    insert into public.messages (conversation_id, sender_id, type, content)
    values (new.conversation_id, bot_id, 'text', reply);
    return new;
  end if;

  if msg ~ '^(мои паки|my packs|mypacks)$' then
    select string_agg(title, E'\n• ' order by created_at) into v_names
    from public.sticker_packs
    where owner_id = new.sender_id;
    reply := case
      when v_names is null then 'Паков пока нет. Напиши «новый пак».'
      else E'Твои паки:\n• ' || v_names
    end;
    insert into public.messages (conversation_id, sender_id, type, content)
    values (new.conversation_id, bot_id, 'text', reply);
    return new;
  end if;

  if msg ~ '^(удалить пак|delete pack) ' then
    v_title := btrim(regexp_replace(
      new.content,
      '^(удалить пак|delete pack)\s+',
      '',
      'i'
    ));
    delete from public.sticker_packs
    where owner_id = new.sender_id and lower(title) = lower(v_title);
    if found then
      reply := 'Удалил пак «' || v_title || '».';
    else
      reply := 'Пака «' || v_title || '» нет. Список: «мои паки».';
    end if;
    insert into public.messages (conversation_id, sender_id, type, content)
    values (new.conversation_id, bot_id, 'text', reply);
    return new;
  end if;

  if msg ~ '(помощь|help|команд)' then
    reply := case when v_en then
      E'I can walk you around Murkot. Try:\n• board — listings and projects\n• match — people cards\n• people — the directory\n• listings — how to post and reply\n• plus — the subscription\n• invite — a group link\n• profile — your developer card\n• newpack — your own sticker pack'
    else
      E'Могу подсказать по Murkot. Напиши:\n• доска — объявления и проекты\n• мэтч — карточки людей\n• люди — каталог\n• объявления — как написать и откликнуться\n• plus — подписка\n• инвайт — ссылка в группу\n• профиль — карточка разработчика\n• новый пак — свой стикерпак'
    end;
  elsif msg ~ '(доска|board)' then
    reply := case when v_en then
      'Board is listings and projects. Open the Board tab: people post roles they need and show what they are building.'
    else
      'Доска — это объявления и проекты. Открой вкладку «Доска»: там ищут людей в команду и показывают, над чем работают.'
    end;
  elsif msg ~ '(мэтч|матч|match)' then
    reply := case when v_en then
      'Match is a stack of people cards. Swipe right if you are interested. A mutual interest opens a chat.'
    else
      'Мэтч — колода карточек людей. Свайп вправо, если интересно. Взаимный интерес открывает чат.'
    end;
  elsif msg ~ '(люди|people|каталог)' then
    reply := case when v_en then
      'People is a directory by skills, city, and status. Use it when you want a specific person instead of swiping cards.'
    else
      'Люди — каталог по навыкам, городу и статусу. Удобно, когда нужен конкретный человек, а не колода карточек.'
    end;
  elsif msg ~ '(объявлен|listing)' then
    reply := case when v_en then
      'A listing is created on the Board. The reply button on a card sends the author a note and can open a chat.'
    else
      'Объявление создаётся на доске. Кнопка отклика на карточке отправляет автору письмо и может открыть чат.'
    end;
  elsif msg ~ '(plus|плюс)' then
    reply := case when v_en then
      'Murkot Plus is a profile cosmetic and extra listings: avatar frame, nick color, and who viewed you. It is turned on from your profile.'
    else
      'Murkot Plus — оформление профиля и больше объявлений: рамка аватара, цвет ника и кто смотрел профиль. Включается в своём профиле.'
    end;
  elsif msg ~ '(инвайт|invite|приглас)' then
    reply := case when v_en then
      'A group invite is a link like /i/… . Create it in the group, send it, and the person joins after they sign in.'
    else
      'Инвайт в группу — ссылка вида /i/… . Её создают в группе и отправляют: после входа человек сразу вступает.'
    end;
  elsif msg ~ '(профиль|profile)' then
    reply := case when v_en then
      'Your profile is the developer card: status, skills, city, and why you are here. Other people open it from your name.'
    else
      'Профиль — карточка разработчика: статус, навыки, город и зачем ты здесь. Её открывают по твоему имени.'
    end;
  elsif msg ~ '(привет|здравств|hello|start|старт)'
     or msg ~ '(^|[^a-z])hi([^a-z]|$)' then
    reply := case when v_en then
      E'Hi, I am Murkot. This is where people find a team, a project, and other people in IT.\n\nTry: board, match, people, listings, newpack.'
    else
      E'Привет, я Murkot. Здесь ищут команду, проект и людей в IT.\n\nНапиши: доска, мэтч, люди, объявления или «новый пак».'
    end;
  else
    reply := case when v_en then
      'I can help you find a team, a project, or people. Try: board, match, people, listings, plus, invite, profile, or newpack.'
    else
      'Могу помочь найти команду, проект или людей. Напиши: доска, мэтч, люди, объявления, plus, инвайт, профиль или «новый пак».'
    end;
  end if;

  insert into public.messages (conversation_id, sender_id, type, content)
  values (new.conversation_id, bot_id, 'text', reply);

  return new;
end;
$$;
