import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/settings_service.dart';
import '../utils/board_tab_bus.dart';
import '../utils/main_tab_bus.dart';
import '../screens/stranger_profile_screen.dart';
import '../screens/user_search_sheet.dart';

class CommandPaletteAction {
  const CommandPaletteAction({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.run,
    this.keywords = const [],
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final List<String> keywords;
  final Future<void> Function(BuildContext context) run;
}

Future<void> showCommandPalette({
  required BuildContext context,
  required ChatService chatService,
  BlacklistService? blacklistService,
  SettingsService? settingsService,
  String? currentUserLogin,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'command-palette',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, anim, secondary) {
      return CommandPaletteDialog(
        chatService: chatService,
        blacklistService: blacklistService,
        settingsService: settingsService,
        currentUserLogin: currentUserLogin,
      );
    },
    transitionBuilder: (context, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class CommandPaletteDialog extends StatefulWidget {
  const CommandPaletteDialog({
    super.key,
    required this.chatService,
    this.blacklistService,
    this.settingsService,
    this.currentUserLogin,
  });

  final ChatService chatService;
  final BlacklistService? blacklistService;
  final SettingsService? settingsService;
  final String? currentUserLogin;

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  int _highlight = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  List<CommandPaletteAction> _actions(AppStrings strings) {
    // Capture navigator under the dialog's parent (MainScreen) before pop.
    final navigator = Navigator.of(context, rootNavigator: true);
    final hostContext = navigator.context;

    return [
        CommandPaletteAction(
          id: 'find_people',
          label: strings.cmdFindPeople,
          subtitle: strings.cmdFindPeopleSub,
          icon: Icons.person_search_outlined,
          keywords: const ['people', 'user', 'поиск', 'люди'],
          run: (ctx) async {
            Navigator.pop(ctx);
            final user = await showUserSearchSheet(
              context: hostContext,
              chatService: widget.chatService,
            );
            if (user == null) return;
            try {
              final conversation =
                  await widget.chatService.openDirectChat(user);
              if (widget.blacklistService != null &&
                  widget.settingsService != null) {
                await navigator.push(
                  MaterialPageRoute<void>(
                    builder: (_) => StrangerProfileScreen(
                      conversation: conversation,
                      chatService: widget.chatService,
                      blacklistService: widget.blacklistService!,
                      currentUserLogin: widget.currentUserLogin ?? '',
                      settingsService: widget.settingsService,
                    ),
                  ),
                );
              }
            } catch (_) {}
          },
        ),
        CommandPaletteAction(
          id: 'new_listing',
          label: strings.cmdNewListing,
          subtitle: strings.cmdNewListingSub,
          icon: Icons.campaign_outlined,
          keywords: const ['listing', 'объявление', 'ad'],
          run: (ctx) async {
            Navigator.pop(ctx);
            // Intent first so a newly mounted ListingsScreen reads it in initState.
            requestBoardCreate(BoardCreateIntent.listing);
            mainTabIndex.value = MainTabs.board;
            requestBoardTab(0);
          },
        ),
        CommandPaletteAction(
          id: 'new_project',
          label: strings.cmdNewProject,
          subtitle: strings.cmdNewProjectSub,
          icon: Icons.folder_outlined,
          keywords: const ['project', 'проект', 'витрина'],
          run: (ctx) async {
            Navigator.pop(ctx);
            requestBoardCreate(BoardCreateIntent.project);
            mainTabIndex.value = MainTabs.board;
            requestBoardTab(1);
          },
        ),
        CommandPaletteAction(
          id: 'board_listings',
          label: strings.cmdOpenListings,
          subtitle: strings.cmdOpenBoardSub,
          icon: Icons.view_list_outlined,
          keywords: const ['board', 'доска', 'listings'],
          run: (ctx) async {
            Navigator.pop(ctx);
            mainTabIndex.value = MainTabs.board;
            requestBoardTab(0);
          },
        ),
        CommandPaletteAction(
          id: 'board_projects',
          label: strings.cmdOpenProjects,
          subtitle: strings.cmdOpenBoardSub,
          icon: Icons.grid_view_rounded,
          keywords: const ['projects', 'витрина', 'проекты'],
          run: (ctx) async {
            Navigator.pop(ctx);
            mainTabIndex.value = MainTabs.board;
            requestBoardTab(1);
          },
        ),
        CommandPaletteAction(
          id: 'board_match',
          label: strings.cmdOpenMatch,
          subtitle: strings.cmdOpenBoardSub,
          icon: Icons.favorite_outline,
          keywords: const ['match', 'мэтч', 'swipe'],
          run: (ctx) async {
            Navigator.pop(ctx);
            mainTabIndex.value = MainTabs.board;
            requestBoardTab(2);
          },
        ),
        CommandPaletteAction(
          id: 'board_communities',
          label: strings.cmdOpenCommunities,
          subtitle: strings.cmdOpenBoardSub,
          icon: Icons.groups_outlined,
          keywords: const ['communities', 'сообщества'],
          run: (ctx) async {
            Navigator.pop(ctx);
            mainTabIndex.value = MainTabs.board;
            requestBoardTab(3);
          },
        ),
        CommandPaletteAction(
          id: 'chats',
          label: strings.cmdOpenChats,
          subtitle: strings.cmdOpenChatsSub,
          icon: Icons.chat_bubble_outline,
          keywords: const ['chats', 'чаты', 'dm', 'сообщения'],
          run: (ctx) async {
            Navigator.pop(ctx);
            mainTabIndex.value = MainTabs.chats;
          },
        ),
        CommandPaletteAction(
          id: 'profile',
          label: strings.cmdOpenProfile,
          subtitle: strings.cmdOpenProfileSub,
          icon: Icons.person_outline,
          keywords: const ['profile', 'профиль', 'note', 'заметка'],
          run: (ctx) async {
            Navigator.pop(ctx);
            mainTabIndex.value = MainTabs.profile;
          },
        ),
      ];
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<CommandPaletteAction> _filtered(AppStrings strings) {
    final all = _actions(strings);
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((a) {
      final hay = [
        a.label,
        a.subtitle,
        ...a.keywords,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _runHighlighted(AppStrings strings) async {
    final items = _filtered(strings);
    if (items.isEmpty) return;
    final index = _highlight.clamp(0, items.length - 1);
    await items[index].run(context);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final items = _filtered(strings);
    if (_highlight >= items.length) _highlight = 0;

    return SafeArea(
      child: Align(
        alignment: const Alignment(0, -0.65),
        child: Material(
          color: theme.colorScheme.surface,
          elevation: 12,
          borderRadius: BorderRadius.circular(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.search, color: theme.colorScheme.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.arrowDown):
                                () => setState(() {
                                      if (items.isEmpty) return;
                                      _highlight = (_highlight + 1) % items.length;
                                    }),
                            const SingleActivator(LogicalKeyboardKey.arrowUp):
                                () => setState(() {
                                      if (items.isEmpty) return;
                                      _highlight =
                                          (_highlight - 1 + items.length) %
                                              items.length;
                                    }),
                            const SingleActivator(LogicalKeyboardKey.enter):
                                () => _runHighlighted(strings),
                            const SingleActivator(LogicalKeyboardKey.escape):
                                () => Navigator.pop(context),
                          },
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: strings.cmdPlaceholder,
                              border: InputBorder.none,
                              filled: false,
                            ),
                            onChanged: (_) => setState(() => _highlight = 0),
                            onSubmitted: (_) => _runHighlighted(strings),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: MurkotColors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          strings.cmdShortcutHint,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: MurkotColors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              strings.cmdEmpty,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final action = items[index];
                              final selected = index == _highlight;
                              return Material(
                                color: selected
                                    ? MurkotColors.orange
                                        .withValues(alpha: 0.12)
                                    : Colors.transparent,
                                child: ListTile(
                                  leading: Icon(action.icon),
                                  title: Text(
                                    action.label,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Text(action.subtitle),
                                  onTap: () => action.run(context),
                                  onFocusChange: (has) {
                                    if (has) {
                                      setState(() => _highlight = index);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
