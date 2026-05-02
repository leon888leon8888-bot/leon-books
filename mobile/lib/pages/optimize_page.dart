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
  bool _loading = true;
  String? _errorMessage;
  double? _draftFontSize;
  double? _draftLineHeight;

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
      _errorMessage = null;
    });
    try {
      final overview = await _client.getLibraryOverview();
      final ttsEngines = await _client.getTtsEngines();
      if (!mounted) {
        return;
      }
      setState(() {
        _overview = overview;
        _ttsEngines = ttsEngines;
        _draftFontSize = overview.readConfig.fontSize;
        _draftLineHeight = overview.readConfig.lineHeight;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveReadConfig(Map<String, dynamic> patch) async {
    await _client.updateReadConfig(patch);
    await _refresh();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('阅读设置已保存')),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 42),
            const SizedBox(height: 12),
            Text(
              '暂时连不上阅读服务',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadSettings(ReadConfig config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '阅读体验',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('主题'),
              subtitle: Text(themeLabel(config.themeName)),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'paper', label: Text('纸张')),
                  ButtonSegment(value: 'night', label: Text('夜间')),
                ],
                selected: {config.themeName},
                onSelectionChanged: (values) {
                  _saveReadConfig({'themeName': values.first});
                },
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: config.immersiveMode,
              title: const Text('沉浸式阅读'),
              subtitle: const Text('阅读时点击页面可隐藏或显示工具栏。'),
              onChanged: (value) => _saveReadConfig({'immersiveMode': value}),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: config.enableContentPurify,
              title: const Text('正文净化'),
              subtitle: const Text('自动过滤多余空行和常见干扰内容。'),
              onChanged: (value) =>
                  _saveReadConfig({'enableContentPurify': value}),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: config.showReadingProgress,
              title: const Text('阅读进度条'),
              subtitle: const Text('显示章内进度和整本书进度。'),
              onChanged: (value) =>
                  _saveReadConfig({'showReadingProgress': value}),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: config.autoTtsNextChapter,
              title: const Text('朗读自动下一章'),
              subtitle: const Text('当前章节朗读完成后继续播放下一章。'),
              onChanged: (value) =>
                  _saveReadConfig({'autoTtsNextChapter': value}),
            ),
            const Divider(height: 28),
            Text('字号：${(_draftFontSize ?? config.fontSize).toStringAsFixed(0)}'),
            Slider(
              min: 14,
              max: 32,
              value: (_draftFontSize ?? config.fontSize).clamp(14, 32).toDouble(),
              onChangeEnd: (value) => _saveReadConfig({'fontSize': value}),
              onChanged: (value) => setState(() {
                _draftFontSize = value;
              }),
            ),
            Text('行高：${(_draftLineHeight ?? config.lineHeight).toStringAsFixed(1)}'),
            Slider(
              min: 1.2,
              max: 2.2,
              value: (_draftLineHeight ?? config.lineHeight).clamp(1.2, 2.2).toDouble(),
              onChangeEnd: (value) => _saveReadConfig({'lineHeight': value}),
              onChanged: (value) => setState(() {
                _draftLineHeight = value;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(LibraryOverview overview) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '内容服务',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('书源 ${overview.bookSourceCount}')),
                Chip(label: Text('书架 ${overview.shelfCount}')),
                Chip(label: Text('朗读音源 ${overview.ttsEngineCount}')),
                Chip(label: Text('净化规则 ${overview.replaceRuleCount}')),
              ],
            ),
            const SizedBox(height: 8),
            const Text('书源和后端校验由服务器自动维护，手机端只负责搜索、阅读、漫画和朗读。'),
          ],
        ),
      ),
    );
  }

  Widget _buildTtsEngines() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '可用朗读音源',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            if (_ttsEngines.isEmpty)
              const Text('暂时没有可用音源。')
            else
              for (final engine in _ttsEngines.take(8))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(engine.name),
                  subtitle: Text(engine.voice.isEmpty ? '默认音色' : engine.voice),
                  trailing: Text(engine.enabled ? '可用' : '停用'),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null || _overview == null) {
      return _buildError();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOverview(_overview!),
          _buildReadSettings(_overview!.readConfig),
          _buildTtsEngines(),
        ],
      ),
    );
  }
}
