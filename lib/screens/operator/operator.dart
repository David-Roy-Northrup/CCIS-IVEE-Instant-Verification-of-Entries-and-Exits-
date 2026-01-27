// lib/screens/operator/operator.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'operator_home.dart';
import 'operator_scanner.dart';
import 'operator_settings.dart';

class OperatorMain extends StatefulWidget {
  const OperatorMain({super.key});

  @override
  State<OperatorMain> createState() => _OperatorMainState();
}

class _OperatorMainState extends State<OperatorMain> {
  int _selectedIndex = 0;
  bool _hasInternet = true;

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  final List<Widget> _pages = const [
    OperatorHome(),
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
          // Go back to home screen when back online
          _selectedIndex = 0;
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
    if (!_hasInternet) return; // disable buttons when offline
    setState(() => _selectedIndex = index);
  }

  Widget _buildHeader() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 3, left: 16, bottom: 0),
        child: Image.asset('assets/header.png', width: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0A0F3C);
    const grayBtn = Colors.grey;

    return WillPopScope(
      // BLOCK Android back button + back swipe/gesture
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: navy,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
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
