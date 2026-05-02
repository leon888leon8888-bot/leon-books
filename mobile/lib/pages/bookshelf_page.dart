import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import 'book_detail_page.dart';
import 'reading_search_page.dart';

class BookshelfPage extends StatefulWidget {
  const BookshelfPage({
    super.key,
    required this.sessionStore,
  });

  final SessionStore sessionStore;

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  late ApiClient _client;
  List<ShelfBook> _books = const [];
  bool _loading = true;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final session = widget.sessionStore.state.value;
    _client = ApiClient(baseUrl: session.baseUrl, token: session.token);
    setState(() {
      _loading = true;
    });
    try {
      final books = await _client.getBookshelf();
      if (!mounted) {
        return;
      }
      setState(() {
        _books = books;
        _offline = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _offline = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReadingSearchPage(sessionStore: widget.sessionStore),
      ),
    );
    await _refresh();
  }

  Future<void> _openShelfBook(ShelfBook book) async {
    if (!book.canResume) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '这本书缺少续读数据，请从搜索结果中重新加入书架。',
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BookDetailPage(
          sessionStore: widget.sessionStore,
          book: ReadingBook.fromShelfBook(book),
          sourceId: book.sourceId,
          initialChapterIndex: book.currentChapterIndex,
          shelfBook: book,
        ),
      ),
    );
    await _refresh();
  }

  Widget _buildHeroCard(ShelfBook? recentBook) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今天想读点什么？',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              recentBook == null
                  ? '从搜索开始，完成搜索、目录、阅读和同步的完整链路。'
                  : '继续阅读《${recentBook.title}》，上次读到 ${recentBook.currentChapter}。',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0A84FF),
                  ),
                  onPressed: _openSearch,
                  icon: const Icon(Icons.travel_explore),
                  label: const Text('找书'),
                ),
                if (recentBook != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    onPressed: () => _openShelfBook(recentBook),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('继续'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShelfBookCard(ShelfBook book) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openShelfBook(book),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 74,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.menu_book_rounded),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.author,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          book.currentChapter,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _openShelfBook(book),
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('打开'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: ((book.progress / 100).clamp(0, 1) as num).toDouble(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '进度 ${book.progress.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    book.updatedAt.toLocal().toString().substring(0, 16),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final recentBook = _books.isEmpty ? null : _books.first;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroCard(recentBook),
          if (_offline) ...[
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.35),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('服务器暂时连接不上。请检查手机网络，或稍后下拉刷新重试。'),
                    ),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '最近阅读',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Text(
                '${_books.length} 本',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_books.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '书架还是空的',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '先从搜索添加一本书，之后就可以续读并同步进度。',
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _openSearch,
                      icon: const Icon(Icons.search),
                      label: const Text('打开搜索'),
                    ),
                  ],
                ),
              ),
            ),
          for (final book in _books) _buildShelfBookCard(book),
        ],
      ),
    );
  }
}
