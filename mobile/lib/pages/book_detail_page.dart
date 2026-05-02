import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import 'comic_reader_page.dart';
import 'reader_page.dart';

class BookDetailPage extends StatefulWidget {
  const BookDetailPage({
    super.key,
    required this.sessionStore,
    required this.book,
    required this.sourceId,
    this.sourceCapabilities = const SourceCapabilities(
      supportsText: true,
      supportsComic: false,
      supportsAudio: false,
      searchable: true,
      explorable: false,
      preferredMode: 'text',
    ),
    this.initialChapterIndex = 0,
    this.shelfBook,
  });

  final SessionStore sessionStore;
  final ReadingBook book;
  final String sourceId;
  final SourceCapabilities sourceCapabilities;
  final int initialChapterIndex;
  final ShelfBook? shelfBook;

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  late ApiClient _client;
  ReadingChapterResult? _chapters;
  ShelfBook? _shelfBook;
  bool _loading = true;
  bool _saving = false;
  bool _openingChapter = false;

  @override
  void initState() {
    super.initState();
    _shelfBook = widget.shelfBook;
    _load();
  }

  Future<void> _load() async {
    final session = widget.sessionStore.state.value;
    _client = ApiClient(baseUrl: session.baseUrl, token: session.token);
    setState(() {
      _loading = true;
    });
    try {
      final chapters = await _client.getChapters(
        book: widget.book,
        sourceId: widget.sourceId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _chapters = chapters;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveToShelf({int chapterIndex = 0, String chapterTitle = '开始阅读'}) async {
    setState(() {
      _saving = true;
    });
    try {
      final shelfBook = await _client.upsertBook(
        id: _shelfBook?.id ?? '',
        title: widget.book.name,
        author: widget.book.author,
        coverUrl: widget.book.coverUrl,
        intro: widget.book.intro,
        wordCount: widget.book.wordCount,
        sourceId: widget.sourceId,
        sourceKey: widget.book.sourceUrl,
        bookUrl: widget.book.bookUrl,
        type: widget.book.type,
        currentChapter: chapterTitle,
        currentChapterIndex: chapterIndex,
        progress: _chapters == null || _chapters!.count == 0
            ? 0
            : (chapterIndex /
                    (((_chapters!.count - 1).clamp(1, 999999) as num).toDouble())) *
                100,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _shelfBook = shelfBook;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已加入书架')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _openReader(int chapterIndex) async {
    if (_chapters == null || _chapters!.items.isEmpty) {
      return;
    }
    final safeIndex = (chapterIndex.clamp(0, _chapters!.items.length - 1) as num).toInt();
    final targetChapter = _chapters!.items[safeIndex];
    setState(() {
      _openingChapter = true;
    });
    try {
      final initialContent = await _client.getChapterContent(
        book: widget.book,
        chapter: targetChapter,
        sourceId: widget.sourceId,
      );
      await _saveToShelf(
        chapterIndex: safeIndex,
        chapterTitle: targetChapter.title,
      );
      if (!mounted) {
        return;
      }
      final shouldOpenComic = initialContent.contentMode == 'comic' ||
          initialContent.imageUrls.isNotEmpty;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => shouldOpenComic
              ? ComicReaderPage(
                  sessionStore: widget.sessionStore,
                  book: widget.book,
                  sourceId: widget.sourceId,
                  chapters: _chapters!.items,
                  initialChapterIndex: safeIndex,
                  shelfBook: _shelfBook,
                  initialContent: initialContent,
                )
              : ReaderPage(
                  sessionStore: widget.sessionStore,
                  book: widget.book,
                  sourceId: widget.sourceId,
                  chapters: _chapters!.items,
                  initialChapterIndex: safeIndex,
                  shelfBook: _shelfBook,
                  initialContent: initialContent,
                ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开章节失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingChapter = false;
        });
      }
    }
  }

  Widget _buildCapabilityChip({
    required String label,
    required bool enabled,
    required IconData icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        icon,
        size: 16,
        color: enabled ? scheme.primary : scheme.onSurfaceVariant,
      ),
      label: Text(label),
      backgroundColor: enabled
          ? scheme.primary.withOpacity(0.10)
          : scheme.surfaceContainerHighest,
      side: BorderSide(
        color: enabled ? scheme.primary.withOpacity(0.24) : Colors.transparent,
      ),
    );
  }

  Widget _buildHeader() {
    final chapterCount = _chapters?.count ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.book.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.book.author} - ${widget.book.kind.isEmpty ? '未知分类' : widget.book.kind}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.book.wordCount.isNotEmpty)
                  Chip(label: Text(widget.book.wordCount)),
                Chip(label: Text('$chapterCount 章')),
                Chip(label: Text(widget.book.sourceName.isEmpty ? '自定义书源' : widget.book.sourceName)),
                _buildCapabilityChip(
                  label: '小说',
                  enabled: widget.sourceCapabilities.supportsText,
                  icon: Icons.subject,
                ),
                _buildCapabilityChip(
                  label: '漫画',
                  enabled: widget.sourceCapabilities.supportsComic,
                  icon: Icons.photo_library_outlined,
                ),
                _buildCapabilityChip(
                  label: '听书',
                  enabled: widget.sourceCapabilities.supportsAudio,
                  icon: Icons.graphic_eq,
                ),
              ],
            ),
            if (widget.book.intro.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                widget.book.intro,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.55,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _loading || _openingChapter || (_chapters?.items.isEmpty ?? true)
                      ? null
                      : () => _openReader(_shelfBook?.currentChapterIndex ?? widget.initialChapterIndex),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_shelfBook == null ? '开始阅读' : '继续阅读'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving || _openingChapter
                      ? null
                      : () => _saveToShelf(
                            chapterIndex: _shelfBook?.currentChapterIndex ?? widget.initialChapterIndex,
                            chapterTitle: _shelfBook?.currentChapter.isNotEmpty == true
                                ? _shelfBook!.currentChapter
                                : '开始阅读',
                          ),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('加入书架'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterTile(ReadingChapter chapter) {
    final isCurrent = _shelfBook != null && chapter.index == _shelfBook!.currentChapterIndex;
    return ListTile(
      onTap: chapter.isVolume ? null : () => _openReader(chapter.index),
      leading: CircleAvatar(
        radius: 14,
        child: Text('${chapter.index + 1}', style: const TextStyle(fontSize: 11)),
      ),
      title: Text(
        chapter.title,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: chapter.isVip || chapter.isPay
          ? const Text('该章节可能需要支持付费内容的书源。')
          : null,
      trailing: isCurrent ? const Icon(Icons.play_circle_fill) : const Icon(Icons.chevron_right),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书籍详情'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildHeader(),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _chapters?.items.length ?? 0,
                    itemBuilder: (context, index) =>
                        _buildChapterTile(_chapters!.items[index]),
                  ),
                ),
              ],
            ),
    );
  }
}
