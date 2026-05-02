import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/offline_library.dart';
import '../services/session_store.dart';
import 'reader_page.dart';

class ComicReaderPage extends StatefulWidget {
  const ComicReaderPage({
    super.key,
    required this.sessionStore,
    required this.book,
    required this.sourceId,
    required this.chapters,
    required this.initialChapterIndex,
    this.shelfBook,
    this.initialContent,
  });

  final SessionStore sessionStore;
  final ReadingBook book;
  final String sourceId;
  final List<ReadingChapter> chapters;
  final int initialChapterIndex;
  final ShelfBook? shelfBook;
  final ReadingContent? initialContent;

  @override
  State<ComicReaderPage> createState() => _ComicReaderPageState();
}

class _ComicReaderPageState extends State<ComicReaderPage> {
  late ApiClient _client;
  late ScrollController _scrollController;

  final OfflineLibrary _offlineLibrary = OfflineLibrary.instance;
  final Map<int, Future<ReadingContent>> _contentFutures = {};
  final Map<int, double> _scrollOffsets = {};

  ReadConfig? _readConfig;
  ShelfBook? _shelfBook;
  OfflineChapterStatus? _offlineStatus;
  double? _pendingScrollRatio;
  int _currentIndex = 0;
  bool _clientReady = false;
  bool _bootstrapping = true;
  bool _immersive = false;
  bool _downloadingOffline = false;
  double _chapterScrollProgress = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex =
        (widget.initialChapterIndex.clamp(0, widget.chapters.length - 1) as num)
            .toInt();
    _shelfBook = widget.shelfBook;
    _scrollController = ScrollController()..addListener(_handleScroll);
    if (widget.initialContent != null) {
      _contentFutures[_currentIndex] = Future.value(widget.initialContent!);
    }
    _bootstrap();
  }

  @override
  void dispose() {
    if (_clientReady) {
      unawaited(_persistProgress(_currentIndex));
    }
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _applyImmersiveMode(false);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final session = widget.sessionStore.state.value;
    _client = ApiClient(baseUrl: session.baseUrl, token: session.token);
    _clientReady = true;
    try {
      await _offlineLibrary.initialize();
      final config = await _client.getReadConfig();
      if (!mounted) {
        return;
      }
      setState(() {
        _readConfig = config;
        _immersive = config.immersiveMode;
      });
      await _applyImmersiveMode(_immersive);
      _ensureContentLoaded(_currentIndex);
      _prefetchNeighbors(_currentIndex);
      await _persistProgress(_currentIndex);
      await _refreshOfflineStatus();
    } finally {
      if (mounted) {
        setState(() {
          _bootstrapping = false;
        });
      }
    }
  }

  Future<void> _applyImmersiveMode(bool enabled) async {
    await SystemChrome.setEnabledSystemUIMode(
      enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    await SystemChrome.setSystemUIOverlayStyle(
      enabled ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
  }

  void _toggleImmersive() {
    final next = !_immersive;
    setState(() {
      _immersive = next;
    });
    _applyImmersiveMode(next);
  }

  Future<void> _refreshOfflineStatus() async {
    final status = await _offlineLibrary.getChapterStatus(
      book: widget.book,
      chapter: widget.chapters[_currentIndex],
      sourceId: widget.sourceId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _offlineStatus = status;
    });
  }

  Future<void> _warmupImageAssets(
    ReadingContent content, {
    int maxImages = 4,
  }) async {
    for (final url in content.imageUrls.take(maxImages)) {
      try {
        await DefaultCacheManager().downloadFile(url);
      } catch (_) {}
    }
  }

  Future<ReadingContent> _loadContent(int index) async {
    final chapter = widget.chapters[index];
    try {
      final networkContent = await _client.getChapterContent(
        book: widget.book,
        chapter: chapter,
        sourceId: widget.sourceId,
      );
      await _offlineLibrary.cacheChapter(
        book: widget.book,
        chapter: chapter,
        sourceId: widget.sourceId,
        content: networkContent,
      );
      unawaited(_warmupImageAssets(
        networkContent,
        maxImages: index == _currentIndex ? 6 : 2,
      ));
      if (index == _currentIndex) {
        unawaited(_refreshOfflineStatus());
      }
      return networkContent;
    } catch (_) {
      final cached = await _offlineLibrary.readChapter(
        book: widget.book,
        chapter: chapter,
        sourceId: widget.sourceId,
      );
      if (cached != null) {
        if (index == _currentIndex) {
          unawaited(_refreshOfflineStatus());
        }
        return cached;
      }
      rethrow;
    }
  }

  Future<ReadingContent> _ensureContentLoaded(int index) {
    return _contentFutures.putIfAbsent(index, () => _loadContent(index));
  }

  void _prefetchNeighbors(int index) {
    if (index > 0) {
      _ensureContentLoaded(index - 1);
    }
    if (index < widget.chapters.length - 1) {
      _ensureContentLoaded(index + 1);
    }
  }

  Future<void> _persistProgress(int index) async {
    final chapter = widget.chapters[index];
    final overallProgress = widget.chapters.isEmpty
        ? 0.0
        : (((index + _chapterScrollProgress) / widget.chapters.length) * 100)
            .clamp(0, 100)
            .toDouble();

    if (_shelfBook == null) {
      final created = await _client.upsertBook(
        title: widget.book.name,
        author: widget.book.author,
        coverUrl: widget.book.coverUrl,
        intro: widget.book.intro,
        wordCount: widget.book.wordCount,
        sourceId: widget.sourceId,
        sourceKey: widget.book.sourceUrl,
        bookUrl: widget.book.bookUrl,
        type: widget.book.type,
        currentChapter: chapter.title,
        currentChapterIndex: chapter.index,
        progress: overallProgress,
        origin: 'comic-reader',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _shelfBook = created;
      });
      return;
    }

    final updated = await _client.updateProgress(
      bookId: _shelfBook!.id,
      progress: overallProgress,
      currentChapter: chapter.title,
      currentChapterIndex: chapter.index,
      coverUrl: widget.book.coverUrl,
      bookUrl: widget.book.bookUrl,
      sourceKey: widget.book.sourceUrl,
      sourceId: widget.sourceId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _shelfBook = updated;
    });
  }

  Future<void> _handleChapterChanged(int index) async {
    if (index == _currentIndex) {
      return;
    }
    setState(() {
      _currentIndex = index;
      _chapterScrollProgress = 0;
    });
    _ensureContentLoaded(index);
    _prefetchNeighbors(index);
    await _persistProgress(index);
    await _refreshOfflineStatus();
  }

  Future<void> _jumpToChapter(
    int index, {
    double? scrollRatio,
  }) async {
    final safeIndex =
        (index.clamp(0, widget.chapters.length - 1) as num).toInt();
    _pendingScrollRatio = scrollRatio;
    await _handleChapterChanged(safeIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScrollPosition());
  }

  int _safeChapterIndexFromSlider(double value) {
    if (widget.chapters.isEmpty) {
      return 0;
    }
    final scaled = value * widget.chapters.length;
    return scaled.floor().clamp(0, widget.chapters.length - 1).toInt();
  }

  double _safeChapterRatioFromSlider(double value, int chapterIndex) {
    if (widget.chapters.isEmpty) {
      return 0;
    }
    final scaled = value * widget.chapters.length;
    return (scaled - chapterIndex).clamp(0.0, 0.999).toDouble();
  }

  Future<void> _changeChapter(int delta) async {
    await _jumpToChapter(_currentIndex + delta, scrollRatio: 0);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollOffsets[_currentIndex] = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final nextProgress = maxExtent <= 0
        ? 0.0
        : (_scrollController.offset / maxExtent).clamp(0.0, 1.0).toDouble();
    if ((nextProgress - _chapterScrollProgress).abs() > 0.01 && mounted) {
      setState(() {
        _chapterScrollProgress = nextProgress;
      });
    }
  }

  void _restoreScrollPosition() {
    if (!_scrollController.hasClients) {
      return;
    }
    final maxExtent = _scrollController.position.maxScrollExtent;
    final pendingRatio = _pendingScrollRatio;
    _pendingScrollRatio = null;
    final offset = pendingRatio != null
        ? maxExtent * pendingRatio
        : (_scrollOffsets[_currentIndex] ?? 0);
    _scrollController.jumpTo(
      (offset.clamp(0, maxExtent) as num).toDouble(),
    );
  }

  Future<void> _cacheCurrentChapter() async {
    setState(() {
      _downloadingOffline = true;
    });
    try {
      final content = await _ensureContentLoaded(_currentIndex);
      await _offlineLibrary.cacheChapter(
        book: widget.book,
        chapter: widget.chapters[_currentIndex],
        sourceId: widget.sourceId,
        content: content,
        downloadAssets: true,
      );
      await _refreshOfflineStatus();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('漫画章节已离线保存')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingOffline = false;
        });
      }
    }
  }

  Future<void> _updateReadConfig(Map<String, dynamic> patch) async {
    final config = await _client.updateReadConfig(patch);
    if (!mounted) {
      return;
    }
    setState(() {
      _readConfig = config;
      _immersive = config.immersiveMode;
    });
    await _applyImmersiveMode(_immersive);
  }

  Future<void> _openSettingsSheet() async {
    final config = _readConfig;
    if (config == null) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        var themeName = config.themeName;
        var immersiveMode = config.immersiveMode;
        var showProgress = config.showReadingProgress;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '漫画阅读设置',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'paper', label: Text('纸张')),
                        ButtonSegment(value: 'night', label: Text('夜间')),
                      ],
                      selected: {themeName},
                      onSelectionChanged: (values) {
                        setSheetState(() {
                          themeName = values.first;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      value: immersiveMode,
                      onChanged: (value) {
                        setSheetState(() {
                          immersiveMode = value;
                        });
                      },
                      title: const Text('沉浸式阅读'),
                      subtitle: const Text(
                        '点击页面可快速隐藏或显示工具栏。',
                      ),
                    ),
                    SwitchListTile(
                      value: showProgress,
                      onChanged: (value) {
                        setSheetState(() {
                          showProgress = value;
                        });
                      },
                      title: const Text('显示长进度条'),
                      subtitle: const Text(
                        '使用整章进度条快速定位。',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        await _updateReadConfig({
                          'themeName': themeName,
                          'immersiveMode': immersiveMode,
                          'showReadingProgress': showProgress,
                        });
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('保存设置'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openChapterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.chapters.length,
            itemBuilder: (context, index) {
              final chapter = widget.chapters[index];
              final isCurrent = index == _currentIndex;
              return ListTile(
                selected: isCurrent,
                leading: CircleAvatar(
                  radius: 14,
                  child: Text('${index + 1}', style: const TextStyle(fontSize: 11)),
                ),
                title: Text(
                  chapter.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: chapter.isVip || chapter.isPay
                    ? const Text('付费章节')
                    : null,
                onTap: chapter.isVolume
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _jumpToChapter(index, scrollRatio: 0);
                      },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openTextFallback(ReadingContent content) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReaderPage(
          sessionStore: widget.sessionStore,
          book: widget.book,
          sourceId: widget.sourceId,
          chapters: widget.chapters,
          initialChapterIndex: _currentIndex,
          shelfBook: _shelfBook,
          initialContent: content,
        ),
      ),
    );
  }

  double get _overallProgress {
    if (widget.chapters.isEmpty) {
      return 0;
    }
    return ((_currentIndex + _chapterScrollProgress) / widget.chapters.length)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  _ComicPalette get _palette {
    final theme = _readConfig?.themeName ?? 'paper';
    if (theme == 'night') {
      return const _ComicPalette(
        background: Color(0xFF0D1117),
        surface: Color(0xFF111827),
        text: Color(0xFFE5E7EB),
        secondary: Color(0xFF9CA3AF),
      );
    }
    return const _ComicPalette(
      background: Color(0xFFF5EFD8),
      surface: Color(0xFFF8F3E5),
      text: Color(0xFF1F2937),
      secondary: Color(0xFF6B7280),
    );
  }

  Widget _buildProgressBar() {
    final palette = _palette;
    if (!(_readConfig?.showReadingProgress ?? true)) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: _overallProgress,
            onChanged: (value) {
              setState(() {
                final chapterIndex = _safeChapterIndexFromSlider(value);
                if (chapterIndex == _currentIndex && _scrollController.hasClients) {
                  final ratio = _safeChapterRatioFromSlider(value, chapterIndex);
                  final target = _scrollController.position.maxScrollExtent * ratio;
                  _scrollController.jumpTo(target);
                }
              });
            },
            onChangeEnd: (value) {
              final chapterIndex = _safeChapterIndexFromSlider(value);
              final ratio = _safeChapterRatioFromSlider(value, chapterIndex);
              _jumpToChapter(chapterIndex, scrollRatio: ratio);
            },
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Chapter ${_currentIndex + 1}/${widget.chapters.length}',
                style: TextStyle(color: palette.secondary),
              ),
            ),
            Text(
              '${(_overallProgress * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: palette.secondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageTile(String url, int index) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        index == 0 ? 12 : 8,
        12,
        8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.fitWidth,
          placeholder: (context, _) => Container(
            color: Colors.black12,
            constraints: const BoxConstraints(minHeight: 220),
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, _, __) => Container(
            color: Colors.black12,
            constraints: const BoxConstraints(minHeight: 220),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined, size: 28),
                  SizedBox(height: 8),
                  Text('图片加载失败'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final palette = _palette;
    final chapter = widget.chapters[_currentIndex];
    return FutureBuilder<ReadingContent>(
      future: _ensureContentLoaded(_currentIndex),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            color: palette.background,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Container(
            color: palette.background,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      '漫画章节加载失败',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _contentFutures.remove(_currentIndex);
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final content = snapshot.data!;
        if (content.imageUrls.isEmpty) {
          return Container(
            color: palette.background,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_outlined, size: 44),
                    const SizedBox(height: 12),
                    Text(
                      '当前章节解析为文字内容。',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '请切换到文字阅读器继续阅读。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.secondary),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _openTextFallback(content),
                      icon: const Icon(Icons.chrome_reader_mode_outlined),
                      label: const Text('打开文字阅读器'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleImmersive,
          child: Container(
            color: palette.background,
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(bottom: _immersive ? 24 : 132),
              itemCount: content.imageUrls.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.book.name,
                          style: TextStyle(
                            color: palette.secondary,
                            fontSize: 13,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          chapter.title,
                          style: TextStyle(
                            color: palette.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                (_offlineStatus?.assetsDownloaded ?? false)
                                    ? '已离线'
                                    : (_offlineStatus?.hasPayload ?? false)
                                        ? '已缓存目录'
                                        : '仅在线',
                              ),
                            ),
                            Chip(label: Text('${content.imageUrls.length} 页')),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                return _buildImageTile(content.imageUrls[index - 1], index - 1);
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapters[_currentIndex];
    final palette = _palette;
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: palette.background,
        appBarTheme: AppBarTheme(
          backgroundColor: palette.surface,
          foregroundColor: palette.text,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        appBar: _immersive
            ? null
            : AppBar(
                title: Text(
                  chapter.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  IconButton(
                    onPressed: _cacheCurrentChapter,
                    icon: _downloadingOffline
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_for_offline_outlined),
                    tooltip: '离线保存漫画',
                  ),
                  IconButton(
                    onPressed: _openChapterSheet,
                    icon: const Icon(Icons.format_list_numbered),
                    tooltip: '目录',
                  ),
                  IconButton(
                    onPressed: _openSettingsSheet,
                    icon: const Icon(Icons.tune),
                    tooltip: '设置',
                  ),
                ],
              ),
        body: _bootstrapping
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(),
        bottomNavigationBar: _immersive
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(color: palette.surface),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildProgressBar(),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _currentIndex == 0
                                    ? null
                                    : () => _changeChapter(-1),
                                icon: const Icon(Icons.chevron_left),
                                label: const Text('上一章'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _openChapterSheet,
                              icon: const Icon(Icons.view_list_outlined),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _cacheCurrentChapter,
                              icon: const Icon(Icons.download_done_outlined),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _currentIndex >= widget.chapters.length - 1
                                    ? null
                                    : () => _changeChapter(1),
                                icon: const Icon(Icons.chevron_right),
                                label: const Text('下一章'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ComicPalette {
  const _ComicPalette({
    required this.background,
    required this.surface,
    required this.text,
    required this.secondary,
  });

  final Color background;
  final Color surface;
  final Color text;
  final Color secondary;
}
