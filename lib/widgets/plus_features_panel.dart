import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/plus_cosmetics.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/plus_analytics_service.dart';
import '../services/billing_service.dart';
import '../widgets/avatar_display.dart';
import '../widgets/murkot_toast.dart';
import '../widgets/payment_sheet.dart';

/// Plus cosmetics controls + who viewed / saved contacts (collapsible).
class PlusFeaturesPanel extends StatefulWidget {
  const PlusFeaturesPanel({
    super.key,
    required this.authService,
    required this.billing,
    required this.user,
  });

  final AuthService authService;
  final BillingService billing;
  final User user;

  @override
  State<PlusFeaturesPanel> createState() => _PlusFeaturesPanelState();
}

class _PlusFeaturesPanelState extends State<PlusFeaturesPanel> {
  final _analytics = PlusAnalyticsService();
  List<ProfileVisitor> _views = const [];
  List<ProfileVisitor> _saves = const [];
  bool _loadingInsight = false;
  bool _openPlus = true;
  bool _openFrame = false;
  bool _openNick = false;
  bool _openViews = false;
  bool _openSaves = false;

  bool get _plus => widget.user.isPlus || widget.billing.isPlus;

  @override
  void initState() {
    super.initState();
    if (_plus) _loadInsight();
  }

  @override
  void didUpdateWidget(covariant PlusFeaturesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_plus && oldWidget.user.isPlus != widget.user.isPlus) {
      _loadInsight();
    }
  }

  Future<void> _loadInsight() async {
    setState(() => _loadingInsight = true);
    final views = await _analytics.listViews();
    final saves = await _analytics.listContactSaves();
    if (!mounted) return;
    setState(() {
      _views = views;
      _saves = saves;
      _loadingInsight = false;
    });
  }

  Future<void> _setFrame(AvatarFrameId frame) async {
    final err = await widget.authService.updateAvatarFrame(frame);
    if (!mounted) return;
    MurkotToast.show(context, err ?? (context.strings.isRu ? 'Рамка обновлена' : 'Frame updated'));
    setState(() {});
  }

  Future<void> _setNick(String? id) async {
    final err = await widget.authService.updateNickColor(id);
    if (!mounted) return;
    MurkotToast.show(
      context,
      err ?? (context.strings.isRu ? 'Цвет ника сохранён' : 'Nick color saved'),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = context.strings.isRu;
    final user = widget.authService.currentUser ?? widget.user;

    if (!_plus) {
      return Card(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Murkot Plus — 399 ₽/мес',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isRu
                    ? '• Гиф-аватар • Рамки • Цвет ника • 5 бустов/сутки • До 15 объявлений • Кто смотрел профиль'
                    : '• GIF avatar • Frames • Nick color • 5 boosts/day • 15 listings • Profile viewers',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  final ok = await showPaymentSheet(
                    context,
                    product: MurkotProduct.plusMonthly,
                    billing: widget.billing,
                  );
                  if (ok) {
                    await widget.authService.refreshPlusFromServer();
                    if (mounted) {
                      setState(() {});
                      _loadInsight();
                    }
                  }
                },
                icon: const Icon(Icons.star),
                label: Text(isRu ? 'Купить Plus' : 'Get Plus'),
              ),
            ],
          ),
        ),
      );
    }

    final untilStr = user.plusUntil != null
        ? ' · ${isRu ? 'до' : 'until'} ${user.plusUntil!.day}.${user.plusUntil!.month}'
        : '';

    return Card(
      child: ExpansionTile(
        initiallyExpanded: _openPlus,
        onExpansionChanged: (v) => setState(() => _openPlus = v),
        leading: Icon(Icons.workspace_premium, color: theme.colorScheme.primary),
        title: Text(
          'Murkot Plus$untilStr',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          isRu ? 'Рамки, цвет ника, гиф-аватар, аналитика' : 'Frames, nick color, GIF avatar, analytics',
          style: theme.textTheme.bodySmall,
        ),
        children: [
          ExpansionTile(
            initiallyExpanded: _openFrame,
            onExpansionChanged: (v) => setState(() => _openFrame = v),
            title: Text(isRu ? 'Рамка аватара' : 'Avatar frame'),
            subtitle: Text(user.avatarFrame.title(isRu)),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final frame in AvatarFrameId.values)
                      ChoiceChip(
                        avatar: Icon(frame.icon, size: 16),
                        label: Text(frame.title(isRu)),
                        selected: user.avatarFrame == frame,
                        onSelected: (_) => _setFrame(frame),
                      ),
                  ],
                ),
              ),
            ],
          ),
          ExpansionTile(
            initiallyExpanded: _openNick,
            onExpansionChanged: (v) => setState(() => _openNick = v),
            title: Text(isRu ? 'Цвет ника' : 'Nick color'),
            subtitle: Text(
              user.nickColorId == null
                  ? (isRu ? 'По умолчанию' : 'Default')
                  : (kNickColorOptions
                          .where((o) => o.id == user.nickColorId)
                          .firstOrNull
                          ?.title(isRu) ??
                      user.nickColorId!),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(isRu ? 'По умолчанию' : 'Default'),
                      selected: user.nickColorId == null,
                      onSelected: (_) => _setNick(null),
                    ),
                    for (final opt in kNickColorOptions)
                      ChoiceChip(
                        avatar: CircleAvatar(
                          backgroundColor: opt.color,
                          radius: 8,
                        ),
                        label: Text(
                          opt.title(isRu),
                          style: TextStyle(
                            color: user.nickColorId == opt.id ? opt.color : null,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        selected: user.nickColorId == opt.id,
                        onSelected: (_) => _setNick(opt.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
          ExpansionTile(
            initiallyExpanded: _openViews,
            onExpansionChanged: (v) {
              setState(() => _openViews = v);
              if (v && _views.isEmpty) _loadInsight();
            },
            leading: Icon(Icons.visibility_outlined,
                color: theme.colorScheme.primary),
            title: Text(isRu ? 'Кто смотрел профиль' : 'Profile viewers'),
            subtitle: Text(
              _loadingInsight
                  ? '…'
                  : (_views.isEmpty
                      ? (isRu ? 'Пока никто' : 'Nobody yet')
                      : '${_views.length}'),
            ),
            trailing: IconButton(
              onPressed: _loadInsight,
              icon: const Icon(Icons.refresh, size: 18),
            ),
            children: [
              if (_loadingInsight)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_views.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    isRu ? 'Пока никто не заходил' : 'No viewers yet',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                )
              else
                for (final v in _views.take(12))
                  _VisitorTile(visitor: v, isRu: isRu),
            ],
          ),
          ExpansionTile(
            initiallyExpanded: _openSaves,
            onExpansionChanged: (v) {
              setState(() => _openSaves = v);
              if (v && _saves.isEmpty) _loadInsight();
            },
            leading: Icon(Icons.bookmark_added_outlined,
                color: theme.colorScheme.primary),
            title: Text(isRu ? 'Кто сохранял контакты' : 'Contact saves'),
            subtitle: Text(
              _saves.isEmpty
                  ? (isRu ? 'Пока пусто' : 'Nothing yet')
                  : '${_saves.length}',
            ),
            children: [
              if (_saves.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    isRu ? 'Пока пусто' : 'Nothing yet',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                )
              else
                for (final v in _saves.take(12))
                  _VisitorTile(visitor: v, isRu: isRu, showSource: true),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              isRu
                  ? 'Гиф-аватар: в меню аватара выбери «Галерея» и загрузи .gif'
                  : 'GIF avatar: open avatar menu → Gallery and pick a .gif',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitorTile extends StatelessWidget {
  const _VisitorTile({
    required this.visitor,
    required this.isRu,
    this.showSource = false,
  });

  final ProfileVisitor visitor;
  final bool isRu;
  final bool showSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: AvatarDisplay(
        name: visitor.login,
        avatarPath: visitor.avatarUrl,
        avatarEmoji: visitor.avatarEmoji,
        radius: 18,
      ),
      title: Text(visitor.login),
      subtitle: Text(
        showSource && (visitor.source ?? '').isNotEmpty
            ? visitor.source!
            : _fmt(visitor.at),
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  String _fmt(DateTime at) {
    return '${at.day.toString().padLeft(2, '0')}.${at.month.toString().padLeft(2, '0')} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  }
}
