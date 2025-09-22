/*
Stats Page Description:
This page displays user statistics and learning progress.
Key features:
- Learning progress tracking
- Performance metrics
- Achievement display
- Progress visualization
*/ 

import 'package:flutter/material.dart';
import 'package:quizzer/UI_systems/global_widgets/widget_global_app_bar.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Stats',
        showHomeButton: true,
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // padding 16 is more than enough do not increase. . . 
        padding: const EdgeInsets.only(right: 16.0), // Add right padding to prevent scroll bar overlap
        children: const [
          Text("Stat page under construction, no stat display currently")
        ],
      ),
    );
  }
}