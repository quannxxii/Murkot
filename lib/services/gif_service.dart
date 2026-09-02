import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class GifHit {
  const GifHit({
    required this.previewUrl,
    required this.url,
    required this.name,
  });

  final String previewUrl;
  final String url;
  final String name;
}

class _CatGif {
  const _CatGif({required this.id, required this.name, required this.tags});

  final String id;
  final String name;
  final List<String> tags;

  String get url => 'https://cataas.com/cat/$id';
}

const _kCats = <_CatGif>[
  _CatGif(id: '1ozkXaGbz1CriQiG', name: 'water cat', tags: ['cat', 'кот', 'water']),
  _CatGif(id: '2tKejk7oauPg3Yt4', name: 'hug cat', tags: ['cat', 'кот', 'hug', 'cute']),
  _CatGif(id: '3mEJCz1Oj7l1E2tm', name: 'surprise cat', tags: ['cat', 'кот', 'surprise', 'wtf']),
  _CatGif(id: '3Z6CcYkHotdUXQC9', name: 'please kitten', tags: ['cat', 'кот', 'cute', 'please']),
  _CatGif(id: '48xLBZGSXgxZRMAB', name: 'sleepy kitten', tags: ['cat', 'кот', 'sleep', 'sleepy']),
  _CatGif(id: '2T7yPn3J5qz54Ygy', name: 'cake cat', tags: ['cat', 'кот', 'cake', 'party']),
  _CatGif(id: '3prWPtfRjrBXs9M7', name: 'jump kitten', tags: ['cat', 'кот', 'jump', 'kitten']),
  _CatGif(id: '60qItVZj8MctIDlg', name: 'omg cat', tags: ['cat', 'кот', 'omg', 'wow']),
  _CatGif(id: '6QhBxfMg4BuXGetL', name: 'fail cat', tags: ['cat', 'кот', 'fail', 'bug']),
  _CatGif(id: '6SzRQLt0yiPjLyNi', name: 'meow', tags: ['cat', 'кот', 'meow']),
  _CatGif(id: '7oTjTbSAhqeQCl7O', name: 'space cat', tags: ['cat', 'кот', 'space']),
  _CatGif(id: '8nqmX1ooqvk4fzRU', name: 'kitten', tags: ['cat', 'кот', 'kitten']),
  _CatGif(id: 'AjPwxqduWA4Yd5T8', name: 'slip cat', tags: ['cat', 'кот', 'slap', 'fail']),
  _CatGif(id: '9WFz0kCbRxtVQQOn', name: 'costume cat', tags: ['cat', 'кот', 'costume']),
  _CatGif(id: 'AYJNTBAktmH3Q7ka', name: 'cat gif', tags: ['cat', 'кот']),
  _CatGif(id: '5a3YH3bjZJWlsZ95', name: 'cat', tags: ['cat', 'кот']),
];

