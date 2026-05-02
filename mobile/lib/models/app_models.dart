import '../app_config.dart';

class ReaderUser {
  const ReaderUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.membershipTier,
  });

  final String id;
  final String email;
  final String displayName;
  final String membershipTier;

  factory ReaderUser.fromJson(Map<String, dynamic> json) {
    return ReaderUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '主人',
      membershipTier: json['membershipTier'] as String? ?? 'founder',
    );
  }
}

class SessionState {
  const SessionState({
    required this.baseUrl,
    required this.token,
    required this.user,
  });

  final String baseUrl;
  final String token;
  final ReaderUser? user;

  bool get isReady => user != null;

  SessionState copyWith({
    String? baseUrl,
    String? token,
    ReaderUser? user,
    bool clearUser = false,
  }) {
    return SessionState(
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
      user: clearUser ? null : (user ?? this.user),
    );
  }

  static const empty = SessionState(
    baseUrl: AppConfig.apiBaseUrl,
    token: AppConfig.apiToken,
    user: null,
  );
}

class ShelfBook {
  const ShelfBook({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.intro,
    required this.wordCount,
    required this.sourceId,
    required this.sourceKey,
    required this.bookUrl,
    required this.type,
    required this.currentChapter,
    required this.currentChapterIndex,
    required this.progress,
    required this.updatedAt,
    required this.origin,
  });

  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final String intro;
  final String wordCount;
  final String sourceId;
  final String sourceKey;
  final String bookUrl;
  final int type;
  final String currentChapter;
  final int currentChapterIndex;
  final double progress;
  final DateTime updatedAt;
  final String origin;

  bool get canResume => sourceKey.isNotEmpty && bookUrl.isNotEmpty;

