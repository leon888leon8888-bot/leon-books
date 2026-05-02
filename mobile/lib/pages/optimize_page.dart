import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import '../utils/display_labels.dart';

class OptimizePage extends StatefulWidget {
  const OptimizePage({
    super.key,
    required this.sessionStore,
  });

  final SessionStore sessionStore;

  @override
  State<OptimizePage> createState() => _OptimizePageState();
}

class _OptimizePageState extends State<OptimizePage> {
  late ApiClient _client;
  LibraryOverview? _overview;
  List<TtsEngine> _ttsEngines = const [];
  List<RssSource> _rssSources = const [];
  List<ReplaceRule> _replaceRules = const [];
  bool _loading = true;

  final _importPathType = ValueNotifier<String>('bookSource');
  final _importController = TextEditingController(
    text:
        '[{"name":"示例书源","url":"https://example.com/source.json","type":"book"}]',
  );

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _importPathType.dispose();
    _importController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final session = widget.sessionStore.state.value;
    _client = ApiClient(baseUrl: session.baseUrl, token: session.token);
    setState(() {
      _loading = true;
    });
    try {
      final overview = await _client.getLibraryOverview();
      final ttsEngines = await _client.getTtsEngines();
      final rssSources = await _client.getRssSources();
      final replaceRules = await _client.getReplaceRules();
      if (!mounted) {
        return;
      }
      setState(() {
        _overview = overview;
        _ttsEngines = ttsEngines;
        _rssSources = rssSources;
        _replaceRules = replaceRules;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _runImport() async {
    final payload = _buildImportPayload(_importController.text);

    final result = await _client.importByType(
      pathType: _importPathType.value,
      payload: payload,
    );
    await _refresh();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已导入 ${result.count} 条，类型：${importTypeLabel(result.pathType)}。'),
      ),
    );
  }

  dynamic _buildImportPayload(String text) {
    final raw = text.trim();
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return {'src': raw};
    }
    if (raw.startsWith('[') || raw.startsWith('{')) {
      final decoded = const JsonDecoder().convert(raw);
      if (decoded is List) {
        return {'items': decoded};
      }
      if (decoded is Map<String, dynamic>) {
        return {'items': [decoded]};
      }
    }
    return {
      'items': [
        {
          'name': '导入项目',
          'url': raw,
          'type': 'book',
        }
      ],
    };
  }

  Future<void> _saveReadConfig(ReadConfig current) async {
    await _client.updateReadConfig({
      'fontSize': current.fontSize,
      'lineHeight': current.lineHeight,
      'paragraphSpacing': current.paragraphSpacing,
      'fontFamily': current.fontFamily,
      'pageTurnMode': current.pageTurnMode == 'slide' ? 'scroll' : 'slide',
      'themeName': current.themeName == 'paper' ? 'night' : 'paper',
      'simplifyChinese': !current.simplifyChinese,
      'boldText': !current.boldText,
      'justifyText': current.justifyText,
      'autoTtsNextChapter': current.autoTtsNextChapter,
    });
    await _refresh();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('阅读配置已更新。')),
    );
  }

  Widget _countTile(String label, int count) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          '$count',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _overview == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final readConfig = _overview!.readConfig;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '阅读体验优化中心',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _countTile('书架项目', _overview!.shelfCount),
          _countTile('书源数量', _overview!.bookSourceCount),
          _countTile('RSS 源', _overview!.rssSourceCount),
          _countTile('净化规则', _overview!.replaceRuleCount),
          _countTile('朗读音源', _overview!.ttsEngineCount),
          _countTile('主题数量', _overview!.themeCount),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '统一导入中心',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder(
                    valueListenable: _importPathType,
                    builder: (context, pathType, _) {
                      return DropdownButtonFormField<String>(
                        value: pathType,
                        items: const [
                          DropdownMenuItem(value: 'bookSource', child: Text('书源')),
                          DropdownMenuItem(value: 'rssSource', child: Text('RSS 源')),
                          DropdownMenuItem(value: 'replaceRule', child: Text('净化规则')),
                          DropdownMenuItem(value: 'httpTTS', child: Text('朗读音源')),
                          DropdownMenuItem(value: 'theme', child: Text('主题')),
                          DropdownMenuItem(value: 'readConfig', child: Text('阅读配置')),
                          DropdownMenuItem(value: 'addToBookshelf', child: Text('加入书架')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _importPathType.value = value;
                          }
                        },
                        decoration: const InputDecoration(labelText: '导入类型'),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _importController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'JSON 内容或 URL',
                      hintText: '{"name":"示例","url":"https://example.com"}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _runImport,
                    child: const Text('开始导入'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '阅读配置',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('字号：${readConfig.fontSize.toStringAsFixed(0)}'),
                  Text('行高：${readConfig.lineHeight.toStringAsFixed(1)}'),
                  Text('段距：${readConfig.paragraphSpacing.toStringAsFixed(0)}'),
                  Text('主题：${themeLabel(readConfig.themeName)}'),
                  Text('翻页模式：${pageModeLabel(readConfig.pageTurnMode)}'),
                  Text('字体：${fontFamilyLabel(readConfig.fontFamily)}'),
                  Text('TTS 自动下一章：${boolLabel(readConfig.autoTtsNextChapter)}'),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => _saveReadConfig(readConfig),
                    child: const Text('切换主题和翻页模式'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '朗读音源',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final engine in _ttsEngines)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(engine.name),
                      subtitle: Text('${engine.voice}\n${engine.url}'),
                      isThreeLine: true,
                      trailing: Text(importTypeLabel(engine.engineType)),
                    ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RSS 与正文净化',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('RSS 源：${_rssSources.length}'),
                  Text('净化规则：${_replaceRules.length}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