const _kCatalog = <GifHit>[
  GifHit(previewUrl: 'https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif', url: 'https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif', name: 'cat dance'),
  GifHit(previewUrl: 'https://media.giphy.com/media/mlvseq9yvZhba/giphy.gif', url: 'https://media.giphy.com/media/mlvseq9yvZhba/giphy.gif', name: 'cat typing'),
  GifHit(previewUrl: 'https://media.giphy.com/media/3o6ZtaO9wxbmR7De8U/giphy.gif', url: 'https://media.giphy.com/media/3o6ZtaO9wxbmR7De8U/giphy.gif', name: 'cat hug'),
  GifHit(previewUrl: 'https://media.giphy.com/media/o0vwzuFwVaAc0/giphy.gif', url: 'https://media.giphy.com/media/o0vwzuFwVaAc0/giphy.gif', name: 'cat wow'),
  GifHit(previewUrl: 'https://media.giphy.com/media/12XMGIWtrHBl5e/giphy.gif', url: 'https://media.giphy.com/media/12XMGIWtrHBl5e/giphy.gif', name: 'cat laugh'),
  GifHit(previewUrl: 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif', url: 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif', name: 'cat heart'),
  GifHit(previewUrl: 'https://media.giphy.com/media/3oriO0OEd9QIDdllqo/giphy.gif', url: 'https://media.giphy.com/media/3oriO0OEd9QIDdllqo/giphy.gif', name: 'cat sleeping'),
  GifHit(previewUrl: 'https://media.giphy.com/media/wKNI6F6M1Cha/giphy.gif', url: 'https://media.giphy.com/media/wKNI6F6M1Cha/giphy.gif', name: 'cat work'),
  GifHit(previewUrl: 'https://media.giphy.com/media/5VKbvrjxpVJCM/giphy.gif', url: 'https://media.giphy.com/media/5VKbvrjxpVJCM/giphy.gif', name: 'this is fine'),
  GifHit(previewUrl: 'https://media.giphy.com/media/3o7aCTPPm4OHfRLSH6/giphy.gif', url: 'https://media.giphy.com/media/3o7aCTPPm4OHfRLSH6/giphy.gif', name: 'mind blown'),
  GifHit(previewUrl: 'https://media.giphy.com/media/26BRv0ThAiIdPKWU0/giphy.gif', url: 'https://media.giphy.com/media/26BRv0ThAiIdPKWU0/giphy.gif', name: 'nope'),
  GifHit(previewUrl: 'https://media.giphy.com/media/l3q2K5jinAlChoCLS/giphy.gif', url: 'https://media.giphy.com/media/l3q2K5jinAlChoCLS/giphy.gif', name: 'awkward'),
  GifHit(previewUrl: 'https://media.giphy.com/media/3orieUeweTEpj2ysE8/giphy.gif', url: 'https://media.giphy.com/media/3orieUeweTEpj2ysE8/giphy.gif', name: 'deal with it'),
  GifHit(previewUrl: 'https://media.giphy.com/media/26gsjCZpPolPr3sBy/giphy.gif', url: 'https://media.giphy.com/media/26gsjCZpPolPr3sBy/giphy.gif', name: 'facepalm'),
  GifHit(previewUrl: 'https://media.giphy.com/media/3o6Zt6ML6BklcajjsA/giphy.gif', url: 'https://media.giphy.com/media/3o6Zt6ML6BklcajjsA/giphy.gif', name: 'laugh cry'),
  GifHit(previewUrl: 'https://media.giphy.com/media/l0HlvtIPzPdt2usKs/giphy.gif', url: 'https://media.giphy.com/media/l0HlvtIPzPdt2usKs/giphy.gif', name: 'wow'),
  GifHit(previewUrl: 'https://media.giphy.com/media/xT0xeJpnrWC4XWblEk/giphy.gif', url: 'https://media.giphy.com/media/xT0xeJpnrWC4XWblEk/giphy.gif', name: 'clap'),
  GifHit(previewUrl: 'https://media.giphy.com/media/26ufdipQqUJ7FM4Ym/giphy.gif', url: 'https://media.giphy.com/media/26ufdipQqUJ7FM4Ym/giphy.gif', name: 'thumbs up'),
  GifHit(previewUrl: 'https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif', url: 'https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif', name: 'loading'),
  GifHit(previewUrl: 'https://media.giphy.com/media/26BRuo6sLetdllPAQ/giphy.gif', url: 'https://media.giphy.com/media/26BRuo6sLetdllPAQ/giphy.gif', name: 'shrug'),
  GifHit(previewUrl: 'https://media.giphy.com/media/l0MYC0LajbaPoEADu/giphy.gif', url: 'https://media.giphy.com/media/l0MYC0LajbaPoEADu/giphy.gif', name: 'party'),
  GifHit(previewUrl: 'https://media.giphy.com/media/3o7TKMt1VVNkHV2PaE/giphy.gif', url: 'https://media.giphy.com/media/3o7TKMt1VVNkHV2PaE/giphy.gif', name: 'confused'),
];

const _kOtakuReactions = <String>[
  'happy', 'wave', 'clap', 'yay', 'thumbsup', 'dance', 'hug', 'cool',
  'yes', 'no', 'laugh', 'love', 'sad', 'cry', 'confused', 'facepalm',
];

const _kQueryToReaction = <String, String>{
  'hi': 'wave',
  'hello': 'wave',
  'привет': 'wave',
  'пока': 'wave',
  'да': 'yes',
  'нет': 'no',
  'ok': 'thumbsup',
  'ок': 'thumbsup',
  'love': 'love',
  'люблю': 'love',
  'lol': 'laugh',
  'ха': 'laugh',
  'sad': 'sad',
  'груст': 'sad',
  'dance': 'dance',
  'танц': 'dance',
  'hug': 'hug',
  'обним': 'hug',
  'wow': 'woah',
  'clap': 'clap',
  'браво': 'clap',
};

