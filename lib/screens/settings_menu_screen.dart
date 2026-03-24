import 'package:flutter/material.dart';

import '../services/app_theme_service.dart';
import 'settings_doctors_screen.dart';
import 'settings_patients_screen.dart';
import 'settings_pdf_screen.dart';
import 'settings_treatments_screen.dart';

class SettingsMenuScreen extends StatelessWidget {
  final int? activeDoctorId;

  const SettingsMenuScreen({
    super.key,
    required this.activeDoctorId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppThemeService.instance.themeMode,
            builder: (context, mode, _) {
              final isDark = mode == ThemeMode.dark;
              return Align(
                alignment: Alignment.topRight,
                child: IconButton.filledTonal(
                  tooltip: isDark ? 'Modo claro' : 'Modo oscuro',
                  onPressed: () => AppThemeService.instance.setDarkMode(!isDark),
                  icon: Icon(isDark ? Icons.light_mode_outlined : Icons.nightlight_round),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          _ModuleTile(
            icon: Icons.medication_outlined,
            title: 'Tratamientos',
            subtitle: 'Crear, editar y eliminar tratamientos',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsTreatmentsScreen(activeDoctorId: activeDoctorId),
                ),
              );
            },
          ),
          _ModuleTile(
            icon: Icons.picture_as_pdf_outlined,
            title: 'PDF',
            subtitle: 'Nombre de clínica, logo y comentarios',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPdfScreen()),
              );
            },
          ),
          _ModuleTile(
            icon: Icons.people_outline,
            title: 'Pacientes',
            subtitle: 'Gestionar pacientes (editar y eliminar)',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPatientsScreen()),
              );
            },
          ),
          _ModuleTile(
            icon: Icons.medical_services_outlined,
            title: 'Doctores',
            subtitle: 'Gestionar doctores (editar y eliminar)',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsDoctorsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
