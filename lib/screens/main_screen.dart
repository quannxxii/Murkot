import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_strings.dart';
import '../models/media_payload.dart';
import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/listings_service.dart';
import '../services/match_service.dart';
import '../services/notification_service.dart';
import '../services/people_service.dart';
import '../services/presence_service.dart';
import '../services/projects_service.dart';
import '../services/settings_service.dart';
import '../utils/configure_web.dart';
import '../utils/invite_deep_link.dart';
import '../utils/main_tab_bus.dart';
import '../utils/profile_deep_link.dart';
import '../widgets/ad_ticker.dart';
import '../widgets/avatar_display.dart';
import '../widgets/command_palette.dart';
import '../widgets/murkot_boot_screen.dart';
import '../widgets/murkot_decor.dart';
import '../widgets/session_boot.dart';
import '../widgets/unlumen/murkot_fx.dart';
import 'about_murkot_screen.dart';
import 'board_screen.dart';
import 'chat_screen.dart';
import 'guest_locked_screen.dart';
import 'messages_hub_screen.dart';
import 'profile_screen.dart';
import 'public_profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.authService,
    required this.settingsService,
    required this.prefs,
    this.isGuest = false,
  });

  final AuthService authService;
  final SettingsService settingsService;
  final SharedPreferences prefs;
  final bool isGuest;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final Set<int> _builtTabs = {MainTabs.board};
  ChatService? _chatService;
  ListingsService? _listingsService;
  ProjectsService? _projectsService;
  MatchService? _matchService;
  PeopleService? _peopleService;
  BlacklistService? _blacklistService;
  PresenceService? _presenceService;
  final _notificationService = NotificationService();
  String? _loadError;
  bool _loadingData = false;
  bool _showBoot = true;
  bool _bootFailed = false;
  bool _bootSlow = false;
  bool _retriedInit = false;
  DateTime? _bootStartedAt;
  Timer? _bootSlowTimer;

  @override
  void initState() {
    super.initState();
    _notificationService.attachSettings(widget.settingsService);
    mainTabIndex.addListener(_onExternalTabChange);
    _initServices();
  }

  void _onExternalTabChange() {
    if (!mounted) return;
    final next = mainTabIndex.value;
    if (_currentIndex == next && _builtTabs.contains(next)) return;
    setState(() {
      _builtTabs.add(next);
      _currentIndex = next;
    });
  }

  void _selectTab(int index) {
    mainTabIndex.value = index;
    setState(() {
      _builtTabs.add(index);
      _currentIndex = index;
    });
  }

  void _disposeSessionServices() {
    _bootSlowTimer?.cancel();
    _bootSlowTimer = null;
    _chatService?.dispose();
    _presenceService?.dispose();
    _listingsService?.dispose();
    _projectsService?.dispose();
    _matchService?.dispose();
    _peopleService?.dispose();
    _blacklistService?.dispose();
    _chatService = null;
    _presenceService = null;
    _listingsService = null;
    _projectsService = null;
    _matchService = null;
    _peopleService = null;
    _blacklistService = null;
  }

  /// Best-effort token refresh. Never block the boot screen for long —
  /// web often hangs on refresh when Supabase is unreachable.
  Future<void> _ensureFreshSession() async {
    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession == null) return;
      await auth.refreshSession().timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Session refresh failed: $e');
    }
  }

  static const _guestUserId = '00000000-0000-0000-0000-000000000000';

  Future<void> _initGuestServices() async {
    _disposeSessionServices();
    const guestId = _guestUserId;
    const guestLogin = 'guest';
    final blacklistService =
        BlacklistService(userId: guestId, userLogin: guestLogin);
    final presenceService = PresenceService(
      userId: guestId,
      userLogin: guestLogin,
    );
    final chatService = ChatService(
      userId: guestId,
      userLogin: guestLogin,
      prefs: widget.prefs,
      blacklistService: blacklistService,
    );
    if (!mounted) {
      chatService.dispose();
      return;
    }
    setState(() {
      _chatService = chatService;
      _listingsService = ListingsService(userId: guestId);
      _projectsService = ProjectsService(userId: guestId);
      _matchService = MatchService();
      _peopleService = PeopleService();
      _blacklistService = blacklistService;
      _presenceService = presenceService;
      _loadError = null;
      _loadingData = false;
      _showBoot = false;
      _bootFailed = false;
    });
    hideMurkotHtmlBoot();
    unawaited(_listingsService!.refresh());
    unawaited(_projectsService!.refresh());
    unawaited(_peopleService!.refresh());
    unawaited(_matchService!.refreshFeed());
  }

  Future<void> _initServices() async {
    if (widget.isGuest) {
      await _initGuestServices();
      return;
    }
    final user = widget.authService.currentUser;
    if (user == null) return;

    // Dispose previous attempt (e.g. after "Retry").
    _disposeSessionServices();

    final blacklistService =
        BlacklistService(userId: user.id, userLogin: user.login);
    final presenceService = PresenceService(
      userId: user.id,
      userLogin: user.login,
    );
    final chatService = ChatService(
      userId: user.id,
      userLogin: user.login,
      prefs: widget.prefs,
      blacklistService: blacklistService,
    );
    chatService.onIncomingMessage = (message, conversation) {
      final body = message.type == MessageType.text
          ? message.content
          : (MediaPayload.tryParse(message.content)?.name ??
              messageTypeLabel(message.type));
      _notificationService.showIncomingMessage(
        title: conversation.name,
        body: '${message.senderName}: $body',
        conversationId: conversation.id,
      );
    };

    if (!mounted) {
      chatService.dispose();
      presenceService.dispose();
      return;
    }

    // Show the shell under a boot overlay — chats hydrate in the background.
    setState(() {
      _chatService = chatService;
      _listingsService = ListingsService(userId: user.id);
      _projectsService = ProjectsService(userId: user.id);
      _matchService = MatchService();
      _peopleService = PeopleService();
      _blacklistService = blacklistService;
      _presenceService = presenceService;
      _loadError = null;
      _loadingData = true;
      _showBoot = true;
      _bootFailed = false;
      _bootSlow = false;
      _bootStartedAt = DateTime.now();
    });

    _bootSlowTimer?.cancel();
    _bootSlowTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || !_showBoot || _bootFailed) return;
      setState(() => _bootSlow = true);
      hideMurkotHtmlBoot();
    });

    unawaited(_notificationService.initialize());
    unawaited(
      _hydrateServices(chatService, blacklistService, presenceService),
    );
  }

  Future<void> _dismissBoot({bool failed = false}) async {
    final started = _bootStartedAt ?? DateTime.now();
    const minShow = Duration(milliseconds: 900);
    final elapsed = DateTime.now().difference(started);
    if (!failed && elapsed < minShow) {
      await Future<void>.delayed(minShow - elapsed);
    }
    if (!mounted) return;
    _bootSlowTimer?.cancel();
    setState(() {
      if (failed) {
        _bootFailed = true;
        _bootSlow = false;
        _showBoot = true;
      } else {
        _bootFailed = false;
        _bootSlow = false;
        _showBoot = false;
      }
    });
    if (failed || !_showBoot) {
      hideMurkotHtmlBoot();
    }
    if (!failed) {
      unawaited(_maybePromptNotifications());
      unawaited(_openPendingDeepLinks());
    }
  }

  Future<void> _openPendingDeepLinks() async {
    await _openPendingInviteDeepLink();
    await _openPendingProfileDeepLink();
  }

  Future<void> _openPendingInviteDeepLink() async {
    final token = consumePendingInviteToken();
    if (token == null) return;
    final chat = _chatService;
    final blacklist = _blacklistService;
    final presence = _presenceService;
    final user = widget.authService.currentUser;
    if (chat == null || blacklist == null || presence == null || user == null) {
      return;
    }
    try {
      final conversation = await chat.redeemConversationInvite(token);
      if (!mounted || conversation == null) return;
      mainTabIndex.value = MainTabs.chats;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ChatScreen(
            conversation: conversation,
            chatService: chat,
            blacklistService: blacklist,
            presenceService: presence,
            currentUserLogin: user.login,
            settingsService: widget.settingsService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.inviteRedeemFailed)),
      );
    }
  }

  Future<void> _openPendingProfileDeepLink() async {
    final login = consumePendingProfileLogin();
    if (login == null) return;
    final chat = _chatService;
    final blacklist = _blacklistService;
    final presence = _presenceService;
    final user = widget.authService.currentUser;
    if (chat == null || blacklist == null || presence == null || user == null) {
      return;
    }
    if (login.toLowerCase() == user.login.toLowerCase()) {
      mainTabIndex.value = MainTabs.profile;
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PublicProfileScreen(
          login: login,
          chatService: chat,
          blacklistService: blacklist,
          presenceService: presence,
          currentUserLogin: user.login,
          settingsService: widget.settingsService,
        ),
      ),
    );
  }

  Future<void> _maybePromptNotifications() async {
    if (!kIsWeb) return;
    final user = widget.authService.currentUser;
    if (user == null) return;
    final key = 'push_prompt_shown_${user.id}';
    if (widget.prefs.getBool(key) ?? false) return;
    await widget.prefs.setBool(key, true);
    // Already granted → register quietly, no snackbar.
    if (_notificationService.isEnabled) return;
    if (!mounted) return;
    final strings = context.strings;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.enableNotificationsHint),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: strings.enableNotificationsAction,
          onPressed: () async {
            final ok =
                await _notificationService.enableAndRequestPermission();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ok
                      ? strings.notificationsEnabledDone
                      : strings.notificationsDenied,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _continueAnyway() {
    if (!mounted) return;
    _bootSlowTimer?.cancel();
    setState(() {
      _showBoot = false;
      _bootFailed = false;
      _bootSlow = false;
      _loadingData = false;
    });
    hideMurkotHtmlBoot();
    unawaited(_maybePromptNotifications());
    unawaited(_openPendingDeepLinks());
  }

  void _retryBoot() {
    _retriedInit = false;
    _initServices();
  }

  Future<void> _hydrateServices(
    ChatService chatService,
    BlacklistService blacklistService,
    PresenceService presenceService,
  ) async {
    // Refresh in parallel with data load — don't serialize a slow timeout.
    final refresh = _ensureFreshSession();

    try {
      await Future.wait([
        refresh,
        blacklistService.initialize().catchError((Object e) {
          debugPrint('Blacklist init failed: $e');
        }),
        chatService.initialize(),
      ]).timeout(const Duration(seconds: 8));

      if (!mounted || !identical(_chatService, chatService)) return;
      setState(() {
        _loadingData = false;
        _loadError = null;
        _bootFailed = false;
      });
      unawaited(presenceService.initialize());
      unawaited(_dismissBoot());
    } catch (e) {
      debugPrint('Hydrate services failed: $e');
      if (!mounted || !identical(_chatService, chatService)) return;

      // One quick retry, then surface the failure on the boot screen.
      if (!_retriedInit) {
        _retriedInit = true;
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (mounted && identical(_chatService, chatService)) {
          await _hydrateServices(
            chatService,
            blacklistService,
            presenceService,
          );
        }
        return;
      }

      setState(() {
        _loadingData = false;
        _loadError = e.toString();
      });
      unawaited(_dismissBoot(failed: true));
    }
  }

  @override
  void dispose() {
    mainTabIndex.removeListener(_onExternalTabChange);
    _disposeSessionServices();
    super.dispose();
  }

  String get _sectionTitle {
    final strings = context.strings;
    return switch (_currentIndex) {
      MainTabs.board => strings.listingsTab,
      MainTabs.chats => strings.messagesTab,
      _ => strings.profile,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authService,
      builder: (context, _) => _buildShell(context),
    );
  }

  Widget _buildShell(BuildContext context) {
    final strings = context.strings;
    final currentUser = widget.authService.currentUser;
    // During a forced re-login the auth screen replaces this widget on the
    // next frame; render a placeholder instead of crashing on null.
    if (currentUser == null && !widget.isGuest) {
      return const Scaffold(body: MurkotBootScreen());
    }
    final login = currentUser?.login ?? 'guest';
    final chatService = _chatService;
    final listingsService = _listingsService;
    final projectsService = _projectsService;
    final matchService = _matchService;
    final peopleService = _peopleService;
    final blacklistService = _blacklistService;
    final presenceService = _presenceService;

    if (chatService == null ||
        listingsService == null ||
        projectsService == null ||
        matchService == null ||
        peopleService == null ||
        blacklistService == null ||
        presenceService == null) {
      return Scaffold(
        body: SessionBootOverlay(
          failed: _bootFailed,
          allowContinueWhileLoading: _bootSlow,
          onContinue: (_bootFailed || _bootSlow) ? _continueAnyway : null,
          onRetry: _bootFailed ? _retryBoot : null,
        ),
      );
    }

    final theme = Theme.of(context);

    final shell = Scaffold(
      appBar: _currentIndex == MainTabs.profile
          ? null
          : AppBar(
              title: Row(
                children: [
                  Flexible(
                    flex: 2,
                    child: Text(
                      _sectionTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_currentIndex == MainTabs.board ||
                      _currentIndex == MainTabs.chats) ...[
                    const SizedBox(width: 8),
                    const Expanded(flex: 3, child: AdTicker()),
                  ],
                ],
              ),
              actions: [
                IconButton(
                  tooltip: strings.cmdShortcutHint,
                  onPressed: () => showCommandPalette(
                    context: context,
                    chatService: chatService,
                  ),
                  icon: const Icon(Icons.search_rounded),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: MurkotThemeSwitch(
                      settings: widget.settingsService,
                    ),
                  ),
                ),
              ],
              bottom: _loadingData && !_showBoot
                  ? const PreferredSize(
                      preferredSize: Size.fromHeight(3),
                      child: LinearProgressIndicator(minHeight: 3),
                    )
                  : null,
            ),
      body: Column(
        children: [
          if (_loadError != null && !_showBoot)
            Material(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off,
                        color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.chatsLoadFailed,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _retriedInit = false;
                        _initServices();
                      },
                      child: Text(strings.retry),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _builtTabs.contains(MainTabs.board)
                    ? BoardScreen(
                        listingsService: listingsService,
                        projectsService: projectsService,
                        matchService: matchService,
                        peopleService: peopleService,
                        chatService: chatService,
                        blacklistService: blacklistService,
                        presenceService: presenceService,
                        currentUserLogin: login,
                        settingsService: widget.settingsService,
                        authService: widget.authService,
                      )
                    : const SizedBox.shrink(),
                _builtTabs.contains(MainTabs.chats)
                    ? (widget.isGuest
                        ? GuestLockedScreen(
                            settingsService: widget.settingsService,
                            title: strings.guestMessengerLocked,
                            body: strings.guestMessengerBody,
                          )
                        : MessagesHubScreen(
                            chatService: chatService,
                            blacklistService: blacklistService,
                            presenceService: presenceService,
                            currentUserLogin: login,
                            settingsService: widget.settingsService,
                            initialFilter: messengerFilter.value,
                          ))
                    : const SizedBox.shrink(),
                _builtTabs.contains(MainTabs.profile)
                    ? (widget.isGuest
                        ? GuestLockedScreen(
                            settingsService: widget.settingsService,
                            title: strings.guestRegister,
                            body: strings.guestGateBody,
                          )
                        : ProfileScreen(
                            authService: widget.authService,
                            settingsService: widget.settingsService,
                            blacklistService: blacklistService,
                          ))
                    : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _showBoot
          ? null
          : _CustomBottomNav(
              currentIndex: _currentIndex,
              onTap: _selectTab,
              boardLabel: strings.listingsTab,
              chatsLabel: strings.messagesTab,
              profileLabel: widget.isGuest
                  ? strings.guestProfileCta
                  : strings.profile,
              profileLogin: widget.isGuest
                  ? strings.guestRegister
                  : currentUser!.login,
              profileAvatarPath:
                  widget.isGuest ? null : currentUser!.avatarPath,
              profileAvatarEmoji:
                  widget.isGuest ? '👋' : currentUser!.avatarEmoji,
              settingsService: widget.settingsService,
            ),
    );

    final content = Stack(
      fit: StackFit.expand,
      children: [
        shell,
        if (_showBoot)
          AnimatedOpacity(
            opacity: _showBoot ? 1 : 0,
            duration: const Duration(milliseconds: 320),
            child: SessionBootOverlay(
              failed: _bootFailed,
              allowContinueWhileLoading: _bootSlow,
              onContinue: (_bootFailed || _bootSlow) ? _continueAnyway : null,
              onRetry: _bootFailed ? _retryBoot : null,
            ),
          ),
      ],
    );

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _OpenCommandPaletteIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _OpenCommandPaletteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenCommandPaletteIntent: CallbackAction<_OpenCommandPaletteIntent>(
            onInvoke: (_) {
              if (_showBoot || _chatService == null) return null;
              showCommandPalette(
                context: context,
                chatService: _chatService!,
              );
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: content,
        ),
      ),
    );
  }
}

class _OpenCommandPaletteIntent extends Intent {
  const _OpenCommandPaletteIntent();
}

class _CustomBottomNav extends StatelessWidget {
  const _CustomBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.boardLabel,
    required this.chatsLabel,
    required this.profileLabel,
    required this.profileLogin,
    required this.settingsService,
    this.profileAvatarPath,
    this.profileAvatarEmoji,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final String boardLabel;
  final String chatsLabel;
  final String profileLabel;
  final String profileLogin;
  final SettingsService settingsService;
  final String? profileAvatarPath;
  final String? profileAvatarEmoji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              // About Murkot — mark + label, separated like profile.
              SizedBox(
                width: 76,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AboutMurkotScreen(
                            settingsService: settingsService,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const MurkotStackedMark(size: 44),
                        const SizedBox(height: 2),
                        Text(
                          context.strings.aboutUs,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: Colors.grey.shade400,
              ),
              Expanded(
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.grid_view_outlined,
                      selectedIcon: Icons.grid_view_rounded,
                      label: boardLabel,
                      isSelected: currentIndex == MainTabs.board,
                      onTap: () => onTap(MainTabs.board),
                    ),
                    _NavItem(
                      icon: Icons.chat_bubble_outline,
                      selectedIcon: Icons.chat_bubble,
                      label: chatsLabel,
                      isSelected: currentIndex == MainTabs.chats,
                      onTap: () => onTap(MainTabs.chats),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: Colors.grey.shade400,
              ),
              SizedBox(
                width: 88,
                child: _ProfileNavItem(
                  label: profileLabel,
                  login: profileLogin,
                  avatarPath: profileAvatarPath,
                  avatarEmoji: profileAvatarEmoji,
                  isSelected: currentIndex == MainTabs.profile,
                  onTap: () => onTap(MainTabs.profile),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Profile nav item: label on top, current account avatar below, nick at
/// the bottom — shows which account is active without opening the profile.
class _ProfileNavItem extends StatelessWidget {
  const _ProfileNavItem({
    required this.label,
    required this.login,
    required this.isSelected,
    required this.onTap,
    this.avatarPath,
    this.avatarEmoji,
  });

  final String label;
  final String login;
  final bool isSelected;
  final VoidCallback onTap;
  final String? avatarPath;
  final String? avatarEmoji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        isSelected ? theme.colorScheme.primary : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Container(
                  decoration: isSelected
                      ? BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        )
                      : null,
                  child: AvatarDisplay(
                    name: login,
                    avatarPath: avatarPath,
                    avatarEmoji: avatarEmoji,
                    radius: 13,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  login,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.primary
        : Colors.grey.shade600;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Material(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isSelected ? selectedIcon : icon, color: color, size: 22),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
