import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/listings_service.dart';
import '../services/match_service.dart';
import '../services/people_service.dart';
import '../services/presence_service.dart';
import '../services/projects_service.dart';
import '../services/settings_service.dart';
import '../utils/board_tab_bus.dart';
import '../widgets/murkot_decor.dart';
import 'communities_screen.dart';
import 'listings_screen.dart';
import 'match_screen.dart';
import 'onboarding_screen.dart';
import 'people_screen.dart';
import 'projects_screen.dart';

/// The "Board" tab: listings, projects, matching, communities and people.
class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    required this.listingsService,
    required this.projectsService,
    required this.matchService,
    required this.peopleService,
    required this.chatService,
    required this.blacklistService,
    required this.presenceService,
    required this.currentUserLogin,
    required this.settingsService,
    required this.authService,
  });

  final ListingsService listingsService;
  final ProjectsService projectsService;
  final MatchService matchService;
  final PeopleService peopleService;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final PresenceService presenceService;
  final String currentUserLogin;
  final SettingsService settingsService;
  final AuthService authService;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final Set<int> _builtTabs;
  bool _welcomeHandled = false;

  @override
  void initState() {
    super.initState();
    final initial = boardTabIndex.value.clamp(0, 4);
    _builtTabs = {initial};
    _tabs = TabController(
      length: 5,
      vsync: this,
      initialIndex: initial,
    );
    _tabs.addListener(_onTabChanged);
    boardTabIndex.addListener(_onExternalTab);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowFirstValue());
  }

  Future<void> _maybeShowFirstValue() async {
    if (_welcomeHandled) return;
    final user = widget.authService.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(boardWelcomePrefsKey(user.id)) ?? false;
    if (!mounted || !pending) return;
    _welcomeHandled = true;
    await prefs.setBool(boardWelcomePrefsKey(user.id), false);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final strings = sheetContext.strings;
        final theme = Theme.of(sheetContext);
        final canMatch = hasMinimumDevCard(user);

        Future<void> choose(VoidCallback action) async {
          Navigator.pop(sheetContext);
          // Let the sheet close before switching tabs / opening create.
          await Future<void>.delayed(const Duration(milliseconds: 120));
          if (!mounted) return;
          action();
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const StretchCatSilhouette(width: 56, opacity: 0.55),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        strings.boardWelcomeTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  strings.boardWelcomeBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => choose(() => requestBoardTab(0)),
                  icon: const Icon(Icons.handshake_outlined),
                  label: Text(strings.boardWelcomeCtaRespond),
                ),
                const SizedBox(height: 10),
                if (canMatch)
                  FilledButton.tonalIcon(
                    onPressed: () => choose(() => requestBoardTab(2)),
                    icon: const Icon(Icons.favorite_outline),
                    label: Text(strings.boardWelcomeCtaMatch),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => choose(() => requestBoardTab(2)),
                    icon: const Icon(Icons.favorite_outline),
                    label: Text(strings.boardWelcomeCtaMatch),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => choose(() {
                    requestBoardTab(0);
                    requestBoardCreate(BoardCreateIntent.listing);
                  }),
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(strings.boardWelcomeCtaPost),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(strings.boardWelcomeAction),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    final index = _tabs.index;
    if (boardTabIndex.value != index) {
      boardTabIndex.value = index;
    }
    if (!_builtTabs.contains(index)) {
      setState(() => _builtTabs.add(index));
    }
  }

  void _onExternalTab() {
    final target = boardTabIndex.value.clamp(0, 4);
    if (!_builtTabs.contains(target)) {
      setState(() => _builtTabs.add(target));
    }
    if (_tabs.index != target) {
      _tabs.animateTo(target);
    }
  }

  @override
  void dispose() {
    boardTabIndex.removeListener(_onExternalTab);
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  Widget _lazy(int index, Widget child) {
    if (!_builtTabs.contains(index)) {
      return const SizedBox.expand();
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);

    return Column(
      children: [
        Material(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabs,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        Tab(text: strings.boardListingsTab),
                        Tab(text: strings.boardProjectsTab),
                        Tab(text: strings.boardMatchTab),
                        Tab(text: strings.boardCommunitiesTab),
                        Tab(text: strings.boardPeopleTab),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: MurkotAtmosphere(
            child: TabBarView(
              controller: _tabs,
              children: [
              _lazy(
                0,
                ListingsScreen(
                  listingsService: widget.listingsService,
                  chatService: widget.chatService,
                  blacklistService: widget.blacklistService,
                  presenceService: widget.presenceService,
                  currentUserLogin: widget.currentUserLogin,
                  settingsService: widget.settingsService,
                  authService: widget.authService,
                ),
              ),
              _lazy(
                1,
                ProjectsScreen(
                  projectsService: widget.projectsService,
                  chatService: widget.chatService,
                  blacklistService: widget.blacklistService,
                  presenceService: widget.presenceService,
                  currentUserLogin: widget.currentUserLogin,
                  settingsService: widget.settingsService,
                ),
              ),
              _lazy(
                2,
                MatchScreen(
                  matchService: widget.matchService,
                  chatService: widget.chatService,
                  blacklistService: widget.blacklistService,
                  presenceService: widget.presenceService,
                  currentUserLogin: widget.currentUserLogin,
                  settingsService: widget.settingsService,
                  authService: widget.authService,
                ),
              ),
              _lazy(
                3,
                CommunitiesScreen(
                  chatService: widget.chatService,
                  blacklistService: widget.blacklistService,
                  presenceService: widget.presenceService,
                  currentUserLogin: widget.currentUserLogin,
                  settingsService: widget.settingsService,
                ),
              ),
              _lazy(
                4,
                PeopleScreen(
                  peopleService: widget.peopleService,
                  chatService: widget.chatService,
                  blacklistService: widget.blacklistService,
                  presenceService: widget.presenceService,
                  currentUserLogin: widget.currentUserLogin,
                  settingsService: widget.settingsService,
                ),
              ),
            ],
            ),
          ),
        ),
      ],
    );
  }
}
