import 'package:flutter/material.dart';

import '../services/settings_service.dart';

class AppStrings {
  AppStrings(this.appLanguage, this.settingsService);

  final AppLanguage appLanguage;
  final SettingsService settingsService;

  bool get isRu => appLanguage == AppLanguage.ru;

  String _l(String key, String ru, String en) =>
      settingsService.label(key, isRu ? ru : en);

  String get appTitle => 'Murkot';
  String get appTagline => isRu
      ? 'Найти команду и проект в IT'
      : 'Find a team and a project in IT';
  String get messagesTab => isRu ? 'Мессенджер' : 'Messenger';
  String get chatsLoadFailed => isRu
      ? 'Не удалось загрузить чаты. Проверьте сеть и нажмите «Повторить».'
      : 'Could not load chats. Check your network and tap Retry.';
  String get authLoginTitle =>
      isRu ? 'Войдите, чтобы продолжить' : 'Sign in to continue';
  String get authRegisterTitle =>
      isRu ? 'Создайте аккаунт' : 'Create an account';
  String get authLoginAction => isRu ? 'Войти' : 'Sign in';
  String get authRegisterAction =>
      isRu ? 'Зарегистрироваться' : 'Sign up';
  String get authHaveAccount =>
      isRu ? 'Уже есть аккаунт? Войти' : 'Already have an account? Sign in';
  String get authNeedAccount =>
      isRu ? 'Нет аккаунта? Создать' : 'No account? Create one';
  String get guestEnter => isRu ? 'Войти как гость' : 'Continue as guest';
  String get guestHint => isRu
      ? 'Доска и люди — без регистрации. Чтобы писать, нужен аккаунт.'
      : 'Browse the board without an account. Messaging needs a signup.';
  String get guestGateTitle =>
      isRu ? 'Сначала зарегистрируйся' : 'Create an account first';
  String get guestGateBody => isRu
      ? 'Гость может смотреть объявления и людей. Чтобы написать, откликнуться или открыть мессенджер — нужен аккаунт.'
      : 'Guests can browse listings and people. Messaging, replies and messenger need an account.';
  String get guestRegister => isRu ? 'Зарегистрироваться' : 'Sign up';
  String get guestKeepBrowsing =>
      isRu ? 'Продолжить смотреть' : 'Keep browsing';
  String get guestMessengerLocked =>
      isRu ? 'Мессенджер для своих' : 'Messenger is for members';
  String get guestMessengerBody => isRu
      ? 'Как гость ты видишь доску. Чтобы писать людям — зарегистрируйся. Это быстро, без лишней анкеты.'
      : 'As a guest you can browse the board. Sign up to message people.';
  String get guestProfileCta => isRu ? 'Регистрация' : 'Sign up';
  String get profileNudgeTitle => isRu
      ? 'Карточка, которую захотят открыть'
      : 'A card people will actually open';
  String get profileNudgeBody => isRu
      ? 'Чем полнее профиль — статус, навыки, город, ссылки — тем охотнее откликаются и зовут в проекты.'
      : 'A fuller profile — status, skills, city, links — gets more replies and project invites.';
  String get profileNudgeDismiss => isRu ? 'Понятно' : 'Got it';
  String get cropAvatarTitle => isRu ? 'Кадрирование' : 'Crop photo';
  String get cropAvatarHint =>
      isRu ? 'Двигай и щипай фото, затем сохрани.' : 'Pan and pinch, then save.';
  String get emojiPickerTitle => isRu ? 'Эмодзи' : 'Emoji';
  String get stickerPickerTitle => isRu ? 'Стикеры Murkot' : 'Murkot stickers';
  String get gifPickerTitle => isRu ? 'Гифки' : 'GIFs';
  String get gifPickerHint => isRu
      ? 'Коты, реакции и поиск. Можно загрузить свою.'
      : 'Cats, reactions, and search. Or upload your own.';
  String get gifSearchHint => isRu ? 'Например: cat, hug, yay' : 'Try: cat, hug, yay';
  String get gifUploadOwn => isRu ? 'Своя гифка' : 'Upload your GIF';
  String get gifLoadFailed =>
      isRu ? 'Гифки сейчас не загрузились' : 'GIFs failed to load';
  String get circleRecordTitle => isRu ? 'Кружок' : 'Circle';
  String get circleCameraFallback => isRu
      ? 'Камера в приложении не открылась. Можно снять кружок системной камерой.'
      : 'In-app camera failed. You can still record with the system camera.';
  String get circleUseSystemCamera =>
      isRu ? 'Системная камера' : 'System camera';
  String recordingCircle(String login) =>
      isRu ? '$login записывает кружок' : '$login is recording a circle';
  String recordingVoice(String login) =>
      isRu ? '$login записывает голосовое' : '$login is recording a voice note';
  String get recordingCircleSelf =>
      isRu ? 'записывает кружок' : 'recording a circle';
  String get recordingVoiceSelf =>
      isRu ? 'записывает голосовое' : 'recording a voice note';
  String get skillShuffle =>
      isRu ? 'Обновить навыки' : 'Shuffle skills';
  String get mediaLinks => isRu ? 'Ссылки' : 'Links';
  String get mediaLinksEmpty =>
      isRu ? 'Ссылок в переписке пока нет' : 'No links in this chat yet';
  String get plusAttach => isRu ? 'Файл или медиа' : 'File or media';
  String get composerStickers => _l(PersonalizationKeys.stickers, 'Стикеры', 'Stickers');
  String get composerGifs => _l(PersonalizationKeys.gif, 'GIF', 'GIF');
  String get composerEmoji => _l(PersonalizationKeys.emoji, 'Эмодзи', 'Emoji');
  String get circleVideo => _l(PersonalizationKeys.circleVideo, 'Кружок', 'Circle');
  String get voiceNote => _l(PersonalizationKeys.voiceNote, 'Голосовое', 'Voice note');
  String get attachPanelExpress =>
      isRu ? 'Настроение' : 'Express';
  String get attachPanelExpressHint => isRu
      ? 'Эмодзи, стикеры и гифки — здесь. Файлы и кружки — в плюсе слева.'
      : 'Emoji, stickers and GIFs live here. Files and circles are in the plus on the left.';
  String get notificationsAndroidHint => isRu
      ? 'На Android пуши из сайта работают в Chrome, если разрешить уведомления. В APK пока баннер внутри приложения: системные пуши требуют Firebase.'
      : 'On Android, site pushes work in Chrome after you allow notifications. The APK currently shows in-app banners; OS pushes need Firebase.';
  String get loginRequired => isRu ? 'Введите логин' : 'Enter login';
  String get emailRequired =>
      isRu ? 'Введите корректную почту' : 'Enter a valid email';
  String get passwordMinLength =>
      isRu ? 'Минимум 6 символов' : 'At least 6 characters';
  String get profile => _l(PersonalizationKeys.profile, 'Профиль', 'Profile');
  String get chats => _l(PersonalizationKeys.chats, 'Чаты', 'Chats');
  String get groups => _l(PersonalizationKeys.groups, 'Группы', 'Groups');
  String get channels => _l(PersonalizationKeys.channels, 'Каналы', 'Channels');
  String get settingsTitle => _l(PersonalizationKeys.settings, 'Настройки', 'Settings');
  String get status => isRu ? 'Статус' : 'Status';
  String get email => isRu ? 'Почта' : 'Email';
  String get login => isRu ? 'Логин' : 'Login';
  String get logout => isRu ? 'Выйти из аккаунта' : 'Log out';
  String get logoutTitle => isRu ? 'Выйти из аккаунта?' : 'Log out?';
  String get logoutMessage =>
      isRu ? 'Вы будете перенаправлены на экран входа.' : 'You will be redirected to the login screen.';
  String get cancel => isRu ? 'Отмена' : 'Cancel';
  String get reportTitle => isRu ? 'Пожаловаться' : 'Report';
  String get reportSubmit => isRu ? 'Отправить жалобу' : 'Submit report';
  String get reportThanks =>
      isRu ? 'Жалоба отправлена. Спасибо.' : 'Report sent. Thank you.';
  String get reportFailed =>
      isRu ? 'Не удалось отправить жалобу' : 'Could not send the report';
  String get reportReasonSpam => isRu ? 'Спам' : 'Spam';
  String get reportReasonAbuse => isRu ? 'Оскорбления / токсичность' : 'Abuse';
  String get reportReasonFake =>
      isRu ? 'Фейк / ввод в заблуждение' : 'Fake / misleading';
  String get reportReasonOther => isRu ? 'Другое' : 'Other';
  String get moderationTitle => isRu ? 'Жалобы' : 'Reports';
  String get moderationEmpty =>
      isRu ? 'Жалоб пока нет' : 'No reports yet';
  String get moderationLoadFailed => isRu
      ? 'Не удалось загрузить жалобы'
      : 'Could not load reports';
  String get moderationStatusOpen => isRu ? 'Открытые' : 'Open';
  String get moderationStatusResolved => isRu ? 'Решено' : 'Resolved';
  String get moderationStatusDismissed => isRu ? 'Отклонено' : 'Dismissed';
  String get moderationStatusAll => isRu ? 'Все' : 'All';
  String get moderationReporter => isRu ? 'Кто пожаловался' : 'Reporter';
  String get moderationTarget => isRu ? 'Цель' : 'Target';
  String get moderationResolve => isRu ? 'Решено' : 'Resolve';
  String get moderationDismiss => isRu ? 'Отклонить' : 'Dismiss';
  String get moderationResolveTitle =>
      isRu ? 'Отметить как решённое?' : 'Mark as resolved?';
  String get moderationDismissTitle =>
      isRu ? 'Отклонить жалобу?' : 'Dismiss report?';
  String get moderationResolveConfirm => isRu
      ? 'Жалоба исчезнет из открытых.'
      : 'The report will leave the open queue.';
  String get moderationUpdated =>
      isRu ? 'Жалоба обновлена' : 'Report updated';
  String get moderationDeactivateListing =>
      isRu ? 'Снять объявление' : 'Deactivate listing';
  String get moderationDeactivateListingConfirm => isRu
      ? 'Объявление перестанет показываться на доске.'
      : 'The listing will stop showing on the board.';
  String get moderationListingDeactivated =>
      isRu ? 'Объявление снято' : 'Listing deactivated';
  String get adminTitle => isRu ? 'Панель админа' : 'Admin panel';
  String get adminDenied => isRu
      ? 'Эта панель только для tima и hex.'
      : 'This panel is only for tima and hex.';
  String get adminLoadFailed => isRu
      ? 'Не удалось загрузить статистику'
      : 'Could not load stats';
  String get adminNeedsMigration => isRu
      ? 'Нужно применить supabase/features_v21.sql в SQL Editor.'
      : 'Apply supabase/features_v21.sql in the SQL Editor.';
  String get adminOnlineNow => isRu ? 'Сейчас онлайн' : 'Online now';
  String get adminUsersTotal => isRu ? 'Всего пользователей' : 'Total users';
  String get adminUsersToday => isRu ? 'Новые сегодня' : 'New today';
  String get adminUsersWeek => isRu ? 'Новые за неделю' : 'New this week';
  String get adminListingsActive =>
      isRu ? 'Активные объявления' : 'Active listings';
  String adminListingsHint(int total) =>
      isRu ? 'из $total всего' : 'of $total total';
  String get adminProjects => isRu ? 'Проекты' : 'Projects';
  String get adminChats => isRu ? 'Чаты' : 'Chats';
  String get adminDirect => isRu ? 'личных' : 'direct';
  String get adminGroups => isRu ? 'групп' : 'groups';
  String get adminChannels => isRu ? 'каналов' : 'channels';
  String get adminMessagesToday =>
      isRu ? 'Сообщения сегодня' : 'Messages today';
  String adminMessagesHint(int total) =>
      isRu ? 'всего $total' : '$total total';
  String get adminReportsOpen => isRu ? 'Открытые жалобы' : 'Open reports';
  String adminReportsHint(int count) => isRu
      ? 'В очереди: $count'
      : 'In queue: $count';
  String get adminSwipesToday =>
      isRu ? 'Свайпы сегодня' : 'Swipes today';
  String get adminDisabledCount =>
      isRu ? 'Заблокированы' : 'Disabled';
  String get adminUsers => isRu ? 'Пользователи' : 'Users';
  String get adminSearchHint =>
      isRu ? 'Поиск по логину или городу' : 'Search by login or city';
  String get adminOnlineOnly =>
      isRu ? 'Только кто сейчас онлайн' : 'Online only';
  String get adminUsersEmpty =>
      isRu ? 'Никого не нашлось' : 'No users found';
  String get adminBadge => 'admin';
  String get adminDisabledBadge => isRu ? 'бан' : 'banned';
  String adminUserListings(int active, int total) => isRu
      ? 'объявл. $active/$total'
      : 'ads $active/$total';
  String get adminDisable => isRu ? 'Заблокировать' : 'Disable';
  String get adminEnable => isRu ? 'Разблокировать' : 'Enable';
  String get adminDisableTitle =>
      isRu ? 'Заблокировать аккаунт?' : 'Disable this account?';
  String get adminEnableTitle =>
      isRu ? 'Разблокировать аккаунт?' : 'Enable this account?';
  String adminDisableConfirm(String login) => isRu
      ? '$login не сможет войти, пока бан не снимут.'
      : '$login will not be able to sign in until the ban is lifted.';
  String adminEnableConfirm(String login) => isRu
      ? 'Снять блокировку с $login?'
      : 'Lift the ban on $login?';
  String adminDisableDone(String login) =>
      isRu ? '$login заблокирован' : '$login is disabled';
  String adminEnableDone(String login) =>
      isRu ? '$login разблокирован' : '$login is enabled';
  String get adminDeactivateListings =>
      isRu ? 'Снять все объявления' : 'Take down all listings';
  String adminDeactivateListingsConfirm(String login) => isRu
      ? 'Все объявления $login исчезнут с доски.'
      : 'All listings by $login will leave the board.';
  String get adminDeactivateListingsDone =>
      isRu ? 'Объявления сняты' : 'Listings taken down';
  String get hideListing => isRu ? 'Скрыть у себя' : 'Hide for me';
  String get hideListingDone =>
      isRu ? 'Объявление скрыто' : 'Listing hidden';
  String get inviteCreate =>
      isRu ? 'Создать инвайт-ссылку' : 'Create invite link';
  String get inviteCreated =>
      isRu ? 'Ссылка скопирована' : 'Invite link copied';
  String get inviteRedeem =>
      isRu ? 'Вступить по инвайту' : 'Join with invite';
  String get inviteRedeemHint => isRu
      ? 'Вставьте ссылку или токен инвайта'
      : 'Paste invite link or token';
  String get inviteRedeemFailed =>
      isRu ? 'Не удалось вступить по инвайту' : 'Could not redeem invite';
  String get inviteMakePublic =>
      isRu ? 'Сделать сообществом' : 'Make a community';
  String get inviteMakePrivate =>
      isRu ? 'Убрать из сообществ' : 'Remove from communities';
  String get matchRestartFeed =>
      isRu ? 'Начать заново' : 'Start over';
  String get matchRestartFeedHint => isRu
      ? 'Покажем снова тех, кого вы ещё не лайкнули'
      : 'We’ll show people you haven’t liked yet';
  String get yes => isRu ? 'Да' : 'Yes';
  String get save => isRu ? 'Сохранить' : 'Save';
  String get confirmLogout => isRu ? 'Выйти' : 'Log out';
  String get changeAvatarHint =>
      isRu ? 'Нажмите на аватар, чтобы изменить' : 'Tap avatar to change';
  String get statusHint => isRu
      ? 'Зачем вы здесь? Одна-две строки'
      : 'Why are you here? One or two lines';
  String get gallery => isRu ? 'Галерея' : 'Gallery';
  String get camera => isRu ? 'Камера' : 'Camera';
  String get removeAvatar => isRu ? 'Удалить аватар' : 'Remove avatar';
  String get avatarUpdated => isRu ? 'Аватар обновлён' : 'Avatar updated';
  String get avatarRemoved => isRu ? 'Аватар удалён' : 'Avatar removed';
  String get statusSaved => isRu ? 'Статус сохранён' : 'Status saved';
  String get pinnedNoteLabel => isRu ? 'ЗАКРЕПЛЕНО' : 'PINNED';
  String get devCardTitle =>
      isRu ? 'Карточка разработчика' : 'Developer card';
  String get devCardSubtitle => isRu
      ? 'Расскажите, кого или что вы ищете'
      : 'Tell others what you are looking for';
  String get devCardEdit => isRu ? 'Редактировать карточку' : 'Edit card';
  String get devCardSaved => isRu ? 'Карточка сохранена' : 'Card saved';
  String get devStatusLabel => isRu ? 'Статус поиска' : 'Search status';
  String get devStatusNone => isRu ? 'Не указан' : 'Not set';
  String get devStatusLookingForTeam =>
      isRu ? 'Ищу команду / работу' : 'Looking for a team / job';
  String get devStatusLookingForMembers =>
      isRu ? 'Ищу людей в проект' : 'Looking for teammates';
  String get devStatusOpenToOffers =>
      isRu ? 'Открыт к предложениям' : 'Open to offers';
  String get devStatusDoNotDisturb =>
      isRu ? 'Не беспокоить' : 'Do not disturb';
  String get availabilityLookingForTeam =>
      isRu ? 'доступен для команды' : 'available for a team';
  String get availabilityLookingForMembers =>
      isRu ? 'собирает команду' : 'building a team';
  String get availabilityOpenToOffers =>
      isRu ? 'открыт к предложениям' : 'open to offers';
  String get availabilityDoNotDisturb =>
      isRu ? 'не беспокоить' : 'do not disturb';
  String get sessionBootTitle =>
      isRu ? 'Загружаем Murkot…' : 'Loading Murkot…';
  String get sessionBootSubtitle => isRu
      ? 'Доска, чаты и профиль почти готовы'
      : 'Board, chats and profile are almost ready';
  String get sessionBootFailedTitle => isRu
      ? 'Не удалось загрузить данные'
      : 'Could not load your data';
  String get sessionBootFailedSubtitle => isRu
      ? 'Нет связи с сервером. Можно открыть приложение и повторить позже.'
      : 'No connection to the server. You can open the app and retry later.';
  String get sessionBootSlowTitle => isRu
      ? 'Сервер отвечает долго'
      : 'Server is taking a while';
  String get sessionBootSlowSubtitle => isRu
      ? 'Можно открыть приложение сейчас — данные подтянутся, когда сеть оживёт.'
      : 'Open the app now — data will catch up when the network recovers.';
  String get continueAnyway => isRu ? 'Открыть приложение' : 'Open app';
  String get onboardingEyebrow =>
      isRu ? 'СТАРТ — КАРТОЧКА' : 'START — YOUR CARD';
  String get onboardingNeedMinimum => isRu
      ? 'Нужны цель и минимум 2 навыка — иначе вас не найдут.'
      : 'You need a goal and at least 2 skills — or people cannot find you.';
  String get onboardingSkipTitle =>
      isRu ? 'Выйти без карточки?' : 'Leave without a card?';
  String get onboardingSkipMessage => isRu
      ? 'Мэтч и поиск команды работают плохо без цели и стека. Можно заполнить позже в профиле.'
      : 'Match and team search work poorly without a goal and stack. You can fill this in later in Profile.';
  String get onboardingSkipConfirm =>
      isRu ? 'Всё равно выйти' : 'Leave anyway';
  String get onboardingWelcome => isRu
      ? 'Соберём вашу карточку'
      : 'Let’s build your card';
  String get onboardingWelcomeSub => isRu
      ? 'Пять коротких шагов — и вас смогут найти на доске и в мэтче.'
      : 'Five short steps — then people can find you on the board and in Match.';
  String get onboardingStepGoal => isRu ? 'Цель' : 'Goal';
  String get onboardingStepGoalTitle => isRu
      ? 'Что вы ищете сейчас?'
      : 'What are you looking for?';
  String get onboardingStepGoalSub => isRu
      ? 'Это главный сигнал для мэтча и объявлений.'
      : 'This is the main signal for Match and listings.';
  String get onboardingStepSkills => isRu ? 'Стек' : 'Stack';
  String get onboardingStepSkillsTitle => isRu
      ? 'Ваш стек технологий'
      : 'Your tech stack';
  String get onboardingStepSkillsSub => isRu
      ? 'Добавьте 2–5 навыков, по которым вас будут находить.'
      : 'Add 2–5 skills people can filter by.';
  String get onboardingStepLevel => isRu ? 'Уровень' : 'Level';
  String get onboardingStepLevelTitle =>
      isRu ? 'Ваш уровень' : 'Your level';
  String get onboardingStepLevelSub => isRu
      ? 'Можно пропустить и указать позже в профиле.'
      : 'You can skip and set this later in your profile.';
  String get onboardingStepCity => isRu ? 'Город' : 'City';
  String get onboardingStepCityTitle =>
      isRu ? 'Откуда вы?' : 'Where are you based?';
  String get onboardingStepCitySub => isRu
      ? 'Город помогает собирать локальные команды.'
      : 'City helps people form local teams.';
  String get onboardingStepLinks => isRu ? 'Ссылки' : 'Links';
  String get onboardingStepLinksTitle => isRu
      ? 'Покажите работы'
      : 'Show your work';
  String get onboardingStepLinksSub => isRu
      ? 'GitHub или портфолио — по желанию.'
      : 'GitHub or portfolio — optional.';
  String get onboardingNext => isRu ? 'Дальше' : 'Next';
  String get onboardingBack => isRu ? 'Назад' : 'Back';
  String get onboardingSkip => isRu ? 'Пропустить' : 'Skip';
  String get onboardingFinish =>
      isRu ? 'Открыть Murkot' : 'Open Murkot';
  String get onboardingSaveFailed => isRu
      ? 'Не удалось сохранить. Можно открыть приложение и заполнить позже.'
      : 'Could not save. You can open the app and fill this in later.';
  String get cmdPlaceholder => isRu
      ? 'Быстрое действие…'
      : 'Quick action…';
  String get cmdShortcutHint => '⌘K / Ctrl+K';
  String get cmdEmpty =>
      isRu ? 'Ничего не найдено' : 'No matching actions';
  String get cmdFindPeople => isRu ? 'Найти людей' : 'Find people';
  String get cmdFindPeopleSub =>
      isRu ? 'Поиск по логину' : 'Search by login';
  String get cmdNewListing =>
      isRu ? 'Создать объявление' : 'Create listing';
  String get cmdNewListingSub =>
      isRu ? 'Доска → объявления' : 'Board → listings';
  String get cmdNewProject => isRu ? 'Добавить проект' : 'Add project';
  String get cmdNewProjectSub =>
      isRu ? 'Доска → проекты' : 'Board → projects';
  String get cmdOpenListings =>
      isRu ? 'Открыть объявления' : 'Open listings';
  String get cmdOpenProjects =>
      isRu ? 'Открыть проекты' : 'Open projects';
  String get cmdOpenMatch => isRu ? 'Открыть мэтч' : 'Open Match';
  String get cmdOpenCommunities =>
      isRu ? 'Открыть сообщества' : 'Open communities';
  String get cmdOpenBoardSub =>
      isRu ? 'Перейти на доску' : 'Go to the board';
  String get cmdOpenChats => isRu ? 'Открыть чаты' : 'Open chats';
  String get cmdOpenChatsSub =>
      isRu ? 'Личные, группы и каналы' : 'DMs, groups and channels';
  String get cmdOpenProfile => isRu ? 'Открыть профиль' : 'Open profile';
  String get cmdOpenProfileSub => isRu
      ? 'Заметка и карточка разработчика'
      : 'Note and developer card';
  String get respondEyebrow => isRu ? 'ОТКЛИК' : 'RESPONSE';
  String get respondTitle =>
      isRu ? 'Отправить отклик?' : 'Send a response?';
  String respondSubtitle(String login, String subject) => isRu
      ? 'Откроется чат с @$login по поводу «$subject», текст отклика уйдёт сразу.'
      : 'Opens a chat with @$login about “$subject” and sends your response right away.';
  String get respondSend =>
      isRu ? 'Отправить отклик' : 'Send response';
  // Legacy aliases (UI copy used to say AirDrop).
  String get airdropEyebrow => respondEyebrow;
  String get airdropTitle => respondTitle;
  String airdropSubtitle(String login, String subject) =>
      respondSubtitle(login, subject);
  String get airdropSend => respondSend;
  String get projectsShowcaseLabel =>
      isRu ? 'ПРОЕКТЫ' : 'PROJECTS';
  String get projectsShowcaseHeading => isRu ? 'Витрина' : 'Showcase';
  String get projectsFinderLabel => projectsShowcaseLabel;
  String get projectsFinderHeading => projectsShowcaseHeading;
  String get matchNeedCardTitle => isRu
      ? 'Сначала заполните карточку'
      : 'Complete your card first';
  String get matchNeedCardBody => isRu
      ? 'Укажите цель и хотя бы 2 навыка в профиле — тогда мэтч станет осмысленным.'
      : 'Set a goal and at least 2 skills in Profile — then Match makes sense.';
  String get matchNeedCardAction =>
      isRu ? 'Открыть профиль' : 'Open profile';
  String get skillsLabel => isRu ? 'Стек технологий' : 'Tech stack';
  String get skillsHint => isRu
      ? 'Например: Flutter, Python, DevOps'
      : 'E.g. Flutter, Python, DevOps';
  String get skillAddHint =>
      isRu ? 'Добавить навык…' : 'Add a skill…';
  String get experienceLabel => isRu ? 'Уровень' : 'Level';
  String get levelJunior => isRu ? 'Джуниор' : 'Junior';
  String get levelMiddle => isRu ? 'Мидл' : 'Middle';
  String get levelSenior => isRu ? 'Сеньор' : 'Senior';
  String get levelLead => isRu ? 'Лид' : 'Lead';
  String get levelNotSet => isRu ? 'Не указан' : 'Not set';
  String get githubLabel => 'GitHub';
  String get portfolioLabel => isRu ? 'Портфолио' : 'Portfolio';
  String get cityLabel => isRu ? 'Город' : 'City';
  String get cityHint =>
      isRu ? 'Например: Алматы' : 'E.g. Warsaw';
  String get linkHint => 'https://…';
  String get listingsTab => isRu ? 'Доска' : 'Board';
  String get listingsTitle => isRu ? 'Доска объявлений' : 'Listings board';
  String get listingCreate =>
      isRu ? 'Разместить объявление' : 'Post a listing';
  String get listingNewTitle =>
      isRu ? 'Новое объявление' : 'New listing';
  String get listingTypeLabel => isRu ? 'Тип объявления' : 'Listing type';
  String get listingFilterAll => isRu ? 'Все' : 'All';
  String get listingsSearchHint => isRu
      ? 'Поиск: название, навыки, город…'
      : 'Search: title, skills, city…';
  String get listingsSortNewest => isRu ? 'Сначала новые' : 'Newest';
  String get listingsSortRelevance =>
      isRu ? 'По релевантности' : 'Relevance';
  String get listingFilterCityAll => isRu ? 'Все города' : 'All cities';
  String get listingFilterCompensationAll =>
      isRu ? 'Любые условия' : 'Any terms';
  String get listingsFilters => isRu ? 'Фильтры' : 'Filters';
  String get listingsFiltersDone => isRu ? 'Готово' : 'Done';
  String get listingTitleLabel => isRu ? 'Заголовок' : 'Title';
  String get listingTitleHint => isRu
      ? 'Например: Ищу Flutter-разработчика в стартап'
      : 'E.g. Looking for a Flutter dev for a startup';
  String get listingDescriptionLabel => isRu ? 'Описание' : 'Description';
  String get listingDescriptionHint => isRu
      ? 'Расскажите о проекте, задачах и кого ищете'
      : 'Describe the project, tasks and who you need';
  String get listingCompensationLabel => isRu ? 'Условия' : 'Compensation';
  String get compensationPaid => isRu ? 'За деньги' : 'Paid';
  String get compensationEquity => isRu ? 'За долю' : 'Equity';
  String get compensationPetProject => isRu ? 'Пет-проект' : 'Pet project';
  String get compensationNotSet => isRu ? 'Не указано' : 'Not set';
  String get listingRespond => isRu ? 'Откликнуться' : 'Respond';
  String get listingResponded =>
      isRu ? 'Вы откликнулись' : 'You responded';
  String get listingOpenChat => isRu ? 'Открыть чат' : 'Open chat';
  String listingResponsesCount(int n) => isRu
      ? (n == 1 ? '1 отклик' : '$n откликов')
      : (n == 1 ? '1 response' : '$n responses');
  String get listingResponsesTitle =>
      isRu ? 'Отклики на объявление' : 'Listing responses';
  String get listingResponsesEmpty =>
      isRu ? 'Пока нет откликов' : 'No responses yet';
  String get listingResponseAccept => isRu ? 'Принять' : 'Accept';
  String get listingResponseReject => isRu ? 'Отклонить' : 'Reject';
  String get listingResponseAccepted => isRu ? 'Принят' : 'Accepted';
  String get listingResponseRejected => isRu ? 'Отклонён' : 'Rejected';
  String get listingResponseInChat => isRu ? 'В диалоге' : 'In chat';
  String listingRespondPrefill(String title) => isRu
      ? 'Привет! Откликаюсь на объявление «$title».'
      : 'Hi! Responding to your listing "$title".';
  String projectContactPrefill(String name) => isRu
      ? 'Привет! Пишу по поводу проекта «$name».'
      : 'Hi! Reaching out about your project "$name".';
  String get listingMineBadge => isRu ? 'Моё' : 'Mine';
  String get listingDelete =>
      isRu ? 'Удалить объявление' : 'Delete listing';
  String get listingDeleteConfirm => isRu
      ? 'Объявление будет удалено безвозвратно.'
      : 'The listing will be permanently deleted.';
  String get listingDeleted =>
      isRu ? 'Объявление удалено' : 'Listing deleted';
  String get listingPublished =>
      isRu ? 'Объявление опубликовано' : 'Listing published';
  String get listingUpdated =>
      isRu ? 'Объявление обновлено' : 'Listing updated';
  String get listingEdit =>
      isRu ? 'Редактировать объявление' : 'Edit listing';
  String get listingEditAction => isRu ? 'Изменить' : 'Edit';
  String get listingsEmpty => isRu
      ? 'Пока нет объявлений.\nРазместите первое — так вас быстрее найдут.'
      : 'No listings yet.\nPost the first one so people can find you.';
  String get listingsEmptyAction =>
      isRu ? 'Разместить объявление' : 'Post a listing';
  String get listingsFilterEmpty => isRu
      ? 'Нет объявлений по выбранным фильтрам'
      : 'No listings match these filters';
  String get clearFilters => isRu ? 'Сбросить фильтры' : 'Clear filters';
  String get boardWelcomeTitle =>
      isRu ? 'Карточка готова — что дальше?' : 'Card ready — what’s next?';
  String get boardWelcomeBody => isRu
      ? 'Выберите один шаг: так Murkot сразу начинает работать для вас.'
      : 'Pick one step so Murkot starts working for you right away.';
  String get boardWelcomeAction =>
      isRu ? 'Позже' : 'Later';
  String get boardWelcomeCtaRespond =>
      isRu ? 'Откликнуться на объявление' : 'Respond to a listing';
  String get boardWelcomeCtaMatch =>
      isRu ? 'Открыть мэтч' : 'Open Match';
  String get boardWelcomeCtaPost =>
      isRu ? 'Разместить своё' : 'Post your listing';
  String get syncDevStatusTitle => isRu
      ? 'Обновить статус в профиле?'
      : 'Update your profile status?';
  String syncDevStatusMessage(String statusLabel) => isRu
      ? 'Поставить в карточке разработчика: «$statusLabel» — так вас легче найдут в мэтчинге.'
      : 'Set your developer card to "$statusLabel" so matching can find you more easily.';
  String get syncDevStatusConfirm =>
      isRu ? 'Обновить статус' : 'Update status';
  String get syncDevStatusDone =>
      isRu ? 'Статус в профиле обновлён' : 'Profile status updated';
  String get listingTitleRequired => isRu
      ? 'Введите заголовок (минимум 3 символа)'
      : 'Enter a title (at least 3 characters)';
  String get listingSaveFailed => isRu
      ? 'Не удалось опубликовать объявление'
      : 'Could not publish the listing';
  String get listingLoadFailed => isRu
      ? 'Не удалось загрузить объявления'
      : 'Could not load listings';
  String get retry => isRu ? 'Повторить' : 'Retry';
  String get deleteAction => isRu ? 'Удалить' : 'Delete';
  String get boardListingsTab => isRu ? 'Объявления' : 'Listings';
  String get boardProjectsTab => isRu ? 'Проекты' : 'Projects';
  String projectsObjectsCount(int count) {
    if (!isRu) {
      return count == 1 ? '1 project' : '$count projects';
    }
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return '$count объект';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return '$count объекта';
    }
    return '$count объектов';
  }

  String get projectCreate => isRu ? 'Добавить проект' : 'Add project';
  String get projectNewTitle => isRu ? 'Новый проект' : 'New project';
  String get projectNameLabel => isRu ? 'Название' : 'Name';
  String get projectNameHint =>
      isRu ? 'Например: Murkot Messenger' : 'E.g. Murkot Messenger';
  String get projectDescriptionHint => isRu
      ? 'Что за проект, на каком он этапе и куда движется'
      : 'What the project is, its stage and where it is heading';
  String get projectLookingForLabel =>
      isRu ? 'Кого не хватает в команде' : 'Who the team needs';
  String get projectLookingForHint =>
      isRu ? 'Добавить роль…' : 'Add a role…';
  String get projectDemoLabel => isRu ? 'Демо' : 'Demo';
  String get projectRepoLabel => isRu ? 'Репозиторий' : 'Repository';
  String get projectContactAuthor =>
      isRu ? 'Написать автору' : 'Message author';
  String get projectDelete => isRu ? 'Удалить проект' : 'Delete project';
  String get projectDeleteConfirm => isRu
      ? 'Проект будет удалён безвозвратно.'
      : 'The project will be permanently deleted.';
  String get projectDeleted => isRu ? 'Проект удалён' : 'Project deleted';
  String get projectPublished =>
      isRu ? 'Проект опубликован' : 'Project published';
  String get projectUpdated =>
      isRu ? 'Проект обновлён' : 'Project updated';
  String get projectEdit => isRu ? 'Редактировать проект' : 'Edit project';
  String get projectsEmpty => isRu
      ? 'Витрина пуста.\nДобавьте проект — или найдите команду в объявлениях.'
      : 'Showcase is empty.\nAdd a project — or find a team in listings.';
  String get projectsEmptyAction =>
      isRu ? 'Добавить проект' : 'Add project';
  String get projectsFilterEmpty => isRu
      ? 'Нет проектов по выбранным фильтрам'
      : 'No projects match these filters';
  String get projectsSearchHint => isRu
      ? 'Поиск: название, стек, роль, город…'
      : 'Search: name, stack, role, city…';
  String get projectsFilters => isRu ? 'Фильтры' : 'Filters';
  String get projectsFiltersDone => isRu ? 'Готово' : 'Done';
  String get projectsSortNewest => isRu ? 'Сначала новые' : 'Newest';
  String get projectsSortRelevance =>
      isRu ? 'По релевантности' : 'Relevance';
  String get projectsFilterRoleAll => isRu ? 'Любая роль' : 'Any role';
  String get projectsLookingForLabel =>
      isRu ? 'Ищут в команду' : 'Looking for';
  String get projectNameRequired => isRu
      ? 'Введите название (минимум 3 символа)'
      : 'Enter a name (at least 3 characters)';
  String get projectSaveFailed => isRu
      ? 'Не удалось опубликовать проект'
      : 'Could not publish the project';
  String get projectLoadFailed => isRu
      ? 'Не удалось загрузить проекты'
      : 'Could not load projects';
  String get boardMatchTab => isRu ? 'Мэтч' : 'Match';
  String get boardCommunitiesTab => isRu ? 'Сообщества' : 'Communities';
  String get boardPeopleTab => isRu ? 'Люди' : 'People';
  String get peopleSearchHint => isRu
      ? 'Логин, стек или город'
      : 'Login, stack or city';
  String get peopleFilters => isRu ? 'Фильтры людей' : 'People filters';
  String get peopleFilterStatusAll => isRu ? 'Любой статус' : 'Any status';
  String get peopleEmpty => isRu
      ? 'Пока никого не нашли.\nДополните свою карточку — так вас тоже найдут.'
      : 'No people yet.\nComplete your card so others can find you too.';
  String get peopleEmptyFiltered => isRu
      ? 'Никого по фильтрам. Сбросьте или измените поиск.'
      : 'No matches for these filters. Clear or change search.';
  String get peopleLoadFailed =>
      isRu ? 'Не удалось загрузить людей' : 'Could not load people';
  String get peopleSortShared =>
      isRu ? 'Общий стек' : 'Shared stack';
  String get peopleSortLogin => isRu ? 'По логину' : 'By login';
  String get peopleOpenProfile =>
      isRu ? 'Открыть профиль' : 'Open profile';
  String get communitiesHint => isRu
      ? 'Тематические сообщества. Вступите и обсуждайте идеи с другими.'
      : 'Themed communities. Join and discuss ideas with others.';
  String get communitiesEmpty => isRu
      ? 'Каталог сообществ пока пуст.\nСкоро здесь появятся тематические комнаты.'
      : 'Community catalog is empty.\nThemed rooms will appear here soon.';
  String get communitiesLoadFailed => isRu
      ? 'Не удалось загрузить сообщества'
      : 'Could not load communities';
  String get communityJoin => isRu ? 'Вступить' : 'Join';
  String get communityOpen => isRu ? 'Открыть' : 'Open';
  String get communityJoined => isRu ? 'Вы вступили' : 'Joined';
  String get communityCategoryStartup =>
      isRu ? 'Стартапы' : 'Startups';
  String get communityCategoryCareer =>
      isRu ? 'Карьера' : 'Career';
  String get communityCategoryDev =>
      isRu ? 'Разработка' : 'Development';
  String get communityCategoryCreative =>
      isRu ? 'Дизайн' : 'Design';
  String get communityCategoryGeneral =>
      isRu ? 'Общее' : 'General';
  String get matchFeedTitle => isRu ? 'Поиск команды' : 'Find a team';
  String get matchMatchesTitle => isRu ? 'Мои мэтчи' : 'My matches';
  String get matchLike => isRu ? 'Интересно' : 'Interested';
  String get matchPass => isRu ? 'Пропустить' : 'Pass';
  String get matchItsAMatch => isRu ? 'Это мэтч!' : "It's a match!";
  String get matchItsAMatchBody => isRu
      ? 'Вы оба заинтересованы. Откройте чат и познакомьтесь.'
      : 'You both are interested. Open a chat and say hi.';
  String matchItsAMatchBodyWithSkills(int shared) => isRu
      ? 'Вы оба заинтересованы. Общий стек: $shared. Откройте чат и познакомьтесь.'
      : 'You both are interested. Shared stack: $shared. Open a chat and say hi.';
  String matchChatOpener({
    required String peerLogin,
    int sharedSkills = 0,
    List<String> peerSkills = const [],
  }) {
    final skillBit = sharedSkills > 0
        ? (isRu
            ? ' У нас $sharedSkills в общем стеке.'
            : ' We share $sharedSkills skills.')
        : (peerSkills.isEmpty
            ? ''
            : (isRu
                ? ' Видел(а) твой стек: ${peerSkills.join(', ')}.'
                : ' Noticed your stack: ${peerSkills.join(', ')}.'));
    return isRu
        ? 'Привет, @$peerLogin! Мы смэтчились.$skillBit Давай познакомимся.'
        : 'Hey @$peerLogin! We matched.$skillBit Nice to meet you.';
  }

  String get matchOpenChat => isRu ? 'Написать' : 'Message';
  String get matchKeepSwiping =>
      isRu ? 'Продолжить' : 'Keep swiping';
  String get matchEmptyFeed => isRu
      ? 'Пока никого нет в ленте.\nЗагляните в объявления или дополните карточку в профиле.'
      : 'No one left in the feed.\nBrowse listings or complete your card in Profile.';
  String get matchEmptyFeedListings =>
      isRu ? 'К объявлениям' : 'Browse listings';
  String get matchEmptyFeedProfile =>
      isRu ? 'Открыть профиль' : 'Open profile';
  String get matchEmptyMatches => isRu
      ? 'Пока нет взаимных мэтчей.\nЛайкайте тех, с кем хотите работать.'
      : 'No mutual matches yet.\nLike people you want to work with.';
  String get matchEmptyMatchesAction =>
      isRu ? 'К ленте мэтча' : 'Back to feed';
  String get matchLoadFailed => isRu
      ? 'Не удалось загрузить ленту мэтчинга'
      : 'Could not load the match feed';
  String get matchSwipeFailed => isRu
      ? 'Не удалось сохранить выбор'
      : 'Could not save your choice';
  String get matchSharedSkills =>
      isRu ? 'Общий стек' : 'Shared stack';
  String get copyProfileLink =>
      isRu ? 'Скопировать ссылку на профиль' : 'Copy profile link';
  String get profileLinkCopied =>
      isRu ? 'Ссылка на профиль скопирована' : 'Profile link copied';
  String get matchHint => isRu
      ? 'Лайкайте подходящих людей — при взаимном интересе откроется чат'
      : 'Like people who fit — a mutual interest opens a chat';
  String get languageLabel => isRu ? 'Язык' : 'Language';
  String get textSize => isRu ? 'Размер текста' : 'Text size';
  String get theme => isRu ? 'Тема' : 'Theme';
  String get themeSystem => isRu ? 'Системная' : 'System';
  String get themeLight => isRu ? 'Светлая' : 'Light';
  String get themeDark => isRu ? 'Тёмная' : 'Dark';
  String get textSmall => isRu ? 'Мелкий' : 'Small';
  String get textNormal => isRu ? 'Обычный' : 'Normal';
  String get textLarge => isRu ? 'Крупный' : 'Large';
  String get languageRu => 'Русский';
  String get languageEn => 'English';
  String get search => isRu ? 'Поиск' : 'Search';
  String get searchChats => isRu ? 'Поиск по чатам' : 'Search chats';
  String get searchGroups => isRu ? 'Поиск по группам' : 'Search groups';
  String get searchChannels => isRu ? 'Поиск по каналам' : 'Search channels';
  String get findUsers => isRu ? 'Найти пользователя' : 'Find user';
  String get searchUsersHint =>
      isRu ? 'Введите логин' : 'Enter login';
  String get searchUsersEmptyHint => isRu
      ? 'Начните вводить логин, чтобы найти людей'
      : 'Start typing a login to find people';
  String get usersNotFound =>
      isRu ? 'Пользователи не найдены' : 'No users found';
  String get findGroup => isRu ? 'Найти группу' : 'Find group';
  String get findChannel => isRu ? 'Найти канал' : 'Find channel';
  String get joinAction => isRu ? 'Вступить' : 'Join';
  String get alreadyMember => isRu ? 'Вы участник' : 'Member';
  String get nothingFound => isRu ? 'Ничего не найдено' : 'Nothing found';
  String get foundMessages => isRu ? 'Сообщения' : 'Messages';
  String get changeAvatar => isRu ? 'Сменить аватар' : 'Change avatar';
  String get attachmentsPanel => isRu ? 'Вложения' : 'Attachments';
  String get chooseEmoji => isRu ? 'Выбрать эмодзи' : 'Choose emoji';
  String get captionHint =>
      isRu ? 'Подпись к вложениям…' : 'Caption for attachments…';
  String membersCount(int count) =>
      isRu ? 'Участников: $count' : 'Members: $count';
  String get chatWithBot =>
      isRu ? 'Написать Murkot' : 'Message Murkot';
  String get botSubtitle => isRu
      ? 'Бот отвечает в реальном времени'
      : 'Bot replies in real time';
  String get noStatus => isRu ? 'Без статуса' : 'No status';
  String get createChat => _l(PersonalizationKeys.createChat, 'Создать новый чат', 'Create new chat');
  String get createGroup => _l(PersonalizationKeys.createGroup, 'Создать новую группу', 'Create new group');
  String get createChannel => _l(PersonalizationKeys.createChannel, 'Создать новый канал', 'Create new channel');
  String get newChatTitle => isRu ? 'Новый чат' : 'New chat';
  String get newGroupTitle => isRu ? 'Новая группа' : 'New group';
  String get newChannelTitle => isRu ? 'Новый канал' : 'New channel';
  String get newChatHint => isRu ? 'Логин пользователя' : 'User login';
  String get newGroupHint => isRu ? 'Название группы' : 'Group name';
  String get newChannelHint => isRu ? 'Название канала' : 'Channel name';
  String get nameRequired => isRu ? 'Введите название' : 'Enter a name';
  String get emptyList => isRu ? 'Список пуст' : 'List is empty';
  String get openChatFailed =>
      isRu ? 'Не удалось открыть чат' : 'Could not open chat';
  String get mediaUploadFailed =>
      isRu ? 'Не удалось отправить файл' : 'Could not send file';
  String get mediaUploading =>
      isRu ? 'Отправка файла...' : 'Uploading file...';
  String get memberAdded =>
      isRu ? 'Участник добавлен' : 'Member added';
  String get memberRemoved =>
      isRu ? 'Участник удалён' : 'Member removed';
  String get memberActionFailed =>
      isRu ? 'Не удалось изменить участников' : 'Could not update members';
  String get openFile => isRu ? 'Открыть файл' : 'Open file';
  String get pickCancelled => isRu ? 'Отменено' : 'Cancelled';
  String get reply => isRu ? 'Ответить' : 'Reply';
  String get replyTo => isRu ? 'Ответ для' : 'Reply to';
  String get userBlockedBanner => isRu
      ? 'Пользователь в чёрном списке. Сообщения недоступны.'
      : 'User is blocked. Messaging is disabled.';
  String get blockedUserHidden => isRu
      ? 'Заблокированные чаты скрыты'
      : 'Blocked chats are hidden';
  String get forward => isRu ? 'Переслать' : 'Forward';
  String get forwardTo => isRu ? 'Переслать в...' : 'Forward to...';
  String get messageForwarded =>
      isRu ? 'Сообщение переслано' : 'Message forwarded';
  String get searchInChat =>
      isRu ? 'Поиск в чате' : 'Search in chat';
  String get searchInChatHint =>
      isRu ? 'Текст сообщения' : 'Message text';
  String get noSearchResults =>
      isRu ? 'Ничего не найдено' : 'No results';
  String get loadOlderMessages =>
      isRu ? 'Загрузить раньше' : 'Load earlier';
  String get enableNotificationsHint => isRu
      ? 'Разрешите уведомления в браузере, чтобы не пропускать сообщения и мэтчи'
      : 'Allow browser notifications to catch messages and matches';
  String get enableNotificationsAction =>
      isRu ? 'Включить' : 'Enable';
  String get notificationsEnabledDone =>
      isRu ? 'Уведомления включены' : 'Notifications enabled';
  String get notificationsDenied => isRu
      ? 'Браузер заблокировал уведомления. Разрешите их в настройках сайта.'
      : 'The browser blocked notifications. Allow them in site settings.';
  String get online => _l(PersonalizationKeys.online, 'в сети', 'online');
  String get offline => _l(PersonalizationKeys.offline, 'не в сети', 'offline');
  String get typing => _l(PersonalizationKeys.typing, 'печатает', 'typing');
  String typingUsers(String names) => isRu ? '$names печатает...' : '$names is typing...';
  String onlineCount(int n) => isRu ? '$n в сети' : '$n online';
  String subscriberCount(int n) => isRu ? '$n подписчиков' : '$n subscribers';
  String get noMessages => isRu ? 'Нет сообщений' : 'No messages';
  String get messageHint => _l(PersonalizationKeys.message, 'Сообщение...', 'Message...');
  String get editMessage => isRu ? 'Редактировать' : 'Edit';
  String get deleteForMe => isRu ? 'Удалить для себя' : 'Delete for me';
  String get deleteForAll => isRu ? 'Удалить для всех' : 'Delete for everyone';
  String get deleteForAllConfirm =>
      isRu ? 'Сообщение будет удалено у всех участников.' : 'Message will be deleted for everyone.';
  String get addReaction => isRu ? 'Добавить реакцию' : 'Add reaction';
  String get pinForMe => isRu ? 'Закрепить для себя' : 'Pin for me';
  String get pinForAll => isRu ? 'Закрепить для всех' : 'Pin for everyone';
  String get voice => isRu ? 'Голос' : 'Voice';
  String get video => isRu ? 'Видео' : 'Video';
  String get image => isRu ? 'Фото' : 'Photo';
  String get music => isRu ? 'Музыка' : 'Music';
  String get sticker => isRu ? 'Стикер' : 'Sticker';
  String get gif => isRu ? 'GIF' : 'GIF';
  String get file => isRu ? 'Файл' : 'File';
  String get profileInfo => _l(PersonalizationKeys.info, 'Информация', 'Info');
  String get images => isRu ? 'Фото' : 'Photos';
  String get videos => isRu ? 'Видео' : 'Videos';
  String get voices => isRu ? 'Голосовые' : 'Voice';
  String get files => isRu ? 'Файлы' : 'Files';
  String get noMedia => isRu ? 'Нет медиа' : 'No media';
  String get blockUser => isRu ? 'Заблокировать' : 'Block';
  String get unblockUser => isRu ? 'Разблокировать' : 'Unblock';
  String blockUserConfirm(String name) =>
      isRu ? 'Заблокировать $name?' : 'Block $name?';
  String unblockUserConfirm(String name) =>
      isRu ? 'Разблокировать $name?' : 'Unblock $name?';
  String get deleteChat => isRu ? 'Удалить чат' : 'Delete chat';
  String get deleteChatConfirm => isRu ? 'Чат будет удалён.' : 'Chat will be deleted.';
  String get leaveGroup => isRu ? 'Выйти из группы' : 'Leave group';
  String get leaveChannel => isRu ? 'Отписаться от канала' : 'Leave channel';
  String get leaveGroupConfirm =>
      isRu ? 'Вы покинете группу.' : 'You will leave the group.';
  String get leaveChannelConfirm =>
      isRu ? 'Вы отпишетесь от канала.' : 'You will leave the channel.';
  String get deleteGroupOrChannel => isRu ? 'Удалить' : 'Delete';
  String deleteGroupOrChannelConfirm(String name) =>
      isRu ? 'Удалить «$name» навсегда?' : 'Delete "$name" permanently?';
  String get rename => isRu ? 'Переименовать' : 'Rename';
  String get profileActions => isRu ? 'Действия' : 'Actions';
  String get editDescription =>
      isRu ? 'Изменить описание' : 'Edit description';
  String get descriptionHint =>
      isRu ? 'Коротко о группе или канале' : 'Short group or channel bio';
  String get descriptionUpdated =>
      isRu ? 'Описание обновлено' : 'Description updated';
  String get noDescription =>
      isRu ? 'Описание не указано' : 'No description yet';
  String get manageMembers => isRu ? 'Управление участниками' : 'Manage members';
  String get members => isRu ? 'Участники' : 'Members';
  String get addMember => isRu ? 'Добавить участника' : 'Add member';
  String get changeName => isRu ? 'Сменить имя' : 'Change name';
  String get changeNameHint => isRu ? 'Новое имя' : 'New name';
  String get nameChanged => isRu ? 'Имя изменено' : 'Name changed';
  String get chooseWallpaper => isRu ? 'Выбрать обои' : 'Choose wallpaper';
  String get uploadWallpaper => isRu ? 'Загрузить своё фото' : 'Upload custom photo';
  String get deleteAccount => isRu ? 'Удалить аккаунт' : 'Delete account';
  String get deleteAccountTitle => isRu ? 'Удалить аккаунт?' : 'Delete account?';
  String get deleteAccountMessage =>
      isRu ? 'Это необратимо. Введите «удалить аккаунт» для подтверждения.' : 'Irreversible. Type phrase to confirm.';
  String get deleteAccountHint => isRu ? 'удалить аккаунт' : 'delete account';
  String get deleteAccountPhrase => isRu ? 'удалить аккаунт' : 'delete account';
  String get deleteAccountValidation =>
      isRu ? 'Введите «удалить аккаунт»' : 'Type the confirmation phrase';
  String get deleteAccountConfirm => isRu ? 'Удалить' : 'Delete';
  String get blacklist => isRu ? 'Чёрный список' : 'Blacklist';
  String blacklistCount(int n) => isRu ? '$n заблокированных' : '$n blocked';
  String get blacklistEmpty => isRu ? 'Чёрный список пуст' : 'Blacklist is empty';
  String get changeEmail => isRu ? 'Сменить почту' : 'Change email';
  String get changeEmailHint => isRu ? 'Новая почта' : 'New email';
  String get passwordHint => isRu ? 'Пароль' : 'Password';
  String get passwordRequired => isRu ? 'Введите пароль' : 'Enter password';
  String get emailChanged => isRu ? 'Почта изменена' : 'Email changed';
  String get birthday => isRu ? 'Дата рождения' : 'Birthday';
  String get setBirthday => isRu ? 'Указать дату рождения' : 'Set birthday';
  String get notSet => isRu ? 'Не указана' : 'Not set';
  String ageYears(int n) => isRu ? '$n лет' : '$n years old';
  String get channelReadOnly =>
      isRu ? 'Писать в канал могут только админы' : 'Only admins can post in channels';
  String get comments => isRu ? 'Комментарии' : 'Comments';
  String get commentHint => isRu ? 'Комментарий...' : 'Comment...';
  String get showMore => isRu ? 'Показать ещё' : 'Show more';
  String get personalization => isRu ? 'Персонализация' : 'Personalization';
  String get personalizationHint =>
      isRu ? 'Замените стандартные подписи на свои' : 'Replace default labels with your own';
  String get resetLabels => isRu ? 'Сбросить' : 'Reset';
  String get aboutUs => isRu ? 'О нас' : 'About us';
  String get aboutTitle => isRu ? 'О Murkot' : 'About Murkot';
  String get back => isRu ? 'Назад' : 'Back';
  String get notifications => isRu ? 'Уведомления' : 'Notifications';
  String get notificationsMessages =>
      isRu ? 'Уведомления о сообщениях' : 'Message notifications';
  String get notificationsHint => isRu
      ? 'Показывать системные уведомления о новых сообщениях'
      : 'Show system notifications for new messages';
  String get interfaceSection => isRu ? 'Интерфейс' : 'Interface';
  String get interfaceSectionHint => isRu
      ? 'Анимации и подсказки'
      : 'Animations and tooltips';
  String get floatingTooltips =>
      isRu ? 'Плавающие подсказки' : 'Floating tooltips';
  String get floatingTooltipsHint => isRu
      ? 'Подсказки следуют за курсором'
      : 'Tooltips follow the cursor';
  String get authSpotlight =>
      isRu ? 'Эффект на экране входа' : 'Auth screen spotlight';
  String get authSpotlightHint => isRu
      ? 'Волнистая область при уходе с карточки входа'
      : 'Wavy area when leaving the login card';
  String get smoothTheme =>
      isRu ? 'Плавная смена темы' : 'Smooth theme transition';
  String get showPassword => isRu ? 'Показать пароль' : 'Show password';
  String get hidePassword => isRu ? 'Скрыть пароль' : 'Hide password';
  String get createAccount => isRu ? 'Создайте аккаунт' : 'Create an account';
  String get signInAccount => isRu ? 'Войдите в аккаунт' : 'Sign in';
  String get register => isRu ? 'Зарегистрироваться' : 'Sign up';
  String get signIn => isRu ? 'Войти' : 'Sign in';
  String get haveAccount =>
      isRu ? 'Уже есть аккаунт? Войти' : 'Already have an account? Sign in';
  String get noAccount =>
      isRu ? 'Нет аккаунта? Создать' : 'No account? Create one';
  String get enterLogin => isRu ? 'Введите логин' : 'Enter login';
  String get enterEmail =>
      isRu ? 'Введите корректную почту' : 'Enter a valid email';
  String get minPassword =>
      isRu ? 'Минимум 6 символов' : 'At least 6 characters';
  String get send => isRu ? 'Отправить' : 'Send';
  String get recording => isRu ? 'Запись…' : 'Recording…';
  String get loadFailed =>
      isRu ? 'Не удалось загрузить данные' : 'Failed to load data';
  String get loadingMurkot =>
      isRu ? 'Загрузка Murkot…' : 'Loading Murkot…';
  String mediaOf(int index, int total) =>
      isRu ? '$index из $total' : '$index of $total';
  String get serverTimeout => isRu
      ? 'Сервер не отвечает. Проверьте интернет-соединение и попробуйте ещё раз.'
      : 'Server is not responding. Check your internet connection and try again.';
  String get smoothThemeHint => isRu
      ? 'Шторка сверху закрывает экран, тема меняется под ней'
      : 'A curtain drops, theme switches underneath, then rises';
  String get messageDeleted =>
      isRu ? 'Сообщение удалено' : 'Message deleted';
  String get editedShort => isRu ? 'изм.' : 'edited';
  String pinnedMessageOf(int index, int total) => isRu
      ? 'Закреплённое сообщение $index из $total'
      : 'Pinned message $index of $total';
  String get micDenied =>
      isRu ? 'Нет доступа к микрофону' : 'Microphone access denied';
  String get voiceRecordFailed =>
      isRu ? 'Не удалось записать голосовое' : 'Could not record voice note';
  String videoTooLargeMb(String mb) => isRu
      ? 'Видео слишком большое ($mb МБ, максимум 50 МБ)'
      : 'Video is too large ($mb MB, max 50 MB)';
  String videoTooLarge(int mb) => videoTooLargeMb('$mb');
  String userNotFound(String login) =>
      isRu ? 'Пользователь @$login не найден' : 'User @$login not found';
  String openProfileFailed(Object e) =>
      isRu ? 'Не удалось открыть профиль: $e' : 'Could not open profile: $e';
  String blockFailed(Object e) =>
      isRu ? 'Не удалось заблокировать: $e' : 'Could not block: $e';
  String unblockFailed(Object e) =>
      isRu ? 'Не удалось разблокировать: $e' : 'Could not unblock: $e';
  String get alwaysOnline =>
      isRu ? 'Всегда на связи' : 'Always online';
  String get emailVerificationTitle =>
      isRu ? 'Подтверждение почты' : 'Email verification';
  String get emailVerificationSent => isRu
      ? 'Мы отправили код подтверждения на вашу почту.'
      : 'We sent a verification code to your email.';
  String emailVerificationSentTo(String email) => isRu
      ? 'Мы отправили код на $email. Введите его ниже или перейдите по ссылке из письма.'
      : 'We sent a code to $email. Enter it below or open the link from the email.';
  String get enterEmailCode =>
      isRu ? 'Введите код из письма' : 'Enter the code from the email';
  String get emailResent =>
      isRu ? 'Письмо отправлено повторно' : 'Email resent';
  String get confirmAction => isRu ? 'Подтвердить' : 'Confirm';
  String get resendCode =>
      isRu ? 'Отправить код ещё раз' : 'Resend code';
  String get aboutTagline => isRu
      ? 'Найти своих в IT и сразу написать'
      : 'Find your people in IT — then talk to them';
  String get aboutBody1 => isRu
      ? 'Murkot — это не «ещё один чат» и не доска объявлений, которая '
          'умирает после отклика. Мы собирали место, где можно найти '
          'команду, пет-проект или людей в стартап — и сразу перейти в '
          'разговор. На Доске висят объявления, проекты, мэтч и люди. '
          'Увидел своё — открыл чат. Без «напишите мне в Telegram», '
          'без десяти вкладок и без ощущения, что ты на hh.ru в 2014.'
      : 'Murkot is not just another chat, and not a job board that dies '
          'after you hit apply. We wanted a place to find a team, a pet '
          'project, or people for a startup — and talk right away. The '
          'Board has listings, projects, match and people. If it clicks, '
          'you open a chat. No “message me on Telegram”, no ten tabs, no '
          '2014 job-site vibes.';
  String get aboutBody2 => isRu
      ? 'Мессенджер здесь настоящий: лички, группы, каналы, голосовые, '
          'кружки, файлы, закреплённые сообщения. В профиле — карточка '
          'разработчика: стек, уровень, город, куда смотришь. Это сигнал '
          'для мэтча и объявлений, а не декоративная строчка «open to work». '
          'Под капотом — Flutter и Supabase: аккаунты, realtime, вложения, '
          'кто сейчас в сети. Никита держит эту кухню. Тима собирает то, '
          'что ты видишь и нажимаешь.'
      : 'The messenger is real: DMs, groups, channels, voice notes, circles, '
          'files, pinned messages. Profiles have a developer card — stack, '
          'level, city, what you are looking for. That is the signal for '
          'match and listings, not a decorative “open to work” line. Under '
          'the hood: Flutter and Supabase — accounts, realtime, media, who '
          'is online. Nikita runs that kitchen. Tima builds what you see '
          'and tap.';
  String get aboutBody3 => isRu
      ? 'Внешне это тёплый апельсиновый кот, который тянется, сидит и '
          'выглядывает из углов. Название, цвет и сок — не брендбук из '
          'Figma, а то, что хотелось видеть на экране самим. Где-то уже '
          'гладко, где-то лапа ещё не дотянулась. Так и живём: два человека, '
          'пет-проект, который пытается стать нормальным продуктом для '
          'тех, кто собирает команды руками, а не через «кто знает '
          'фронтендера?» в общем чате.'
      : 'On the outside it is a warm orange cat that stretches, sits and '
          'peeks from the corners. The name, the color, the juice — not a '
          'Figma brand book, just what we wanted on our own screens. Some '
          'parts are already smooth; elsewhere a paw is still reaching. '
          'Two people, a pet project trying to become a real product for '
          'anyone who builds teams by hand instead of asking “anyone know '
          'a frontend?” in a group chat.';
  String get aboutTeam => isRu ? 'Кто это сделал' : 'Who made this';
  String get aboutPhotoSoon =>
      isRu ? 'Фото появится позже' : 'Photo coming soon';
  String get aboutTimaSoon =>
      isRu ? 'скоро тут что-то будет' : 'something will be here soon';
  String get aboutCreator1Role => isRu
      ? 'Бэкенд: аккаунты, база, realtime, вся кухня под капотом'
      : 'Backend: accounts, database, realtime, the kitchen underneath';
  String get aboutCreator2Role => isRu
      ? 'Фронтенд: экраны, навигация, как это выглядит и нажимается'
      : 'Frontend: screens, navigation, how it looks and feels';
  String get aboutBody4 => isRu
      ? 'Если ты уже внутри — пользуйся Доской как доской, чатами как '
          'чатами. Можно просто болтать. Можно повесить объявление и ждать '
          'отклик. Можно свайпнуть мэтч и написать первым. Мы сами так и '
          'пользуемся, пока дописываем хвосты.'
      : 'If you are already in — use the Board as a board and chats as '
          'chats. You can just talk. You can post a listing and wait. You '
          'can match and write first. That is how we use it while we finish '
          'the tails.';
  String get aboutBody5 => isRu
      ? 'Ранняя сборка, кот ещё не везде дотянулся. Если что-то бесит или '
          'наоборот зашло — напиши. Налей сока и оставайся, нам не жалко.'
      : 'Early build, the cat has not reached every corner yet. If something '
          'sucks or actually works — write us. Pour some juice and stay, '
          'we do not mind.';
}

class AppStringsScope extends InheritedWidget {
  const AppStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final AppStrings strings;

  static AppStrings? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppStringsScope>()
        ?.strings;
  }

  @override
  bool updateShouldNotify(AppStringsScope oldWidget) =>
      strings.appLanguage != oldWidget.strings.appLanguage ||
      strings.settingsService != oldWidget.strings.settingsService;
}

extension AppStringsContext on BuildContext {
  AppStrings get strings =>
      dependOnInheritedWidgetOfExactType<AppStringsScope>()!.strings;
}
