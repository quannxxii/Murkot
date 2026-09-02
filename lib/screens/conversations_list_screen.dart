import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/presence_service.dart';
import '../services/settings_service.dart';
import '../utils/invite_deep_link.dart';
import '../widgets/avatar_display.dart';
import '../widgets/confirm_dialogs.dart';
import '../widgets/conversation_list_tile.dart';
import '../widgets/murkot_action_pills.dart';
import '../widgets/murkot_decor.dart';
import '../widgets/section_search_bar.dart';
import '../widgets/unlumen/murkot_fx.dart';
import 'chat_screen.dart';
import 'conversation_search_sheet.dart';
import 'stranger_profile_screen.dart';
import 'user_search_sheet.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({
    super.key,
    required this.type,
    required this.chatService,
    required this.blacklistService,
    required this.presenceService,
    required this.currentUserLogin,
    required this.settingsService,
  });

  final ConversationType type;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final PresenceService presenceService;
  final String currentUserLogin;
  final SettingsService settingsService;

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  Timer? _messageSearchDebounce;
  List<MessageSearchHit> _messageHits = const [];
  bool _searchingMessages = false;

  @override
  void dispose() {
    _messageSearchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _messageSearchDebounce?.cancel();
    _messageSearchDebounce = Timer(
      const Duration(milliseconds: 350),
      _runMessageSearch,
    );
  }

  Future<void> _runMessageSearch() async {
    final q = _query.trim();
    if (q.length < 2) {
      if (mounted) {
        setState(() {
          _messageHits = const [];
          _searchingMessages = false;
        });
      }
      return;
    }

    setState(() => _searchingMessages = true);
    try {
      final hits =
          await widget.chatService.searchMessagesGlobal(q, widget.type);
      if (!mounted || _query.trim() != q) return;
      setState(() {
        _messageHits = hits;
        _searchingMessages = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searchingMessages = false);
    }
  }

  Future<void> _findPublic() async {
    final strings = context.strings;
    final preview = await showConversationSearchSheet(
      context: context,
      chatService: widget.chatService,
      type: widget.type,
    );
    if (preview == null || !mounted) return;

    try {
      final conversation =
          await widget.chatService.joinConversation(preview.id);
      if (!mounted) return;
      if (conversation != null) {
        _openChat(conversation);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.openChatFailed}: $e')),
      );
    }
  }

  Future<void> _redeemInvite() async {
    final strings = context.strings;
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.inviteRedeem),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: strings.inviteRedeemHint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(strings.inviteRedeem),
          ),
        ],
      ),
    );
    if (token == null || token.isEmpty || !mounted) return;
    final normalized = normalizeInviteInput(token);
    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.inviteRedeemFailed)),
      );
      return;
    }
    try {
      final conversation =
          await widget.chatService.redeemConversationInvite(normalized);
      if (!mounted) return;
      if (conversation != null) _openChat(conversation);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.inviteRedeemFailed)),
      );
    }
  }

  int get _sectionIndex => switch (widget.type) {
        ConversationType.direct => 0,
        ConversationType.group => 1,
        ConversationType.channel => 2,
      };

  Future<void> _createNew() async {
    final strings = context.strings;

    if (widget.type == ConversationType.direct) {
      final user = await showUserSearchSheet(
        context: context,
        chatService: widget.chatService,
      );
      if (user == null || !mounted) return;

      try {
        final conversation = await widget.chatService.openDirectChat(user);
        if (!mounted) return;
        _openChat(conversation);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${strings.openChatFailed}: $e')),
        );
      }
      return;
    }

    final name = await showTextInputDialog(
      context: context,
      title: createDialogTitleForSection(strings, _sectionIndex),
      hint: createDialogHintForSection(strings, _sectionIndex),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return strings.nameRequired;
        }
        return null;
      },
    );

    if (name == null || !mounted) return;

    try {
      final conversation = await widget.chatService.createConversation(
        type: widget.type,
        name: name.trim(),
      );
      if (!mounted) return;
      _openChat(conversation);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.openChatFailed}: $e')),
      );
    }
  }

  void _openChat(Conversation conversation, {String? initialMessageId}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChatScreen(
          conversation: conversation,
          chatService: widget.chatService,
          blacklistService: widget.blacklistService,
          presenceService: widget.presenceService,
          currentUserLogin: widget.currentUserLogin,
          settingsService: widget.settingsService,
          initialMessageId: initialMessageId,
        ),
      ),
    );
  }

  void _openProfile(Conversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StrangerProfileScreen(
          conversation: conversation,
          chatService: widget.chatService,
          blacklistService: widget.blacklistService,
          currentUserLogin: widget.currentUserLogin,
          settingsService: widget.settingsService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.chatService,
        widget.blacklistService,
        widget.presenceService,
      ]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final conversations = widget.chatService.searchConversations(
          widget.type,
          _query,
        );

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SectionSearchBar(
                    controller: _searchController,
                    hint: searchHintForSection(strings, _sectionIndex),
                    onChanged: _onQueryChanged,
                  ),
                ),
              ],
            ),
            if (_searchingMessages) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Single section mark — watermark when list has items.
                  if (conversations.isNotEmpty || _messageHits.isNotEmpty)
                    IgnorePointer(
                      child: MurkotSectionMark(
                        type: widget.type,
                        width: 280,
                        opacity: 0.28,
                      ),
                    ),
                  if (conversations.isEmpty && _messageHits.isEmpty)
                    MurkotEmptyHero(
                      type: widget.type,
                      width: 280,
                      caption: strings.emptyList,
                    )
                  else
                    ListView(
                      children: [
                        for (var i = 0; i < conversations.length; i++) ...[
                          Builder(builder: (context) {
                            final conversation = conversations[i];
                            final online = conversation.type ==
                                    ConversationType.direct
                                ? widget.presenceService
                                    .isOnline(conversation.name)
                                : false;
                            return MurkotVelocityHighlight(
                              child: ConversationListTile(
                              conversation: conversation,
                              isOnline: online,
                              onTapBody: () => _openChat(conversation),
                              onTapAvatar: () => _openProfile(conversation),
                            ),
                            );
                          }),
                          if (i < conversations.length - 1)
                            Divider(
                              height: 1,
                              indent: 72,
                              color: theme.dividerColor.withValues(alpha: 0.35),
                            ),
                        ],
                        if (_query.trim().length >= 2 &&
                            _messageHits.isNotEmpty) ...[
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(
                              strings.foundMessages,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          ..._messageHits.map(
                            (hit) => ListTile(
                              leading: AvatarDisplay(
                                name: hit.conversation.name,
                                avatarPath: hit.conversation.avatarPath,
                                avatarEmoji: conversationAvatarEmoji(
                                  hit.conversation,
                                ),
                                radius: 22,
                              ),
                              title: Text(
                                hit.conversation.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${hit.message.senderName}: '
                                '${messagePreviewText(hit.message, maxChars: 64)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _openChat(
                                hit.conversation,
                                initialMessageId: hit.message.id,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            MurkotActionPillsRow(
              pills: [
                if (widget.type != ConversationType.direct)
                  MurkotActionPill(
                    icon: Icons.vpn_key_outlined,
                    label: strings.inviteRedeem,
                    onPressed: _redeemInvite,
                  ),
                if (widget.type != ConversationType.direct)
                  MurkotActionPill(
                    icon: Icons.search,
                    label: widget.type == ConversationType.channel
                        ? strings.findChannel
                        : strings.findGroup,
                    onPressed: _findPublic,
                  ),
                MurkotActionPill(
                  icon: Icons.add,
                  label: createLabelForSection(strings, _sectionIndex),
                  onPressed: _createNew,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
