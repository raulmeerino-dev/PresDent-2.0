import 'package:flutter/material.dart';

import 'settings_menu_screen.dart';

class SettingsScreen extends StatelessWidget {
  final int? activeDoctorId;

  const SettingsScreen({
    super.key,
    required this.activeDoctorId,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsMenuScreen(activeDoctorId: activeDoctorId);
  }
}
