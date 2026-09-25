# Murkot

**Murkot** — CIS IT-площадка, чтобы найти команду, проект или людей в стартап. Чаты внутри — чтобы договориться.

## Что внутри

- **Доска** — объявления, витрина проектов, матч по карточкам, сообщества
- **Чаты** — личные, группы и каналы
- **Профиль** — карточка разработчика, заметка «зачем я здесь»

## Запуск

```bash
flutter pub get
flutter run -d chrome --web-hostname 127.0.0.1 --web-port 8080
```

Конфиг Supabase: `lib/config/supabase_config.dart` (URL + anon key). Для продакшена — отдельный Supabase-проект и свои ключи; anon key сам по себе не секрет, но RLS обязан быть жёстким.

## Миграции Supabase (по порядку)

В SQL Editor проекта применяйте файлы из `supabase/` **строго по порядку**, если база ещё не накатывалась:

1. `schema.sql` — база (если новый проект)
2. `features_v2.sql` … `features_v9.sql`
3. `features_v10.sql` … `features_v15.sql` — доска / матч / сообщества
4. **`features_v16.sql`** — security hardening (обязательно перед публичным доступом)
5. **`features_v17.sql`** — push events (матч), жалобы, скрытие объявлений, аналитика, инвайты в группы

5. **`features_v18.sql`** — очередь жалоб (модераторы, resolve/dismiss, снятие объявления)
6. **`features_v19.sql`** — отклики на объявления (`listing_responses`)
7. **`features_v20.sql`** — поиск людей (`search_people`)
8. **`features_v21.sql`** — панель админа (`tima` / `hex`): статистика, бан, снятие объявлений
9. **`features_v22.sql`** — гостевой просмотр доски (anon SELECT) и статус «не беспокоить»
10. **`features_v23.sql`** — гости видят имена/аватарки, людей, матч и сообщества
11. **`features_v24.sql`** … **`features_v25.sql`** — админ-аватары, письма, мэтч likes
12. **`features_v26.sql`** — Murkot Plus: рамки, цвет ника, просмотры профиля, бусты
13. **`features_v27.sql`** — перезапуск мэтча, сообщества, превью изменённого сообщения
14. **`features_v28.sql`** — бот Murkot: гид по площадке и приветствие в пустом чате
15. **`features_v29.sql`** — свои стикерпаки через бота (`новый пак` → картинки → `готово`)
16. **`features_v30.sql`** — свои стикеры из панели: `create_my_sticker_pack` / `add_my_sticker`
17. **`features_v31.sql`** — короткое имя пака, ссылка `/s/имя`, установка и удаление стикера
18. **`features_v32.sql`** — превью пака по ссылке, до кнопки «Добавить стикеры»

### Smoke / CI

Локально:
```bash
dart run tool/soft_launch_smoke.dart   # demo login + listings/people/match
dart run tool/backend_smoke_test.dart  # signup → chat → cleanup
```

На GitHub: workflow `.github/workflows/smoke.yml` (push/PR в `main`).

### Публичный профиль

- Ссылка вида `https://…/@login` (кнопка «ссылка» в своём профиле; на web берётся текущий origin)
- Deep link открывает карточку после входа
- **Инвайты в группы/каналы:** `https://…/i/<token>` — «Создать инвайт-ссылку» копирует URL; после входа ссылка сразу вступает
- **Vercel (рекомендуется):** см. [`docs/vercel.md`](docs/vercel.md) — `base-href /`, SPA rewrites
- GitHub Pages: `https://quannxxii.github.io/Murkot/` + `web/404.html`

### Модерация (после v18)

- Первый профиль в базе автоматически попадает в `app_moderators` (если список пуст)
- Добавить себя:  
  `insert into app_moderators (user_id) select id from profiles where lower(login) = lower('ваш_логин');`
- В приложении: Профиль → Настройки → **Жалобы**

### Push (после v6 + v17)

Код уже готов (`device_tokens`, `push_events`, Edge `push-on-message` / `push-on-event`, web SW). Осталось один раз настроить проект:

1. **VAPID-ключи** (не коммитьте private key):
   ```bash
   npx web-push generate-vapid-keys
   ```
   - Public → `lib/config/push_config.dart` (`PushConfig.vapidPublicKey`)
   - Public + Private → secrets Supabase (шаг 2)

2. **Secrets + deploy** (из корня репо, после `npx supabase login` и `link`):
   ```bash
   npx supabase secrets set VAPID_PUBLIC_KEY="<public>"
   npx supabase secrets set VAPID_PRIVATE_KEY="<private>"
   npx supabase secrets set VAPID_SUBJECT="mailto:support@murkot.app"
   npx supabase functions deploy push-on-message --no-verify-jwt
   npx supabase functions deploy push-on-event --no-verify-jwt
   ```

3. **Database Webhooks** (Dashboard → Database → Webhooks):
   - `public.messages` INSERT → Edge Function `push-on-message`
   - `public.push_events` INSERT → Edge Function `push-on-event`

4. **Проверка в приложении**:
   - Включите уведомления (snackbar после входа или Настройки)
   - В `device_tokens` должна появиться строка `platform=web` с JSON-подпиской
   - Закройте/сверните вкладку, отправьте сообщение с другого аккаунта → OS-уведомление
   - Взаимный матч → строки в `push_events` + push

Если секреты уже выставлены под текущий public key в `push_config.dart`, достаточно deploy + webhooks.

## Проверка после v16

- нельзя править чужое сообщение
- приватную группу нельзя найти/вступить через поиск
- в `profiles` через REST не отдаётся `email` чужих пользователей
