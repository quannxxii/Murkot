import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../models/conversation.dart';
import '../models/media_payload.dart';
import '../models/message.dart';
import '../models/system_payload.dart';
import '../services/blacklist_service.dart';
import '../services/chat_service.dart';
import '../services/media_service.dart';
import '../services/presence_service.dart';
import '../services/settings_service.dart';
import '../utils/helpers.dart';
import '../utils/main_tab_bus.dart';
import '../services/voice_recorder.dart';
import '../data/sticker_packs.dart';
import '../widgets/avatar_display.dart';
import '../widgets/circle_video_player.dart';
import '../widgets/composer_pickers.dart';
import '../widgets/murkot_decor.dart';
import '../widgets/confirm_dialogs.dart';
import '../widgets/voice_message_player.dart';
import '../widgets/unlumen/murkot_fx.dart';
import 'about_murkot_screen.dart';
import 'circle_recorder_screen.dart';
import 'forward_message_sheet.dart';
import 'media_viewer_screen.dart';
import 'stranger_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversation,
    required this.chatService,
    required this.blacklistService,
    required this.presenceService,
    required this.currentUserLogin,
    required this.settingsService,
    this.initialMessageId,
    this.initialComposerText,
  });

  final Conversation conversation;
  final ChatService chatService;
  final BlacklistService blacklistService;
  final PresenceService presenceService;
  final String currentUserLogin;
  final SettingsService settingsService;

  /// If set, the chat opens scrolled to this message (search result).
  final String? initialMessageId;

  /// Prefill the composer (e.g. listing/project respond template).
  final String? initialComposerText;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messageFocusNode = FocusNode();
  final _messageKeys = <String, GlobalKey>{};

  late Conversation _conversation;
  bool _showScrollDown = false;
  bool _isTyping = false;
  bool _loadingHistory = false;
  Message? _replyTo;
  bool _searchMode = false;
  final _chatSearchController = TextEditingController();
  String _chatSearchQuery = '';
  List<Message>? _remoteSearchResults;
  bool _searchLoading = false;
  final _viewedPosts = <String>{};
  bool _recordingVoice = false;
  DateTime? _voiceStartedAt;
  Timer? _voiceTick;
  final List<_DraftAttachment> _drafts = [];
  bool _sendingDrafts = false;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    final prefill = widget.initialComposerText?.trim();
    if (prefill != null && prefill.isNotEmpty) {
      _messageController.text = prefill;
      _messageController.selection =
          TextSelection.collapsed(offset: prefill.length);
    }
    _scrollController.addListener(_onScroll);
    widget.chatService.setActiveConversation(_conversation.id);
    _bootstrapMessages();
  }

  Future<void> _bootstrapMessages() async {
    await widget.chatService.ensureMessagesLoaded(_conversation.id);
    if (!mounted) return;
    await widget.chatService.markMessagesRead(_conversation.id);

    final targetId = widget.initialMessageId;
    if (targetId != null) {
      await _revealMessage(targetId);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _messageFocusNode.requestFocus();
      _scrollToBottom(jump: true);
    });
  }

  /// Loads older pages until [messageId] is present, then scrolls to it.
  Future<void> _revealMessage(String messageId) async {
    bool isLoaded() => widget.chatService
        .getMessages(_conversation.id)
        .any((m) => m.id == messageId);

    var guard = 0;
    while (!isLoaded() &&
        widget.chatService.hasMoreMessages(_conversation.id) &&
        guard < 12) {
      await widget.chatService.loadOlderMessages(_conversation.id);
      guard++;
    }
    if (!mounted) return;

    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (isLoaded()) {
        _scrollToMessage(messageId);
      } else {
        _scrollToBottom(jump: true);
      }
    });
  }

  @override
  void dispose() {
    _voiceTick?.cancel();
    if (_recordingVoice) {
      cancelVoiceRecording();
    }
    if (_isTyping) {
      widget.chatService.setTyping(_conversation.id, false);
    }
    widget.chatService.setActiveConversation(null);
    _messageController.dispose();
    _chatSearchController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final atBottom = position.maxScrollExtent - position.pixels < 80;
    if (atBottom != !_showScrollDown) {
      setState(() => _showScrollDown = !atBottom);
    }

    if (position.pixels <= 48) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingHistory || _searchMode) return;
    if (!widget.chatService.hasMoreMessages(_conversation.id)) return;
    if (widget.chatService.isLoadingMessages(_conversation.id)) return;

    setState(() => _loadingHistory = true);
    final beforeMax = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final beforeOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    await widget.chatService.loadOlderMessages(_conversation.id);
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final afterMax = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(beforeOffset + (afterMax - beforeMax));
    });
    setState(() => _loadingHistory = false);
  }

  Future<void> _onChatSearchChanged(String value) async {
    setState(() {
      _chatSearchQuery = value;
      _searchLoading = value.trim().length >= 2;
    });
    if (value.trim().length < 2) {
      setState(() {
        _remoteSearchResults = null;
        _searchLoading = false;
      });
      return;
    }

    final results = await widget.chatService.searchMessagesRemote(
      _conversation.id,
      value,
    );
    if (!mounted || _chatSearchController.text != value) return;
    setState(() {
      _remoteSearchResults = results;
      _searchLoading = false;
    });
  }

  String _statusText(AppStrings strings) {
    final othersTyping = _conversation.typingUsers
        .where((login) => login != widget.currentUserLogin)
        .toList();
    final activity = widget.chatService.peerActivity(_conversation.id);
    final actor = widget.chatService.peerActivityLogin(_conversation.id);
    if (activity == 'circle' && actor != null) {
      return strings.recordingCircle(actor);
    }
    if (activity == 'voice' && actor != null) {
      return strings.recordingVoice(actor);
    }
    if (othersTyping.isNotEmpty) {
      if (_conversation.type == ConversationType.group) {
        return strings.typingUsers(othersTyping.join(', '));
      }
      return strings.typing;
    }

    return switch (_conversation.type) {
      ConversationType.direct => widget.presenceService.isOnline(_conversation.name)
          ? strings.online
          : formatLastSeen(
              widget.presenceService.lastSeenOf(_conversation.name) ??
                  _conversation.contactLastSeen,
              isRu: strings.isRu,
            ),
      ConversationType.group => strings.onlineCount(
          _conversation.memberIds
              .where(widget.presenceService.isOnline)
              .length,
        ),
      ConversationType.channel =>
        strings.subscriberCount(_conversation.subscriberCount),
    };
  }

  void _onTextChanged(String text) {
    final shouldType = text.isNotEmpty;
    if (shouldType != _isTyping) {
      _isTyping = shouldType;
      widget.chatService.setTyping(_conversation.id, shouldType);
    }
  }

  Future<void> _sendText() async {
    if (_drafts.isNotEmpty) {
      await _sendDrafts();
      return;
    }

    final text = _messageController.text;
    if (text.trim().isEmpty) return;

    if (!widget.chatService.canSendMessages(_conversation)) return;

    final replyId = _replyTo?.id;
    _messageController.clear();
    _onTextChanged('');
    setState(() => _replyTo = null);
    _messageFocusNode.requestFocus();

    try {
      await widget.chatService.sendMessage(
        conversationId: _conversation.id,
        type: MessageType.text,
        content: text,
        replyToId: replyId,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      // Offline queue keeps the bubble; only hard policy errors show snackbar.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (jump) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      } else {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _scrollToMessage(String messageId) async {
    // Off-screen items are not built by ListView.builder, so their GlobalKey
    // has no context yet. Jump near the estimated position first, then let
    // ensureVisible fine-tune once the item is built.
    for (var attempt = 0; attempt < 6; attempt++) {
      final ctx = _messageKeys[messageId]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
          alignment: 0.3,
        );
        return;
      }

      if (!_scrollController.hasClients) return;
      final messages = widget.chatService.getMessages(_conversation.id);
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index == -1) return;

      final fraction = messages.length <= 1 ? 0.0 : index / (messages.length - 1);
      final position = _scrollController.position;
      _scrollController.jumpTo(
        (position.maxScrollExtent * fraction)
            .clamp(0.0, position.maxScrollExtent),
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
    }
  }

  void _openImageViewer(String tappedUrl) {
    final urls = <String>[];
    for (final message in widget.chatService.getMessages(_conversation.id)) {
      if (message.isDeletedForAll) continue;
      final isImageType = message.type == MessageType.image ||
          message.type == MessageType.sticker ||
          message.type == MessageType.gif;
      if (!isImageType) continue;
      final media = MediaPayload.tryParse(message.content);
      if (media == null) continue;
      urls.addAll(media.allUrls);
    }
    if (!urls.contains(tappedUrl)) urls.add(tappedUrl);
    MediaViewerScreen.open(
      context,
      urls: urls,
      initialIndex: urls.indexOf(tappedUrl),
    );
  }

  /// Immediate media send — used only for circle videos (recorded and sent).
  Future<void> _sendMedia(MessageType type, {bool asCircle = false}) async {
    if (!widget.chatService.canSendMessages(_conversation)) return;

    final strings = context.strings;
    final picked = await _pickMedia(type, asCircle: asCircle);
    if (picked == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.mediaUploading)),
    );

    try {
      await widget.chatService.sendMediaBytes(
        conversationId: _conversation.id,
        type: type,
        bytes: picked.bytes,
        fileName: picked.name,
        contentType: picked.contentType,
        durationMs: picked.durationMs,
        isCircle: asCircle || picked.isCircle,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.mediaUploadFailed}: $e')),
      );
    }
  }

  /// Picks media/files and stages them as a draft above the composer,
  /// instead of sending right away.
  Future<void> _addDraft(MessageType type) async {
    if (!widget.chatService.canSendMessages(_conversation)) return;

    final added = <_DraftAttachment>[];

    switch (type) {
      case MessageType.image:
        final files = await ImagePicker().pickMultiImage(imageQuality: 85);
        for (final file in files) {
          added.add(_DraftAttachment(
            type: MessageType.image,
            bytes: await file.readAsBytes(),
            name: file.name,
            contentType: 'image/jpeg',
          ));
        }
      case MessageType.sticker:
        final stickerFile = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (stickerFile != null) {
          added.add(_DraftAttachment(
            type: type,
            bytes: await stickerFile.readAsBytes(),
            name: stickerFile.name,
            contentType: 'image/jpeg',
          ));
        }
      case MessageType.gif:
        final gifResult = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['gif', 'webp'],
          allowMultiple: true,
          withData: true,
        );
        // Fallback to ImagePicker if FilePicker yields nothing (e.g. iOS gallery).
        if ((gifResult == null || gifResult.files.isEmpty)) {
          final fallback = await ImagePicker().pickImage(
            source: ImageSource.gallery,
          );
          if (fallback != null) {
            added.add(_DraftAttachment(
              type: type,
              bytes: await fallback.readAsBytes(),
              name: fallback.name,
              contentType: 'image/gif',
            ));
          }
        } else {
          for (final file in gifResult.files) {
            var bytes = file.bytes;
            if (bytes == null && file.path != null) {
              bytes = await XFile(file.path!).readAsBytes();
            }
            if (bytes == null) continue;
            final isWebp = file.name.toLowerCase().endsWith('.webp');
            added.add(_DraftAttachment(
              type: type,
              bytes: bytes,
              name: file.name,
              contentType: isWebp ? 'image/webp' : 'image/gif',
            ));
          }
        }
      case MessageType.video:
        final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
        if (file != null) {
          // Large videos freeze the UI if we read them silently — show
          // progress and bail early when the file is over the upload limit.
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.strings.mediaUploading)),
          );
          try {
            final length = await file.length();
            if (length > MediaService.maxUploadBytes) {
              final mb = (length / (1024 * 1024)).toStringAsFixed(1);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.strings.videoTooLargeMb(mb)),
                ),
              );
              return;
            }
            final bytes = await file.readAsBytes();
            added.add(_DraftAttachment(
              type: MessageType.video,
              bytes: bytes,
              name: file.name,
              contentType: 'video/mp4',
            ));
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${context.strings.mediaUploadFailed}: $e'),
              ),
            );
            return;
          }
        }
      case MessageType.music:
      case MessageType.file:
        final result = await FilePicker.platform.pickFiles(
          type: type == MessageType.music ? FileType.audio : FileType.any,
          allowMultiple: true,
          withData: true,
        );
        for (final file in result?.files ?? const <PlatformFile>[]) {
          var bytes = file.bytes;
          // Some desktop platforms return only a path.
          if (bytes == null && file.path != null) {
            bytes = await XFile(file.path!).readAsBytes();
          }
          if (bytes == null) continue;
          added.add(_DraftAttachment(
            type: type,
            bytes: bytes,
            name: file.name,
            contentType: type == MessageType.music
                ? 'audio/mpeg'
                : 'application/octet-stream',
          ));
        }
      case MessageType.text:
      case MessageType.emoji:
      case MessageType.voice:
      case MessageType.system:
        return;
    }

    if (added.isEmpty || !mounted) return;
    setState(() => _drafts.addAll(added));
    _messageFocusNode.requestFocus();
  }

  /// Uploads drafted attachments: photos are grouped up to 10 per message,
  /// the composer text becomes the caption of the first message.
  Future<void> _sendDrafts() async {
    if (_sendingDrafts || _drafts.isEmpty) return;
    if (!widget.chatService.canSendMessages(_conversation)) return;

    final strings = context.strings;
    final caption = _messageController.text.trim();
    final drafts = List<_DraftAttachment>.of(_drafts);
    _messageController.clear();
    _onTextChanged('');
    setState(() {
      _drafts.clear();
      _sendingDrafts = true;
    });
    _messageFocusNode.requestFocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.mediaUploading)),
    );

    try {
      String? captionLeft = caption.isEmpty ? null : caption;

      final images =
          drafts.where((d) => d.type == MessageType.image).toList();
      final others =
          drafts.where((d) => d.type != MessageType.image).toList();

      for (var i = 0; i < images.length; i += 10) {
        final chunk =
            images.sublist(i, math.min(i + 10, images.length));
        await widget.chatService.sendImageAlbum(
          conversationId: _conversation.id,
          images: [
            for (final d in chunk)
              (bytes: d.bytes, name: d.name, contentType: d.contentType),
          ],
          caption: captionLeft,
        );
        captionLeft = null;
      }

      for (final d in others) {
        await widget.chatService.sendMediaBytes(
          conversationId: _conversation.id,
          type: d.type,
          bytes: d.bytes,
          fileName: d.name,
          contentType: d.contentType,
          caption: captionLeft,
        );
        captionLeft = null;
      }

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${strings.mediaUploadFailed}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingDrafts = false);
    }
  }

  Future<void> _startVoiceNote() async {
    if (!widget.chatService.canSendMessages(_conversation) || _recordingVoice) {
      return;
    }
    final ok = await startVoiceRecording();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.micDenied)),
      );
      return;
    }
    unawaited(
      widget.chatService.setComposerActivity(_conversation.id, 'voice'),
    );
    setState(() {
      _recordingVoice = true;
      _voiceStartedAt = DateTime.now();
    });
    _voiceTick?.cancel();
    _voiceTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _stopVoiceNote({required bool send}) async {
    if (!_recordingVoice) return;
    _voiceTick?.cancel();
    _voiceTick = null;
    setState(() => _recordingVoice = false);
    unawaited(widget.chatService.setComposerActivity(_conversation.id, null));
    if (!send) {
      await cancelVoiceRecording();
      _voiceStartedAt = null;
      return;
    }

    final recording = await stopVoiceRecording();
    _voiceStartedAt = null;
    if (recording == null || recording.bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.voiceRecordFailed)),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.mediaUploading)),
    );
    try {
      await widget.chatService.sendMediaBytes(
        conversationId: _conversation.id,
        type: MessageType.voice,
        bytes: recording.bytes,
        fileName: recording.fileName,
        contentType: recording.mimeType,
        durationMs: recording.durationMs,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strings.mediaUploadFailed}: $e')),
      );
    }
  }

  Future<void> _sendCircleVideo() async {
    if (!widget.chatService.canSendMessages(_conversation)) return;
    unawaited(
      widget.chatService.setComposerActivity(_conversation.id, 'circle'),
    );
    try {
      final recorded = await recordCircleVideo(context);
      if (recorded == null) return;
      await widget.chatService.sendMediaBytes(
        conversationId: _conversation.id,
        type: MessageType.video,
        bytes: recorded.bytes,
        fileName: recorded.name,
        contentType: 'video/mp4',
        isCircle: true,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.strings.mediaUploadFailed}: $e')),
      );
    } finally {
      unawaited(widget.chatService.setComposerActivity(_conversation.id, null));
    }
  }

  Future<_PickedMedia?> _pickMedia(
    MessageType type, {
    bool asCircle = false,
  }) async {
    switch (type) {
      case MessageType.image:
      case MessageType.sticker:
      case MessageType.gif:
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );
        if (file == null) return null;
        return _PickedMedia(
          bytes: await file.readAsBytes(),
          name: file.name,
          contentType: 'image/jpeg',
        );
      case MessageType.video:
        final file = await ImagePicker().pickVideo(
          source: asCircle ? ImageSource.camera : ImageSource.gallery,
          maxDuration: asCircle ? const Duration(seconds: 60) : null,
        );
        if (file == null) return null;
        final length = await file.length();
        if (length > MediaService.maxUploadBytes) {
          throw StateError(
            context.strings.videoTooLargeMb(
              (length / (1024 * 1024)).toStringAsFixed(1),
            ),
          );
        }
        return _PickedMedia(
          bytes: await file.readAsBytes(),
          name: file.name,
          contentType: 'video/mp4',
          isCircle: asCircle,
        );
      case MessageType.voice:
      case MessageType.music:
        final result = await FilePicker.platform.pickFiles(
          type: FileType.audio,
          withData: true,
        );
        final file = result?.files.single;
        if (file?.bytes == null) return null;
        return _PickedMedia(
          bytes: file!.bytes!,
          name: file.name,
          contentType: 'audio/mpeg',
        );
      case MessageType.file:
        final result = await FilePicker.platform.pickFiles(withData: true);
        final file = result?.files.single;
        if (file?.bytes == null) return null;
        return _PickedMedia(
          bytes: file!.bytes!,
          name: file.name,
          contentType: 'application/octet-stream',
        );
      case MessageType.text:
      case MessageType.emoji:
      case MessageType.system:
        return null;
    }
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StrangerProfileScreen(
          conversation: _conversation,
          chatService: widget.chatService,
          blacklistService: widget.blacklistService,
          currentUserLogin: widget.currentUserLogin,
          settingsService: widget.settingsService,
        ),
      ),
    );
  }

  Future<void> _openUserProfile(String login) async {
    final trimmed = login.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.toLowerCase() == widget.currentUserLogin.toLowerCase()) {
      // Own profile lives on the main Profile tab.
      mainTabIndex.value = MainTabs.profile;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return;
    }

    try {
      // Prefer an already-loaded DM whose display name is the peer.
      final existing = widget.chatService
          .getConversations(ConversationType.direct)
          .where((c) => c.name.toLowerCase() == trimmed.toLowerCase())
          .firstOrNull;

      Conversation conversation;
      if (existing != null) {
        conversation = existing;
      } else {
        final users = await widget.chatService.searchUsers(trimmed);
        final exact = users.where(
          (u) => u.login.toLowerCase() == trimmed.toLowerCase(),
        );
        if (exact.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.strings.userNotFound(trimmed))),
          );
          return;
        }
        conversation = await widget.chatService.openDirectChat(exact.first);
      }
      if (!mounted) return;
      await Navigator.of(context).push(
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.openProfileFailed(e))),
      );
    }
  }

  Future<void> _runMessageAction(String action, Message message) async {
    final strings = context.strings;
    switch (action) {
      case 'reply':
        setState(() => _replyTo = message);
        _messageFocusNode.requestFocus();
      case 'forward':
        await showForwardMessageSheet(
          context: context,
          chatService: widget.chatService,
          message: message,
        );
      case 'edit':
        final newText = await showTextInputDialog(
          context: context,
          title: strings.editMessage,
          hint: strings.messageHint,
          initialValue: message.content,
          validator: (v) =>
              v == null || v.trim().isEmpty ? strings.nameRequired : null,
        );
        if (newText != null) {
          await widget.chatService.editMessage(
              _conversation.id, message.id, newText);
        }
      case 'delete_me':
        await widget.chatService.deleteMessage(
            _conversation.id, message.id, forEveryone: false);
      case 'delete_all':
        final confirmed = await showConfirmDialog(
          context: context,
          title: strings.deleteForAll,
          message: strings.deleteForAllConfirm,
        );
        if (confirmed == true) {
          await widget.chatService.deleteMessage(
              _conversation.id, message.id, forEveryone: true);
        }
      case 'pin_me':
        await widget.chatService.pinMessage(
            _conversation.id, message.id, forEveryone: false);
      case 'pin_all':
        await widget.chatService.pinMessage(
            _conversation.id, message.id, forEveryone: true);
      case 'react':
        await _showReactionPicker(message);
    }
  }

  void _showOrbitActions(Message message, Offset pressGlobal) {
    final key = _messageKeys.putIfAbsent(message.id, GlobalKey.new);
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            MurkotOrbitActions(
              actions: _orbitActionsFor(message),
              pressGlobal: pressGlobal,
              anchorKey: key,
              onDismiss: () => entry.remove(),
            ),
          ],
        );
      },
    );
    overlay.insert(entry);
  }

  List<OrbitAction> _orbitActionsFor(Message message) {
    final strings = context.strings;
    final isOwn = message.senderId == widget.currentUserLogin;
    final isChannel = _conversation.type == ConversationType.channel;
    final isSystem = message.type == MessageType.system;
    final actions = <OrbitAction>[];

    if (!isSystem && !isChannel) {
      actions.add(OrbitAction(
        icon: Icons.reply,
        label: strings.reply,
        onTap: () => _runMessageAction('reply', message),
      ));
    }
    if (!isSystem) {
      actions.add(OrbitAction(
        icon: Icons.forward,
        label: strings.forward,
        onTap: () => _runMessageAction('forward', message),
      ));
      actions.add(OrbitAction(
        icon: Icons.add_reaction_outlined,
        label: strings.addReaction,
        onTap: () => _runMessageAction('react', message),
      ));
      actions.add(OrbitAction(
        icon: Icons.push_pin_outlined,
        label: strings.pinForMe,
        onTap: () => _runMessageAction('pin_me', message),
      ));
    }
    if (!isSystem && (isOwn || _conversation.isAdmin)) {
      actions.add(OrbitAction(
        icon: Icons.push_pin,
        label: strings.pinForAll,
        onTap: () => _runMessageAction('pin_all', message),
      ));
    }
    if (!isSystem && isOwn && !isChannel) {
      actions.add(OrbitAction(
        icon: Icons.edit_outlined,
        label: strings.editMessage,
        onTap: () => _runMessageAction('edit', message),
      ));
      actions.add(OrbitAction(
        icon: Icons.delete_outline,
        label: strings.deleteForMe,
        onTap: () => _runMessageAction('delete_me', message),
        isDestructive: true,
      ));
    }
    return actions;
  }

  Future<void> _showMessageActions(Message message) async {
    final strings = context.strings;
    final isOwn = message.senderId == widget.currentUserLogin;
    final isChannel = _conversation.type == ConversationType.channel;
    final isSystem = message.type == MessageType.system;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSystem && !isChannel)
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: Text(strings.reply),
                  onTap: () => Navigator.pop(context, 'reply'),
                ),
              if (!isSystem)
                ListTile(
                  leading: const Icon(Icons.forward),
                  title: Text(strings.forward),
                  onTap: () => Navigator.pop(context, 'forward'),
                ),
              if (!isSystem && isOwn && !isChannel) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(strings.editMessage),
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(strings.deleteForMe),
                  onTap: () => Navigator.pop(context, 'delete_me'),
                ),
                ListTile(
                  leading: Icon(Icons.delete_forever,
                      color: Theme.of(context).colorScheme.error),
                  title: Text(strings.deleteForAll,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                  onTap: () => Navigator.pop(context, 'delete_all'),
                ),
              ],
              if (!isSystem) ...[
                ListTile(
                  leading: const Icon(Icons.push_pin_outlined),
                  title: Text(strings.pinForMe),
                  onTap: () => Navigator.pop(context, 'pin_me'),
                ),
                if (isOwn || _conversation.isAdmin)
                  ListTile(
                    leading: const Icon(Icons.push_pin),
                    title: Text(strings.pinForAll),
                    onTap: () => Navigator.pop(context, 'pin_all'),
                  ),
              ],
              ListTile(
                leading: const Icon(Icons.add_reaction_outlined),
                title: Text(strings.addReaction),
                onTap: () => Navigator.pop(context, 'react'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;
    await _runMessageAction(action, message);
  }

  Future<void> _showReactionPicker(Message message) async {
    const emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: emojis
                .map((e) => IconButton(
                      iconSize: 32,
                      onPressed: () => Navigator.pop(context, e),
                      icon: Text(e, style: const TextStyle(fontSize: 28)),
                    ))
                .toList(),
          ),
        ),
      ),
    );
    if (emoji != null) {
      await widget.chatService.toggleReaction(
          _conversation.id, message.id, emoji);
    }
  }

  Future<void> _showComments(Message post) async {
    final strings = context.strings;
    var visibleCount = 10;
    final commentController = TextEditingController();
    final commentFocus = FocusNode();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        // Autofocus once the sheet is on screen.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (commentFocus.canRequestFocus) commentFocus.requestFocus();
        });

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submitComment() async {
              final text = commentController.text.trim();
              if (text.isEmpty) return;
              commentController.clear();
              await widget.chatService.addComment(
                postMessageId: post.id,
                conversationId: _conversation.id,
                content: text,
              );
              // Keep the caret in the field so the next comment is immediate.
              commentFocus.requestFocus();
            }

            return ListenableBuilder(
              listenable: widget.chatService,
              builder: (context, _) {
                final comments = widget.chatService.getComments(post.id);
                final shown = comments.take(visibleCount).toList();

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.55,
                    minChildSize: 0.3,
                    maxChildSize: 0.9,
                    builder: (context, scrollController) {
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(strings.comments,
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                          ),
                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              itemCount: shown.length +
                                  (comments.length > visibleCount ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == shown.length) {
                                  return TextButton(
                                    onPressed: () => setSheetState(
                                        () => visibleCount += 10),
                                    child: Text(strings.showMore),
                                  );
                                }
                                final c = shown[index];
                                return ListTile(
                                  leading: GestureDetector(
                                    onTap: () =>
                                        _openUserProfile(c.senderName),
                                    child: AvatarDisplay(
                                      name: c.senderName,
                                      avatarPath: widget.chatService
                                          .avatarUrlForLogin(c.senderName),
                                      avatarEmoji: c.senderEmoji,
                                      radius: 18,
                                    ),
                                  ),
                                  title: GestureDetector(
                                    onTap: () =>
                                        _openUserProfile(c.senderName),
                                    child: Text(
                                      c.senderName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  subtitle: Text(c.content),
                                );
                              },
                            ),
                          ),
                          if (widget.chatService
                              .canSendMessages(_conversation))
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: commentController,
                                      focusNode: commentFocus,
                                      autofocus: true,
                                      textInputAction: TextInputAction.send,
                                      decoration: InputDecoration(
                                        hintText: strings.commentHint,
                                      ),
                                      onSubmitted: (_) => submitComment(),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.send),
                                    onPressed: submitComment,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );

    commentController.dispose();
    commentFocus.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final canSend = widget.chatService.canSendMessages(_conversation);
    final isChannel = _conversation.type == ConversationType.channel;

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.chatService,
        widget.blacklistService,
        widget.presenceService,
      ]),
      builder: (context, _) {
        final updated = widget.chatService.getConversation(_conversation.id);
        if (updated != null) _conversation = updated;

        // Wide (desktop) layout: nav rail 25% | chat 50% | attachments 25%;
        // all bubbles are left-aligned in the same format as peer messages.
        final isWide = MediaQuery.of(context).size.width >= 720;

        final messages = _searchMode && _chatSearchQuery.isNotEmpty
            ? (_remoteSearchResults ??
                widget.chatService.searchMessages(
                  _conversation.id,
                  _chatSearchQuery,
                ))
            : widget.chatService.getMessages(_conversation.id);
        final pinned = widget.chatService.getPinnedMessages(_conversation.id);
        final isBlocked =
            widget.chatService.isDirectBlocked(_conversation);
        final isOnlineDirect = _conversation.type == ConversationType.direct &&
            widget.presenceService.isOnline(_conversation.name);

        return Scaffold(
          appBar: AppBar(
            leading: const MurkotBackButton(),
            titleSpacing: 0,
            title: _searchMode
                ? TextField(
                    controller: _chatSearchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: strings.searchInChatHint,
                      border: InputBorder.none,
                    ),
                    onChanged: _onChatSearchChanged,
                  )
                : InkWell(
                    onTap: _openProfile,
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            AvatarDisplay(
                              name: _conversation.name,
                              avatarPath: _conversation.avatarPath,
                              avatarEmoji:
                                  conversationAvatarEmoji(_conversation),
                              radius: 28,
                              fontSize: 20,
                            ),
                            if (isOnlineDirect)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.surface,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _conversation.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Builder(builder: (context) {
                                final status = _statusText(strings);
                                final typing = _conversation.typingUsers.any(
                                  (l) => l != widget.currentUserLogin,
                                );
                                if (typing) {
                                  return MurkotShimmerText(
                                    status,
                                    style: theme.textTheme.bodySmall,
                                  );
                                }
                                return Text(
                                  status,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isOnlineDirect
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            actions: [
              MurkotFloatingTooltip(
                message: strings.searchInChat,
                child: IconButton(
                  tooltip: '',
                  icon: Icon(_searchMode ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      _searchMode = !_searchMode;
                      if (!_searchMode) {
                        _chatSearchController.clear();
                        _chatSearchQuery = '';
                        _remoteSearchResults = null;
                      }
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Center(
                  child: MurkotThemeSwitch(
                    settings: widget.settingsService,
                  ),
                ),
              ),
            ],
          ),
          body: _DesktopChatLayout(
            isWide: isWide,
            navRail: isWide ? _buildDesktopNavRail(context) : null,
            sidePanel: isWide
                ? _buildDesktopSidePanel(
                    context,
                    canSend: canSend && !isBlocked,
                  )
                : null,
            child: Stack(
            children: [
              Column(
                children: [
                  if (pinned.isNotEmpty)
                    _PinnedBar(
                      pinned: pinned,
                      onJump: _revealMessage,
                    ),
                  if (_loadingHistory ||
                      _searchLoading ||
                      widget.chatService.isLoadingMessages(_conversation.id))
                    const LinearProgressIndicator(minHeight: 2),
                  Expanded(
                    child: messages.isEmpty
                        ? Center(
                            child: widget.chatService
                                    .isLoadingMessages(_conversation.id)
                                ? const MurkotLoader(size: 40)
                                : Text(
                                    _searchMode && _chatSearchQuery.isNotEmpty
                                        ? strings.noSearchResults
                                        : strings.noMessages,
                                    style:
                                        TextStyle(color: Colors.grey.shade600),
                                  ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            itemCount: messages.length +
                                (widget.chatService
                                        .hasMoreMessages(_conversation.id) &&
                                    !_searchMode
                                    ? 1
                                    : 0),
                            itemBuilder: (context, index) {
                              if (!_searchMode &&
                                  widget.chatService
                                      .hasMoreMessages(_conversation.id) &&
                                  index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Center(
                                    child: TextButton(
                                      onPressed: _loadOlder,
                                      child: Text(strings.loadOlderMessages),
                                    ),
                                  ),
                                );
                              }

                              final messageIndex = !_searchMode &&
                                      widget.chatService.hasMoreMessages(
                                          _conversation.id)
                                  ? index - 1
                                  : index;
                              final message = messages[messageIndex];
                              final prev = messageIndex > 0
                                  ? messages[messageIndex - 1]
                                  : null;
                              final showDate = prev == null ||
                                  !_sameDay(prev.timestamp, message.timestamp);

                              _messageKeys.putIfAbsent(
                                  message.id, () => GlobalKey());

                              if (isChannel && _viewedPosts.add(message.id)) {
                                widget.chatService.incrementViews(
                                    _conversation.id, message.id);
                              }

                              if (message.type == MessageType.system) {
                                return Column(
                                  key: _messageKeys[message.id],
                                  children: [
                                    if (showDate)
                                      _DateSeparator(date: message.timestamp),
                                    _SystemNotice(
                                      message: message,
                                      onLongPress: (pos) =>
                                          _showOrbitActions(message, pos),
                                      onReactionTap: () =>
                                          _showReactionPicker(message),
                                      onActorTap: _openUserProfile,
                                      onMessageTap: (id) =>
                                          unawaited(_revealMessage(id)),
                                    ),
                                  ],
                                );
                              }

                              return Column(
                                key: _messageKeys[message.id],
                                children: [
                                  if (showDate)
                                    _DateSeparator(date: message.timestamp),
                                  _MessageBubble(
                                    message: message,
                                    isOwn: message.senderId ==
                                        widget.currentUserLogin,
                                    forceLeft: isWide,
                                    senderAvatarUrl: widget.chatService
                                        .avatarUrlForLogin(message.senderId),
                                    showSender: isWide ||
                                        _conversation.type !=
                                            ConversationType.direct ||
                                        message.senderId !=
                                            widget.currentUserLogin,
                                    isChannel: isChannel,
                                    commentCount: widget.chatService
                                        .getComments(message.id)
                                        .length,
                                    onLongPress: (pos) =>
                                        _showOrbitActions(message, pos),
                                    onSenderTap: () => unawaited(
                                          _openUserProfile(message.senderName),
                                        ),
                                    onImageTap: _openImageViewer,
                                    onReactionTap: () =>
                                        _showReactionPicker(message),
                                    onCommentsTap: isChannel
                                        ? () => _showComments(message)
                                        : null,
                                    onRetry: message.sendStatus ==
                                            MessageSendStatus.failed
                                        ? () => widget.chatService
                                            .retryFailedMessage(message.id)
                                        : null,
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  if (isBlocked)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: theme.colorScheme.errorContainer,
                      child: Text(
                        strings.userBlockedBanner,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    )
                  else if (canSend) ...[
                    if (_drafts.isNotEmpty)
                      Material(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: SizedBox(
                            height: 72,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _drafts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) => _DraftChip(
                                draft: _drafts[index],
                                onRemove: _sendingDrafts
                                    ? null
                                    : () => setState(
                                        () => _drafts.removeAt(index)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_replyTo != null)
                      Material(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.reply,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(
                            '${strings.replyTo} ${_replyTo!.senderName}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            messagePreviewText(_replyTo!, maxChars: 48),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _replyTo = null),
                          ),
                        ),
                      ),
                    if (_recordingVoice)
                      Material(
                        color: theme.colorScheme.errorContainer,
                        child: ListTile(
                          leading: Icon(
                            Icons.mic,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(
                            '${strings.recording} ${_voiceElapsed()}',
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MurkotFloatingTooltip(
                                message: strings.cancel,
                                child: IconButton(
                                  tooltip: '',
                                  onPressed: () =>
                                      _stopVoiceNote(send: false),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                              MurkotFloatingTooltip(
                                message: strings.send,
                                child: IconButton(
                                  tooltip: '',
                                  onPressed: () =>
                                      _stopVoiceNote(send: true),
                                  icon: Icon(
                                    Icons.send,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      _MessageInputBar(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        onChanged: _onTextChanged,
                        onSend: _sendText,
                        onAttach: _showAttachMenu,
                        onCircle: _sendCircleVideo,
                        onVoiceStart: _startVoiceNote,
                        hintText: _drafts.isNotEmpty
                            ? strings.captionHint
                            : null,
                        forceSendButton: _drafts.isNotEmpty,
                      ),
                  ] else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Text(
                        strings.channelReadOnly,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                ],
              ),
              if (_showScrollDown)
                Positioned(
                  right: 16,
                  bottom: canSend && !isBlocked ? 80 : 16,
                  child: FloatingActionButton.small(
                    onPressed: () => _scrollToBottom(),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ),
            ],
            ),
          ),
        );
      },
    );
  }

  /// Desktop-only vertical navigation (board / messenger filters / profile).
  Widget _buildDesktopNavRail(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final selectedFilter = switch (_conversation.type) {
      ConversationType.direct => 0,
      ConversationType.group => 1,
      ConversationType.channel => 2,
    };

    void goBoard() {
      mainTabIndex.value = MainTabs.board;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    void goMessenger(ConversationType type) {
      messengerFilter.value = type;
      mainTabIndex.value = MainTabs.chats;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    void goProfile() {
      mainTabIndex.value = MainTabs.profile;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RailSeparatedBlock(
            onTap: goBoard,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.grid_view_rounded,
                    color: theme.colorScheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.listingsTab,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          _RailItem(
            icon: Icons.chat_bubble_outline,
            selectedIcon: Icons.chat_bubble,
            label: strings.chats,
            isSelected: selectedFilter == 0,
            onTap: () => goMessenger(ConversationType.direct),
          ),
          _RailItem(
            icon: Icons.group_outlined,
            selectedIcon: Icons.group,
            label: strings.groups,
            isSelected: selectedFilter == 1,
            onTap: () => goMessenger(ConversationType.group),
          ),
          _RailItem(
            icon: Icons.campaign_outlined,
            selectedIcon: Icons.campaign,
            label: strings.channels,
            isSelected: selectedFilter == 2,
            onTap: () => goMessenger(ConversationType.channel),
          ),
          _RailSeparatedBlock(
            onTap: goProfile,
            child: Row(
              children: [
                AvatarDisplay(
                  name: widget.currentUserLogin,
                  avatarPath: widget.chatService
                      .avatarUrlForLogin(widget.currentUserLogin),
                  avatarEmoji: widget.chatService
                      .emojiForLogin(widget.currentUserLogin),
                  radius: 26,
                  fontSize: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.profile,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        widget.currentUserLogin,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AboutMurkotScreen(
                        settingsService: widget.settingsService,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MurkotSectionMark(
                        type: _conversation.type,
                        width: 168,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.aboutUs,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Desktop-only attachments panel (replaces the popup attach menu).
  Widget _buildDesktopSidePanel(BuildContext context, {required bool canSend}) {
    final strings = context.strings;
    final theme = Theme.of(context);

    if (!canSend) {
      return ColoredBox(
        color: theme.colorScheme.surface,
        child: const Center(
          child: MurkotStackedMark(size: 200),
        ),
      );
    }

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.attachPanelExpress,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.attachPanelExpressHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 1,
              mainAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: [
                _SidePanelTile(
                  icon: Icons.emoji_emotions_outlined,
                  label: strings.composerEmoji,
                  onTap: _openEmojiPicker,
                ),
                _SidePanelTile(
                  icon: Icons.auto_awesome,
                  label: strings.composerStickers,
                  onTap: _openStickerPicker,
                ),
                _SidePanelTile(
                  icon: Icons.gif_box_outlined,
                  label: strings.composerGifs,
                  onTap: _openGifPicker,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _voiceElapsed() {
    final started = _voiceStartedAt;
    if (started == null) return '0:00';
    final sec = DateTime.now().difference(started).inSeconds;
    final m = sec ~/ 60;
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _openEmojiPicker() async {
    await showEmojiPicker(
      context,
      onPick: (emoji) {
        final text = _messageController.text;
        final selection = _messageController.selection;
        final start = selection.isValid ? selection.start : text.length;
        final end = selection.isValid ? selection.end : text.length;
        final next = text.replaceRange(start, end, emoji);
        _messageController.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: start + emoji.length),
        );
        _onTextChanged(next);
      },
    );
  }

  Future<void> _openStickerPicker() async {
    await showStickerPicker(
      context,
      onPick: (sticker) => _sendSticker(sticker),
    );
  }

  Future<void> _sendSticker(StickerItem sticker) async {
    if (!widget.chatService.canSendMessages(_conversation)) return;
    try {
      await widget.chatService.sendMessage(
        conversationId: _conversation.id,
        type: MessageType.sticker,
        content: sticker.glyph,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openGifPicker() async {
    await showGifPicker(
      context,
      onPick: (gif) async {
        if (!widget.chatService.canSendMessages(_conversation)) return;
        try {
          await widget.chatService.sendMessage(
            conversationId: _conversation.id,
            type: MessageType.gif,
            content: MediaPayload(url: gif.url, name: gif.name).encode(),
          );
          _scrollToBottom();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      },
      onUploadOwn: () => _addDraft(MessageType.gif),
      chatService: widget.chatService,
    );
  }

  Future<void> _showAttachMenu() async {
    final strings = context.strings;
    final type = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            _AttachTile(icon: Icons.image, label: strings.image, type: MessageType.image),
            _AttachTile(icon: Icons.videocam, label: strings.video, type: MessageType.video),
            _AttachActionTile(
              icon: Icons.motion_photos_on_outlined,
              label: strings.circleVideo,
              onTap: () => Navigator.pop(context, 'circle'),
            ),
            _AttachActionTile(
              icon: Icons.emoji_emotions_outlined,
              label: strings.composerEmoji,
              onTap: () => Navigator.pop(context, 'emoji'),
            ),
            _AttachActionTile(
              icon: Icons.auto_awesome_outlined,
              label: strings.composerStickers,
              onTap: () => Navigator.pop(context, 'sticker'),
            ),
            _AttachActionTile(
              icon: Icons.gif_box_outlined,
              label: strings.composerGifs,
              onTap: () => Navigator.pop(context, 'gif'),
            ),
            _AttachTile(icon: Icons.mic, label: strings.voice, type: MessageType.voice),
            _AttachTile(icon: Icons.music_note, label: strings.music, type: MessageType.music),
            _AttachTile(icon: Icons.attach_file, label: strings.file, type: MessageType.file),
          ],
        ),
      ),
    );
    if (type == 'circle') {
      await _sendCircleVideo();
    } else if (type == 'emoji') {
      await _openEmojiPicker();
    } else if (type == 'sticker') {
      await _openStickerPicker();
    } else if (type == 'gif') {
      await _openGifPicker();
    } else if (type == MessageType.voice) {
      await _startVoiceNote();
    } else if (type is MessageType) {
      await _addDraft(type);
    }
  }
}

/// Wide screens: nav rail (25%) | chat (50%) | attachments panel (25%).
/// Narrow screens: the chat fills everything.
class _DesktopChatLayout extends StatelessWidget {
  const _DesktopChatLayout({
    required this.isWide,
    required this.child,
    this.navRail,
    this.sidePanel,
  });

  final bool isWide;
  final Widget child;
  final Widget? navRail;
  final Widget? sidePanel;

  @override
  Widget build(BuildContext context) {
    if (!isWide) return child;

    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor.withValues(alpha: 0.4);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 9, child: navRail ?? const SizedBox.shrink()),
        Container(width: 1, color: dividerColor),
        Expanded(flex: 24, child: child),
        Container(width: 1, color: dividerColor),
        Expanded(flex: 9, child: sidePanel ?? const SizedBox.shrink()),
      ],
    );
  }
}

/// Vertical navigation item for the desktop rail.
class _RailSeparatedBlock extends StatelessWidget {
  const _RailSeparatedBlock({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: Colors.grey.shade300),
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: child,
            ),
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade300),
      ],
    );
  }
}

/// Vertical navigation item for the desktop rail.
class _RailItem extends StatelessWidget {
  const _RailItem({
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
    final color =
        isSelected ? theme.colorScheme.primary : Colors.grey.shade700;

    return Material(
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(isSelected ? selectedIcon : icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Attachment shortcut tile in the desktop side panel.
class _SidePanelTile extends StatelessWidget {
  const _SidePanelTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _pinnedPreview(Message msg, AppStrings strings) {
  if (msg.isDeletedForAll) return strings.messageDeleted;
  if (msg.type == MessageType.system) {
    return SystemPayload.tryParse(msg.content)?.text ?? msg.content;
  }
  if (msg.type == MessageType.text) {
    return msg.content;
  }
  final media = MediaPayload.tryParse(msg.content);
  return media?.name ?? messageTypeLabel(msg.type);
}

/// Compact pinned-messages bar: one row with the current pin and its
/// index ("Закреплённое сообщение 2 из 5"), an arrow expands the full list.
class _PinnedBar extends StatefulWidget {
  const _PinnedBar({required this.pinned, required this.onJump});

  final List<Message> pinned;
  final ValueChanged<String> onJump;

  @override
  State<_PinnedBar> createState() => _PinnedBarState();
}

class _PinnedBarState extends State<_PinnedBar> {
  bool _expanded = false;
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pinned = widget.pinned;
    final index = _current.clamp(0, pinned.length - 1);
    final message = pinned[index];

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              widget.onJump(message.id);
              // Cycle to the next pin, like in Telegram.
              setState(() => _current = (index + 1) % pinned.length);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.push_pin,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.strings.pinnedMessageOf(
                            index + 1,
                            pinned.length,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          truncateChatPreview(
                            _pinnedPreview(message, context.strings),
                            maxChars: 64,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: pinned.length,
                itemBuilder: (context, i) {
                  final msg = pinned[i];
                  return InkWell(
                    onTap: () {
                      widget.onJump(msg.id);
                      setState(() {
                        _current = i;
                        _expanded = false;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 26),
                          Text(
                            '${i + 1}. ',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _pinnedPreview(msg, context.strings),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
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

/// Even grid for photo albums: 2×2 for four photos, up to 3 per row
/// otherwise — no dangling gaps in the corner.
class _AlbumGrid extends StatelessWidget {
  const _AlbumGrid({required this.urls, this.onImageTap});

  final List<String> urls;
  final ValueChanged<String>? onImageTap;

  @override
  Widget build(BuildContext context) {
    const totalWidth = 256.0;
    const spacing = 4.0;
    final columns = switch (urls.length) {
      2 || 4 => 2,
      3 => 3,
      _ => 3,
    };
    final cell = (totalWidth - spacing * (columns - 1)) / columns;

    return SizedBox(
      width: totalWidth,
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final url in urls)
            GestureDetector(
              onTap: onImageTap == null ? null : () => onImageTap!(url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  width: cell,
                  height: cell,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => SizedBox(
                    width: cell,
                    height: cell,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SystemNotice extends StatelessWidget {
  const _SystemNotice({
    required this.message,
    required this.onLongPress,
    required this.onReactionTap,
    required this.onActorTap,
    required this.onMessageTap,
  });

  final Message message;
  final ValueChanged<Offset> onLongPress;
  final VoidCallback onReactionTap;
  final ValueChanged<String> onActorTap;
  final ValueChanged<String> onMessageTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload =
        SystemPayload.tryParse(message.content) ??
        SystemPayload(text: message.content);
    final style = TextStyle(fontSize: 12, color: Colors.grey.shade700);
    final linkStyle = style.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w700,
    );

    final spans = <InlineSpan>[];
    var remaining = payload.text;

    void consumeLogin(String? login) {
      if (login == null || login.isEmpty) return;
      final index = remaining.indexOf(login);
      if (index < 0) return;
      if (index > 0) {
        spans.add(TextSpan(text: remaining.substring(0, index), style: style));
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => onActorTap(login),
            child: Text(login, style: linkStyle),
          ),
        ),
      );
      remaining = remaining.substring(index + login.length);
    }

    // Highlight actor, then target login if present.
    consumeLogin(payload.actorLogin);
    if (payload.targetLogin != null &&
        payload.targetLogin != payload.actorLogin) {
      consumeLogin(payload.targetLogin);
    }
    if (remaining.isNotEmpty) {
      spans.add(TextSpan(text: remaining, style: style));
    }

    if (payload.targetMessageId != null &&
        (payload.targetPreview?.isNotEmpty ?? false)) {
      spans.add(const TextSpan(text: ': '));
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => onMessageTap(payload.targetMessageId!),
            child: Text(
              '«${truncateChatPreview(payload.targetPreview, maxChars: 36)}»',
              style: linkStyle.copyWith(
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Center(
            child: GestureDetector(
              onLongPressStart: (d) => onLongPress(d.globalPosition),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text.rich(
                  TextSpan(children: spans),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          if (message.reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: GestureDetector(
                onTap: onReactionTap,
                onLongPressStart: (d) => onLongPress(d.globalPosition),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    message.reactions.values.toSet().join(' '),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            formatDateSeparator(date),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.showSender,
    required this.isChannel,
    required this.commentCount,
    required this.onLongPress,
    required this.onReactionTap,
    this.onCommentsTap,
    this.onRetry,
    this.onImageTap,
    this.onSenderTap,
    this.forceLeft = false,
    this.senderAvatarUrl,
  });

  final Message message;
  final bool isOwn;
  final bool showSender;
  final bool isChannel;
  final int commentCount;
  final ValueChanged<Offset> onLongPress;
  final VoidCallback onReactionTap;
  final VoidCallback? onCommentsTap;
  final VoidCallback? onRetry;
  final ValueChanged<String>? onImageTap;
  final VoidCallback? onSenderTap;

  /// Desktop mode: align every bubble to the left regardless of sender.
  final bool forceLeft;
  final String? senderAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignRight = isOwn && !forceLeft;
    // Desktop: own messages use the same format as the peer's, with avatar
    // and sender name on the left.
    final showAvatar = showSender && (!isOwn || forceLeft);

    if (message.isDeletedForAll) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(context.strings.messageDeleted,
              style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
        ),
      );
    }

    final media = MediaPayload.tryParse(message.content);
    final isImageType = message.type == MessageType.image ||
        message.type == MessageType.sticker ||
        message.type == MessageType.gif;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPressStart: (d) => onLongPress(d.globalPosition),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showAvatar) ...[
                GestureDetector(
                  onTap: onSenderTap,
                  child: AvatarDisplay(
                    name: message.senderName,
                    avatarPath: senderAvatarUrl,
                    avatarEmoji: message.senderEmoji,
                    radius: 14,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(
                      MediaQuery.of(context).size.width * 0.72,
                      440,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: alignRight
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (showAvatar)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2, left: 4),
                          child: GestureDetector(
                            onTap: onSenderTap,
                            child: Text(message.senderName,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                )),
                          ),
                        ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: media != null && isImageType ? 6 : 14,
                          vertical: media != null && isImageType ? 6 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: isOwn
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(alignRight ? 16 : 4),
                            bottomRight: Radius.circular(alignRight ? 4 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.replyToId != null) ...[
                              Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 280),
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: (isOwn
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.primary)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border(
                                    left: BorderSide(
                                      color: isOwn
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.primary,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.replyToSender ?? '',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: isOwn
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.primary,
                                      ),
                                    ),
                                    Text(
                                      truncateChatPreview(
                                        message.replyToContent,
                                        maxChars: 48,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                        color: isOwn
                                            ? theme.colorScheme.onPrimary
                                                .withValues(alpha: 0.9)
                                            : theme.colorScheme.onSurface
                                                .withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (media != null &&
                                message.type == MessageType.voice)
                              VoiceMessagePlayer(
                                url: media.url,
                                durationMs: media.durationMs,
                                foreground: isOwn
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                              )
                            else if (media != null &&
                                message.type == MessageType.video &&
                                media.isCircle)
                              CircleVideoPlayer(url: media.url, size: 200)
                            else if (media != null &&
                                isImageType &&
                                media.album.length > 1)
                              _AlbumGrid(
                                urls: media.album,
                                onImageTap: onImageTap,
                              )
                            else if (media != null && isImageType)
                              GestureDetector(
                                onTap: onImageTap == null
                                    ? null
                                    : () => onImageTap!(media.url),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    media.url,
                                    width: 220,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Text(
                                      media.name,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: isOwn
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else if (media != null)
                              InkWell(
                                onTap: () => launchUrl(
                                  Uri.parse(media.url),
                                  mode: LaunchMode.externalApplication,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      message.type == MessageType.video
                                          ? Icons.videocam_outlined
                                          : Icons.insert_drive_file_outlined,
                                      size: 20,
                                      color: isOwn
                                          ? theme.colorScheme.onPrimary
                                          : theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        media.name,
                                        style:
                                            theme.textTheme.bodyMedium?.copyWith(
                                          color: isOwn
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.onSurface,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (message.type == MessageType.sticker)
                              Text(
                                message.content,
                                style: const TextStyle(fontSize: 56),
                              )
                            else
                              Text(
                                message.type == MessageType.text
                                    ? message.content
                                    : messageTypeLabel(message.type),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isOwn
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            if (media != null &&
                                (media.caption?.isNotEmpty ?? false))
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  media.caption!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isOwn
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (message.isEdited)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Text(context.strings.editedShort,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: isOwn
                                              ? theme.colorScheme.onPrimary
                                                  .withOpacity(0.7)
                                              : Colors.grey.shade600,
                                          fontSize: 10,
                                        )),
                                  ),
                                Text(
                                  formatMessageTime(message.timestamp),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isOwn
                                        ? theme.colorScheme.onPrimary
                                            .withOpacity(0.7)
                                        : Colors.grey.shade600,
                                    fontSize: 10,
                                  ),
                                ),
                                if (isOwn) ...[
                                  const SizedBox(width: 4),
                                  if (message.sendStatus ==
                                      MessageSendStatus.sending)
                                    Icon(
                                      Icons.schedule,
                                      size: 14,
                                      color: theme.colorScheme.onPrimary
                                          .withOpacity(0.7),
                                    )
                                  else if (message.sendStatus ==
                                      MessageSendStatus.failed)
                                    GestureDetector(
                                      onTap: onRetry,
                                      child: Icon(
                                        Icons.error_outline,
                                        size: 14,
                                        color: Colors.orange.shade200,
                                      ),
                                    )
                                  else
                                    Icon(
                                      message.isRead
                                          ? Icons.done_all
                                          : Icons.done,
                                      size: 14,
                                      color: message.isRead
                                          ? Colors.lightBlueAccent
                                          : theme.colorScheme.onPrimary
                                              .withOpacity(0.7),
                                    ),
                                ],
                                if (isChannel) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.visibility,
                                      size: 12,
                                      color: isOwn
                                          ? theme.colorScheme.onPrimary
                                              .withOpacity(0.7)
                                          : Colors.grey.shade600),
                                  const SizedBox(width: 2),
                                  Text('${message.viewCount}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontSize: 10,
                                        color: isOwn
                                            ? theme.colorScheme.onPrimary
                                                .withOpacity(0.7)
                                            : Colors.grey.shade600,
                                      )),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (message.reactions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: GestureDetector(
                            onTap: onReactionTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                message.reactions.values.toSet().join(' '),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      if (isChannel && onCommentsTap != null)
                        InkWell(
                          onTap: onCommentsTap,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4, left: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 14, color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Text('$commentCount',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.primary)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  const _MessageInputBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSend,
    required this.onVoiceStart,
    this.onAttach,
    this.onCircle,
    this.hintText,
    this.forceSendButton = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final VoidCallback? onCircle;
  final VoidCallback onVoiceStart;
  final String? hintText;

  /// Show the send button even with empty text (drafted attachments).
  final bool forceSendButton;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty || forceSendButton;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (onAttach != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      child: Material(
                        color: Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onAttach,
                          child: const SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(Icons.add, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter) {
                          final isShift =
                              HardwareKeyboard.instance.isShiftPressed;
                          if (!isShift) {
                            onSend();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: onChanged,
                        maxLines: 6,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: hintText ?? context.strings.messageHint,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                        ),
                      ),
                    ),
                  ),
                  if (onCircle != null)
                    MurkotFloatingTooltip(
                      message: context.strings.circleVideo,
                      child: IconButton(
                        tooltip: '',
                        icon: const Icon(Icons.motion_photos_on_outlined),
                        onPressed: onCircle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  const SizedBox(width: 2),
                  if (hasText)
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: onSend,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  else
                    MurkotFloatingTooltip(
                      message: context.strings.voiceNote,
                      child: IconButton(
                        tooltip: '',
                        icon: const Icon(Icons.mic),
                        onPressed: onVoiceStart,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({
    required this.icon,
    required this.label,
    required this.type,
  });

  final IconData icon;
  final String label;
  final MessageType type;

  @override
  Widget build(BuildContext context) {
    return _AttachActionTile(
      icon: icon,
      label: label,
      onTap: () => Navigator.pop(context, type),
    );
  }
}

class _AttachActionTile extends StatelessWidget {
  const _AttachActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickedMedia {
  const _PickedMedia({
    required this.bytes,
    required this.name,
    required this.contentType,
    this.durationMs,
    this.isCircle = false,
  });

  final Uint8List bytes;
  final String name;
  final String contentType;
  final int? durationMs;
  final bool isCircle;
}

/// An attachment staged in the composer before sending.
class _DraftAttachment {
  const _DraftAttachment({
    required this.type,
    required this.bytes,
    required this.name,
    required this.contentType,
  });

  final MessageType type;
  final Uint8List bytes;
  final String name;
  final String contentType;
}

/// Preview chip of a drafted attachment with a remove button.
class _DraftChip extends StatelessWidget {
  const _DraftChip({required this.draft, this.onRemove});

  final _DraftAttachment draft;
  final VoidCallback? onRemove;

  bool get _isImage =>
      draft.type == MessageType.image ||
      draft.type == MessageType.sticker ||
      draft.type == MessageType.gif;

  IconData get _icon => switch (draft.type) {
        MessageType.video => Icons.videocam,
        MessageType.music => Icons.music_note,
        MessageType.file => Icons.insert_drive_file_outlined,
        _ => Icons.attach_file,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget body;
    if (_isImage) {
      body = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          draft.bytes,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
        ),
      );
    } else {
      body = Container(
        width: 150,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(_icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                draft.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.only(top: 6, right: 6), child: body),
        Positioned(
          top: 0,
          right: 0,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 1.5),
              ),
              child: Icon(
                Icons.close,
                size: 12,
                color: theme.colorScheme.onError,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
