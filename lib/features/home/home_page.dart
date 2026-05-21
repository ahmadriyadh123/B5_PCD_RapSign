import 'package:flutter/material.dart';
import 'package:logbook_app_001/features/logbook/log_view.dart';
import 'package:logbook_app_001/features/legalitas/legalitas_view.dart';

class HomePage extends StatefulWidget {
  final String username;
  final String teamId;
  final String role;

  const HomePage({
    super.key,
    required this.username,
    required this.teamId,
    required this.role,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      LogView(username: widget.username, teamId: widget.teamId, role: widget.role),
      const LegalitasView(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Logbook',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.verified),
            label: 'Legalitas',
          ),
        ],
      ),
    );
  }
}
