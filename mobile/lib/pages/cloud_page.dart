import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import '../utils/display_labels.dart';

class CloudPage extends StatefulWidget {
  const CloudPage({
    super.key,
    required this.sessionStore,
  });

  final SessionStore sessionStore;

  @override
  State<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends State<CloudPage> {
  late ApiClient _client;
  SyncOverview? _overview;
  bool _loading = true;

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
      final overview = await _client.getSyncOverview();
      if (!mounted) {
        return;
      }
      setState(() {
        _overview = overview;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggle({
    bool? autoBookshelfBackup,
    bool? autoSourceBackup,
    bool? autoProgressSync,
  }) async {
    await _client.updateSyncSettings(
      autoBookshelfBackup: autoBookshelfBackup,
      autoSourceBackup: autoSourceBackup,
      autoProgressSync: autoProgressSync,
    );
    await _refresh();
  }

  Future<void> _run(Future<void> Function() action, String successText) async {
    await action();
    await _refresh();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successText)),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '尚未运行';
    }
    return value.toLocal().toString().replaceFirst('.000', '');
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    required VoidCallback onRun,
    required String lastTimeLabel,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Switch(value: enabled, onChanged: onChanged),
              ],
            ),
            Text(subtitle),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRun,
              child: const Text('立即执行'),
            ),
            const SizedBox(height: 8),
            Text('上次运行：$lastTimeLabel'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _overview == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('同步能力'),
              subtitle: Text('当前身份：${membershipLabel(_overview!.membershipTier)}'),
              trailing: Text(
                '书架 ${_overview!.shelfCount} / 书源 ${_overview!.sourceCount}',
              ),
            ),
          ),
          _buildCard(
            title: '书架备份',
            subtitle: '把本地书架状态保存到你的自有后端。',
            enabled: _overview!.autoBookshelfBackup,
            onChanged: (value) => _toggle(autoBookshelfBackup: value),
            onRun: () => _run(_client.backupBookshelf, '书架备份完成'),
            lastTimeLabel: _formatDate(_overview!.lastBookshelfBackupAt),
          ),
          _buildCard(
            title: '书源备份',
            subtitle: '同步你已经筛选过的书源集合。',
            enabled: _overview!.autoSourceBackup,
            onChanged: (value) => _toggle(autoSourceBackup: value),
            onRun: () => _run(_client.backupSources, '书源备份完成'),
            lastTimeLabel: _formatDate(_overview!.lastSourceBackupAt),
          ),
          _buildCard(
            title: '阅读进度同步',
            subtitle: '上传阅读进度，方便后续多设备续读。',
            enabled: _overview!.autoProgressSync,
            onChanged: (value) => _toggle(autoProgressSync: value),
            onRun: () => _run(_client.pushProgress, '阅读进度同步完成'),
            lastTimeLabel: _formatDate(_overview!.lastProgressSyncAt),
          ),
        ],
      ),
    );
  }
}
