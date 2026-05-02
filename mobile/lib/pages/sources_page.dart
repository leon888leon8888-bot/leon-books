import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';
import '../utils/display_labels.dart';

class SourcesPage extends StatefulWidget {
  const SourcesPage({
    super.key,
    required this.sessionStore,
  });

  final SessionStore sessionStore;

  @override
  State<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends State<SourcesPage> {
  late ApiClient _client;
  List<SourceRule> _sources = const [];
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
      final sources = await _client.getSources();
      if (!mounted) {
        return;
      }
      setState(() {
        _sources = sources;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _addSource() async {
    await _client.importSource(
      name: '自托管 OPDS 示例',
      url: 'https://example.com/opds',
      type: 'book',
    );
    await _refresh();
  }

  Future<void> _checkSource(SourceRule source) async {
    await _client.checkSource(source.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _addSource,
            icon: const Icon(Icons.add_link),
            label: const Text('导入示例书源'),
          ),
          const SizedBox(height: 16),
          for (final source in _sources)
            Card(
              child: ListTile(
                title: Text(source.name),
                subtitle: Text('${sourceTypeLabel(source.type)} / ${source.url}'),
                trailing: FilledButton.tonal(
                  onPressed: () => _checkSource(source),
                  child: Text(source.lastCheckStatus == 'ok'
                      ? '已校验'
                      : '校验 ${sourceStatusLabel(source.lastCheckStatus)}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
