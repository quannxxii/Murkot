import 'dart:async';

import 'package:flutter/material.dart';

import '../data/emoji_categories.dart';
import '../data/sticker_packs.dart';
import '../l10n/app_strings.dart';
import '../services/chat_service.dart';
import '../services/gif_service.dart';

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
      final strings = context.strings;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.84,
        minChildSize: 0.48,
        maxChildSize: 0.96,
        builder: (context, scrollController) {
          return DefaultTabController(
            length: kStickerPacks.length,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    child: Text(
                      strings.stickerPickerTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TabBar(
                    isScrollable: true,
                    tabs: [
                      for (final pack in kStickerPacks)
                        Tab(text: pack.title(strings.isRu)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (final pack in kStickerPacks)
                          GridView.count(
                            controller: scrollController,
                            crossAxisCount: 4,
                            padding: const EdgeInsets.all(14),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.05,
                            children: [
                              for (final sticker in pack.stickers)
                                InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () {
                                    Navigator.pop(context);
                                    onPick(sticker);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Center(
                                      child: Text(
                                        sticker.glyph,
                                        style: const TextStyle(fontSize: 50),
                                      ),
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
          );
        },
      );
    },
  );
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
