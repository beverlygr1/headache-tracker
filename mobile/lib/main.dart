import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/tracker/state/tracker_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    HeadacheTrackerApp(
      controller: TrackerController.demo(),
    ),
  );
}
