// lib/screens/operator/administrator.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'administrator_home.dart';
import '/screens/operator/operator_scanner.dart';
import '/screens/operator/operator_settings.dart';

class AdministratorMain extends StatefulWidget {
  const AdministratorMain({super.key});

  @override
  State<AdministratorMain> createState() => _AdministratorMainState();
}

class _AdministratorMainState extends State<AdministratorMain> {
  int _selectedIndex = 0;
  bool _hasInternet = true;

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  final List<Widget> _pages = const [
    AdministratorHome(),
    OperatorScanner(),
    OperatorSettings(),
  ];

  @override
  void initState() {
    super.initState();
    _initConnectivity();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      _updateConnectivity(connected);
    });
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    final connected = result != ConnectivityResult.none;
    _updateConnectivity(connected);
  }

  void _updateConnectivity(bool connected) {
    if (connected != _hasInternet) {
      setState(() {
        _hasInternet = connected;
        if (_hasInternet) {
          _selectedIndex = 0; // go back home when online again
        }
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (!_hasInternet) return;
    setState(() => _selectedIndex = index);
  }

  Widget _buildHeader() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        // tightened (no top padding) so it hugs the tabs more
        padding: const EdgeInsets.only(left: 16),
        child: Image.asset('assets/header.png', width: 200),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    // Disable Android system back button
    return false;
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0A0F3C);
    const grayBtn = Colors.grey;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: navy,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),

              Expanded(
                child: _hasInternet
                    ? IndexedStack(index: _selectedIndex, children: _pages)
                    : const Center(
                        child: Text(
                          'No Internet Connection',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: navy,
            indicatorColor: Colors.white,
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(color: Colors.white),
            ),
            iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: navy);
              }
              return const IconThemeData(color: Colors.white);
            }),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            destinations: [
              NavigationDestination(
                icon: Icon(
                  Icons.home_outlined,
                  color: _hasInternet ? Colors.white : grayBtn,
                ),
                selectedIcon: Icon(
                  Icons.home,
                  color: _hasInternet ? navy : grayBtn,
                ),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: _hasInternet ? Colors.white : grayBtn,
                ),
                selectedIcon: Icon(
                  Icons.add_circle,
                  color: _hasInternet ? navy : grayBtn,
                ),
                label: 'Scan',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.settings_outlined,
                  color: _hasInternet ? Colors.white : grayBtn,
                ),
                selectedIcon: Icon(
                  Icons.settings,
                  color: _hasInternet ? navy : grayBtn,
                ),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
