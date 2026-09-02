import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../models/conversation.dart';
import '../models/media_payload.dart';
import '../models/message.dart';
import '../models/public_conversation.dart';
import '../models/system_payload.dart';
import '../models/user.dart';
import '../models/user_preview.dart';
import '../utils/helpers.dart';
import 'blacklist_service.dart';
import 'gif_service.dart';
import 'media_service.dart';

/// Owns conversation list, message cache, realtime and outbox for the signed-in
/// user. Full repository split is deferred; keep dispose/subscriptions tight.
class ChatService extends ChangeNotifier {
  ChatService({
    required String userId,
    required String userLogin,
    required SharedPreferences prefs,
    BlacklistService? blacklistService,
  })  : _userId = userId,
        _userLogin = userLogin,
        _prefs = prefs,
        _blacklistService = blacklistService {
    _blacklistService?.addListener(_onBlacklistChanged);
  }

  static const botUserId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeee01';
  static const botLogin = 'Murkot';
  static const messagePageSize = 40;

  final String _userId;
  final String _userLogin;
  final SharedPreferences _prefs;
  final BlacklistService? _blacklistService;
  final _client = Supabase.instance.client;

  String get _outboxKey => 'outbox_$_userId';
  bool _flushingOutbox = false;

  List<Conversation> _conversations = [];
  final Map<String, List<Message>> _messages = {};
  final Map<String, List<Message>> _comments = {};
  final Map<String, List<String>> _pinnedForEveryone = {};
  final Map<String, List<String>> _pinnedForMe = {};
  final Set<String> _hiddenMessageIds = {};
  final Map<String, Set<String>> _readByMe = {};
  final Set<String> _readByOthers = {};
  final Map<String, List<String>> _typingUsers = {};
  final Map<String, Map<String, String>> _composerActivity = {};
  final Map<String, _ProfileRef> _profilesById = {};
  final Set<String> _messagesInitialized = {};
  final Map<String, bool> _hasMoreMessages = {};
  final Map<String, bool> _loadingMessages = {};

  RealtimeChannel? _channel;
  String? _activeConversationId;
  void Function(Message message, Conversation conversation)? onIncomingMessage;

  bool _ready = false;
  bool get isReady => _ready;

  Future<void> initialize() async {
    await _loadAll(preserveMessages: false);
    _restoreOutboxMessages();
    _subscribeRealtime();
    _ready = true;
    notifyListeners();
    unawaited(flushOutbox());
  }

  void setActiveConversation(String? conversationId) {
    _activeConversationId = conversationId;
  }

  bool hasMoreMessages(String conversationId) =>
      _hasMoreMessages[conversationId] ?? true;

  bool isLoadingMessages(String conversationId) =>
      _loadingMessages[conversationId] ?? false;

  Future<void> ensureMessagesLoaded(String conversationId) async {
    if (_messagesInitialized.contains(conversationId)) return;
    await _fetchMessagesPage(conversationId);
  }

  Future<bool> loadOlderMessages(String conversationId) async {
    if (_loadingMessages[conversationId] == true) return false;
    if (_hasMoreMessages[conversationId] == false) return false;
    if (!_messagesInitialized.contains(conversationId)) {
      await ensureMessagesLoaded(conversationId);
      return hasMoreMessages(conversationId);
    }
    return _fetchMessagesPage(conversationId, older: true);
  }

  /// Loads a user's public profile by login (e.g. for the stranger screen).
  Future<User?> fetchProfileByLogin(String login) async {
    try {
      final rows = await _client.rpc(
        'get_public_profile_by_login',
        params: {'p_login': login},
      );
      if (rows is List && rows.isNotEmpty) {
        return User.fromProfileRow(
          Map<String, dynamic>.from(rows.first as Map),
        );
      }

      // Fallback if RPC migration not applied yet.
      final row = await _client
          .from('profiles')
          .select(
            'id, login, status, avatar_url, avatar_emoji, profile_wallpaper_id, '
            'custom_wallpaper_url, birthday, created_at, updated_at, '
            'dev_status, skills, experience_level, github_url, portfolio_url, '
            'city, is_bot, last_seen_at, avatar_frame, nick_color, is_plus, plus_until',
          )
          .ilike('login', login)
          .maybeSingle();
      if (row == null) return null;
      return User.fromProfileRow(row);
    } catch (e) {
      debugPrint('fetchProfileByLogin failed: $e');
      return null;
    }
  }

  void _onBlacklistChanged() => notifyListeners();

  bool isDirectBlocked(Conversation conversation) {
    if (conversation.type != ConversationType.direct) return false;
    return _blacklistService?.isBlocked(conversation.name) ?? false;
  }

  bool canMessageConversation(Conversation conversation) {
    if (conversation.type == ConversationType.channel && !conversation.isAdmin) {
      return false;
    }
    return !isDirectBlocked(conversation);
  }

  @override
  void dispose() {
    _blacklistService?.removeListener(_onBlacklistChanged);
    _channel?.unsubscribe();
    super.dispose();
  }

