import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/match_candidate.dart';
import '../models/user.dart';
import 'analytics_service.dart';

/// Swipe-based team-building matching.
class MatchService extends ChangeNotifier {
  MatchService();

  final _client = Supabase.instance.client;

  List<MatchCandidate> _feed = const [];
  List<MatchCandidate> _matches = const [];
  List<MatchCandidate> _likedMe = const [];
  List<MatchCandidate> _iLiked = const [];
  bool _loadingFeed = false;
  bool _loadingMatches = false;
  bool _loadingLiked = false;
  bool _swiping = false;
  String? _feedError;
  String? _matchesError;

  List<MatchCandidate> get feed => _feed;
  List<MatchCandidate> get matches => _matches;
  List<MatchCandidate> get likedMe => _likedMe;
  List<MatchCandidate> get iLiked => _iLiked;
  bool get isLoadingFeed => _loadingFeed;
  bool get isLoadingMatches => _loadingMatches;
  bool get isLoadingLiked => _loadingLiked;
  bool get isSwiping => _swiping;
  String? get feedError => _feedError;
  String? get matchesError => _matchesError;
  MatchCandidate? get current => _feed.isEmpty ? null : _feed.first;

  Future<void> refreshFeed() async {
    _loadingFeed = true;
    _feedError = null;
    notifyListeners();

    try {
      final rows = await _client.rpc('get_match_feed', params: {'p_limit': 40});
      _feed = (rows as List)
          .map((row) =>
              MatchCandidate.fromRow(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('Match feed failed: $e');
      try {
        await _refreshFeedFromProfiles();
      } catch (fallback) {
        debugPrint('Match fallback failed: $fallback');
        _feedError = e.toString();
      }
    } finally {
      _loadingFeed = false;
      notifyListeners();
    }
  }

  Future<void> _refreshFeedFromProfiles() async {
    dynamic rows;
    try {
      rows = await _client
          .from('public_profiles')
          .select()
          .eq('is_bot', false)
          .limit(40);
    } catch (_) {
      rows = await _client
          .from('profiles')
          .select(
            'id, login, status, avatar_emoji, avatar_url, is_bot, '
            'dev_status, skills, experience_level, github_url, '
            'portfolio_url, city',
          )
          .eq('is_bot', false)
          .limit(40);
    }
    final feed = <MatchCandidate>[];
    if (rows is List) {
      for (final raw in rows) {
        final map = Map<String, dynamic>.from(raw as Map);
        final candidate = MatchCandidate.fromRow(map);
        if (candidate.user.devStatus == DevStatus.none &&
            candidate.user.skills.isEmpty) {
          continue;
        }
        feed.add(candidate);
      }
    }
    _feed = feed;
    _feedError = null;
  }

  Future<void> refreshMatches() async {
    _loadingMatches = true;
    _matchesError = null;
    notifyListeners();

    try {
      final rows = await _client.rpc('get_my_matches');
      _matches = (rows as List)
          .map((row) =>
              MatchCandidate.fromRow(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (e) {
      debugPrint('Matches load failed: $e');
      _matchesError = e.toString();
    } finally {
      _loadingMatches = false;
      notifyListeners();
    }
  }

  Future<void> refreshLiked() async {
    _loadingLiked = true;
    notifyListeners();
    try {
      final meRows = await _client.rpc('get_who_liked_me');
      _likedMe = (meRows as List).map((r) => MatchCandidate.fromRow(Map<String, dynamic>.from(r as Map))).toList();
    } catch (e) {
      debugPrint('who liked me failed: $e');
      _likedMe = const [];
    }
    try {
      final iRows = await _client.rpc('get_whom_i_liked');
      _iLiked = (iRows as List).map((r) => MatchCandidate.fromRow(Map<String, dynamic>.from(r as Map))).toList();
    } catch (e) {
      debugPrint('whom i liked failed: $e');
      _iLiked = const [];
    } finally {
      _loadingLiked = false;
      notifyListeners();
    }
  }

  /// Records a like/pass for [candidate]. Returns true on mutual match.
  Future<bool?> swipe({
    required MatchCandidate candidate,
    required bool liked,
  }) async {
    if (_swiping) return null;

    _swiping = true;
    notifyListeners();

    try {
      final rows = await _client.rpc(
        'swipe_match',
        params: {
          'p_target_id': candidate.user.id,
          'p_liked': liked,
        },
      );
      final isMatch = rows is List &&
          rows.isNotEmpty &&
          (Map<String, dynamic>.from(rows.first as Map)['is_match'] == true);

      _feed =
          _feed.where((c) => c.user.id != candidate.user.id).toList(growable: false);
      if (isMatch) {
        await refreshMatches();
        await AnalyticsService.instance.track('match_mutual', {
          'target': candidate.user.login,
        });
      } else {
        await AnalyticsService.instance.track(
          liked ? 'match_like' : 'match_pass',
          {'target': candidate.user.login},
        );
      }
      return isMatch;
    } catch (e) {
      debugPrint('Swipe failed: $e');
      rethrow;
    } finally {
      _swiping = false;
      notifyListeners();
    }
  }

  /// Clears passes so people you skipped can appear again (keeps mutual likes).
  Future<void> restartUnmatchedFeed() async {
    _loadingFeed = true;
    _feedError = null;
    notifyListeners();
    try {
      await _client.rpc('reset_match_passes');
    } catch (e) {
      debugPrint('reset_match_passes failed: $e');
      // Soft fallback: reload feed as-is if SQL not applied yet.
    }
    await refreshFeed();
  }

  /// Drops blocked users from the local feed and records a pass on the server
  /// so they do not reappear on the next refresh.
  Future<void> skipBlockedLogins(Iterable<String> blockedLogins) async {
    final blocked = blockedLogins.map((e) => e.toLowerCase()).toSet();
    if (blocked.isEmpty || _feed.isEmpty) return;

    final toSkip = _feed
        .where((c) => blocked.contains(c.user.login.toLowerCase()))
        .toList(growable: false);
    if (toSkip.isEmpty) return;

    final skipIds = toSkip.map((c) => c.user.id).toSet();
    _feed =
        _feed.where((c) => !skipIds.contains(c.user.id)).toList(growable: false);
    notifyListeners();

    for (final candidate in toSkip) {
      try {
        await _client.rpc(
          'swipe_match',
          params: {
            'p_target_id': candidate.user.id,
            'p_liked': false,
          },
        );
      } catch (e) {
        debugPrint('Skip blocked match failed: $e');
      }
    }
  }
}
