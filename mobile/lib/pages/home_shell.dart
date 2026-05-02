import 'package:flutter/material.dart';

import '../services/session_store.dart';
import 'bookshelf_page.dart';
import 'cloud_page.dart';
import 'optimize_page.dart';
import 'sources_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.sessionStore,
  });

  final SessionStore sessionStore;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      BookshelfPage(sessionStore: widget.sessionStore),
      SourcesPage(sessionStore: widget.sessionStore),
      CloudPage(sessionStore: widget.sessionStore),
      OptimizePage(sessionStore: widget.sessionStore),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leon的书'),
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() {
            _index = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub),
            label: '书源',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: '同步',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
