-- Features v28: Murkot guide bot.
-- Apply after features_v27.sql.
-- Replaces the TujhBot demo replies (ping / time / echo) with product help,
-- and greets the user the first time a direct chat with the bot is empty.

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

  if msg ~ '(помощь|help|команд)' then
    reply := case when v_en then
      E'I can walk you around Murkot. Try:\n• board — listings and projects\n• match — people cards\n• people — the directory\n• listings — how to post and reply\n• plus — the subscription\n• invite — a group link\n• profile — your developer card'
    else
      E'Могу подсказать по Murkot. Напиши:\n• доска — объявления и проекты\n• мэтч — карточки людей\n• люди — каталог\n• объявления — как написать и откликнуться\n• plus — подписка\n• инвайт — ссылка в группу\n• профиль — карточка разработчика'
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
      E'Hi, I am Murkot. This is where people find a team, a project, and other people in IT.\n\nTry: board, match, people, listings. Or tap a button under the composer.'
    else
      E'Привет, я Murkot. Здесь ищут команду, проект и людей в IT.\n\nНапиши: доска, мэтч, люди или объявления. Или нажми кнопку под полем ввода.'
    end;
  else
    reply := case when v_en then
      'I can help you find a team, a project, or people. Try: board, match, people, listings, plus, invite, or profile.'
    else
      'Могу помочь найти команду, проект или людей. Напиши: доска, мэтч, люди, объявления, plus, инвайт или профиль.'
    end;
  end if;

  insert into public.messages (conversation_id, sender_id, type, content)
  values (new.conversation_id, bot_id, 'text', reply);

  return new;
end;
$$;

create or replace function public.ensure_bot_greeting(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  bot_id uuid := 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeee01';
  greeting text := E'Привет! Я Murkot. Здесь ищут команду, проект и людей в IT.\n\nНапиши или нажми:\n• доска — объявления и проекты\n• мэтч — карточки людей\n• люди — каталог\n• объявления — как откликнуться\n\nЕщё умею: plus, инвайт, профиль. Напиши «помощь».';
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  perform pg_advisory_xact_lock(hashtext(p_conversation_id::text));

  if not exists (
    select 1
    from public.conversations c
    join public.conversation_members me
      on me.conversation_id = c.id and me.user_id = auth.uid()
    join public.conversation_members bot
      on bot.conversation_id = c.id and bot.user_id = bot_id
    where c.id = p_conversation_id
      and c.type = 'direct'
  ) then
    return;
  end if;

  if exists (
    select 1 from public.messages m where m.conversation_id = p_conversation_id
  ) then
    return;
  end if;

  insert into public.messages (conversation_id, sender_id, type, content)
  values (p_conversation_id, bot_id, 'text', greeting);
end;
$$;

revoke all on function public.ensure_bot_greeting(uuid) from public;
grant execute on function public.ensure_bot_greeting(uuid) to authenticated;
