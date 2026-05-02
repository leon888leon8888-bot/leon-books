import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_models.dart';

class OfflineChapterStatus {
  const OfflineChapterStatus({
    required this.hasPayload,
    required this.assetsDownloaded,
  });

  final bool hasPayload;
  final bool assetsDownloaded;
}

class OfflineLibrary {
  OfflineLibrary._();

  static final OfflineLibrary instance = OfflineLibrary._();
  static const _indexFileName = 'offline_index.json';

  Directory? _rootDirectory;
  Map<String, dynamic>? _index;

  Future<void> initialize() async {
    if (_rootDirectory != null && _index != null) {
      return;
    }
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory('${documents.path}/reader_rebuild_offline');
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    _rootDirectory = root;
    _index = await _loadIndex();
  }

  Future<OfflineChapterStatus> getChapterStatus({
    required ReadingBook book,
    required ReadingChapter chapter,
    required String sourceId,
  }) async {
    await initialize();
    final record = _entryFor(
      _chapterKey(
        sourceId: sourceId,
        bookUrl: book.bookUrl,
        chapterIndex: chapter.index,
      ),
    );
    return OfflineChapterStatus(
      hasPayload: record != null,
      assetsDownloaded: record?['assetsDownloaded'] == true,
    );
  }

  Future<void> cacheChapter({
    required ReadingBook book,
    required ReadingChapter chapter,
    required String sourceId,
    required ReadingContent content,
    bool downloadAssets = false,
  }) async {
    await initialize();
    final key = _chapterKey(
      sourceId: sourceId,
      bookUrl: book.bookUrl,
      chapterIndex: chapter.index,
    );
    final file = File('${_chaptersDirectory.path}/$key.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(_serializeContent(content)));

    var assetsDownloaded = content.imageUrls.isEmpty;
    if (downloadAssets && content.imageUrls.isNotEmpty) {
      for (final url in content.imageUrls) {
        await DefaultCacheManager().downloadFile(url);
      }
      assetsDownloaded = true;
    }

    _index![key] = {
      'key': key,
      'sourceId': sourceId,
      'bookUrl': book.bookUrl,
      'chapterIndex': chapter.index,
      'chapterTitle': chapter.title,
      'bookName': book.name,
      'contentMode': content.contentMode,
      'imageCount': content.imageUrls.length,
      'assetsDownloaded': assetsDownloaded,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _persistIndex();
  }

  Future<ReadingContent?> readChapter({
    required ReadingBook book,
    required ReadingChapter chapter,
    required String sourceId,
  }) async {
    await initialize();
    final key = _chapterKey(
      sourceId: sourceId,
      bookUrl: book.bookUrl,
      chapterIndex: chapter.index,
    );
    final file = File('${_chaptersDirectory.path}/$key.json');
    if (!await file.exists()) {
      return null;
    }
    final raw = await file.readAsString();
    final payload = jsonDecode(raw) as Map<String, dynamic>;
    return ReadingContent.fromJson(payload);
  }

  Future<void> markAssetsDownloaded({
    required ReadingBook book,
    required ReadingChapter chapter,
    required String sourceId,
  }) async {
    await initialize();
    final key = _chapterKey(
      sourceId: sourceId,
      bookUrl: book.bookUrl,
      chapterIndex: chapter.index,
    );
    final record = _entryFor(key);
    if (record == null) {
      return;
    }
    record['assetsDownloaded'] = true;
    record['updatedAt'] = DateTime.now().toIso8601String();
    await _persistIndex();
  }

  Map<String, dynamic>? _entryFor(String key) {
    final payload = _index?[key];
    return payload is Map<String, dynamic> ? payload : null;
  }

  Future<Map<String, dynamic>> _loadIndex() async {
    final file = File('${_rootDirectory!.path}/$_indexFileName');
    if (!await file.exists()) {
      return <String, dynamic>{};
    }
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _persistIndex() async {
    final file = File('${_rootDirectory!.path}/$_indexFileName');
    await file.writeAsString(jsonEncode(_index));
  }

  Directory get _chaptersDirectory => Directory('${_rootDirectory!.path}/chapters');

  String _chapterKey({
    required String sourceId,
    required String bookUrl,
    required int chapterIndex,
  }) {
    final raw = '$sourceId::$bookUrl::$chapterIndex';
    return sha1.convert(utf8.encode(raw)).toString();
  }

  Map<String, dynamic> _serializeContent(ReadingContent content) {
    return {
      'source': {
        'id': content.source.id,
        'name': content.source.name,
        'bookSourceUrl': content.source.bookSourceUrl,
        'capabilities': {
          'supportsText': content.source.capabilities.supportsText,
          'supportsComic': content.source.capabilities.supportsComic,
          'supportsAudio': content.source.capabilities.supportsAudio,
          'searchable': content.source.capabilities.searchable,
          'explorable': content.source.capabilities.explorable,
          'preferredMode': content.source.capabilities.preferredMode,
        },
      },
      'url': content.url,
      'bookname': content.bookname,
      'chapterIndex': content.chapterIndex,
      'contentLength': content.contentLength,
      'contentMode': content.contentMode,
      'imageUrls': content.imageUrls,
      'text': content.text,
      'rules': content.rules,
    };
  }
}