/// Instant local catalog — never waits on network.
List<GifHit> searchGifsLocal(String rawQuery) {
  final q = rawQuery.trim().toLowerCase();
  final hits = <GifHit>[];
  final seen = <String>{};

  void add(GifHit hit) {
    if (hit.url.isEmpty || !seen.add(hit.url)) return;
    hits.add(hit);
  }

  for (final item in _kCats) {
    if (q.isEmpty ||
        item.name.contains(q) ||
        item.tags.any((t) => t.contains(q) || q.contains(t))) {
      add(GifHit(previewUrl: item.url, url: item.url, name: item.name));
    }
  }
  for (final hit in _kCatalog) {
    if (q.isEmpty ||
        hit.name.contains(q) ||
        q.split(RegExp(r'\s+')).any((w) => w.isNotEmpty && hit.name.contains(w))) {
      add(hit);
    }
  }
  if (hits.isEmpty) {
    for (final hit in _kCatalog) {
      add(hit);
    }
    for (final item in _kCats) {
      add(GifHit(previewUrl: item.url, url: item.url, name: item.name));
    }
  }
  return hits;
}

/// Local results first; optional short network enrich (never hangs the UI).
Future<List<GifHit>> searchGifs(String rawQuery) async {
  final local = searchGifsLocal(rawQuery);
  final q = rawQuery.trim().toLowerCase();
  final seen = {for (final h in local) h.url};
  final merged = List<GifHit>.from(local);

  void add(GifHit hit) {
    if (hit.url.isEmpty || !seen.add(hit.url)) return;
    merged.add(hit);
  }

  try {
    await Future.wait([
      _otaku(q).timeout(const Duration(seconds: 2)).then((list) {
        for (final hit in list) {
          add(hit);
        }
      }).catchError((_) {}),
      _cataas(q).timeout(const Duration(seconds: 2)).then((list) {
        for (final hit in list) {
          add(hit);
        }
      }).catchError((_) {}),
    ]).timeout(const Duration(seconds: 3));
  } catch (_) {
    // Keep local results.
  }
  return merged;
}

Future<List<GifHit>> _cataas(String query) async {
  final tags = (query.isEmpty ||
          query == 'cat' ||
          query == 'кот' ||
          query == 'gif' ||
          query == 'гиф')
      ? 'gif'
      : query;
  try {
    final uri = Uri.https('cataas.com', '/api/cats', {
      'limit': '12',
      'tags': tags,
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 2));
    if (response.statusCode != 200) return const [];
    final json = jsonDecode(response.body);
    if (json is! List || json.isEmpty) return const [];
    final hits = <GifHit>[];
    for (final raw in json) {
      if (raw is! Map) continue;
      final id = raw['id'] as String?;
      if (id == null || id.isEmpty) continue;
      final url = 'https://cataas.com/cat/$id';
      hits.add(GifHit(previewUrl: url, url: url, name: 'cat'));
    }
    return hits;
  } catch (_) {
    return const [];
  }
}

Future<List<GifHit>> _otaku(String query) async {
  final reactions = _reactionsFor(query).take(3).toList();
  if (reactions.isEmpty) return const [];
  final results = await Future.wait(
    reactions.map((reaction) async {
      try {
        final uri = Uri.https('api.otakugifs.xyz', '/gif', {
          'reaction': reaction,
          'format': 'gif',
        });
        final response =
            await http.get(uri).timeout(const Duration(seconds: 2));
        if (response.statusCode != 200) return null;
        final json = jsonDecode(response.body);
        if (json is! Map) return null;
        final url = json['url'] as String?;
        if (url == null || url.isEmpty) return null;
        return GifHit(previewUrl: url, url: url, name: reaction);
      } catch (_) {
        return null;
      }
    }),
  );
  return results.whereType<GifHit>().toList();
}

List<String> _reactionsFor(String query) {
  if (query.isEmpty || query == 'gif' || query == 'гиф') {
    return _kOtakuReactions.take(3).toList();
  }
  for (final entry in _kQueryToReaction.entries) {
    if (query.contains(entry.key) || entry.key.contains(query)) {
      return [entry.value];
    }
  }
  return const [];
}
