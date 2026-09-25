import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/emoji_categories.dart';
import '../data/sticker_packs.dart';
import '../l10n/app_strings.dart';
import '../services/chat_service.dart';
import '../services/gif_service.dart';
import '../services/sticker_pack_service.dart';
import '../utils/sticker_image_pick.dart';
import '../utils/sticker_pack_link.dart';
import 'confirm_dialogs.dart';

Future<void> showEmojiPicker(
  BuildContext context, {
  required ValueChanged<String> onPick,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final isRu = context.strings.isRu;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.38,
        maxChildSize: 0.96,
        builder: (context, scrollController) {
          return DefaultTabController(
            length: kEmojiCategories.length,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Column(
                  children: [
                    Text(
                      context.strings.emojiPickerTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        for (final cat in kEmojiCategories)
                          Tab(text: cat.title(isRu)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TabBarView(
                        children: [
                          for (final cat in kEmojiCategories)
                            GridView.count(
                              controller: scrollController,
                              crossAxisCount: 8,
                              children: [
                                for (final emoji in cat.emojis)
                                  InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      onPick(emoji);
                                    },
                                    child: Center(
                                      child: Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 28),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> showStickerPicker(
  BuildContext context, {
  required void Function(StickerItem sticker) onPick,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.46,
        minChildSize: 0.34,
        maxChildSize: 0.72,
        builder: (context, _) {
          return _StickerPickerSheet(onPick: onPick);
        },
      );
    },
  );
}

class _StickerPickerSheet extends StatefulWidget {
  const _StickerPickerSheet({required this.onPick});

  final void Function(StickerItem sticker) onPick;

  @override
  State<_StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<_StickerPickerSheet>
    with TickerProviderStateMixin {
  bool _saving = false;

  /// File dialog must open in this tap. On the release build the browser
  /// drops the gesture if ImagePicker waits first, so the dialog never appears.
  Future<void> _createPack() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final strings = context.strings;
    final List<PickedStickerImage> files;
    try {
      files = await pickStickerImages();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${strings.stickersSaveFailed}: $e')),
      );
      return;
    }
    if (files.isEmpty) return;
    final dialogContext = mounted ? context : navigator.context;
    if (!dialogContext.mounted) return;
    final title = await showTextInputDialog(
      context: dialogContext,
      title: strings.newStickerPackTitle,
      hint: strings.newStickerPackHint,
      maxLength: 40,
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return strings.nameRequired;
        return null;
      },
    );
    if (title == null) return;
    await _saveStickers(files, title: title.trim(), messenger: messenger);
  }

  Future<void> _addToCurrent() async {
    if (_saving) return;
    final pack = _packs[_tabs.index];
    if (!pack.isOwner) return;
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.strings;
    final List<PickedStickerImage> files;
    try {
      files = await pickStickerImages();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${strings.stickersSaveFailed}: $e')),
      );
      return;
    }
    if (files.isEmpty) return;
    await _saveStickers(files, packId: pack.id, messenger: messenger);
  }

  Future<void> _sharePack(StickerPack pack) async {
    final name = pack.shortName;
    if (name == null) return;
    await Clipboard.setData(
      ClipboardData(text: buildPublicStickerPackUrl(name)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.stickerPackLinkCopied)),
    );
  }

  Future<void> _deleteSticker(StickerItem sticker) async {
    if (_saving) return;
    final strings = context.strings;
    final ok = await showConfirmDialog(
      context: context,
      title: strings.deleteSticker,
      message: strings.deleteStickerConfirm,
      confirmLabel: strings.deleteAction,
      isDestructive: true,
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await StickerPackService().deleteSticker(sticker.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.stickerDeleted)),
      );
      await _loadMine();
    } catch (e) {
      if (!mounted) return;
      _showSqlError(e, strings.stickersSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deletePack(StickerPack pack) async {
    if (_saving) return;
    final strings = context.strings;
    final ok = await showConfirmDialog(
      context: context,
      title: strings.deleteStickerPack,
      message: strings.deleteStickerPackConfirm,
      confirmLabel: strings.deleteAction,
      isDestructive: true,
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await StickerPackService().deletePack(pack.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.stickerPackDeleted)),
      );
      await _loadMine();
    } catch (e) {
      if (!mounted) return;
      _showSqlError(e, strings.stickersSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSqlError(
    Object error,
    String fallback, [
    ScaffoldMessengerState? messenger,
  ]) {
    final text = error.toString();
    final missing = text.contains('PGRST202') ||
        text.contains('delete_my_sticker') ||
        text.contains('sticker_packs') ||
        text.contains('create_my_sticker_pack') ||
        text.contains('add_my_sticker');
    final bar = messenger ?? ScaffoldMessenger.of(context);
    bar.showSnackBar(
      SnackBar(
        content: Text(
          missing ? '$fallback. SQL: features_v29.sql, features_v30.sql и features_v31.sql' : '$fallback: $error',
        ),
      ),
    );
  }

  Future<void> _saveStickers(
    List<PickedStickerImage> files, {
    String? packId,
    String? title,
    ScaffoldMessengerState? messenger,
  }) async {
    if (mounted) setState(() => _saving = true);
    final strings = mounted ? context.strings : null;
    final bar = messenger ??
        (mounted ? ScaffoldMessenger.of(context) : null);
    try {
      final service = StickerPackService();
      final id = packId ?? await service.createPack(title!);
      for (final file in files) {
        await service.addImage(
          packId: id,
          bytes: file.bytes,
          fileName: file.name,
        );
      }
      final saved = strings?.stickersSaved ?? 'Stickers added';
      bar?.showSnackBar(SnackBar(content: Text(saved)));
      if (mounted) await _loadMine(selectFirstCustom: packId == null);
    } catch (e) {
      if (strings != null && bar != null) {
        _showSqlError(e, strings.stickersSaveFailed, bar);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  late TabController _tabs;
  List<StickerPack> _packs = kStickerPacks;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _packs.length, vsync: this);
    _bindTabs(_tabs);
    stickerPacksChanged.addListener(_onPacksChanged);
    _loadMine();
  }

  void _onPacksChanged() {
    if (mounted) unawaited(_loadMine());
  }

  void _bindTabs(TabController controller) {
    controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadMine({bool selectFirstCustom = false}) async {
    try {
      final mine = await StickerPackService().loadMine();
      if (!mounted) return;
      final next = [...mine, ...kStickerPacks];
      final previous = selectFirstCustom ? 0 : _tabs.index;
      _tabs.dispose();
      _tabs = TabController(
        length: next.length,
        vsync: this,
        initialIndex: previous.clamp(0, next.length - 1),
      );
      _bindTabs(_tabs);
      setState(() => _packs = next);
    } catch (e) {
      debugPrint('sticker packs load failed: $e');
    }
  }

  @override
  void dispose() {
    stickerPacksChanged.removeListener(_onPacksChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 4, 4),
            child: _PackHeader(
              pack: _packs[_tabs.index],
              saving: _saving,
              onShare: () => _sharePack(_packs[_tabs.index]),
              onDelete: () => _deletePack(_packs[_tabs.index]),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                for (final pack in _packs)
                  GridView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: pack.stickers.length + (pack.isOwner ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (pack.isOwner && index == 0) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _saving ? null : _addToCurrent,
                          child: Icon(
                            Icons.add_rounded,
                            size: 32,
                            color: theme.colorScheme.primary,
                          ),
                        );
                      }
                      final sticker =
                          pack.stickers[index - (pack.isOwner ? 1 : 0)];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => widget.onPick(
                          pack.shortName == null
                              ? sticker
                              : StickerItem(
                                  id: sticker.id,
                                  glyph: sticker.glyph,
                                  label: sticker.label,
                                  imageUrl: sticker.imageUrl,
                                  packShortName: pack.shortName,
                                ),
                        ),
                        onLongPress: pack.isOwner && sticker.isImage
                            ? () => _deleteSticker(sticker)
                            : null,
                        child: Center(child: _StickerGlyph(sticker: sticker)),
                      );
                    },
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _packs.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _saving ? null : _createPack,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        _saving ? Icons.hourglass_top : Icons.add_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  );
                }
                final pack = _packs[index - 1];
                final selected = _tabs.index == index - 1;
                final icon = pack.stickers.isEmpty ? null : pack.stickers.first;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _tabs.index = index - 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: icon == null
                          ? Text(
                              pack.title(strings.isRu).characters.first,
                              style: const TextStyle(fontSize: 22),
                            )
                          : _PackIcon(sticker: icon),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PackHeader extends StatelessWidget {
  const _PackHeader({
    required this.pack,
    required this.saving,
    required this.onShare,
    required this.onDelete,
  });

  final StickerPack pack;
  final bool saving;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final name = pack.shortName;
    final subtitle = pack.isOwner && name != null
        ? '$name · ${strings.stickerHoldToDelete}'
        : name ?? (pack.isOwner ? strings.stickerHoldToDelete : '');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pack.title(strings.isRu),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (name != null)
          IconButton(
            tooltip: strings.shareStickerPack,
            onPressed: onShare,
            icon: const Icon(Icons.link_rounded),
          ),
        if (pack.isOwner)
          IconButton(
            tooltip: strings.deleteStickerPack,
            onPressed: saving ? null : onDelete,
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          ),
      ],
    );
  }
}

class _PackIcon extends StatelessWidget {
  const _PackIcon({required this.sticker});

  final StickerItem sticker;

  @override
  Widget build(BuildContext context) {
    if (!sticker.isImage) {
      return Text(sticker.glyph, style: const TextStyle(fontSize: 24));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        sticker.imageUrl!,
        width: 28,
        height: 28,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.sticky_note_2_outlined, size: 22),
      ),
    );
  }
}

class _StickerGlyph extends StatelessWidget {
  const _StickerGlyph({required this.sticker});

  final StickerItem sticker;

  @override
  Widget build(BuildContext context) {
    if (!sticker.isImage) {
      return Text(sticker.glyph, style: const TextStyle(fontSize: 40));
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Image.network(
        sticker.imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

Future<void> showGifPicker(
  BuildContext context, {
  required void Function(GifHit gif) onPick,
  required Future<void> Function() onUploadOwn,
  ChatService? chatService,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _GifPickerSheet(
      onPick: onPick,
      onUploadOwn: onUploadOwn,
      chatService: chatService,
    ),
  );
}

class _GifPickerSheet extends StatefulWidget {
  const _GifPickerSheet({
    required this.onPick,
    required this.onUploadOwn,
    this.chatService,
  });

  final void Function(GifHit gif) onPick;
  final Future<void> Function() onUploadOwn;
  final ChatService? chatService;

  @override
  State<_GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<_GifPickerSheet> with SingleTickerProviderStateMixin {
  final _query = TextEditingController(text: '');
  List<GifHit> _hits = const [];
  bool _loading = false;
  String? _error;
  late TabController _tabController;
  int _searchGen = 0;
  Timer? _debounce;

  List<GifHit> get _ownGifs {
    final cs = widget.chatService;
    if (cs == null) return const [];
    try {
      return cs.collectOwnGifHits();
    } catch (_) {
      return const [];
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final gen = ++_searchGen;
    final q = _query.text;
    // Instant local catalog — never blocks the UI.
    final local = searchGifsLocal(q);
    if (!mounted || gen != _searchGen) return;
    setState(() {
      _hits = local;
      _loading = true;
      _error = null;
    });
    try {
      final hits = await searchGifs(q);
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _hits = hits;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _search);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.50,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                Text(strings.gifPickerTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(strings.gifPickerHint, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: strings.isRu ? 'Поиск' : 'Search'),
                    Tab(text: strings.isRu ? 'Мои' : 'Mine'),
                  ],
                ),
                const SizedBox(height: 8),
                if (_tabController.index == 0)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _query,
                          decoration: InputDecoration(
                            hintText: strings.gifSearchHint,
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onChanged: _onQueryChanged,
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(onPressed: _search, child: const Icon(Icons.search, size: 20)),
                    ],
                  ),
                if (_tabController.index == 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await widget.onUploadOwn();
                      },
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(strings.gifUploadOwn),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Search tab — keep local hits visible while network refreshes.
                      _hits.isEmpty && _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _hits.isEmpty
                              ? Center(
                                  child: Text(
                                    _error != null
                                        ? strings.gifLoadFailed
                                        : strings.gifLoadFailed,
                                  ),
                                )
                              : Stack(
                                  children: [
                                    GridView.builder(
                                      controller: scrollController,
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 8,
                                        crossAxisSpacing: 8,
                                        childAspectRatio: 1.1,
                                      ),
                                      itemCount: _hits.length,
                                      itemBuilder: (context, index) {
                                        final hit = _hits[index];
                                        return InkWell(
                                          onTap: () {
                                            Navigator.pop(context);
                                            widget.onPick(hit);
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              hit.previewUrl,
                                              fit: BoxFit.cover,
                                              gaplessPlayback: true,
                                              cacheWidth: 400,
                                              errorBuilder: (_, __, ___) => ColoredBox(
                                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                                child: const Center(child: Icon(Icons.gif_box_outlined, size: 28)),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    if (_loading)
                                      const Positioned(
                                        top: 0,
                                        left: 0,
                                        right: 0,
                                        child: LinearProgressIndicator(minHeight: 2),
                                      ),
                                  ],
                                ),
                      // Mine tab
                      Builder(builder: (context) {
                        final own = _ownGifs;
                        if (own.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.gif_box_outlined, size: 36, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(strings.isRu ? 'Тут пока нет твоих гифок' : 'No GIFs yet',
                                    style: const TextStyle(color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(strings.isRu ? 'Отправь гифку — она появится здесь' : 'Send a GIF and it will appear here',
                                    style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          );
                        }
                        return GridView.builder(
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.1,
                          ),
                          itemCount: own.length,
                          itemBuilder: (context, index) {
                            final hit = own[index];
                            return InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                widget.onPick(hit);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  hit.previewUrl,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  cacheWidth: 400,
                                  errorBuilder: (_, __, ___) => const ColoredBox(
                                    color: Colors.black12,
                                    child: Center(child: Icon(Icons.gif_box_outlined)),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
