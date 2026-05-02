import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/local_reader_database.dart';
import '../services/session_store.dart';
import '../utils/display_labels.dart';
import 'book_detail_page.dart';

class ReadingSearchPage extends StatefulWidget {
  const ReadingSearchPage({
    super.key,
    required this.sessionStore,
    this.embedded = false,
  });

  final SessionStore sessionStore;
  final bool embedded;

  @override
  State<ReadingSearchPage> createState() => _ReadingSearchPageState();
}

class _ReadingSearchPageState extends State<ReadingSearchPage> {
  final TextEditingController _queryController = TextEditingController();
  late ApiClient _client;

  SearchOptions? _options;
  GroupedSearchResult? _result;
  String _mode = 'fuzzy';
  String _category = 'book';
  String _sourceSelection = '';
  bool _loadingOptions = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    final session = widget.sessionStore.state.value;
    _client = ApiClient(baseUrl: session.baseUrl, token: session.token);
    setState(() {
      _loadingOptions = true;
    });
    try {
      final options = await _client.getSearchOptions();
      if (!mounted) {
        return;
      }
      setState(() {
        _options = options;
        _mode = options.defaultMode;
        _category = options.defaultCategory;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接阅读服务失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingOptions = false;
        });
      }
    }
  }

  Future<void> _runSearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      return;
    }
    setState(() {
      _searching = true;
    });
    try {
      final result = await _client.searchGroupedBooks(
        query: query,
        mode: _mode,
        category: _category,
        sourceIds: _sourceSelection.isEmpty ? const [] : [_sourceSelection],
      );
      await LocalReaderDatabase.instance.addSearchHistory(
        query: query,
        category: _category,
        mode: _mode,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('搜索失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  Widget _buildCapabilityChip({
    required String label,
    required bool active,
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: active
          ? (color ?? scheme.primary).withOpacity(0.12)
          : scheme.surfaceContainerHighest,
      side: BorderSide(
        color: active ? (color ?? scheme.primary).withOpacity(0.32) : Colors.transparent,
      ),
      labelStyle: TextStyle(
        color: active ? (color ?? scheme.primary) : scheme.onSurfaceVariant,
        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }

  Future<void> _openVariant(SearchVariant variant) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BookDetailPage(
          sessionStore: widget.sessionStore,
          book: variant.book,
          sourceId: variant.source.id,
          sourceCapabilities: variant.source.capabilities,
        ),
      ),
    );
  }

  Future<void> _showVariantPicker(SearchGroup group) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              group.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '同一作品匹配到多个来源，请选择要打开的书源。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            for (final variant in group.variants)
              Card(
                child: ListTile(
                  onTap: () {
                    Navigator.of(context).pop();
                    _openVariant(variant);
                  },
                  title: Text(variant.source.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${variant.book.author.isEmpty ? '未知作者' : variant.book.author} - 评分 ${variant.score}',
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildCapabilityChip(
                            label: '小说',
                            active: variant.source.capabilities.supportsText,
                          ),
                          _buildCapabilityChip(
                            label: '漫画',
                            active: variant.source.capabilities.supportsComic,
                            color: const Color(0xFFEF6C00),
                          ),
                          _buildCapabilityChip(
                            label: '听书',
                            active: variant.source.capabilities.supportsAudio,
                            color: const Color(0xFF7B1FA2),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  isThreeLine: true,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSearchControls() {
    final sources = _options?.sources ?? const <SourceRule>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '快速搜索，自动合并同名资源',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                labelText: '按书名 / 作者搜索',
                suffixIcon: IconButton(
                  onPressed: _searching ? null : _runSearch,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '搜索模式',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'precise', label: Text('精准')),
                ButtonSegment(value: 'fuzzy', label: Text('模糊')),
              ],
              selected: {_mode},
              onSelectionChanged: (value) {
                setState(() {
                  _mode = value.first;
                });
              },
            ),
            const SizedBox(height: 14),
            Text(
              '内容类型',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'book', label: Text('小说')),
                ButtonSegment(value: 'comic', label: Text('漫画')),
                ButtonSegment(value: 'audio', label: Text('听书')),
                ButtonSegment(value: 'all', label: Text('全部')),
              ],
              selected: {_category},
              onSelectionChanged: (value) {
                setState(() {
                  _category = value.first;
                });
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _sourceSelection.isEmpty ? '__smart__' : _sourceSelection,
              decoration: const InputDecoration(labelText: '书源范围'),
              items: [
                const DropdownMenuItem(
                  value: '__smart__',
                  child: Text('智能优选书源'),
                ),
                ...sources.map(
                  (source) => DropdownMenuItem(
                    value: source.id,
                    child: Text(
                      '${source.name} (${sourceStatusLabel(source.lastCheckStatus)})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _sourceSelection = value == null || value == '__smart__' ? '' : value;
                });
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('三体'),
                  onPressed: () => _queryController.text = '三体',
                ),
                ActionChip(
                  label: const Text('侦探'),
                  onPressed: () => _queryController.text = '侦探',
                ),
                ActionChip(
                  label: const Text('冒险漫画'),
                  onPressed: () => _queryController.text = '冒险漫画',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(SearchGroup group) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => group.variants.length == 1 ? _openVariant(group.bestVariant) : _showVariantPicker(group),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      group.markers.supportsComic
                          ? Icons.photo_library_outlined
                          : group.markers.supportsAudio
                              ? Icons.headphones
                              : Icons.auto_stories,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${group.author.isEmpty ? '未知作者' : group.author} - ${group.kind.isEmpty ? '未知分类' : group.kind}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (group.wordCount.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            group.wordCount,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: () => group.variants.length == 1
                        ? _openVariant(group.bestVariant)
                        : _showVariantPicker(group),
                    child: Text(group.variants.length == 1 ? '打开' : '选择书源'),
                  ),
                ],
              ),
              if (group.intro.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  group.intro,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${group.sourceCount} 个书源')),
                  _buildCapabilityChip(label: '小说', active: group.markers.supportsText),
                  _buildCapabilityChip(
                    label: '漫画',
                    active: group.markers.supportsComic,
                    color: const Color(0xFFEF6C00),
                  ),
                  _buildCapabilityChip(
                    label: '听书',
                    active: group.markers.supportsAudio,
                    color: const Color(0xFF7B1FA2),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '推荐书源：${group.bestVariant.source.name}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunSummary() {
    final result = _result;
    if (result == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: ExpansionTile(
        title: Text('书源搜索摘要（${result.sourceRuns.length}）'),
        subtitle: Text(
          '${result.sourceCount} 个书源参与搜索，合并出 ${result.groupCount} 组结果',
        ),
        children: [
          for (final run in result.sourceRuns)
            ListTile(
              title: Text(run.name),
              subtitle: Text(
                '${sourceStatusLabel(run.status)} / ${run.elapsedMs} ms / ${run.resultCount} 条',
              ),
              trailing: Wrap(
                spacing: 6,
                children: [
                  if (run.capabilities.supportsComic)
                    const Icon(Icons.photo_library_outlined, size: 18),
                  if (run.capabilities.supportsAudio)
                    const Icon(Icons.graphic_eq, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _loadingOptions
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadOptions,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSearchControls(),
                const SizedBox(height: 8),
                if (_searching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_result == null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        '输入书名或作者即可搜索。结果会自动合并同一作品，并标注小说、漫画、听书能力。',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.5,
                            ),
                      ),
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Text(
                        '搜索结果',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '${_result!.groupCount}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final group in _result!.items) _buildGroupCard(group),
                  _buildRunSummary(),
                ],
              ],
            ),
          );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
      ),
      body: body,
    );
  }
}
