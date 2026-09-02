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

/// Direct GIF URLs so the picker is never empty if search APIs are blocked.
const _kCats = <_CatGif>[
  _CatGif(id: '1ozkXaGbz1CriQiG', name: 'water cat', tags: ['cat', 'кот', 'water']),
  _CatGif(id: '2tKejk7oauPg3Yt4', name: 'hug cat', tags: ['cat', 'кот', 'hug', 'cute']),
  _CatGif(id: '3mEJCz1Oj7l1E2tm', name: 'angry cat', tags: ['cat', 'кот', 'angry', 'wtf']),
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

/// Animated fallbacks hosted on Giphy CDN — memes + cats, CORS-friendly on web.
const _kAnimatedFallback = <GifHit>[
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
  GifHit(previewUrl: 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif', url: 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif', name: 'love'),
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
  GifHit(previewUrl: 'https://media.giphy.com/media/26gsjCZpPolPr3sBy/giphy.gif', url: 'https://media.giphy.com/media/26gsjCZpPolPr3sBy/giphy.gif', name: 'fail'),
  GifHit(previewUrl: 'https://media.giphy.com/media/3o7TKMt1VVNkHV2PaE/giphy.gif', url: 'https://media.giphy.com/media/3o7TKMt1VVNkHV2PaE/giphy.gif', name: 'confused'),
];

const _kMemeTags = <String>[
  'meme', 'lol', 'funny', 'fail', 'wow', 'omg', 'nope', 'yes', 'party',
  'clap', 'facepalm', 'awkward', 'deal', 'fine', 'shrug', 'thumbs',
];

const _kOtakuReactions = <String>[
  'happy', 'wave', 'clap', 'yay', 'thumbsup', 'dance', 'hug', 'cool',
  'yes', 'no', 'laugh', 'love', 'sad', 'cry', 'confused', 'facepalm',
  'celebrate', 'sleep', 'wink', 'woah',
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
  'yes': 'yes',
  'no': 'no',
  'love': 'love',
  'люблю': 'love',
  'lol': 'laugh',
  'ха': 'laugh',
  'lolol': 'laugh',
  'sad': 'sad',
  'груст': 'sad',
  'cry': 'cry',
  'dance': 'dance',
  'танц': 'dance',
  'hug': 'hug',
  'обним': 'hug',
  'wow': 'woah',
  'omg': 'surprised',
  'clap': 'clap',
  'браво': 'clap',
  'yay': 'yay',
  'win': 'celebrate',
  'ура': 'celebrate',
  'sleep': 'sleep',
  'спать': 'sleep',
  'coffee': 'sip',
  'кофе': 'sip',
  'work': 'sweat',
  'код': 'cool',
  'code': 'cool',
};

Future<List<GifHit>> searchGifs(String rawQuery) async {
  final q = rawQuery.trim().toLowerCase();
  final hits = <GifHit>[];
  final seen = <String>{};

  void add(GifHit hit) {
    if (hit.url.isEmpty || !seen.add(hit.url)) return;
    hits.add(hit);
  }

  // Local cats filtered by query — instant, no network.
  for (final item in _kCats) {
    if (q.isEmpty ||
        item.name.contains(q) ||
        item.tags.any((t) => t.contains(q) || q.contains(t))) {
      add(GifHit(previewUrl: item.url, url: item.url, name: item.name));
    }
  }
  // Meme / humor catalog — always mix into results.
  final wantMemes = q.isEmpty ||
      _kMemeTags.any((t) => q.contains(t) || t.contains(q)) ||
      q == 'gif' ||
      q == 'гиф' ||
      q == 'мем' ||
      q == 'meme' ||
      q == 'lol' ||
      q == 'смех' ||
      q == 'funny';
  if (wantMemes || q.isEmpty) {
    for (final hit in _kAnimatedFallback) {
      if (q.isEmpty ||
          wantMemes ||
          hit.name.contains(q) ||
          q.contains(hit.name.split(' ').first)) {
        add(hit);
      }
    }
  } else {
    for (final hit in _kAnimatedFallback) {
      if (hit.name.contains(q) || q.contains(hit.name.split(' ').first)) {
        add(hit);
      }
    }
  }

  await Future.wait([
    _cataas(q).then((list) {
      for (final hit in list) {
        add(hit);
      }
    }).catchError((_) {}),
    _otaku(q).then((list) {
      for (final hit in list) {
        add(hit);
      }
    }).catchError((_) {}),
  ]);

  if (hits.isEmpty) {
    for (final item in _kCats) {
      add(GifHit(previewUrl: item.url, url: item.url, name: item.name));
    }
    for (final hit in _kAnimatedFallback) {
      add(hit);
    }
  }
  return hits;
}

Future<List<GifHit>> _cataas(String query) async {
  // Try specific tag first, fall back to generic gif if no hits.
  final attempts = <String>[];
  if (query.isEmpty ||
      query == 'cat' ||
      query == 'кот' ||
      query == 'gif' ||
      query == 'гиф') {
    attempts.add('gif');
  } else {
    attempts.add(query);
    attempts.add('gif');
  }
  for (final tags in attempts) {
    try {
      final uri = Uri.https('cataas.com', '/api/cats', {
        'limit': '16',
        'tags': tags,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) continue;
      final json = jsonDecode(response.body);
      if (json is! List || json.isEmpty) continue;
      final hits = <GifHit>[];
      for (final raw in json) {
        if (raw is! Map) continue;
        final id = raw['id'] as String?;
        if (id == null || id.isEmpty) continue;
        final url = 'https://cataas.com/cat/$id';
        final rawTags = raw['tags'];
        final name = rawTags is List && rawTags.isNotEmpty
            ? rawTags.first.toString()
            : 'cat';
        hits.add(GifHit(previewUrl: url, url: url, name: name));
      }
      if (hits.isNotEmpty) return hits;
    } catch (_) {
      continue;
    }
  }
  return const [];
}

Future<List<GifHit>> _otaku(String query) async {
  final reactions = _reactionsFor(query);
  if (reactions.isEmpty) return const [];
  final results = await Future.wait(
    reactions.take(8).map((reaction) async {
      final uri = Uri.https('api.otakugifs.xyz', '/gif', {
        'reaction': reaction,
        'format': 'gif',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body);
      if (json is! Map) return null;
      final url = json['url'] as String?;
      if (url == null || url.isEmpty) return null;
      return GifHit(previewUrl: url, url: url, name: reaction);
    }),
  );
  return results.whereType<GifHit>().toList();
}

List<String> _reactionsFor(String query) {
  if (query.isEmpty || query == 'cat' || query == 'кот' || query == 'gif') {
    return _kOtakuReactions.take(8).toList();
  }
  for (final entry in _kQueryToReaction.entries) {
    if (query.contains(entry.key) || entry.key.contains(query)) {
      return [entry.value];
    }
  }
  final matched = _kOtakuReactions
      .where((r) => r.contains(query) || query.contains(r))
      .toList();
  return matched.isEmpty ? const [] : matched;
}
