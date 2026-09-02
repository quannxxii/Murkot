import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../models/match_candidate.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/match_service.dart';
import '../services/presence_service.dart';
import '../services/settings_service.dart';
import '../utils/board_tab_bus.dart';
import '../utils/main_tab_bus.dart';
import '../widgets/airdrop_contact_sheet.dart';
import '../widgets/avatar_display.dart';
import '../widgets/dev_card.dart';
import '../widgets/dev_status_badge.dart';
import '../widgets/guest_gate.dart';
import '../widgets/murkot_decor.dart';
import '../widgets/unlumen/murkot_fx.dart';
import 'chat_screen.dart';
import 'onboarding_screen.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({
    super.key,
    required this.matchService,
    required this.chatService,
    required this.blacklistService,
    required this.presenceService,
    required this.currentUserLogin,
    required this.settingsService,
    required this.authService,
  });

  final MatchService matchService;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final PresenceService presenceService;
  final String currentUserLogin;
  final SettingsService settingsService;
  final AuthService authService;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  bool _showMatches = false;

  @override
  void initState() {
    super.initState();
    widget.blacklistService.addListener(_onBlacklistChanged);
    _loadFeed();
    if (!widget.settingsService.isGuest) {
      widget.matchService.refreshMatches();
      widget.matchService.refreshLiked();
    }
  }

  @override
  void dispose() {
    widget.blacklistService.removeListener(_onBlacklistChanged);
    super.dispose();
  }

  void _onBlacklistChanged() {
    unawaited(widget.matchService
        .skipBlockedLogins(widget.blacklistService.blockedUsers));
  }

  Future<void> _loadFeed() async {
    await widget.matchService.refreshFeed();
    await widget.matchService
        .skipBlockedLogins(widget.blacklistService.blockedUsers);
  }

  Future<void> _openChat(
    MatchCandidate candidate, {
    bool alreadyConfirmed = false,
  }) async {
    if (!await ensureRegistered(context, settings: widget.settingsService)) {
      return;
    }
    final strings = context.strings;
    final opener = strings.matchChatOpener(
      peerLogin: candidate.user.login,
      sharedSkills: candidate.sharedSkills,
      peerSkills: candidate.user.skills.take(3).toList(),
    );
    var messageToSend = opener;
    if (!alreadyConfirmed) {
      final edited = await showAirdropContactSheet(
        context: context,
        recipient: candidate.preview,
        subjectTitle: strings.matchItsAMatch,
        previewText: opener,
      );
      if (edited == null || !mounted) return;
      messageToSend = edited;
    }

    try {
      final conversation =
          await widget.chatService.openDirectChat(candidate.preview);
      await widget.chatService.ensureMessagesLoaded(conversation.id);
      final hasText = widget.chatService
          .getMessages(conversation.id)
          .any((m) => m.type == MessageType.text);
      if (!hasText) {
        await widget.chatService.sendMessage(
          conversationId: conversation.id,
          type: MessageType.text,
          content: messageToSend,
        );
      }
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ChatScreen(
            conversation: conversation,
            chatService: widget.chatService,
            blacklistService: widget.blacklistService,
            presenceService: widget.presenceService,
            currentUserLogin: widget.currentUserLogin,
            settingsService: widget.settingsService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.openChatFailed)),
      );
    }
  }

  Future<void> _showMatchDialog(MatchCandidate candidate) async {
    final strings = context.strings;
    final body = candidate.sharedSkills > 0
        ? strings.matchItsAMatchBodyWithSkills(candidate.sharedSkills)
        : strings.matchItsAMatchBody;
    final openChat = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.matchItsAMatch),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarDisplay(
              name: candidate.user.login,
              avatarPath: candidate.user.avatarPath,
              avatarEmoji: candidate.user.avatarEmoji,
              radius: 36,
            ),
            const SizedBox(height: 12),
            Text(
              candidate.user.login,
              style: Theme.of(dialogContext)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.matchKeepSwiping),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.matchOpenChat),
          ),
        ],
      ),
    );
    if (openChat == true && mounted) {
      await _openChat(candidate, alreadyConfirmed: true);
    }
  }

  MatchCandidate? get _visibleCandidate {
    for (final item in widget.matchService.feed) {
      if (!widget.blacklistService.isBlocked(item.user.login)) {
        return item;
      }
    }
    return null;
  }

  Future<void> _swipe(bool liked) async {
    if (!await ensureRegistered(context, settings: widget.settingsService)) {
      return;
    }
    final strings = context.strings;
    final candidate = _visibleCandidate;
    if (candidate == null) return;

    try {
      final isMatch = await widget.matchService.swipe(
        candidate: candidate,
        liked: liked,
      );
      if (!mounted) return;
      if (isMatch == true) {
        await _showMatchDialog(candidate);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.matchSwipeFailed}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final service = widget.matchService;
    final me = widget.authService.currentUser;
    final isGuest = widget.settingsService.isGuest;

    if (!isGuest && (me == null || !hasMinimumDevCard(me))) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.badge_outlined,
                  size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                strings.matchNeedCardTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                strings.matchNeedCardBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => mainTabIndex.value = MainTabs.profile,
                child: Text(strings.matchNeedCardAction),
              ),
            ],
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([service, widget.blacklistService]),
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(strings.matchFeedTitle),
                          icon: const Icon(Icons.style_outlined, size: 18),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(
                            service.matches.isEmpty
                                ? strings.matchMatchesTitle
                                : '${strings.matchMatchesTitle} (${service.matches.length})',
                          ),
                          icon: const Icon(Icons.favorite_outline, size: 18),
                        ),
                      ],
                      selected: {_showMatches},
                      onSelectionChanged: (value) {
                        setState(() => _showMatches = value.first);
                        if (value.first) {
                          service.refreshMatches();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (!_showMatches)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  strings.matchHint,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            Expanded(
              child: _showMatches
                  ? _MatchesList(
                      service: service,
                      blacklistService: widget.blacklistService,
                      onOpenChat: _openChat,
                      onRetry: service.refreshMatches,
                      onBackToFeed: () => setState(() => _showMatches = false),
                    )
                  : _FeedPane(
                      service: service,
                      candidate: _visibleCandidate,
                      onLike: () => _swipe(true),
                      onPass: () => _swipe(false),
                      onRetry: _loadFeed,
                      onRestart: () => service.restartUnmatchedFeed(),
                      onOpenListings: () {
                        mainTabIndex.value = MainTabs.board;
                        requestBoardTab(0);
                      },
                      onOpenProfile: () {
                        mainTabIndex.value = MainTabs.profile;
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FeedPane extends StatelessWidget {
  const _FeedPane({
    required this.service,
    required this.candidate,
    required this.onLike,
    required this.onPass,
    required this.onRetry,
    required this.onRestart,
    required this.onOpenListings,
    required this.onOpenProfile,
  });

  final MatchService service;
  final MatchCandidate? candidate;
  final VoidCallback onLike;
  final VoidCallback onPass;
  final Future<void> Function() onRetry;
  final Future<void> Function() onRestart;
  final VoidCallback onOpenListings;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);

    if (service.feedError != null) {
      return _ErrorState(text: strings.matchLoadFailed, onRetry: onRetry);
    }
    if (service.isLoadingFeed && service.feed.isEmpty) {
      return const Center(child: MurkotLoader(size: 40));
    }

    final shown = candidate;
    if (shown == null) {
      return RefreshIndicator(
        onRefresh: onRetry,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: _EmptyState(
                text: strings.matchEmptyFeed,
                primaryLabel: strings.matchRestartFeed,
                onPrimary: () {
                  onRestart();
                },
                secondaryLabel: strings.matchEmptyFeedListings,
                onSecondary: onOpenListings,
                tertiaryLabel: strings.matchEmptyFeedProfile,
                onTertiary: onOpenProfile,
                hint: strings.matchRestartFeedHint,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRetry,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _MatchCard(candidate: shown),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: service.isSwiping ? null : onPass,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                    icon: const Icon(Icons.close),
                    label: Text(strings.matchPass),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: service.isSwiping ? null : onLike,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    icon: service.isSwiping
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.favorite),
                    label: Text(strings.matchLike),
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

class _MatchesList extends StatelessWidget {
  const _MatchesList({
    required this.service,
    required this.blacklistService,
    required this.onOpenChat,
    required this.onRetry,
    required this.onBackToFeed,
  });

  final MatchService service;
  final BlacklistService blacklistService;
  final ValueChanged<MatchCandidate> onOpenChat;
  final Future<void> Function() onRetry;
  final VoidCallback onBackToFeed;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final matches = service.matches
        .where((m) => !blacklistService.isBlocked(m.user.login))
        .toList();

    if (service.matchesError != null) {
      return _ErrorState(text: strings.matchLoadFailed, onRetry: onRetry);
    }
    if (service.isLoadingMatches && matches.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (matches.isEmpty && service.likedMe.isEmpty && service.iLiked.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRetry,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: _EmptyState(
                text: strings.matchEmptyMatches,
                primaryLabel: strings.matchEmptyMatchesAction,
                onPrimary: onBackToFeed,
              ),
            ),
          ],
        ),
      );
    }

    Widget likedSection(String title, List<MatchCandidate> list) {
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final u = list[i].user;
                return GestureDetector(
                  onTap: () => onOpenChat(list[i]),
                  child: Column(
                    children: [
                      AvatarDisplay(name: u.login, avatarPath: u.avatarPath, avatarEmoji: u.avatarEmoji, radius: 28),
                      const SizedBox(height: 4),
                      SizedBox(width: 64, child: Text(u.login, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await onRetry();
        await service.refreshLiked();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: [
          likedSection(strings.isRu ? 'Тебя лайкнули' : 'Liked you', service.likedMe),
          likedSection(strings.isRu ? 'Ты лайкнул' : 'You liked', service.iLiked),
          if (matches.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
              child: Text(strings.matchMatchesTitle, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            for (var index = 0; index < matches.length; index++) ...[
              Builder(builder: (context) {
                final match = matches[index];
                final user = match.user;
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    leading: AvatarDisplay(name: user.login, avatarPath: user.avatarPath, avatarEmoji: user.avatarEmoji, radius: 24),
                    title: Text(user.login, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([if (user.devStatus != DevStatus.none) availabilityLabel(strings, user.devStatus), if (user.skills.isNotEmpty) user.skills.take(3).join(' · ')].where((s) => s.isNotEmpty).join('\n'), maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: FilledButton.tonal(onPressed: () => onOpenChat(match), child: Text(strings.matchOpenChat)),
                  ),
                );
              }),
              if (index != matches.length - 1) const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.candidate});

  final MatchCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final user = candidate.user;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: AvatarDisplay(
                name: user.login,
                avatarPath: user.avatarPath,
                avatarEmoji: user.avatarEmoji,
                radius: 48,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                user.login,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (user.status.isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  user.status,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            ],
            if (user.devStatus != DevStatus.none) ...[
              const SizedBox(height: 16),
              Center(
                child: DevStatusBadge(status: user.devStatus, large: true),
              ),
            ],
            if (user.experienceLevel != null ||
                (user.city?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (user.experienceLevel != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.military_tech_outlined,
                            size: 16, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          experienceLevelLabel(strings, user.experienceLevel!),
                        ),
                      ],
                    ),
                  if (user.city?.isNotEmpty ?? false)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.place_outlined,
                            size: 16, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(user.city!),
                      ],
                    ),
                ],
              ),
            ],
            if (user.skills.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final skill in user.skills)
                    Chip(
                      label: Text(skill),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
            if (candidate.sharedSkills > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.handshake_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${strings.matchSharedSkills}: ${candidate.sharedSkills}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            if ((user.githubUrl?.isNotEmpty ?? false) ||
                (user.portfolioUrl?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (user.githubUrl?.isNotEmpty ?? false)
                    ActionChip(
                      avatar: const Icon(Icons.code, size: 16),
                      label: Text(strings.githubLabel),
                      onPressed: () => _openLink(user.githubUrl!),
                    ),
                  if (user.portfolioUrl?.isNotEmpty ?? false)
                    ActionChip(
                      avatar: const Icon(Icons.link, size: 16),
                      label: Text(strings.portfolioLabel),
                      onPressed: () => _openLink(user.portfolioUrl!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    var target = url.trim();
    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      target = 'https://$target';
    }
    final uri = Uri.tryParse(target);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.text,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.tertiaryLabel,
    this.onTertiary,
    this.hint,
  });

  final String text;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? tertiaryLabel;
  final VoidCallback? onTertiary;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StretchCatSilhouette(width: 160, opacity: 0.32),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
            if (primaryLabel != null && onPrimary != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onPrimary,
                child: Text(primaryLabel!),
              ),
            ],
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
            ],
            if (tertiaryLabel != null && onTertiary != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onTertiary,
                child: Text(tertiaryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.text, required this.onRetry});

  final String text;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(strings.retry)),
        ],
      ),
    );
  }
}