  List<Conversation> getConversations(ConversationType type) {
    return _conversations
        .where((c) => c.type == type && !isDirectBlocked(c))
        .toList()
      ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity));
  }

  List<Conversation> searchConversations(ConversationType type, String query) {
    final q = query.trim();
    if (q.isEmpty) return getConversations(type);
    return getConversations(type).where((c) {
      return matchesSearch(c.name, q) ||
          matchesSearch(c.lastMessage, q) ||
          (c.lastMessageSender != null &&
              matchesSearch(c.lastMessageSender!, q));
    }).toList();
  }

  Conversation? getConversation(String id) {
    try {
      return _conversations.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Message> getMessages(String conversationId) {
    return (_messages[conversationId] ?? [])
        .where((m) => !_hiddenMessageIds.contains(m.id) && !m.deletedForMe)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  List<Message> getMediaMessages(String conversationId, MessageType type) {
    return getMessages(conversationId).where((m) => m.type == type).toList();
  }

  List<Message> getPinnedMessages(String conversationId) {
    final allIds = {
      ...(_pinnedForEveryone[conversationId] ?? []),
      ...(_pinnedForMe[conversationId] ?? []),
    };
    final messages = getMessages(conversationId);
    return allIds
        .map((id) => messages.where((m) => m.id == id).firstOrNull)
        .whereType<Message>()
        .toList();
  }

  List<Message> getComments(String messageId) {
    return List<Message>.from(_comments[messageId] ?? [])
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  bool canSendMessages(Conversation conversation) {
    return canMessageConversation(conversation);
  }

  Future<void> setTyping(String conversationId, bool isTyping) async {
    await setComposerActivity(
      conversationId,
      isTyping ? 'typing' : null,
    );
  }

  /// [activity] is `typing`, `voice`, `circle`, or null to clear.
  Future<void> setComposerActivity(String conversationId, String? activity) async {
    final typing = List<String>.from(_typingUsers[conversationId] ?? []);
    final map = Map<String, String>.from(_composerActivity[conversationId] ?? {});
    if (activity == null || activity.isEmpty) {
      typing.remove(_userLogin);
      map.remove(_userLogin);
    } else {
      if (activity == 'typing' && !typing.contains(_userLogin)) {
        typing.add(_userLogin);
      }
      if (activity != 'typing') typing.remove(_userLogin);
      map[_userLogin] = activity;
    }
    _typingUsers[conversationId] = typing;
    _composerActivity[conversationId] = map;
    _applyTypingToConversation(conversationId);
    notifyListeners();

    await _channel?.sendBroadcastMessage(
      event: 'typing',
      payload: {
        'conversation_id': conversationId,
        'login': _userLogin,
        'is_typing': activity == 'typing',
        'activity': activity,
      },
    );
  }

  String? peerActivity(String conversationId) {
    final map = _composerActivity[conversationId];
    if (map == null) return null;
    for (final entry in map.entries) {
      if (entry.key != _userLogin) return entry.value;
    }
    return null;
  }

  String? peerActivityLogin(String conversationId) {
    final map = _composerActivity[conversationId];
    if (map == null) return null;
    for (final entry in map.entries) {
      if (entry.key != _userLogin) return entry.key;
    }
    return null;
  }

  Future<List<UserPreview>> searchUsers(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final rows = await _client.rpc(
      'search_users',
      params: {'search_query': q},
    );

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(UserPreview.fromRow)
        .toList();
  }

  Future<Conversation> openDirectChat(UserPreview user) async {
    if (_blacklistService?.isBlocked(user.login) ?? false) {
      throw StateError('User is blocked');
    }

    final row = await _client.rpc(
      'get_or_create_direct_chat',
      params: {'other_user_id': user.id},
    );
    final map = Map<String, dynamic>.from(row as Map);
    // conversations.name is set by whoever created the DM and is often the
    // *current* user's login — never trust it for the peer display name.
    final conversation = _upsertLocalConversationFromRow(
      map,
      fallbackName: user.login,
      fallbackEmoji: user.avatarEmoji,
      memberIds: [_userLogin, user.login],
      contactStatus: user.status,
      forcePeerDisplay: true,
      peerAvatarUrl: user.avatarUrl,
    );
    return conversation;
  }

  Future<Conversation> openBotChat() async {
    return openDirectChat(
      const UserPreview(
        id: botUserId,
        login: botLogin,
        status: 'Всегда на связи',
        avatarEmoji: '🤖',
        isBot: true,
      ),
    );
  }

  Future<Conversation> createConversation({
    required ConversationType type,
    required String name,
  }) async {
    if (type == ConversationType.direct) {
      final users = await searchUsers(name);
      final exact = users.where(
        (u) => u.login.toLowerCase() == name.trim().toLowerCase(),
      );
      if (exact.isNotEmpty) {
        return openDirectChat(exact.first);
      }
      throw StateError('User not found: ${name.trim()}');
    }

    final emoji = pickRandomEmoji();
    final row = await _client.rpc(
      'create_conversation',
      params: {
        'p_type': type.name,
        'p_name': name.trim(),
        'p_emoji': emoji,
      },
    );

    final map = Map<String, dynamic>.from(row as Map);
    return _upsertLocalConversationFromRow(
      map,
      fallbackName: name.trim(),
      fallbackEmoji: emoji,
      memberIds: [_userLogin],
      isAdmin: true,
    );
  }

  Conversation _upsertLocalConversationFromRow(
    Map<String, dynamic> map, {
    required String fallbackName,
    String? fallbackEmoji,
    List<String> memberIds = const [],
    String contactStatus = '',
    bool isAdmin = false,
    bool forcePeerDisplay = false,
    String? peerAvatarUrl,
  }) {
    final id = map['id'] as String;
    final existing = getConversation(id);
    final type = _parseType(map['type'] as String? ?? 'direct');
    final rawName = map['name'] as String?;
    // DM rows store an asymmetric creator-picked name — often OUR login.
    final displayName = forcePeerDisplay
        ? fallbackName
        : (type == ConversationType.direct &&
                (rawName == null ||
                    rawName.toLowerCase() == _userLogin.toLowerCase()))
            ? fallbackName
            : (rawName ?? fallbackName);
    final displayAvatar = forcePeerDisplay
        ? (peerAvatarUrl ?? existing?.avatarPath)
        : (map['avatar_url'] as String? ?? existing?.avatarPath);
    final conversation = Conversation(
      id: id,
      type: type,
      name: displayName,
      avatarPath: displayAvatar,
      avatarEmoji: forcePeerDisplay
          ? (fallbackEmoji ?? existing?.avatarEmoji)
          : (map['avatar_emoji'] as String? ??
              fallbackEmoji ??
              existing?.avatarEmoji),
      lastMessage: map['last_message'] as String? ?? existing?.lastMessage ?? '',
      lastMessageSender:
          map['last_message_sender'] as String? ?? existing?.lastMessageSender,
      lastActivity: DateTime.parse(
        map['last_activity'] as String? ?? DateTime.now().toIso8601String(),
      ),
      isAdmin: isAdmin || (existing?.isAdmin ?? false),
      memberIds: memberIds.isNotEmpty ? memberIds : (existing?.memberIds ?? [_userLogin]),
      contactStatus: contactStatus.isNotEmpty
          ? contactStatus
          : (existing?.contactStatus ?? ''),
      contactBirthday: existing?.contactBirthday,
      pinnedForAllIds: existing?.pinnedForAllIds ?? const [],
      onlineCount: existing?.onlineCount ?? 0,
      subscriberCount: existing?.subscriberCount ?? 0,
      description: map['description'] as String? ?? existing?.description ?? '',
    );

    _conversations = [
      ..._conversations.where((c) => c.id != conversation.id),
      conversation,
    ];
    _messages.putIfAbsent(conversation.id, () => []);
    notifyListeners();
    return conversation;
  }

  Future<void> deleteConversation(String id) async {
    await _client.from('conversations').delete().eq('id', id);
    _conversations.removeWhere((c) => c.id == id);
    _messages.remove(id);
    _pinnedForEveryone.remove(id);
    _pinnedForMe.remove(id);
    _typingUsers.remove(id);
    notifyListeners();
  }

  Future<void> leaveConversation(String id) async {
    await _client
        .from('conversation_members')
        .delete()
        .eq('conversation_id', id)
        .eq('user_id', _userId);
    _conversations.removeWhere((c) => c.id == id);
    _messages.remove(id);
    notifyListeners();
  }

  /// Uploads a new group/channel avatar and persists it on the conversation.
  Future<void> updateConversationAvatarBytes(
    String conversationId,
    Uint8List bytes,
  ) async {
    if (bytes.isEmpty) throw StateError('Empty image');

    final path = '$_userId/conv_$conversationId.jpg';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    final url = _client.storage.from('avatars').getPublicUrl(path);
    final busted = '$url?t=${DateTime.now().millisecondsSinceEpoch}';

    final conversation = getConversation(conversationId);
    if (conversation == null) return;
    await updateConversation(conversation.copyWith(avatarPath: busted));
    await sendSystemMessage(
      conversationId,
      SystemPayload(
        text: '$_userLogin обновил(а) аватар',
        actorLogin: _userLogin,
      ).encode(),
    );
  }

  /// Search public groups/channels by name (RPC, see features_v8.sql).
  Future<List<PublicConversationPreview>> searchPublicConversations(
    String query,
    ConversationType type,
  ) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final rows = await _client.rpc(
      'search_public_conversations',
      params: {'search_query': q, 'p_type': type.name},
    );

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PublicConversationPreview.fromRow)
        .toList();
  }

  /// Featured community channels for the Board catalog (features_v14.sql).
  Future<List<PublicConversationPreview>> listCommunityChannels() async {
    try {
      final rows = await _client.rpc('list_community_channels');
      if (rows is! List) return const [];
      return [
        for (final raw in rows)
          if (raw is Map)
            PublicConversationPreview.fromRow(Map<String, dynamic>.from(raw)),
      ];
    } catch (e) {
      debugPrint('list_community_channels failed: $e');
      return _listFeaturedConversationsFallback();
    }
  }

  Future<List<PublicConversationPreview>> _listFeaturedConversationsFallback() async {
    final rows = await _client
        .from('conversations')
        .select(
          'id, type, name, description, avatar_emoji, avatar_url, category',
        )
        .eq('is_featured', true)
        .inFilter('type', ['group', 'channel'])
        .order('name');
    return (rows as List)
        .map((row) => PublicConversationPreview.fromRow(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  /// Join a public group/channel, then refresh the conversation list.
  Future<Conversation?> joinConversation(String conversationId) async {
    await _client.rpc(
      'join_conversation',
      params: {'p_conversation_id': conversationId},
    );
    await _loadAll(preserveMessages: true);
    notifyListeners();
    final conversation = getConversation(conversationId);
    // Channels are read-only for regular members — no system notice there.
    if (conversation != null && conversation.type == ConversationType.group) {
      await sendSystemMessage(
        conversationId,
        SystemPayload(
          text: '$_userLogin вступил(а) в группу',
          actorLogin: _userLogin,
        ).encode(),
      );
    }
    return conversation;
  }

  /// Admin-only invite token for private groups/channels.
  Future<String> createConversationInvite(String conversationId) async {
    final token = await _client.rpc(
      'create_conversation_invite',
      params: {'p_conversation_id': conversationId, 'p_days': 7},
    );
    return token as String;
  }

  Future<Conversation?> redeemConversationInvite(String token) async {
    final id = await _client.rpc(
      'redeem_conversation_invite',
      params: {'p_token': token.trim()},
    );
    await _loadAll(preserveMessages: true);
    notifyListeners();
    return getConversation(id as String);
  }

  Future<void> setConversationPublic(String conversationId, bool isPublic) async {
    await _client.rpc(
      'set_conversation_public',
      params: {
        'p_conversation_id': conversationId,
        'p_is_public': isPublic,
      },
    );
  }

  /// Public + featured so the group/channel appears in Board → Communities.
  Future<void> setConversationCommunity(
    String conversationId,
    bool asCommunity,
  ) async {
    try {
      await _client.rpc(
        'set_conversation_community',
        params: {
          'p_conversation_id': conversationId,
          'p_as_community': asCommunity,
        },
      );
    } catch (_) {
      // Fallback if v27 SQL not applied yet.
      await setConversationPublic(conversationId, asCommunity);
      try {
        await _client.from('conversations').update({
          'is_featured': asCommunity,
        }).eq('id', conversationId);
      } catch (e) {
        debugPrint('setConversationCommunity featured fallback: $e');
      }
    }
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      notifyListeners();
    }
  }

  /// Search text messages across all my conversations of [type].
  Future<List<MessageSearchHit>> searchMessagesGlobal(
    String query,
    ConversationType type,
  ) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final convIds = _conversations
        .where((c) => c.type == type)
        .map((c) => c.id)
        .toList();
    if (convIds.isEmpty) return const [];

    final rows = await _client
        .from('messages')
        .select(
          '*, sender:profiles!messages_sender_id_fkey(login, avatar_emoji, avatar_url)',
        )
        .inFilter('conversation_id', convIds)
        .eq('type', 'text')
        .ilike('content', '%$q%')
        .order('created_at', ascending: false)
        .limit(30);

    final hits = <MessageSearchHit>[];
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final conversation = getConversation(row['conversation_id'] as String);
      if (conversation == null) continue;
      _rememberSender(row);
      hits.add(MessageSearchHit(
        conversation: conversation,
        message: _messageFromRow(row, replyLookup: _findMessage),
      ));
    }
    return hits;
  }

  Future<void> updateConversation(Conversation updated) async {
    await _client.from('conversations').update({
      'name': updated.name,
      'description': updated.description,
      'avatar_emoji': updated.avatarEmoji,
      'avatar_url': updated.avatarPath,
    }).eq('id', updated.id);

    final index = _conversations.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _conversations[index] = updated;
      notifyListeners();
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    required MessageType type,
    required String content,
    String? senderEmoji,
    String? replyToId,
  }) async {
    final conversation = getConversation(conversationId);
    if (conversation != null && !canSendMessages(conversation)) {
      throw StateError('Cannot send messages in this conversation');
    }

    final parts =
        type == MessageType.text ? splitMessageText(content) : [content];

    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      final localId =
          'local_${DateTime.now().microsecondsSinceEpoch}_$i';
      final reply = i == 0 ? replyToId : null;
      final replyMsg = reply == null ? null : _findMessage(reply);

      final pending = Message(
        id: localId,
        conversationId: conversationId,
        senderId: _userLogin,
        senderName: _userLogin,
        type: type,
        content: part,
        timestamp: DateTime.now(),
        senderEmoji: senderEmoji,
        replyToId: reply,
        replyToSender: replyMsg?.senderName,
        replyToContent:
            replyMsg == null ? null : messagePreviewText(replyMsg),
        sendStatus: MessageSendStatus.sending,
      );
      _addMessageLocal(pending);
      _upsertOutboxEntry({
        'localId': localId,
        'conversationId': conversationId,
        'type': type.name,
        'content': part,
        'replyToId': reply,
        'senderEmoji': senderEmoji,
        'createdAt': pending.timestamp.toIso8601String(),
      });
      notifyListeners();

      await _deliverOutboxItem(localId);
    }
  }

  Future<void> retryFailedMessage(String localId) async {
    if (!localId.startsWith('local_')) return;
    _setLocalSendStatus(localId, MessageSendStatus.sending);
    await _deliverOutboxItem(localId);
  }

  Future<void> flushOutbox() async {
    if (_flushingOutbox) return;
    _flushingOutbox = true;
    try {
      final entries = _readOutbox();
      for (final entry in List<Map<String, dynamic>>.from(entries)) {
        final localId = entry['localId'] as String?;
        if (localId == null) continue;
        _setLocalSendStatus(localId, MessageSendStatus.sending);
        await _deliverOutboxItem(localId);
      }
    } finally {
      _flushingOutbox = false;
    }
  }

  Future<void> _deliverOutboxItem(String localId) async {
    final entries = _readOutbox();
    final index = entries.indexWhere((e) => e['localId'] == localId);
    if (index == -1) return;
    final entry = entries[index];

    try {
      final payload = <String, dynamic>{
        'conversation_id': entry['conversationId'],
        'sender_id': _userId,
        'type': entry['type'],
        'content': entry['content'],
      };
      final replyToId = entry['replyToId'] as String?;
      if (replyToId != null && !replyToId.startsWith('local_')) {
        payload['reply_to_id'] = replyToId;
      }

      final row = await _client
          .from('messages')
          .insert(payload)
          .select(
            '*, sender:profiles!messages_sender_id_fkey(login, avatar_emoji, avatar_url)',
          )
          .single();

      final serverMessage = _messageFromRow(row, replyLookup: _findMessage);
      _rememberSender(row);
      _replaceLocalMessage(localId, serverMessage);
      _removeOutboxEntry(localId);
      notifyListeners();
    } catch (_) {
      _setLocalSendStatus(localId, MessageSendStatus.failed);
      notifyListeners();
    }
  }

  void _restoreOutboxMessages() {
    for (final entry in _readOutbox()) {
      final localId = entry['localId'] as String?;
      final conversationId = entry['conversationId'] as String?;
      final content = entry['content'] as String?;
      final typeName = entry['type'] as String?;
      if (localId == null || conversationId == null || content == null) {
        continue;
      }
      final type = MessageType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => MessageType.text,
      );
      final replyToId = entry['replyToId'] as String?;
      final replyMsg = replyToId == null ? null : _findMessage(replyToId);
      final createdAt = DateTime.tryParse(entry['createdAt'] as String? ?? '') ??
          DateTime.now();
      final pending = Message(
        id: localId,
        conversationId: conversationId,
        senderId: _userLogin,
        senderName: _userLogin,
        type: type,
        content: content,
        timestamp: createdAt,
        senderEmoji: entry['senderEmoji'] as String?,
        replyToId: replyToId,
        replyToSender: replyMsg?.senderName,
        replyToContent:
            replyMsg == null ? null : messagePreviewText(replyMsg),
        sendStatus: MessageSendStatus.failed,
      );
      _addMessageLocal(pending);
    }
  }

  List<Map<String, dynamic>> _readOutbox() {
    final raw = _prefs.getString(_outboxKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistOutbox(List<Map<String, dynamic>> entries) async {
    await _prefs.setString(_outboxKey, jsonEncode(entries));
  }

  void _upsertOutboxEntry(Map<String, dynamic> entry) {
    final entries = _readOutbox();
    final localId = entry['localId'] as String;
    final index = entries.indexWhere((e) => e['localId'] == localId);
    if (index == -1) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
    unawaited(_persistOutbox(entries));
  }

  void _removeOutboxEntry(String localId) {
    final entries = _readOutbox()
      ..removeWhere((e) => e['localId'] == localId);
    unawaited(_persistOutbox(entries));
  }

  void _setLocalSendStatus(String localId, MessageSendStatus status) {
    for (final list in _messages.values) {
      final index = list.indexWhere((m) => m.id == localId);
      if (index == -1) continue;
      list[index] = list[index].copyWith(sendStatus: status);
      notifyListeners();
      return;
    }
  }

  void _replaceLocalMessage(String localId, Message serverMessage) {
    final list = _messages[serverMessage.conversationId];
    if (list == null) {
      _addMessageLocal(serverMessage);
      return;
    }
    final index = list.indexWhere((m) => m.id == localId);
    if (index == -1) {
      if (!list.any((m) => m.id == serverMessage.id)) {
        list.add(serverMessage);
      }
      return;
    }
    list[index] = serverMessage;
  }

  Message? _findMessage(String id) {
    for (final list in _messages.values) {
      for (final message in list) {
        if (message.id == id) return message;
      }
    }
    return null;
  }

  List<Message> searchMessages(String conversationId, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return getMessages(conversationId);
    return getMessages(conversationId).where((m) {
      return messagePreviewText(m).toLowerCase().contains(q) ||
          m.senderName.toLowerCase().contains(q);
    }).toList();
  }

  Future<List<Message>> searchMessagesRemote(
    String conversationId,
    String query,
  ) async {
    final q = query.trim();
    if (q.isEmpty) return getMessages(conversationId);

    final rows = await _client
        .from('messages')
        .select(
          '*, sender:profiles!messages_sender_id_fkey(login, avatar_emoji, avatar_url)',
        )
        .eq('conversation_id', conversationId)
        .ilike('content', '%$q%')
        .order('created_at', ascending: false)
        .limit(50);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((row) => _messageFromRow(row, replyLookup: _findMessage))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> forwardMessage({
    required Message message,
    required String targetConversationId,
  }) async {
    final target = getConversation(targetConversationId);
    if (target == null) {
      throw StateError('Conversation not found');
    }
    if (!canSendMessages(target)) {
      throw StateError('Cannot send to this conversation');
    }

    final prefix = '↪ ${message.senderName}: ';
    final content = message.type == MessageType.text
        ? '$prefix${message.content}'
        : message.content;

    await sendMessage(
      conversationId: targetConversationId,
      type: message.type,
      content: content,
    );
  }

  Future<void> sendMediaBytes({
    required String conversationId,
    required MessageType type,
    required Uint8List bytes,
    required String fileName,
    String contentType = 'application/octet-stream',
    int? durationMs,
    bool isCircle = false,
    String? caption,
  }) async {
    final url = await MediaService.uploadChatMedia(
      conversationId: conversationId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
    );

    await sendMessage(
      conversationId: conversationId,
      type: type,
      content: MediaPayload(
        url: url,
        name: fileName,
        durationMs: durationMs,
        isCircle: isCircle,
        caption: caption,
      ).encode(),
    );
  }

  /// Uploads several photos and sends them as one grouped message (album).
  Future<void> sendImageAlbum({
    required String conversationId,
    required List<({Uint8List bytes, String name, String contentType})> images,
    String? caption,
  }) async {
    if (images.isEmpty) return;

    final urls = <String>[];
    for (final image in images) {
      urls.add(await MediaService.uploadChatMedia(
        conversationId: conversationId,
        bytes: image.bytes,
        fileName: image.name,
        contentType: image.contentType,
      ));
    }

    await sendMessage(
      conversationId: conversationId,
      type: MessageType.image,
      content: MediaPayload(
        url: urls.first,
        name: urls.length == 1 ? images.first.name : '${urls.length} фото',
        caption: caption,
        album: urls.length > 1 ? urls : const [],
      ).encode(),
    );
  }

  /// Sends a centered service notice ("X добавил Y" etc). Never throws.
  Future<void> sendSystemMessage(String conversationId, String text) async {
    try {
      await sendMessage(
        conversationId: conversationId,
        type: MessageType.system,
        content: text,
      );
    } catch (e) {
      debugPrint('sendSystemMessage failed: $e');
    }
  }

  /// Local-only system notice — visible only on this device/session
  /// (used for "pin for me").
  void addLocalSystemMessage(String conversationId, String text) {
    final message = Message(
      id: 'local_sys_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: _userLogin,
      senderName: _userLogin,
      type: MessageType.system,
      content: text,
      timestamp: DateTime.now(),
    );
    _addMessageLocal(message);
    notifyListeners();
  }

  Future<void> addMemberByLogin(String conversationId, String login) async {
    await _client.rpc(
      'add_conversation_member_by_login',
      params: {
        'p_conversation_id': conversationId,
        'p_login': login.trim(),
      },
    );
    await _loadAll();
    notifyListeners();
    final target = login.trim();
    await sendSystemMessage(
      conversationId,
      SystemPayload(
        text: '$_userLogin добавил(а) $target',
        actorLogin: _userLogin,
        targetLogin: target,
      ).encode(),
    );
  }

  Future<void> addMember(String conversationId, UserPreview user) async {
    await _client.rpc(
      'add_conversation_member',
      params: {
        'p_conversation_id': conversationId,
        'p_user_id': user.id,
      },
    );
    await _loadAll();
    notifyListeners();
    await sendSystemMessage(
      conversationId,
      SystemPayload(
        text: '$_userLogin добавил(а) ${user.login}',
        actorLogin: _userLogin,
        targetLogin: user.login,
      ).encode(),
    );
  }

  Future<void> removeMemberByLogin(String conversationId, String login) async {
    await _client.rpc(
      'remove_conversation_member_by_login',
      params: {
        'p_conversation_id': conversationId,
        'p_login': login.trim(),
      },
    );
    await _loadAll();
    notifyListeners();
    final target = login.trim();
    await sendSystemMessage(
      conversationId,
      SystemPayload(
        text: '$_userLogin удалил(а) $target',
        actorLogin: _userLogin,
        targetLogin: target,
      ).encode(),
    );
  }

  Future<void> addComment({
    required String postMessageId,
    required String conversationId,
    required String content,
  }) async {
    final row = await _client
        .from('message_comments')
        .insert({
          'post_message_id': postMessageId,
          'conversation_id': conversationId,
          'sender_id': _userId,
          'content': content,
        })
        .select(
          '*, sender:profiles!message_comments_sender_id_fkey(login, avatar_emoji, avatar_url)',
        )
        .single();

    final comment = _commentFromRow(row);
    _comments.putIfAbsent(postMessageId, () => []).add(comment);
    notifyListeners();
  }

  Future<void> markMessagesRead(String conversationId) async {
    final list = _messages[conversationId];
    if (list == null) return;

    final unread = list
        .where((m) {
          if (m.senderId == _userLogin) return false;
          return !(_readByMe[conversationId]?.contains(m.id) ?? false);
        })
        .map((m) => m.id)
        .toList();
    if (unread.isEmpty) return;

    final payload = unread
        .map((id) => {'message_id': id, 'user_id': _userId})
        .toList();
    await _client.from('message_reads').upsert(payload);

    _readByMe.putIfAbsent(conversationId, () => {}).addAll(unread);
    _messages[conversationId] = list
        .map((m) => unread.contains(m.id) ? m.copyWith(isRead: true) : m)
        .toList();
    notifyListeners();
  }

  Future<void> incrementViews(String conversationId, String messageId) async {
    final list = _messages[conversationId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final nextLocal = list[index].viewCount + 1;
    list[index] = list[index].copyWith(viewCount: nextLocal);
    notifyListeners();

    try {
      final next = await _client.rpc(
        'increment_message_view_count',
        params: {'p_message_id': messageId},
      );
      final resolved = next is int ? next : nextLocal;
      final fresh = _messages[conversationId];
      if (fresh == null) return;
      final i = fresh.indexWhere((m) => m.id == messageId);
      if (i == -1) return;
      fresh[i] = fresh[i].copyWith(viewCount: resolved);
      notifyListeners();
    } catch (e) {
      debugPrint('incrementViews failed: $e');
    }
  }

  Future<void> editMessage(
    String conversationId,
    String messageId,
    String newContent,
  ) async {
    await _client.from('messages').update({
      'content': newContent,
      'is_edited': true,
    }).eq('id', messageId);

    final list = _messages[conversationId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    list[index] = list[index].copyWith(content: newContent, isEdited: true);
    _syncConversationPreview(conversationId);

    // Also patch DB preview if this is still the latest visible message
    // (v27 trigger does the same; this helps before migration is applied).
    final visible = getMessages(conversationId);
    if (visible.isNotEmpty && visible.last.id == messageId) {
      try {
        await _client.from('conversations').update({
          'last_message': messagePreviewText(visible.last, maxChars: 200),
        }).eq('id', conversationId);
      } catch (e) {
        debugPrint('editMessage preview patch: $e');
      }
    }
    notifyListeners();
  }

  Future<void> deleteMessage(
    String conversationId,
    String messageId, {
    required bool forEveryone,
  }) async {
    if (forEveryone) {
      await _client.rpc(
        'soft_delete_message_for_all',
        params: {'p_message_id': messageId},
      );

      final list = _messages[conversationId];
      if (list != null) {
        final index = list.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          list[index] =
              list[index].copyWith(isDeletedForAll: true, content: '');
        }
      }
    } else {
      await _client.from('message_hides').upsert({
        'message_id': messageId,
        'user_id': _userId,
      });
      _hiddenMessageIds.add(messageId);

      final list = _messages[conversationId];
      if (list != null) {
        final index = list.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          list[index] = list[index].copyWith(deletedForMe: true);
        }
      }
    }

    await _unpinMessageLocal(conversationId, messageId);
    _syncConversationPreview(conversationId);
    notifyListeners();
  }

  Future<void> pinMessage(
    String conversationId,
    String messageId, {
    required bool forEveryone,
  }) async {
    var deleteQuery = _client
        .from('message_pins')
        .delete()
        .eq('message_id', messageId)
        .eq('for_everyone', forEveryone);
    if (!forEveryone) {
      deleteQuery = deleteQuery.eq('pinned_by', _userId);
    }
    await deleteQuery;

    await _client.from('message_pins').insert({
      'message_id': messageId,
      'conversation_id': conversationId,
      'pinned_by': _userId,
      'for_everyone': forEveryone,
    });

    if (forEveryone) {
      final pinned =
          List<String>.from(_pinnedForEveryone[conversationId] ?? []);
      if (!pinned.contains(messageId)) pinned.add(messageId);
      _pinnedForEveryone[conversationId] = pinned;

      final conv = getConversation(conversationId);
      if (conv != null) {
        await _replaceConversation(
          conv.copyWith(pinnedForAllIds: pinned),
        );
      }
    } else {
      final pinned = List<String>.from(_pinnedForMe[conversationId] ?? []);
      if (!pinned.contains(messageId)) pinned.add(messageId);
      _pinnedForMe[conversationId] = pinned;
    }
    notifyListeners();

    final target = _findMessage(messageId);
    final preview = target == null
        ? 'сообщение'
        : messagePreviewText(target, maxChars: 40);
    final payload = SystemPayload(
      text: forEveryone
          ? '$_userLogin закрепил(а) сообщение'
          : 'Вы закрепили сообщение для себя',
      actorLogin: _userLogin,
      targetMessageId: messageId,
      targetPreview: preview,
    ).encode();
    if (forEveryone) {
      await sendSystemMessage(conversationId, payload);
    } else {
      addLocalSystemMessage(conversationId, payload);
    }
  }

  Future<void> unpinMessage(
    String conversationId,
    String messageId, {
    required bool forEveryone,
  }) async {
    var query = _client
        .from('message_pins')
        .delete()
        .eq('message_id', messageId)
        .eq('for_everyone', forEveryone);
    if (!forEveryone) {
      query = query.eq('pinned_by', _userId);
    }
    await query;

    if (forEveryone) {
      _pinnedForEveryone[conversationId] =
          (_pinnedForEveryone[conversationId] ?? [])
              .where((id) => id != messageId)
              .toList();
      final conv = getConversation(conversationId);
      if (conv != null) {
        await _replaceConversation(
          conv.copyWith(
            pinnedForAllIds: _pinnedForEveryone[conversationId]!,
          ),
        );
      }
    } else {
      _pinnedForMe[conversationId] = (_pinnedForMe[conversationId] ?? [])
          .where((id) => id != messageId)
          .toList();
    }
    notifyListeners();
  }

  Future<void> toggleReaction(
    String conversationId,
    String messageId,
    String emoji,
  ) async {
    final list = _messages[conversationId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final reactions = Map<String, String>.from(list[index].reactions);
    final isLocalOnly = messageId.startsWith('local_');

    if (reactions[_userLogin] == emoji) {
      if (!isLocalOnly) {
        await _client
            .from('message_reactions')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', _userId);
      }
      reactions.remove(_userLogin);
    } else {
      if (!isLocalOnly) {
        await _client.from('message_reactions').upsert({
          'message_id': messageId,
          'user_id': _userId,
          'emoji': emoji,
        });
      }
      reactions[_userLogin] = emoji;
    }

    list[index] = list[index].copyWith(reactions: reactions);
    notifyListeners();
  }

  Future<void> _loadAll({bool preserveMessages = true}) async {
    final memberRows = await _client
        .from('conversation_members')
        .select(
          'conversation_id, role, user_id, profiles(login, status, birthday, avatar_emoji, avatar_url, last_seen_at)',
        )
        .eq('user_id', _userId);

    final myMemberships = (memberRows as List).cast<Map<String, dynamic>>();
    if (myMemberships.isEmpty) {
      _conversations = [];
      return;
    }

    final convIds =
        myMemberships.map((m) => m['conversation_id'] as String).toList();

    // Conversations + members + hides + pins in parallel (was 4 serial round-trips).
    final batched = await Future.wait([
      _client
          .from('conversations')
          .select()
          .inFilter('id', convIds)
          .order('last_activity', ascending: false),
      _client
          .from('conversation_members')
          .select(
            'conversation_id, role, user_id, profiles(login, status, birthday, avatar_emoji, avatar_url, last_seen_at)',
          )
          .inFilter('conversation_id', convIds),
      _client.from('message_hides').select('message_id').eq('user_id', _userId),
      _client.from('message_pins').select().inFilter('conversation_id', convIds),
    ]);

    final convRows = batched[0] as List;
    final allMembers = batched[1] as List;
    final hideRows = batched[2] as List;
    final pinRows = batched[3] as List;

    final membersByConv = <String, List<Map<String, dynamic>>>{};
    for (final row in allMembers.cast<Map<String, dynamic>>()) {
      membersByConv
          .putIfAbsent(row['conversation_id'] as String, () => [])
          .add(row);
      final profile = row['profiles'] as Map<String, dynamic>?;
      final userId = row['user_id'] as String?;
      if (profile != null && userId != null) {
        _profilesById[userId] = _ProfileRef(
          login: profile['login'] as String? ?? 'user',
          emoji: profile['avatar_emoji'] as String?,
          avatarUrl: profile['avatar_url'] as String?,
        );
      }
    }

    _profilesById[_userId] = _ProfileRef(
      login: _userLogin,
      emoji: _profilesById[_userId]?.emoji,
      avatarUrl: _profilesById[_userId]?.avatarUrl,
    );
    _profilesById[botUserId] = const _ProfileRef(
      login: botLogin,
      emoji: '🤖',
    );

    final myRoleByConv = {
      for (final m in myMemberships)
        m['conversation_id'] as String: m['role'] as String,
    };

    _hiddenMessageIds
      ..clear()
      ..addAll(hideRows.map((e) => e['message_id'] as String));

    _pinnedForEveryone.clear();
    _pinnedForMe.clear();
    for (final row in pinRows.cast<Map<String, dynamic>>()) {
      final convId = row['conversation_id'] as String;
      final messageId = row['message_id'] as String;
      if (row['for_everyone'] as bool) {
        _pinnedForEveryone.putIfAbsent(convId, () => []).add(messageId);
      } else if (row['pinned_by'] == _userId) {
        _pinnedForMe.putIfAbsent(convId, () => []).add(messageId);
      }
    }

    _conversations = convRows.cast<Map<String, dynamic>>().map((row) {
      final id = row['id'] as String;
      final type = _parseType(row['type'] as String);
      final members = membersByConv[id] ?? [];
      final memberLogins = members
          .map((m) {
            final profile = m['profiles'] as Map<String, dynamic>?;
            return profile?['login'] as String? ?? '';
          })
          .where((l) => l.isNotEmpty)
          .toList();

      String contactStatus = '';
      DateTime? contactBirthday;
      DateTime? contactLastSeen;
      var displayName = row['name'] as String;
      var avatarPath = row['avatar_url'] as String?;
      var avatarEmoji = row['avatar_emoji'] as String?;

      if (type == ConversationType.direct) {
        final other = members.cast<Map<String, dynamic>?>().firstWhere(
              (m) => m?['user_id'] != _userId,
              orElse: () => null,
            );
        final profile = other?['profiles'] as Map<String, dynamic>?;
        // Always show the peer — conversations.name is asymmetric by creator.
        final peerLogin = profile?['login'] as String?;
        if (peerLogin != null && peerLogin.isNotEmpty) {
          displayName = peerLogin;
        } else {
          displayName = memberLogins.firstWhere(
            (l) => l.toLowerCase() != _userLogin.toLowerCase(),
            orElse: () => displayName,
          );
        }
        avatarPath = profile?['avatar_url'] as String? ?? avatarPath;
        avatarEmoji = profile?['avatar_emoji'] as String? ?? avatarEmoji;
        contactStatus = profile?['status'] as String? ?? '';
        final b = profile?['birthday'] as String?;
        if (b != null && b.isNotEmpty) {
          contactBirthday = DateTime.tryParse(b);
        }
        final seen = profile?['last_seen_at'] as String?;
        if (seen != null && seen.isNotEmpty) {
          contactLastSeen = DateTime.tryParse(seen);
        }
      }

      return Conversation(
        id: id,
        type: type,
        name: displayName,
        avatarPath: avatarPath,
        avatarEmoji: avatarEmoji,
        lastMessage: row['last_message'] as String? ?? '',
        lastMessageSender: row['last_message_sender'] as String?,
        lastActivity: DateTime.parse(row['last_activity'] as String),
        memberIds: memberLogins,
        isAdmin: myRoleByConv[id] == 'admin',
        description: row['description'] as String? ?? '',
        contactStatus: contactStatus,
        contactBirthday: contactBirthday,
        contactLastSeen: contactLastSeen,
        onlineCount: type == ConversationType.group ? memberLogins.length : 0,
        subscriberCount:
            type == ConversationType.channel ? memberLogins.length : 0,
        typingUsers: _typingUsers[id] ?? const [],
        pinnedForAllIds: _pinnedForEveryone[id] ?? const [],
      );
    }).toList();

    // Messages are loaded per-chat with pagination.
    if (!preserveMessages) {
      _messages.clear();
      _comments.clear();
      _messagesInitialized.clear();
      _hasMoreMessages.clear();
      _readByMe.clear();
      _readByOthers.clear();
    } else {
      // Drop caches for conversations that no longer exist.
      final alive = convIds.toSet();
      _messages.removeWhere((id, _) => !alive.contains(id));
      _messagesInitialized.removeWhere((id) => !alive.contains(id));
      _hasMoreMessages.removeWhere((id, _) => !alive.contains(id));
    }
  }

  Future<bool> _fetchMessagesPage(
    String conversationId, {
    bool older = false,
  }) async {
    _loadingMessages[conversationId] = true;
    notifyListeners();

    try {
      final existing = _messages[conversationId];
      final oldest = older && existing != null && existing.isNotEmpty
          ? existing.first.timestamp.toUtc().toIso8601String()
          : null;

      final List<dynamic> rawRows;
      if (oldest != null) {
        rawRows = await _client
            .from('messages')
            .select(
              '*, sender:profiles!messages_sender_id_fkey(login, avatar_emoji, avatar_url)',
            )
            .eq('conversation_id', conversationId)
            .lt('created_at', oldest)
            .order('created_at', ascending: false)
            .limit(messagePageSize);
      } else {
        rawRows = await _client
            .from('messages')
            .select(
              '*, sender:profiles!messages_sender_id_fkey(login, avatar_emoji, avatar_url)',
            )
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: false)
            .limit(messagePageSize);
      }

      final rows = rawRows.cast<Map<String, dynamic>>();
      _hasMoreMessages[conversationId] = rows.length >= messagePageSize;
      _messagesInitialized.add(conversationId);

      if (rows.isEmpty) {
        _messages.putIfAbsent(conversationId, () => []);
        return false;
      }

      final messageIds = rows.map((r) => r['id'] as String).toList();
      final reactionsByMessage = await _loadReactionsFor(messageIds);
      await _mergeReadsFor(rows);

      final page = rows.reversed.map((row) {
        final message = _messageFromRow(
          row,
          reactions: reactionsByMessage[row['id'] as String] ?? const {},
          replyLookup: _findMessage,
        );
        _rememberSender(row);
        return message;
      }).toList();

      final current = List<Message>.from(_messages[conversationId] ?? []);
      final pendingLocal =
          current.where((m) => m.isLocalPending).toList(growable: false);
      if (older) {
        final existingIds = current.map((m) => m.id).toSet();
        final olderOnly =
            page.where((m) => !existingIds.contains(m.id)).toList();
        _messages[conversationId] = [...olderOnly, ...current];
      } else {
        // Initial page: keep realtime newer messages + offline outbox.
        final pageIds = page.map((m) => m.id).toSet();
        final newerLive = current
            .where((m) => !pageIds.contains(m.id) && !m.isLocalPending)
            .where(
              (m) =>
                  page.isEmpty ||
                  !m.timestamp.isBefore(page.last.timestamp),
            )
            .toList();
        _messages[conversationId] = [...page, ...newerLive, ...pendingLocal]
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }

      _resolveReplies(conversationId);
      await _loadCommentsFor(conversationId);
      return _hasMoreMessages[conversationId] ?? false;
    } finally {
      _loadingMessages[conversationId] = false;
      notifyListeners();
    }
  }

  Future<Map<String, Map<String, String>>> _loadReactionsFor(
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return {};
    final reactionRows = await _client
        .from('message_reactions')
        .select(
          'message_id, emoji, profiles!message_reactions_user_id_fkey(login)',
        )
        .inFilter('message_id', messageIds);

    final reactionsByMessage = <String, Map<String, String>>{};
    for (final row in (reactionRows as List).cast<Map<String, dynamic>>()) {
      final messageId = row['message_id'] as String;
      final emoji = row['emoji'] as String;
      final login =
          (row['profiles'] as Map<String, dynamic>?)?['login'] as String?;
      if (login != null) {
        reactionsByMessage.putIfAbsent(messageId, () => {})[login] = emoji;
      }
    }
    return reactionsByMessage;
  }

  Future<void> _mergeReadsFor(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final messageIds = rows.map((r) => r['id'] as String).toList();
    final readRows = await _client
        .from('message_reads')
        .select('message_id, user_id')
        .inFilter('message_id', messageIds);

    final senderByMessageId = {
      for (final row in rows) row['id'] as String: row['sender_id'] as String?,
    };
    final convByMessageId = {
      for (final row in rows)
        row['id'] as String: row['conversation_id'] as String,
    };

    for (final row in (readRows as List).cast<Map<String, dynamic>>()) {
      final messageId = row['message_id'] as String?;
      final readerId = row['user_id'] as String?;
      if (messageId == null || readerId == null) continue;
      final convId = convByMessageId[messageId];
      if (convId == null) continue;

      if (readerId == _userId) {
        _readByMe.putIfAbsent(convId, () => {}).add(messageId);
      } else if (senderByMessageId[messageId] == _userId) {
        _readByOthers.add(messageId);
      }
    }
  }

  Future<void> _loadCommentsFor(String conversationId) async {
    final commentRows = await _client
        .from('message_comments')
        .select(
          '*, sender:profiles!message_comments_sender_id_fkey(login, avatar_emoji, avatar_url)',
        )
        .eq('conversation_id', conversationId)
        .order('created_at');

    final keepKeys = _comments.keys
        .where((key) {
          final list = _comments[key];
          return list != null &&
              list.isNotEmpty &&
              list.first.conversationId != conversationId;
        })
        .toList();
    final kept = {
      for (final key in keepKeys) key: _comments[key]!,
    };
    _comments
      ..clear()
      ..addAll(kept);

    for (final row in (commentRows as List).cast<Map<String, dynamic>>()) {
      final comment = _commentFromRow(row);
      final postId = row['post_message_id'] as String;
      _comments.putIfAbsent(postId, () => []).add(comment);
    }
  }

  void _resolveReplies(String conversationId) {
    final list = _messages[conversationId];
    if (list == null) return;
    for (var i = 0; i < list.length; i++) {
      final m = list[i];
      if (m.replyToId == null) continue;
      final reply = _findMessage(m.replyToId!);
      if (reply == null) continue;
      list[i] = m.copyWith(
        replyToSender: reply.senderName,
        replyToContent: messagePreviewText(reply),
      );
    }
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    // Supabase Realtime = WebSocket. Incoming rows arrive here instantly.
    _channel = _client.channel('messenger-$_userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) => unawaited(_onMessageInsert(payload.newRecord)),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        callback: (payload) => _onMessageUpdate(payload.newRecord),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'message_reads',
        callback: (payload) => _onReadInsert(payload.newRecord),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'conversations',
        callback: (_) => _softReload(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'conversation_members',
        callback: (_) => _softReload(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'message_comments',
        callback: (_) => _softReload(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'message_reactions',
        callback: (_) => _softReload(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'message_pins',
        callback: (_) => _softReload(),
      )
      ..onBroadcast(
        event: 'typing',
        callback: (payload) {
          final data = payload['payload'] as Map<String, dynamic>? ?? payload;
          final convId = data['conversation_id'] as String?;
          final login = data['login'] as String?;
          final isTyping = data['is_typing'] as bool? ?? false;
          final activity = data['activity'] as String?;
          if (convId == null || login == null || login == _userLogin) return;

          final typing = List<String>.from(_typingUsers[convId] ?? []);
          final map = Map<String, String>.from(_composerActivity[convId] ?? {});
          if (activity == null || activity.isEmpty) {
            typing.remove(login);
            map.remove(login);
          } else {
            map[login] = activity;
            if (activity == 'typing') {
              if (!typing.contains(login)) typing.add(login);
            } else {
              typing.remove(login);
            }
          }
          if (activity == null && isTyping) {
            if (!typing.contains(login)) typing.add(login);
            map[login] = 'typing';
          }
          _typingUsers[convId] = typing;
          _composerActivity[convId] = map;
          _applyTypingToConversation(convId);
          notifyListeners();
        },
      )
      ..subscribe();
  }

  Future<void> _onMessageInsert(Map<String, dynamic> row) async {
    final id = row['id'] as String?;
    final conversationId = row['conversation_id'] as String?;
    if (id == null || conversationId == null) return;

    final existing = _messages[conversationId];
    if (existing != null && existing.any((m) => m.id == id)) return;

    // Keep chat open even if this conversation was just created remotely.
    if (getConversation(conversationId) == null) {
      _softReload();
      return;
    }

    var senderId = row['sender_id'] as String?;
    var profile = senderId == null ? null : _profilesById[senderId];
    if (profile == null && senderId != null) {
      try {
        final p = await _client
            .from('profiles')
            .select('id, login, avatar_emoji, avatar_url')
            .eq('id', senderId)
            .maybeSingle();
        if (p != null) {
          profile = _ProfileRef(
            login: p['login'] as String,
            emoji: p['avatar_emoji'] as String?,
            avatarUrl: p['avatar_url'] as String?,
          );
          _profilesById[senderId] = profile;
        }
      } catch (_) {}
    }

    final replyToId = row['reply_to_id'] as String?;
    final reply = replyToId == null ? null : _findMessage(replyToId);
    final message = Message(
      id: id,
      conversationId: conversationId,
      senderId: profile?.login ?? 'user',
      senderName: profile?.login ?? 'user',
      type: _parseMessageType(row['type'] as String? ?? 'text'),
      content: row['content'] as String? ?? '',
      timestamp: DateTime.parse(
        row['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      isEdited: row['is_edited'] as bool? ?? false,
      isDeletedForAll: row['is_deleted_for_all'] as bool? ?? false,
      viewCount: row['view_count'] as int? ?? 0,
      senderEmoji: profile?.emoji,
      isRead: profile?.login == _userLogin
          ? _readByOthers.contains(id)
          : (_readByMe[conversationId]?.contains(id) ?? false),
      replyToId: replyToId,
      replyToSender: reply?.senderName,
      replyToContent: reply == null ? null : messagePreviewText(reply),
    );

    _addMessageLocal(message);
    notifyListeners();
  }

  void _onMessageUpdate(Map<String, dynamic> row) {
    final id = row['id'] as String?;
    final conversationId = row['conversation_id'] as String?;
    if (id == null || conversationId == null) return;

    final list = _messages[conversationId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == id);
    if (index == -1) {
      _softReload();
      return;
    }

    list[index] = list[index].copyWith(
      content: row['content'] as String? ?? list[index].content,
      isEdited: row['is_edited'] as bool? ?? list[index].isEdited,
      isDeletedForAll:
          row['is_deleted_for_all'] as bool? ?? list[index].isDeletedForAll,
      viewCount: row['view_count'] as int? ?? list[index].viewCount,
    );
    _syncConversationPreview(conversationId);
    notifyListeners();
  }

  void _onReadInsert(Map<String, dynamic> row) {
    final messageId = row['message_id'] as String?;
    final readerId = row['user_id'] as String?;
    if (messageId == null || readerId == null || readerId == _userId) return;

    final message = _findMessage(messageId);
    if (message == null || message.senderId != _userLogin) return;

    _readByOthers.add(messageId);
    final list = _messages[message.conversationId];
    if (list == null) return;
    final index = list.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    list[index] = list[index].copyWith(isRead: true);
    notifyListeners();
  }

  void _addMessageLocal(Message message) {
    final list = _messages.putIfAbsent(message.conversationId, () => []);
    if (list.any((m) => m.id == message.id)) return;
    list.add(message);
    _updateConversationPreview(message.conversationId, message);

    if (message.senderId != _userLogin &&
        message.conversationId != _activeConversationId) {
      final conversation = getConversation(message.conversationId);
      if (conversation != null) {
        onIncomingMessage?.call(message, conversation);
      }
    }
  }

  void _rememberSender(Map<String, dynamic> row) {
    final senderId = row['sender_id'] as String?;
    final sender = row['sender'] as Map<String, dynamic>?;
    if (senderId == null || sender == null) return;
    final login = sender['login'] as String?;
    if (login == null) return;
    _profilesById[senderId] = _ProfileRef(
      login: login,
      emoji: sender['avatar_emoji'] as String?,
      avatarUrl: sender['avatar_url'] as String? ??
          _profilesById[senderId]?.avatarUrl,
    );
  }

  /// Profile avatar URL for a member login (from cached profiles).
  String? avatarUrlForLogin(String login) {
    final key = login.trim().toLowerCase();
    for (final profile in _profilesById.values) {
      if (profile.login.toLowerCase() == key) return profile.avatarUrl;
    }
    return null;
  }

  /// Profile emoji for a member login (from cached profiles).
  String? emojiForLogin(String login) {
    final key = login.trim().toLowerCase();
    for (final profile in _profilesById.values) {
      if (profile.login.toLowerCase() == key) return profile.emoji;
    }
    return null;
  }

  /// GIFs sent by current user across all conversations (for "My GIFs" tab).
  List<GifHit> collectOwnGifHits() {
    final seen = <String>{};
    final hits = <GifHit>[];
    for (final list in _messages.values) {
      for (final m in list) {
        if (m.type != MessageType.gif) continue;
        if (m.senderId != _userLogin) continue;
        final media = MediaPayload.tryParse(m.content);
        if (media == null || media.url.isEmpty) continue;
        if (!seen.add(media.url)) continue;
        hits.add(GifHit(previewUrl: media.url, url: media.url, name: media.name));
      }
    }
    return hits.reversed.take(40).toList();
  }

  Timer? _reloadDebounce;
  void _softReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 200), () async {
      try {
        await _loadAll(preserveMessages: true);
        unawaited(flushOutbox());
        notifyListeners();
      } catch (e) {
        debugPrint('Chat reload failed: $e');
      }
    });
  }

  Message _messageFromRow(
    Map<String, dynamic> row, {
    Map<String, String> reactions = const {},
    Message? Function(String id)? replyLookup,
  }) {
    final sender = row['sender'] as Map<String, dynamic>?;
    final login = sender?['login'] as String? ?? 'user';
    final conversationId = row['conversation_id'] as String;
    final id = row['id'] as String;
    final isMine = login == _userLogin;
    final readSet = _readByMe[conversationId] ?? {};
    final replyToId = row['reply_to_id'] as String?;
    final reply = replyToId == null ? null : replyLookup?.call(replyToId);

    return Message(
      id: id,
      conversationId: conversationId,
      senderId: login,
      senderName: login,
      type: _parseMessageType(row['type'] as String? ?? 'text'),
      content: row['content'] as String? ?? '',
      timestamp: DateTime.parse(row['created_at'] as String),
      reactions: reactions,
      isEdited: row['is_edited'] as bool? ?? false,
      isDeletedForAll: row['is_deleted_for_all'] as bool? ?? false,
      deletedForMe: _hiddenMessageIds.contains(id),
      isRead: isMine ? _readByOthers.contains(id) : readSet.contains(id),
      viewCount: row['view_count'] as int? ?? 0,
      senderEmoji: sender?['avatar_emoji'] as String?,
      replyToId: replyToId,
      replyToSender: reply?.senderName,
      replyToContent: reply == null ? null : messagePreviewText(reply),
    );
  }

  Message _commentFromRow(Map<String, dynamic> row) {
    final sender = row['sender'] as Map<String, dynamic>?;
    final login = sender?['login'] as String? ?? 'user';
    return Message(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      senderId: login,
      senderName: login,
      type: MessageType.text,
      content: row['content'] as String? ?? '',
      timestamp: DateTime.parse(row['created_at'] as String),
      senderEmoji: sender?['avatar_emoji'] as String?,
    );
  }

  void _updateConversationPreview(String conversationId, Message message) {
    final preview = messagePreviewText(message, maxChars: 80);
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    _conversations[index] = _conversations[index].copyWith(
      lastMessage: preview,
      lastMessageSender: message.type == MessageType.system
          ? null
          : _userLogin,
      lastActivity: message.timestamp,
    );
  }

  void _syncConversationPreview(String conversationId) {
    final visible = getMessages(conversationId);
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;

    if (visible.isEmpty) {
      _conversations[index] = _conversations[index].copyWith(
        lastMessage: '',
        lastMessageSender: null,
      );
      return;
    }

    final last = visible.last;
    _conversations[index] = _conversations[index].copyWith(
      lastMessage: messagePreviewText(last, maxChars: 80),
      lastMessageSender: last.type == MessageType.system
          ? null
          : (last.senderId == _userLogin ? _userLogin : last.senderName),
      lastActivity: last.timestamp,
    );
  }

  Future<void> _unpinMessageLocal(
    String conversationId,
    String messageId,
  ) async {
    _pinnedForMe[conversationId]?.remove(messageId);
    _pinnedForEveryone[conversationId]?.remove(messageId);
    await _client
        .from('message_pins')
        .delete()
        .eq('message_id', messageId)
        .eq('conversation_id', conversationId);
  }

  Future<void> _replaceConversation(Conversation updated) async {
    final index = _conversations.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _conversations[index] = updated;
    }
  }

  void _applyTypingToConversation(String conversationId) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    _conversations[index] = _conversations[index].copyWith(
      typingUsers: List<String>.from(_typingUsers[conversationId] ?? const []),
    );
  }

  ConversationType _parseType(String value) {
    return ConversationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ConversationType.direct,
    );
  }

  MessageType _parseMessageType(String value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }
}

class _ProfileRef {
  const _ProfileRef({required this.login, this.emoji, this.avatarUrl});

  final String login;
  final String? emoji;
  final String? avatarUrl;
}

/// Result of a global message search: the message plus its conversation.
class MessageSearchHit {
  const MessageSearchHit({required this.conversation, required this.message});

  final Conversation conversation;
  final Message message;
}
