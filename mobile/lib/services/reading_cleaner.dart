import '../models/app_models.dart';

class ReadingCleaner {
  static final List<RegExp> _lineFilters = [
    RegExp(
      r'^\s*(最新网址|备用网址|本章未完|本章完|手机用户请|求收藏|求推荐|求月票|广告|推广|微信公众号|关注公众号)',
      caseSensitive: false,
    ),
    RegExp(r'^\s*(PS[:：]|注[:：]|作者有话说[:：])', caseSensitive: false),
    RegExp(
      r'(www\.|\.com|\.cn|\.net|公众号|微信|QQ交流群)',
      caseSensitive: false,
    ),
  ];

  static String cleanRawText(
    String rawText, {
    required bool enabled,
    List<ReplaceRule> replaceRules = const [],
  }) {
    var text = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text.replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&');

    if (!enabled) {
      return text.trim();
    }

    for (final rule in replaceRules.where((item) => item.enabled)) {
      if (rule.pattern.isEmpty) {
        continue;
      }
      try {
        text = text.replaceAll(RegExp(rule.pattern, multiLine: true), rule.replacement);
      } catch (_) {}
    }

    final seen = <String>{};
    final paragraphs = <String>[];
    for (final rawLine in text.split('\n')) {
      final line = rawLine
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll('\u3000', ' ')
          .trim();
      if (line.isEmpty) {
        continue;
      }
      if (line.length < 80 && _lineFilters.any((pattern) => pattern.hasMatch(line))) {
        continue;
      }
      if (seen.contains(line) && line.length < 40) {
        continue;
      }
      seen.add(line);
      paragraphs.add(line);
    }

    return paragraphs.join('\n\n').trim();
  }

  static List<String> paragraphs(
    String rawText, {
    required bool enabled,
    List<ReplaceRule> replaceRules = const [],
  }) {
    final cleaned = cleanRawText(
      rawText,
      enabled: enabled,
      replaceRules: replaceRules,
    );
    return cleaned
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
