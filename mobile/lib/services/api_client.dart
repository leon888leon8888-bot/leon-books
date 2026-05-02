import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/app_models.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.token,
  });

  final String baseUrl;
  final String token;
  String? _activeBaseUrl;
  static const Duration _timeout = Duration(seconds: 20);

  List<String> get _baseUrls {
    final urls = <String>[
      if (_activeBaseUrl != null) _activeBaseUrl!,
      baseUrl,
      ...AppConfig.apiBaseUrls,
    ];
    final seen = <String>{};
    return [
      for (final url in urls)
        if (url.trim().isNotEmpty && seen.add(url.trim())) url.trim(),
    ];
  }

  Uri _uri(String path, {String? overrideBaseUrl}) {
    return Uri.parse('${overrideBaseUrl ?? baseUrl}$path');
  }

  Map<String, String> _headers({bool json = false}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _json(http.Response response) async {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(body['message'] ?? '请求失败');
    }
    return body;
  }

  bool _shouldTryNext(Object error) {
    final text = '$error'.toLowerCase();
    return text.contains('failed host lookup') ||
        text.contains('no route to host') ||
        text.contains('connection refused') ||
        text.contains('connection timed out') ||
        text.contains('timed out') ||
        text.contains('network is unreachable') ||
        text.contains('socketexception') ||
        text.contains('clientexception');
  }

  Future<http.Response> _request(
    String path, {
    required String method,
    Object? body,
    Map<String, String>? queryParameters,
  }) async {
    Object? lastError;
    for (final candidateBaseUrl in _baseUrls) {
      final uri = _uri(path, overrideBaseUrl: candidateBaseUrl)
          .replace(queryParameters: queryParameters);
      try {
        final headers = _headers(json: body != null);
        final encodedBody = body == null ? null : jsonEncode(body);
        final response = switch (method) {
          'GET' => await http.get(uri, headers: headers).timeout(_timeout),
          'POST' => await http
              .post(uri, headers: headers, body: encodedBody)
              .timeout(_timeout),
          'PATCH' => await http
              .patch(uri, headers: headers, body: encodedBody)
              .timeout(_timeout),
          'PUT' => await http
              .put(uri, headers: headers, body: encodedBody)
              .timeout(_timeout),
          _ => throw UnsupportedError('Unsupported HTTP method: $method'),
        };
        if (response.statusCode >= 500 && candidateBaseUrl != _baseUrls.last) {
          lastError = Exception('服务暂时不可用：${response.statusCode}');
          continue;
        }
        _activeBaseUrl = candidateBaseUrl;
        return response;
      } catch (error) {
        lastError = error;
        if (!_shouldTryNext(error)) {
          rethrow;
        }
      }
    }
    throw Exception('无法连接阅读服务，请切换手机网络后重试。$lastError');
  }

  Future<ReaderUser> getMe() async {
    final response = await _request('/me', method: 'GET');
    final json = await _json(response);
    return ReaderUser.fromJson(json);
  }

  Future<List<ShelfBook>> getBookshelf() async {
    final response = await _request('/bookshelf', method: 'GET');
    final json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => ShelfBook.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ShelfBook> addBook({
    required String title,
    required String author,
    required String currentChapter,
    String coverUrl = '',
    String intro = '',
    String wordCount = '',
    String sourceId = '',
    String sourceKey = '',
    String bookUrl = '',
    int type = 0,
    int currentChapterIndex = 0,
    double progress = 0,
    String origin = 'manual',
  }) async {
    final response = await _request(
      '/bookshelf',
      method: 'POST',
      body: {
        'title': title,
        'author': author,
        'coverUrl': coverUrl,
        'intro': intro,
        'wordCount': wordCount,
        'sourceId': sourceId,
        'sourceKey': sourceKey,
        'bookUrl': bookUrl,
        'type': type,
        'currentChapter': currentChapter,
        'currentChapterIndex': currentChapterIndex,
        'progress': progress,
        'origin': origin,
      },
    );
    final json = await _json(response);
    return ShelfBook.fromJson(json);
  }

  Future<ShelfBook> upsertBook({
    String id = '',
    required String title,
    required String author,
    String coverUrl = '',
    String intro = '',
    String wordCount = '',
    String sourceId = '',
    String sourceKey = '',
    String bookUrl = '',
    int type = 0,
    String currentChapter = '开始阅读',
    int currentChapterIndex = 0,
    double progress = 0,
    String origin = 'search',
  }) async {
    final response = await _request(
      '/bookshelf/upsert',
      method: 'POST',
      body: {
        if (id.isNotEmpty) 'id': id,
        'title': title,
        'author': author,
        'coverUrl': coverUrl,
        'intro': intro,
        'wordCount': wordCount,
        'sourceId': sourceId,
        'sourceKey': sourceKey,
        'bookUrl': bookUrl,
        'type': type,
        'currentChapter': currentChapter,
        'currentChapterIndex': currentChapterIndex,
        'progress': progress,
        'origin': origin,
      },
    );
    final json = await _json(response);
    return ShelfBook.fromJson(json);
  }

  Future<ShelfBook> updateProgress({
    required String bookId,
    required double progress,
    required String currentChapter,
    int? currentChapterIndex,
    String? coverUrl,
    String? bookUrl,
    String? sourceKey,
    String? sourceId,
  }) async {
    final response = await _request(
      '/bookshelf/$bookId/progress',
      method: 'PATCH',
      body: {
        'progress': progress,
        'currentChapter': currentChapter,
        if (currentChapterIndex != null) 'currentChapterIndex': currentChapterIndex,
        if (coverUrl != null) 'coverUrl': coverUrl,
        if (bookUrl != null) 'bookUrl': bookUrl,
        if (sourceKey != null) 'sourceKey': sourceKey,
        if (sourceId != null) 'sourceId': sourceId,
      },
    );
    final json = await _json(response);
    return ShelfBook.fromJson(json);
  }

  Future<List<SourceRule>> getSources() async {
    final response = await _request('/sources', method: 'GET');
    final json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => SourceRule.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SearchOptions> getSearchOptions() async {
    final response = await _request('/search/options', method: 'GET');
    final json = await _json(response);
    return SearchOptions.fromJson(json);
  }

  Future<SourceRule> importSource({
    required String name,
    required String url,
    required String type,
  }) async {
    final response = await _request(
      '/sources/import',
      method: 'POST',
      body: {
        'name': name,
        'url': url,
        'type': type,
      },
    );
    final json = await _json(response);
    return SourceRule.fromJson(json);
  }

  Future<SourceRule> checkSource(String sourceId) async {
    final response = await _request('/sources/$sourceId/check', method: 'POST');
    final json = await _json(response);
    return SourceRule.fromJson(json);
  }

  Future<List<RssSource>> getRssSources() async {
    final response = await _request('/rss-sources', method: 'GET');
    final json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => RssSource.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReplaceRule>> getReplaceRules() async {
    final response = await _request('/replace-rules', method: 'GET');
    final json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => ReplaceRule.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TtsEngine>> getTtsEngines() async {
    final response = await _request('/tts-engines', method: 'GET');
    final json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => TtsEngine.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ThemePreset>> getThemes() async {
    final response = await _request('/themes', method: 'GET');
    final json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => ThemePreset.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ReadConfig> getReadConfig() async {
    final response = await _request('/read-config', method: 'GET');
    final json = await _json(response);
    return ReadConfig.fromJson(json);
  }

  Future<ReadConfig> updateReadConfig(Map<String, dynamic> payload) async {
    final response =
        await _request('/read-config', method: 'PUT', body: payload);
    final json = await _json(response);
    return ReadConfig.fromJson(json);
  }

  Future<LibraryOverview> getLibraryOverview() async {
    final response = await _request('/library/overview', method: 'GET');
    final json = await _json(response);
    return LibraryOverview.fromJson(json);
  }

  Future<ImportResult> importByType({
    required String pathType,
    required dynamic payload,
  }) async {
    final response =
        await _request('/import/$pathType', method: 'POST', body: payload);
    final json = await _json(response);
    return ImportResult.fromJson(json);
  }

  Future<SyncOverview> getSyncOverview() async {
    final response = await _request('/sync/overview', method: 'GET');
    final json = await _json(response);
    return SyncOverview.fromJson(json);
  }

  Future<void> backupBookshelf() async {
    final response =
        await _request('/sync/bookshelf/backup', method: 'POST');
    await _json(response);
  }

  Future<void> backupSources() async {
    final response = await _request('/sync/sources/backup', method: 'POST');
    await _json(response);
  }

  Future<void> pushProgress() async {
    final response = await _request('/sync/progress/push', method: 'POST');
    await _json(response);
  }

  Future<SyncOverview> updateSyncSettings({
    bool? autoBookshelfBackup,
    bool? autoSourceBackup,
    bool? autoProgressSync,
  }) async {
    final response = await _request(
      '/sync/settings',
      method: 'PATCH',
      body: {
        if (autoBookshelfBackup != null)
          'autoBookshelfBackup': autoBookshelfBackup,
        if (autoSourceBackup != null) 'autoSourceBackup': autoSourceBackup,
        if (autoProgressSync != null) 'autoProgressSync': autoProgressSync,
      },
    );
    final json = await _json(response);
    return SyncOverview.fromJson({
      'membershipTier': 'founder',
      'autoBookshelfBackup': json['autoBookshelfBackup'],
      'autoSourceBackup': json['autoSourceBackup'],
      'autoProgressSync': json['autoProgressSync'],
      'lastBookshelfBackupAt': null,
      'lastSourceBackupAt': null,
      'lastProgressSyncAt': null,
      'backupCount': 0,
      'sourceCount': 0,
      'shelfCount': 0,
    });
  }

  Future<ReadingSearchResult> searchBooks({
    required String query,
    String sourceId = '',
    int page = 1,
  }) async {
    final parameters = <String, String>{
      'query': query,
      'page': '$page',
      if (sourceId.isNotEmpty) 'sourceId': sourceId,
    };
    final response = await _request(
      '/reading/search',
      method: 'GET',
      queryParameters: parameters,
    );
    final json = await _json(response);
    return ReadingSearchResult.fromJson(json);
  }

  Future<GroupedSearchResult> searchGroupedBooks({
    required String query,
    String mode = 'fuzzy',
    String category = 'book',
    List<String> sourceIds = const [],
    int page = 1,
  }) async {
    final payload = {
      'query': query,
      'mode': mode,
      'category': category,
      'page': page,
      if (sourceIds.isNotEmpty) 'sourceIds': sourceIds,
    };
    final response =
        await _request('/search/books', method: 'POST', body: payload);
    final json = await _json(response);
    return GroupedSearchResult.fromJson(json);
  }

  Future<ReadingChapterResult> getChapters({
    required ReadingBook book,
    String sourceId = '',
  }) async {
    final response = await _request(
      '/reading/chapters',
      method: 'POST',
      body: {
        if (sourceId.isNotEmpty) 'sourceId': sourceId,
        if (sourceId.isEmpty && book.sourceUrl.isNotEmpty)
          'bookSourceUrl': book.sourceUrl,
        'url': book.bookUrl,
        'bookname': book.name,
      },
    );
    final json = await _json(response);
    return ReadingChapterResult.fromJson(json);
  }

  Future<ReadingContent> getChapterContent({
    required ReadingBook book,
    required ReadingChapter chapter,
    String sourceId = '',
  }) async {
    final response = await _request(
      '/reading/content',
      method: 'POST',
      body: {
        if (sourceId.isNotEmpty) 'sourceId': sourceId,
        if (sourceId.isEmpty && book.sourceUrl.isNotEmpty)
          'bookSourceUrl': book.sourceUrl,
        'url': book.bookUrl,
        'bookname': book.name,
        'index': chapter.index,
        'type': book.type,
      },
    );
    final json = await _json(response);
    return ReadingContent.fromJson(json);
  }

  Future<String> getDefaultTtsId() async {
    final response = await _request('/tts/default', method: 'GET');
    final json = await _json(response);
    return json['id'] as String? ?? '';
  }

  Uri buildTtsStreamUri({
    required String id,
    required String text,
    int speechRate = 5,
  }) {
    return _uri('/tts/stream', overrideBaseUrl: _activeBaseUrl).replace(
      queryParameters: {
        'id': id,
        'text': text,
        'speechRate': '$speechRate',
        if (token.isNotEmpty) 'token': token,
      },
    );
  }
}
