import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/offline_library.dart';
import '../services/reading_cleaner.dart';
import '../services/session_store.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({
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
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  static const List<double> _ttsSpeeds = [0.85, 1.0, 1.2, 1.5];
  static const List<_FontOption> _fontOptions = [
    _FontOption(label: '系统默认', value: 'system'),
    _FontOption(label: '苹方', value: 'PingFang SC'),
    _FontOption(label: 'Georgia', value: 'Georgia'),
    _FontOption(label: 'Menlo', value: 'Menlo'),
  ];

  late ApiClient _client;
  late PageController _pageController;
  late ScrollController _scrollController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final OfflineLibrary _offlineLibrary = OfflineLibrary.instance;
  final Map<int, Future<ReadingContent>> _contentFutures = {};
  final Map<int, double> _scrollOffsets = {};

  ReadConfig? _readConfig;
  List<TtsEngine> _ttsEngines = const [];
  List<ReplaceRule> _replaceRules = const [];
  String _selectedTtsId = '';
  ShelfBook? _shelfBook;
  OfflineChapterStatus? _offlineStatus;
  int _currentIndex = 0;
  int _currentTtsChunkIndex = -1;
  bool _clientReady = false;
  bool _bootstrapping = true;
  bool _immersive = false;
  bool _downloadingOffline = false;
  bool _loadingTts = false;
  double _scrollProgress = 0;
  double _ttsSpeed = 1.0;
  Timer? _sleepTimer;
  StreamSubscription<int?>? _playerIndexSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<bool>? _playerPlayingSubscription;

  @override
  void initState() {
    super.initState();
    _currentIndex =
        (widget.initialChapterIndex.clamp(0, widget.chapters.length - 1) as num)
            .toInt();
    _shelfBook = widget.shelfBook;
    _pageController = PageController(initialPage: _currentIndex);
    _scrollController = ScrollController()..addListener(_handleScroll);
    if (widget.initialContent != null) {
      _contentFutures[_currentIndex] = Future.value(widget.initialContent!);
    }
    _playerIndexSubscription = _audioPlayer.currentIndexStream.listen((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentTtsChunkIndex = value ?? -1;
      });
    });
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handleTtsCompleted();
      }
    });
    _playerPlayingSubscription = _audioPlayer.playingStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _playerIndexSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _playerPlayingSubscription?.cancel();
    _audioPlayer.dispose();
    if (_clientReady) {
      unawaited(_persistProgress(_currentIndex));
    }
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _pageController.dispose();
    _applyImmersiveMode(false);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final session = widget.sessionStore.state.value;
    _client = ApiClient(baseUrl: session.baseUrl, token: session.token);
    _clientReady = true;
    try {
      await _offlineLibrary.initialize();
      final results = await Future.wait([
        _client.getReadConfig(),
        _client.getTtsEngines().catchError((_) => <TtsEngine>[]),
        _client.getDefaultTtsId().catchError((_) => ''),
        _client.getReplaceRules().catchError((_) => <ReplaceRule>[]),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _readConfig = results[0] as ReadConfig;
        _ttsEngines = results[1] as List<TtsEngine>;
        _selectedTtsId = (results[2] as String).isEmpty && _ttsEngines.isNotEmpty
            ? _ttsEngines.first.id
            : results[2] as String;
        _replaceRules = results[3] as List<ReplaceRule>;
        _immersive = _readConfig?.immersiveMode ?? false;
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
    SystemChrome.setSystemUIOverlayStyle(
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
      if (index == _currentIndex) {
        unawaited(_refreshOfflineStatus());
      }
      return networkContent;
    } catch (error) {
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
    final progress = widget.chapters.length <= 1
        ? 100.0
        : (index / (widget.chapters.length - 1)) * 100;

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
        progress: progress,
        origin: 'reader',
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
      progress: progress,
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
      _scrollProgress = 0;
    });
    _ensureContentLoaded(index);
    _prefetchNeighbors(index);
    await _persistProgress(index);
    await _refreshOfflineStatus();
  }

  Future<void> _jumpToChapter(int index) async {
    final safeIndex =
        (index.clamp(0, widget.chapters.length - 1) as num).toInt();
    final isSlideMode = _readConfig?.pageTurnMode == 'slide';
    if (isSlideMode) {
      await _pageController.animateToPage(
        safeIndex,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _handleChapterChanged(safeIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final offset = _scrollOffsets[_currentIndex] ?? 0;
        _scrollController.jumpTo(
          (offset.clamp(0, _scrollController.position.maxScrollExtent) as num)
              .toDouble(),
        );
      }
    });
  }

  Future<void> _changeChapter(int delta) async {
    await _jumpToChapter(_currentIndex + delta);
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
    if ((nextProgress - _scrollProgress).abs() > 0.01 && mounted) {
      setState(() {
        _scrollProgress = nextProgress;
      });
    }
  }

  Future<void> _cacheCurrentChapter({bool forceAssetDownload = false}) async {
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
        downloadAssets: forceAssetDownload,
      );
      await _refreshOfflineStatus();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            forceAssetDownload
                ? '章节和资源已离线保存'
                : '章节已离线保存',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingOffline = false;
        });
      }
    }
  }

  Future<void> _handleTtsCompleted() async {
    if ((_readConfig?.autoTtsNextChapter ?? false) &&
        _currentIndex < widget.chapters.length - 1) {
      await _jumpToChapter(_currentIndex + 1);
      await _startTtsPlayback(restart: true);
    }
  }

  int _speechRateValue() {
    final value = (_ttsSpeed * 5).round();
    return value.clamp(1, 9).toInt();
  }

  List<String> _ttsChunks(String text) {
    final cleaned = text.replaceAll('\r', '').trim();
    final matches =
        RegExp(r'[^。！？!?；;]+[。！？!?；;]?', dotAll: true).allMatches(cleaned);
    final segments = <String>[];
    for (final match in matches) {
      final segment = match.group(0)?.trim() ?? '';
      if (segment.isNotEmpty) {
        segments.add(segment);
      }
    }
    if (segments.isEmpty && cleaned.isNotEmpty) {
      segments.add(cleaned);
    }

    final chunks = <String>[];
    final buffer = StringBuffer();
    for (final segment in segments) {
      if (buffer.isEmpty) {
        buffer.write(segment);
        continue;
      }
      if ((buffer.length + segment.length + 1) > 280) {
        chunks.add(buffer.toString());
        buffer
          ..clear()
          ..write(segment);
        continue;
      }
      buffer
        ..write('\n')
        ..write(segment);
    }
    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString());
    }
    return chunks;
  }

  Future<void> _startTtsPlayback({bool restart = false}) async {
    if (_selectedTtsId.isEmpty) {
      if (_ttsEngines.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无可用朗读音源')),
        );
        return;
      }
      setState(() {
        _selectedTtsId = _ttsEngines.first.id;
      });
    }

    setState(() {
      _loadingTts = true;
    });
    try {
      final content = await _ensureContentLoaded(_currentIndex);
      final cleanedText = _displayParagraphs(content).join('\n');
      final chunks = _ttsChunks(cleanedText);
      if (chunks.isEmpty) {
        throw Exception('没有可朗读的正文内容');
      }
      final sources = chunks
          .map(
            (chunk) => AudioSource.uri(
              _client.buildTtsStreamUri(
                id: _selectedTtsId,
                text: chunk,
                speechRate: _speechRateValue(),
              ),
            ),
          )
          .toList();
      await _audioPlayer.stop();
      await _audioPlayer.setSpeed(_ttsSpeed);
      await _audioPlayer.setAudioSources(
        sources,
        initialIndex: 0,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _currentTtsChunkIndex = 0;
      });
      await _audioPlayer.play();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('朗读失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingTts = false;
        });
      }
    }
  }

  Future<void> _pauseTts() => _audioPlayer.pause();

  Future<void> _resumeTts() => _audioPlayer.play();

  Future<void> _stopTts() async {
    _sleepTimer?.cancel();
    await _audioPlayer.stop();
    if (mounted) {
      setState(() {
        _currentTtsChunkIndex = -1;
      });
    }
  }

  void _setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    if (duration == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清除定时关闭')),
        );
      }
      return;
    }
    _sleepTimer = Timer(duration, () {
      _audioPlayer.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('定时关闭已触发')),
        );
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已设置 ${duration.inMinutes} 分钟后停止朗读')),
      );
    }
  }

  Future<void> _openChapterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return ListView.builder(
          itemCount: widget.chapters.length,
          itemBuilder: (context, index) {
            final chapter = widget.chapters[index];
            final selected = index == _currentIndex;
            return ListTile(
              selected: selected,
              onTap: chapter.isVolume
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _jumpToChapter(index);
                    },
              title: Text(chapter.title),
              subtitle: chapter.isPay || chapter.isVip
                  ? const Text('可能需要支持付费内容的书源')
                  : null,
              trailing: selected ? const Icon(Icons.play_circle_fill) : null,
            );
          },
        );
      },
    );
  }

  Future<void> _openSettingsSheet() async {
    final current = _readConfig;
    if (current == null) {
      return;
    }

    double fontSize = current.fontSize;
    double lineHeight = current.lineHeight;
    double paragraphSpacing = current.paragraphSpacing;
    String pageTurnMode = current.pageTurnMode;
    String themeName = current.themeName;
    String fontFamily = current.fontFamily;
    bool justifyText = current.justifyText;
    bool boldText = current.boldText;
    bool immersiveMode = current.immersiveMode;
    bool enableContentPurify = current.enableContentPurify;
    bool showReadingProgress = current.showReadingProgress;
    bool autoTtsNextChapter = current.autoTtsNextChapter;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    '阅读设置',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 18),
                  Text('字号 ${fontSize.toStringAsFixed(0)}'),
                  Slider(
                    min: 14,
                    max: 32,
                    value: (fontSize.clamp(14, 32) as num).toDouble(),
                    onChanged: (value) => setSheetState(() => fontSize = value),
                  ),
                  Text('行高 ${lineHeight.toStringAsFixed(1)}'),
                  Slider(
                    min: 1.2,
                    max: 2.2,
                    value: (lineHeight.clamp(1.2, 2.2) as num).toDouble(),
                    onChanged: (value) => setSheetState(() => lineHeight = value),
                  ),
                  Text('段距 ${paragraphSpacing.toStringAsFixed(0)}'),
                  Slider(
                    min: 4,
                    max: 24,
                    value: (paragraphSpacing.clamp(4, 24) as num).toDouble(),
                    onChanged: (value) =>
                        setSheetState(() => paragraphSpacing = value),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: fontFamily,
                    decoration: const InputDecoration(labelText: '字体'),
                    items: _fontOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.value,
                            child: Text(option.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setSheetState(() => fontFamily = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'paper', label: Text('纸张')),
                      ButtonSegment(value: 'night', label: Text('夜间')),
                    ],
                    selected: {themeName},
                    onSelectionChanged: (value) {
                      setSheetState(() => themeName = value.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'slide', label: Text('翻页')),
                      ButtonSegment(value: 'scroll', label: Text('滚动')),
                    ],
                    selected: {pageTurnMode},
                    onSelectionChanged: (value) {
                      setSheetState(() => pageTurnMode = value.first);
                    },
                  ),
                  SwitchListTile(
                    value: justifyText,
                    onChanged: (value) =>
                        setSheetState(() => justifyText = value),
                    title: const Text('两端对齐'),
                  ),
                  SwitchListTile(
                    value: boldText,
                    onChanged: (value) => setSheetState(() => boldText = value),
                    title: const Text('加粗正文'),
                  ),
                  SwitchListTile(
                    value: immersiveMode,
                    onChanged: (value) =>
                        setSheetState(() => immersiveMode = value),
                    title: const Text('沉浸式阅读'),
                  ),
                  SwitchListTile(
                    value: enableContentPurify,
                    onChanged: (value) =>
                        setSheetState(() => enableContentPurify = value),
                    title: const Text('正文净化'),
                    subtitle:
                        const Text('过滤广告行并应用净化规则'),
                  ),
                  SwitchListTile(
                    value: showReadingProgress,
                    onChanged: (value) =>
                        setSheetState(() => showReadingProgress = value),
                    title: const Text('显示长进度条'),
                  ),
                  SwitchListTile(
                    value: autoTtsNextChapter,
                    onChanged: (value) =>
                        setSheetState(() => autoTtsNextChapter = value),
                    title: const Text('朗读自动下一章'),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () async {
                      final updated = await _client.updateReadConfig({
                        'fontSize': fontSize,
                        'lineHeight': lineHeight,
                        'paragraphSpacing': paragraphSpacing,
                        'fontFamily': fontFamily,
                        'pageTurnMode': pageTurnMode,
                        'themeName': themeName,
                        'justifyText': justifyText,
                        'boldText': boldText,
                        'immersiveMode': immersiveMode,
                        'enableContentPurify': enableContentPurify,
                        'showReadingProgress': showReadingProgress,
                        'autoTtsNextChapter': autoTtsNextChapter,
                      });
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _readConfig = updated;
                        _immersive = updated.immersiveMode;
                      });
                      await _applyImmersiveMode(updated.immersiveMode);
                      if (pageTurnMode == 'slide') {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_pageController.hasClients) {
                            _pageController.jumpToPage(_currentIndex);
                          }
                        });
                      }
                      Navigator.of(context).pop();
                    },
                    child: const Text('应用'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openTtsSheet() async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        String localSelectedTtsId = _selectedTtsId;
        double localSpeed = _ttsSpeed;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final playing = _audioPlayer.playing;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    '朗读',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '阅读器内置播放器、倍速、定时关闭和自动续章。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: localSelectedTtsId.isEmpty ? null : localSelectedTtsId,
                    decoration: const InputDecoration(labelText: '音色'),
                    items: _ttsEngines
                        .map(
                          (engine) => DropdownMenuItem(
                            value: engine.id,
                            child: Text(engine.voice.isEmpty
                                ? engine.name
                                : '${engine.name} · ${engine.voice}'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setSheetState(() => localSelectedTtsId = value);
                      setState(() {
                        _selectedTtsId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('播放速度 ${localSpeed.toStringAsFixed(2)}x'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _ttsSpeeds
                        .map(
                          (speed) => ChoiceChip(
                            label: Text('${speed.toStringAsFixed(speed == 1 ? 0 : 2)}x'),
                            selected: (localSpeed - speed).abs() < 0.01,
                            onSelected: (_) async {
                              setSheetState(() => localSpeed = speed);
                              setState(() {
                                _ttsSpeed = speed;
                              });
                              if (_audioPlayer.playing) {
                                await _audioPlayer.setSpeed(speed);
                              }
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _loadingTts
                              ? null
                              : () async {
                                  Navigator.of(context).pop();
                                  await _startTtsPlayback();
                                },
                          icon: const Icon(Icons.play_arrow),
                          label: Text(playing ? '重新播放' : '播放'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: playing ? _pauseTts : _resumeTts,
                          icon: Icon(playing ? Icons.pause : Icons.play_circle_outline),
                          label: Text(playing ? '暂停' : '继续'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _stopTts,
                          icon: const Icon(Icons.stop),
                          label: const Text('停止'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentTtsChunkIndex < 0
                        ? '当前没有朗读片段'
                        : '正在朗读第 ${_currentTtsChunkIndex + 1} 段',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '定时关闭',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('15 分钟'),
                        onPressed: () => _setSleepTimer(const Duration(minutes: 15)),
                      ),
                      ActionChip(
                        label: const Text('30 分钟'),
                        onPressed: () => _setSleepTimer(const Duration(minutes: 30)),
                      ),
                      ActionChip(
                        label: const Text('60 分钟'),
                        onPressed: () => _setSleepTimer(const Duration(hours: 1)),
                      ),
                      ActionChip(
                        label: const Text('清除'),
                        onPressed: () => _setSleepTimer(null),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  _ReaderPalette get _palette {
    switch (_readConfig?.themeName) {
      case 'night':
        return const _ReaderPalette(
          background: Color(0xFF111827),
          surface: Color(0xFF0F172A),
          text: Color(0xFFF9FAFB),
          secondary: Color(0xFFCBD5E1),
        );
      case 'paper':
      default:
        return const _ReaderPalette(
          background: Color(0xFFF7F1E3),
          surface: Color(0xFFFFFBF1),
          text: Color(0xFF2D2A26),
          secondary: Color(0xFF6B6258),
        );
    }
  }

  String? _resolvedFontFamily() {
    final configured = _readConfig?.fontFamily ?? 'system';
    if (configured == 'system') {
      return null;
    }
    return configured;
  }

  List<String> _displayParagraphs(ReadingContent content) {
    return ReadingCleaner.paragraphs(
      content.text,
      enabled: _readConfig?.enableContentPurify ?? true,
      replaceRules: _replaceRules,
    );
  }

  Widget _buildReadingProgressBar() {
    final config = _readConfig;
    if (config == null || !config.showReadingProgress) {
      return const SizedBox.shrink();
    }
    final isSlideMode = config.pageTurnMode == 'slide';
    final sliderValue = isSlideMode
        ? (widget.chapters.length <= 1
            ? 0.0
            : (_currentIndex / (widget.chapters.length - 1))
                .clamp(0.0, 1.0)
                .toDouble())
        : _scrollProgress;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isSlideMode
                    ? '全书进度 ${(sliderValue * 100).toStringAsFixed(0)}%'
                    : '章内进度 ${(sliderValue * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: _palette.secondary),
              ),
            ),
            Text(
              _offlineStatus?.assetsDownloaded == true
                  ? '已离线'
                  : _offlineStatus?.hasPayload == true
                      ? '已缓存'
                      : '仅在线',
              style: TextStyle(color: _palette.secondary),
            ),
          ],
        ),
        Slider(
          value: sliderValue.clamp(0.0, 1.0).toDouble(),
          onChanged: (value) {
            setState(() {
              if (isSlideMode) {
                _scrollProgress = value;
              } else {
                _scrollProgress = value;
              }
            });
          },
          onChangeEnd: (value) async {
            if (isSlideMode) {
              final nextIndex = (value * (widget.chapters.length - 1)).round();
              await _jumpToChapter(nextIndex);
              return;
            }
            if (_scrollController.hasClients) {
              final maxExtent = _scrollController.position.maxScrollExtent;
              await _scrollController.animateTo(
                maxExtent * value,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildContentPage(int index) {
    final chapter = widget.chapters[index];
    final palette = _palette;
    final config = _readConfig;

    return FutureBuilder<ReadingContent>(
      future: _ensureContentLoaded(index),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    '章节加载失败',
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
                        _contentFutures.remove(index);
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              ),
            ),
          );
        }
        final content = snapshot.data!;
        final paragraphs = _displayParagraphs(content);
        final scrollView = SelectionArea(
          child: SingleChildScrollView(
            controller: config?.pageTurnMode == 'scroll' ? _scrollController : null,
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              _immersive ? 32 : 140,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.book.name,
                  style: TextStyle(
                    color: palette.secondary,
                    fontSize: 13,
                    letterSpacing: 0.4,
                    fontFamily: _resolvedFontFamily(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  chapter.title,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: (config?.fontSize ?? 18) + 5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    fontFamily: _resolvedFontFamily(),
                  ),
                ),
                const SizedBox(height: 18),
                for (final paragraph in paragraphs) ...[
                  Text(
                    paragraph,
                    textAlign: (config?.justifyText ?? true)
                        ? TextAlign.justify
                        : TextAlign.start,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: config?.fontSize ?? 18,
                      height: config?.lineHeight ?? 1.6,
                      fontWeight: (config?.boldText ?? false)
                          ? FontWeight.w600
                          : FontWeight.w400,
                      fontFamily: _resolvedFontFamily(),
                    ),
                  ),
                  SizedBox(height: config?.paragraphSpacing ?? 12),
                ],
              ],
            ),
          ),
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleImmersive,
          child: Container(
            color: palette.background,
            child: scrollView,
          ),
        );
      },
    );
  }

  Widget _buildReaderBody() {
    final isSlideMode = _readConfig?.pageTurnMode == 'slide';
    if (isSlideMode) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleImmersive,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.chapters.length,
          onPageChanged: _handleChapterChanged,
          itemBuilder: (context, index) => _buildContentPage(index),
        ),
      );
    }
    return _buildContentPage(_currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final chapter = widget.chapters[_currentIndex];
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
                    tooltip: '离线保存',
                  ),
                  IconButton(
                    onPressed: _openChapterSheet,
                    icon: const Icon(Icons.format_list_numbered),
                    tooltip: '目录',
                  ),
                ],
              ),
        body: _bootstrapping
            ? const Center(child: CircularProgressIndicator())
            : _buildReaderBody(),
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
                        _buildReadingProgressBar(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '第 ${_currentIndex + 1}/${widget.chapters.length} 章',
                                style: TextStyle(color: palette.secondary),
                              ),
                            ),
                            Text(
                              '${((_currentIndex + 1) / widget.chapters.length * 100).toStringAsFixed(0)}%',
                              style: TextStyle(color: palette.secondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _currentIndex == 0 ? null : () => _changeChapter(-1),
                                icon: const Icon(Icons.chevron_left),
                                label: const Text('上一章'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _openChapterSheet,
                              icon: const Icon(Icons.list_alt),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _openTtsSheet,
                              icon: const Icon(Icons.graphic_eq),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _openSettingsSheet,
                              icon: const Icon(Icons.tune),
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

class _ReaderPalette {
  const _ReaderPalette({
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

class _FontOption {
  const _FontOption({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}