  factory ShelfBook.fromJson(Map<String, dynamic> json) {
    return ShelfBook(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      intro: json['intro'] as String? ?? '',
      wordCount: json['wordCount'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? '',
      sourceKey: json['sourceKey'] as String? ?? '',
      bookUrl: json['bookUrl'] as String? ?? '',
      type: (json['type'] as num? ?? 0).toInt(),
      currentChapter: json['currentChapter'] as String? ?? '开始阅读',
      currentChapterIndex: (json['currentChapterIndex'] as num? ?? 0).toInt(),
      progress: (json['progress'] as num? ?? 0).toDouble(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      origin: json['origin'] as String? ?? 'manual',
    );
  }
}

class SourceRule {
  const SourceRule({
    required this.id,
    required this.sourceKey,
    required this.name,
    required this.url,
    required this.type,
    required this.group,
    required this.comment,
    required this.order,
    required this.enabled,
    required this.enabledExplore,
    required this.lastCheckStatus,
    required this.lastCheckReason,
    required this.capabilities,
  });

  final String id;
  final String sourceKey;
  final String name;
  final String url;
  final String type;
  final String group;
  final String comment;
  final int order;
  final bool enabled;
  final bool enabledExplore;
  final String lastCheckStatus;
  final String lastCheckReason;
  final SourceCapabilities capabilities;

  factory SourceRule.fromJson(Map<String, dynamic> json) {
    return SourceRule(
      id: json['id'] as String? ?? '',
      sourceKey: json['sourceKey'] as String? ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      type: json['type'] as String? ?? 'book',
      group: json['group'] as String? ?? '',
      comment: json['comment'] as String? ?? '',
      order: (json['order'] as num? ?? 0).toInt(),
      enabled: json['enabled'] as bool? ?? true,
      enabledExplore: json['enabledExplore'] as bool? ?? true,
      lastCheckStatus: json['lastCheckStatus'] as String? ?? 'unknown',
      lastCheckReason: json['lastCheckReason'] as String? ?? '',
      capabilities: SourceCapabilities.fromJson(
        json['capabilities'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }
}

class SourceCapabilities {
  const SourceCapabilities({
    required this.supportsText,
    required this.supportsComic,
    required this.supportsAudio,
    required this.searchable,
    required this.explorable,
    required this.preferredMode,
  });

  final bool supportsText;
  final bool supportsComic;
  final bool supportsAudio;
  final bool searchable;
  final bool explorable;
  final String preferredMode;

  factory SourceCapabilities.fromJson(Map<String, dynamic> json) {
    return SourceCapabilities(
      supportsText: json['supportsText'] as bool? ?? false,
      supportsComic: json['supportsComic'] as bool? ?? false,
      supportsAudio: json['supportsAudio'] as bool? ?? false,
      searchable: json['searchable'] as bool? ?? true,
      explorable: json['explorable'] as bool? ?? false,
      preferredMode: json['preferredMode'] as String? ?? 'text',
    );
  }
}

class ReadingSourceRef {
  const ReadingSourceRef({
    required this.id,
    required this.name,
    required this.bookSourceUrl,
    this.capabilities = const SourceCapabilities(
      supportsText: true,
      supportsComic: false,
      supportsAudio: false,
      searchable: true,
      explorable: false,
      preferredMode: 'text',
    ),
  });

  final String id;
  final String name;
  final String bookSourceUrl;
  final SourceCapabilities capabilities;

  factory ReadingSourceRef.fromJson(Map<String, dynamic> json) {
    return ReadingSourceRef(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      bookSourceUrl: json['bookSourceUrl'] as String? ?? '',
      capabilities: SourceCapabilities.fromJson(
        json['capabilities'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }
}

class ReadingBook {
  const ReadingBook({
    required this.bookUrl,
    required this.tocUrl,
    required this.sourceUrl,
    required this.sourceName,
    required this.type,
    required this.name,
    required this.author,
    required this.kind,
    required this.intro,
    required this.wordCount,
    required this.latestChapterTitle,
    required this.coverUrl,
  });

  final String bookUrl;
  final String tocUrl;
  final String sourceUrl;
  final String sourceName;
  final int type;
  final String name;
  final String author;
  final String kind;
  final String intro;
  final String wordCount;
  final String latestChapterTitle;
  final String coverUrl;

  factory ReadingBook.fromJson(Map<String, dynamic> json) {
    return ReadingBook(
      bookUrl: json['bookUrl'] as String? ?? '',
      tocUrl: json['tocUrl'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      sourceName: json['sourceName'] as String? ?? '',
      type: (json['type'] as num? ?? 0).toInt(),
      name: json['name'] as String? ?? '',
      author: json['author'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      intro: json['intro'] as String? ?? '',
      wordCount: json['wordCount'] as String? ?? '',
      latestChapterTitle: json['latestChapterTitle'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
    );
  }

  factory ReadingBook.fromShelfBook(ShelfBook shelfBook) {
    return ReadingBook(
      bookUrl: shelfBook.bookUrl,
      tocUrl: '',
      sourceUrl: shelfBook.sourceKey,
      sourceName: '',
      type: shelfBook.type,
      name: shelfBook.title,
      author: shelfBook.author,
      kind: '',
      intro: shelfBook.intro,
      wordCount: shelfBook.wordCount,
      latestChapterTitle: shelfBook.currentChapter,
      coverUrl: shelfBook.coverUrl,
    );
  }
}

class ReadingSearchResult {
  const ReadingSearchResult({
    required this.source,
    required this.page,
    required this.count,
    required this.items,
  });

  final ReadingSourceRef source;
  final int page;
  final int count;
  final List<ReadingBook> items;

  factory ReadingSearchResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return ReadingSearchResult(
      source: ReadingSourceRef.fromJson(
        json['source'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      page: (json['page'] as num? ?? 1).toInt(),
      count: (json['count'] as num? ?? rawItems.length).toInt(),
      items: rawItems
          .map((item) => ReadingBook.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReadingChapter {
  const ReadingChapter({
    required this.id,
    required this.title,
    required this.url,
    required this.tag,
    required this.index,
    required this.isVolume,
    required this.isPay,
    required this.isVip,
  });

  final String id;
  final String title;
  final String url;
  final String tag;
  final int index;
  final bool isVolume;
  final bool isPay;
  final bool isVip;

  factory ReadingChapter.fromJson(Map<String, dynamic> json) {
    return ReadingChapter(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      index: (json['index'] as num? ?? 0).toInt(),
      isVolume: json['isVolume'] as bool? ?? false,
      isPay: json['isPay'] as bool? ?? false,
      isVip: json['isVip'] as bool? ?? false,
    );
  }
}

class ReadingChapterResult {
  const ReadingChapterResult({
    required this.source,
    required this.url,
    required this.bookname,
    required this.count,
    required this.items,
  });

  final ReadingSourceRef source;
  final String url;
  final String bookname;
  final int count;
  final List<ReadingChapter> items;

  factory ReadingChapterResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return ReadingChapterResult(
      source: ReadingSourceRef.fromJson(
        json['source'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      url: json['url'] as String? ?? '',
      bookname: json['bookname'] as String? ?? '',
      count: (json['count'] as num? ?? rawItems.length).toInt(),
      items: rawItems
          .map((item) => ReadingChapter.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ReadingContent {
  const ReadingContent({
    required this.source,
    required this.url,
    required this.bookname,
    required this.chapterIndex,
    required this.contentLength,
    required this.contentMode,
    required this.imageUrls,
    required this.text,
    required this.rules,
  });

  final ReadingSourceRef source;
  final String url;
  final String bookname;
  final int chapterIndex;
  final int contentLength;
  final String contentMode;
  final List<String> imageUrls;
  final String text;
  final List<dynamic> rules;

  List<String> get paragraphs => text
      .split('\n')
      .map((line) => line.trimRight())
      .where((line) => line.trim().isNotEmpty)
      .toList();

  factory ReadingContent.fromJson(Map<String, dynamic> json) {
    return ReadingContent(
      source: ReadingSourceRef.fromJson(
        json['source'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      url: json['url'] as String? ?? '',
      bookname: json['bookname'] as String? ?? '',
      chapterIndex: (json['chapterIndex'] as num? ?? 0).toInt(),
      contentLength: (json['contentLength'] as num? ?? 0).toInt(),
      contentMode: json['contentMode'] as String? ?? 'text',
      imageUrls: (json['imageUrls'] as List<dynamic>? ?? const [])
          .map((item) => '$item')
          .where((item) => item.isNotEmpty)
          .toList(),
      text: json['text'] as String? ?? '',
      rules: json['rules'] as List<dynamic>? ?? const [],
    );
  }
}

class SearchOptions {
  const SearchOptions({
    required this.modes,
    required this.categories,
    required this.defaultMode,
    required this.defaultCategory,
    required this.sources,
  });

  final List<String> modes;
  final List<String> categories;
  final String defaultMode;
  final String defaultCategory;
  final List<SourceRule> sources;

  factory SearchOptions.fromJson(Map<String, dynamic> json) {
    return SearchOptions(
      modes: (json['modes'] as List<dynamic>? ?? const [])
          .map((item) => '$item')
          .toList(),
      categories: (json['categories'] as List<dynamic>? ?? const [])
          .map((item) => '$item')
          .toList(),
      defaultMode: (json['defaults'] as Map<String, dynamic>? ?? const {})['mode']
              as String? ??
          'fuzzy',
      defaultCategory:
          (json['defaults'] as Map<String, dynamic>? ?? const {})['category']
                  as String? ??
              'book',
      sources: (json['sources'] as List<dynamic>? ?? const [])
          .map((item) => SourceRule.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SearchVariant {
  const SearchVariant({
    required this.score,
    required this.source,
    required this.book,
  });

  final int score;
  final ReadingSourceRef source;
  final ReadingBook book;

  factory SearchVariant.fromJson(Map<String, dynamic> json) {
    return SearchVariant(
      score: (json['score'] as num? ?? 0).toInt(),
      source: ReadingSourceRef.fromJson(
        json['source'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      book: ReadingBook.fromJson(
        json['book'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
    );
  }
}

class SearchGroup {
  const SearchGroup({
    required this.groupId,
    required this.title,
    required this.author,
    required this.intro,
    required this.wordCount,
    required this.kind,
    required this.coverUrl,
    required this.bestScore,
    required this.sourceCount,
    required this.markers,
    required this.bestVariant,
    required this.variants,
  });

  final String groupId;
  final String title;
  final String author;
  final String intro;
  final String wordCount;
  final String kind;
  final String coverUrl;
  final int bestScore;
  final int sourceCount;
  final SourceCapabilities markers;
  final SearchVariant bestVariant;
  final List<SearchVariant> variants;

  factory SearchGroup.fromJson(Map<String, dynamic> json) {
    return SearchGroup(
      groupId: json['groupId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      intro: json['intro'] as String? ?? '',
      wordCount: json['wordCount'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      bestScore: (json['bestScore'] as num? ?? 0).toInt(),
      sourceCount: (json['sourceCount'] as num? ?? 0).toInt(),
      markers: SourceCapabilities.fromJson(
        json['markers'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      bestVariant: SearchVariant.fromJson(
        json['bestVariant'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      variants: (json['variants'] as List<dynamic>? ?? const [])
          .map((item) => SearchVariant.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SearchRun {
  const SearchRun({
    required this.id,
    required this.name,
    required this.order,
    required this.bookSourceUrl,
    required this.capabilities,
    required this.lastCheckStatus,
    required this.lastCheckReason,
    required this.elapsedMs,
    required this.resultCount,
    required this.status,
    required this.errorMessage,
  });

  final String id;
  final String name;
  final int order;
  final String bookSourceUrl;
  final SourceCapabilities capabilities;
  final String lastCheckStatus;
  final String lastCheckReason;
  final int elapsedMs;
  final int resultCount;
  final String status;
  final String errorMessage;

  factory SearchRun.fromJson(Map<String, dynamic> json) {
    return SearchRun(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      order: (json['order'] as num? ?? 0).toInt(),
      bookSourceUrl: json['bookSourceUrl'] as String? ?? '',
      capabilities: SourceCapabilities.fromJson(
        json['capabilities'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      lastCheckStatus: json['lastCheckStatus'] as String? ?? 'unknown',
      lastCheckReason: json['lastCheckReason'] as String? ?? '',
      elapsedMs: (json['elapsedMs'] as num? ?? 0).toInt(),
      resultCount: (json['resultCount'] as num? ?? 0).toInt(),
      status: json['status'] as String? ?? 'unknown',
      errorMessage: json['errorMessage'] as String? ?? '',
    );
  }
}

class GroupedSearchResult {
  const GroupedSearchResult({
    required this.query,
    required this.mode,
    required this.category,
    required this.page,
    required this.sourceCount,
    required this.groupCount,
    required this.items,
    required this.sourceRuns,
  });

  final String query;
  final String mode;
  final String category;
  final int page;
  final int sourceCount;
  final int groupCount;
  final List<SearchGroup> items;
  final List<SearchRun> sourceRuns;

  factory GroupedSearchResult.fromJson(Map<String, dynamic> json) {
    return GroupedSearchResult(
      query: json['query'] as String? ?? '',
      mode: json['mode'] as String? ?? 'fuzzy',
      category: json['category'] as String? ?? 'book',
      page: (json['page'] as num? ?? 1).toInt(),
      sourceCount: (json['sourceCount'] as num? ?? 0).toInt(),
      groupCount: (json['groupCount'] as num? ?? 0).toInt(),
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((item) => SearchGroup.fromJson(item as Map<String, dynamic>))
          .toList(),
      sourceRuns: (json['sourceRuns'] as List<dynamic>? ?? const [])
          .map((item) => SearchRun.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RssSource {
  const RssSource({
    required this.id,
    required this.name,
    required this.url,
    required this.enabled,
  });

  final String id;
  final String name;
  final String url;
  final bool enabled;

  factory RssSource.fromJson(Map<String, dynamic> json) {
    return RssSource(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class ReplaceRule {
  const ReplaceRule({
    required this.id,
    required this.name,
    required this.pattern,
    required this.replacement,
    required this.enabled,
  });

  final String id;
  final String name;
  final String pattern;
  final String replacement;
  final bool enabled;

  factory ReplaceRule.fromJson(Map<String, dynamic> json) {
    return ReplaceRule(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      pattern: json['pattern'] as String? ?? '',
      replacement: json['replacement'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class TtsEngine {
  const TtsEngine({
    required this.id,
    required this.name,
    required this.url,
    required this.voice,
    required this.engineType,
    required this.enabled,
  });

  final String id;
  final String name;
  final String url;
  final String voice;
  final String engineType;
  final bool enabled;

  factory TtsEngine.fromJson(Map<String, dynamic> json) {
    return TtsEngine(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      voice: json['voice'] as String? ?? '',
      engineType: json['engineType'] as String? ?? 'httpTTS',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class ThemePreset {
  const ThemePreset({
    required this.id,
    required this.name,
    required this.background,
    required this.foreground,
    required this.accent,
  });

  final String id;
  final String name;
  final String background;
  final String foreground;
  final String accent;

  factory ThemePreset.fromJson(Map<String, dynamic> json) {
    return ThemePreset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      background: json['background'] as String? ?? '#ffffff',
      foreground: json['foreground'] as String? ?? '#111111',
      accent: json['accent'] as String? ?? '#1e88e5',
    );
  }
}

class ReadConfig {
  const ReadConfig({
    required this.fontSize,
    required this.lineHeight,
    required this.paragraphSpacing,
    required this.fontFamily,
    required this.pageTurnMode,
    required this.themeName,
    required this.immersiveMode,
    required this.enableContentPurify,
    required this.showReadingProgress,
    required this.simplifyChinese,
    required this.boldText,
    required this.justifyText,
    required this.autoTtsNextChapter,
    required this.updatedAt,
  });

  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final String fontFamily;
  final String pageTurnMode;
  final String themeName;
  final bool immersiveMode;
  final bool enableContentPurify;
  final bool showReadingProgress;
  final bool simplifyChinese;
  final bool boldText;
  final bool justifyText;
  final bool autoTtsNextChapter;
  final DateTime? updatedAt;

  factory ReadConfig.fromJson(Map<String, dynamic> json) {
    return ReadConfig(
      fontSize: (json['fontSize'] as num? ?? 18).toDouble(),
      lineHeight: (json['lineHeight'] as num? ?? 1.6).toDouble(),
      paragraphSpacing: (json['paragraphSpacing'] as num? ?? 12).toDouble(),
      fontFamily: json['fontFamily'] as String? ?? 'system',
      pageTurnMode: json['pageTurnMode'] as String? ?? 'slide',
      themeName: json['themeName'] as String? ?? 'paper',
      immersiveMode: json['immersiveMode'] as bool? ?? false,
      enableContentPurify: json['enableContentPurify'] as bool? ?? true,
      showReadingProgress: json['showReadingProgress'] as bool? ?? true,
      simplifyChinese: json['simplifyChinese'] as bool? ?? false,
      boldText: json['boldText'] as bool? ?? false,
      justifyText: json['justifyText'] as bool? ?? true,
      autoTtsNextChapter: json['autoTtsNextChapter'] as bool? ?? true,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }
}

class LibraryOverview {
  const LibraryOverview({
    required this.shelfCount,
    required this.bookSourceCount,
    required this.rssSourceCount,
    required this.replaceRuleCount,
    required this.ttsEngineCount,
    required this.themeCount,
    required this.readConfig,
  });

  final int shelfCount;
  final int bookSourceCount;
  final int rssSourceCount;
  final int replaceRuleCount;
  final int ttsEngineCount;
  final int themeCount;
  final ReadConfig readConfig;

  factory LibraryOverview.fromJson(Map<String, dynamic> json) {
    return LibraryOverview(
      shelfCount: json['shelfCount'] as int? ?? 0,
      bookSourceCount: json['bookSourceCount'] as int? ?? 0,
      rssSourceCount: json['rssSourceCount'] as int? ?? 0,
      replaceRuleCount: json['replaceRuleCount'] as int? ?? 0,
      ttsEngineCount: json['ttsEngineCount'] as int? ?? 0,
      themeCount: json['themeCount'] as int? ?? 0,
      readConfig:
          ReadConfig.fromJson(json['readConfig'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class ImportResult {
  const ImportResult({
    required this.pathType,
    required this.count,
  });

  final String pathType;
  final int count;

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    return ImportResult(
      pathType: json['pathType'] as String? ?? 'unknown',
      count: json['count'] as int? ?? 0,
    );
  }
}

class SyncOverview {
  const SyncOverview({
    required this.membershipTier,
    required this.autoBookshelfBackup,
    required this.autoSourceBackup,
    required this.autoProgressSync,
    required this.lastBookshelfBackupAt,
    required this.lastSourceBackupAt,
    required this.lastProgressSyncAt,
    required this.backupCount,
    required this.sourceCount,
    required this.shelfCount,
  });

  final String membershipTier;
  final bool autoBookshelfBackup;
  final bool autoSourceBackup;
  final bool autoProgressSync;
  final DateTime? lastBookshelfBackupAt;
  final DateTime? lastSourceBackupAt;
  final DateTime? lastProgressSyncAt;
  final int backupCount;
  final int sourceCount;
  final int shelfCount;

  factory SyncOverview.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? value) =>
        value == null ? null : DateTime.tryParse(value);

    return SyncOverview(
      membershipTier: json['membershipTier'] as String? ?? 'founder',
      autoBookshelfBackup: json['autoBookshelfBackup'] as bool? ?? false,
      autoSourceBackup: json['autoSourceBackup'] as bool? ?? false,
      autoProgressSync: json['autoProgressSync'] as bool? ?? false,
      lastBookshelfBackupAt:
          parseDate(json['lastBookshelfBackupAt'] as String?),
      lastSourceBackupAt: parseDate(json['lastSourceBackupAt'] as String?),
      lastProgressSyncAt: parseDate(json['lastProgressSyncAt'] as String?),
      backupCount: json['backupCount'] as int? ?? 0,
      sourceCount: json['sourceCount'] as int? ?? 0,
      shelfCount: json['shelfCount'] as int? ?? 0,
    );
  }
}
