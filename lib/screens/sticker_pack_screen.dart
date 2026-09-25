import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/brand_theme.dart';
import '../l10n/app_strings.dart';
import '../services/settings_service.dart';
import '../services/sticker_pack_service.dart';
import '../utils/sticker_pack_link.dart';
import '../widgets/guest_gate.dart';

/// Page opened from `/s/<name>`, like Telegram's add-stickers link.
class StickerPackScreen extends StatefulWidget {
  const StickerPackScreen({
    super.key,
    required this.shortName,
    required this.settingsService,
  });

  final String shortName;
  final SettingsService settingsService;

  @override
  State<StickerPackScreen> createState() => _StickerPackScreenState();
}

class _StickerPackScreenState extends State<StickerPackScreen> {
  StickerPackPreview? _pack;
  bool _loading = true;
  bool _missingSql = false;
  bool _adding = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _missingSql = false;
    });
    try {
      final pack = await StickerPackService().preview(widget.shortName);
      if (!mounted) return;
      setState(() {
        _pack = pack;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
        _missingSql = e.toString().contains('get_sticker_pack') ||
            e.toString().contains('PGRST202');
      });
    }
  }

  Future<void> _add() async {
    final pack = _pack;
    if (pack == null || _adding || pack.isOwner || pack.isInstalled) return;
    if (widget.settingsService.isGuest) {
      pendingStickerPack.value = pack.shortName;
      await ensureRegistered(
        context,
        settings: widget.settingsService,
      );
      return;
    }
    setState(() => _adding = true);
    final strings = context.strings;
    try {
      await StickerPackService().install(pack.shortName);
      if (!mounted) return;
      setState(() {
        _pack = pack.copyWith(isInstalled: true);
        _adding = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.stickerPackInstalled)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _adding = false);
      final missing = e.toString().contains('install_sticker_pack') ||
          e.toString().contains('PGRST202');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            missing
                ? '${strings.stickerPackInstallFailed}. SQL: features_v31.sql'
                : strings.stickerPackInstallFailed,
          ),
        ),
      );
    }
  }

  Future<void> _copyLink(String shortName) async {
    await Clipboard.setData(
      ClipboardData(text: buildPublicStickerPackUrl(shortName)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.stickerPackLinkCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final pack = _pack;
    return Scaffold(
      appBar: AppBar(
        title: Text(pack?.title ?? strings.addStickers),
        actions: [
          if (pack != null)
            IconButton(
              tooltip: strings.shareStickerPack,
              onPressed: () => _copyLink(pack.shortName),
              icon: const Icon(Icons.link_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : pack == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _missingSql
                          ? '${strings.stickerPackNotFound}. SQL: features_v31.sql и features_v32.sql'
                          : _error == null
                              ? strings.stickerPackNotFound
                              : '${strings.stickerPackNotFound}: $_error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Column(
                        children: [
                          Text(
                            pack.shortName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: MurkotColors.orange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            strings.stickerPackCount(pack.stickers.length),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                        itemCount: pack.stickers.length,
                        itemBuilder: (context, index) {
                          final sticker = pack.stickers[index];
                          return Image.network(
                            sticker.imageUrl ?? '',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: FilledButton(
                          onPressed: pack.isOwner || pack.isInstalled || _adding
                              ? null
                              : _add,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            backgroundColor: MurkotColors.orange,
                            disabledBackgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                          child: _adding
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  pack.isOwner || pack.isInstalled
                                      ? strings.stickerPackAlreadyAdded
                                      : strings.addStickers,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
