import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/session_store.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({
    super.key,
    required this.sessionStore,
  });

  final SessionStore sessionStore;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _baseUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController.text = widget.sessionStore.state.value.baseUrl;
    _tokenController.text = widget.sessionStore.state.value.token;
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
    });
    try {
      final baseUrl = _baseUrlController.text.trim();
      final token = _tokenController.text.trim();
      await widget.sessionStore.saveBaseUrl(baseUrl);
      final client = ApiClient(baseUrl: baseUrl, token: token);
      final user = await client.getMe();
      await widget.sessionStore.saveOwnerSession(
        baseUrl: baseUrl,
        token: token,
        user: user,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '轻读私人版',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '当前版本无需登录，填写后端地址和设备令牌后即可进入。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      labelText: '后端 API 地址',
                      hintText: 'http://127.0.0.1:3030/api',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tokenController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '设备令牌',
                      hintText: '仅本地开发可留空',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _connect,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('进入应用'),
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
