import 'package:flutter/material.dart';

import 'home_tabs/students_tab.dart';
import 'home_tabs/events_tab.dart';
import 'home_tabs/attendance_log_tab.dart';
import 'home_tabs/delete_log_tab.dart';
import 'home_tabs/statistics_tab.dart';
import 'home_tabs/user_access_tab.dart';

class AdministratorHome extends StatelessWidget {
  const AdministratorHome({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF0A0F3C);

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: navy,
        appBar: AppBar(
          backgroundColor: navy,
          elevation: 0,
          automaticallyImplyLeading: false,
          toolbarHeight: 0, // removes the extra space above the tab icons
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.school_outlined)),
              Tab(icon: Icon(Icons.event_note)),
              Tab(icon: Icon(Icons.list_alt)),
              Tab(icon: Icon(Icons.delete_sweep)),
              Tab(icon: Icon(Icons.analytics_outlined)),
              Tab(icon: Icon(Icons.supervised_user_circle)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            StudentsTab(),
            EventsTab(),
            AttendanceLogTab(),
            DeleteLogTab(),
            StatisticsTab(),
            UserAccessTab(),
          ],
        ),
      ),
    );
  }
}
