import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/app_models.dart';

class LocalReaderDatabase {
  LocalReaderDatabase._();

  static final LocalReaderDatabase instance = LocalReaderDatabase._();

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }
    final dbPath = await getDatabasesPath();
    final opened = await openDatabase(
      p.join(dbPath, 'reader_rebuild.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE shelf_books (
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE reading_progress (
            book_id TEXT PRIMARY KEY,
            chapter_index INTEGER NOT NULL,
            chapter_title TEXT NOT NULL,
            progress REAL NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE offline_chapters (
            cache_key TEXT PRIMARY KEY,
            book_url TEXT NOT NULL,
            source_id TEXT NOT NULL,
            chapter_index INTEGER NOT NULL,
            content_mode TEXT NOT NULL,
            image_count INTEGER NOT NULL DEFAULT 0,
            assets_downloaded INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE search_history (
            query TEXT PRIMARY KEY,
            category TEXT NOT NULL,
            mode TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
    _database = opened;
    return opened;
  }

  Future<void> upsertShelfBook(ShelfBook book, String payloadJson) async {
    final db = await database;
    await db.insert(
      'shelf_books',
      {
        'id': book.id,
        'payload': payloadJson,
        'updated_at': book.updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertProgress({
    required String bookId,
    required int chapterIndex,
    required String chapterTitle,
    required double progress,
  }) async {
    final db = await database;
    await db.insert(
      'reading_progress',
      {
        'book_id': bookId,
        'chapter_index': chapterIndex,
        'chapter_title': chapterTitle,
        'progress': progress,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addSearchHistory({
    required String query,
    required String category,
    required String mode,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return;
    }
    final db = await database;
    await db.insert(
      'search_history',
      {
        'query': normalizedQuery,
        'category': category,
        'mode': mode,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
