// lib/screens/operator/administrator_home.dart
// Tabs expanded to 5, spaced evenly, and NO back button in AppBar.

import 'package:flutter/material.dart';

import 'home_tabs/students_tab.dart';
import 'home_tabs/events_tab.dart';
import 'home_tabs/attendance_log_tab.dart';
import 'home_tabs/statistics_tab.dart';
import 'home_tabs/user_access_tab.dart';

class AdministratorHome extends StatefulWidget {
  const AdministratorHome({super.key});

  @override
  State<AdministratorHome> createState() => _AdministratorHomeState();
}

class _AdministratorHomeState extends State<AdministratorHome>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0A0F3C);

    return Scaffold(
      backgroundColor: navy,
      appBar: AppBar(
        backgroundColor: navy,
        elevation: 0,
        centerTitle: true,

        automaticallyImplyLeading: false,
        leading: const SizedBox.shrink(),

        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          tabAlignment: TabAlignment.fill, // even spacing across the width
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.people)),
            Tab(icon: Icon(Icons.celebration)),
            Tab(icon: Icon(Icons.view_list)),
            Tab(icon: Icon(Icons.analytics_outlined)),
            Tab(icon: Icon(Icons.admin_panel_settings)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          StudentsTab(),
          EventsTab(),
          AttendanceLogTab(),
          StatisticsTab(),
          UserAccessTab(),
        ],
      ),
    );
  }
}
