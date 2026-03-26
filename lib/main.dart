import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database/database_helper.dart';
import 'models/patient.dart';
import 'services/app_theme_service.dart';
import 'screens/create_estimate_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/session_flow_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES');

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const PresDent2App());
}

class PresDent2App extends StatefulWidget {
  const PresDent2App({super.key});

  @override
  State<PresDent2App> createState() => _PresDent2AppState();
}

class _PresDent2AppState extends State<PresDent2App> {
  final _themeService = AppThemeService.instance;

  @override
  void initState() {
    super.initState();
    _themeService.loadThemeMode();
  }

  @override
  Widget build(BuildContext context) {
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B7A75),
      brightness: Brightness.light,
    );
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B7A75),
      brightness: Brightness.dark,
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeService.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'PresDent 2.0',
          builder: (context, child) {
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              child: child,
            );
          },
          themeMode: themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightColorScheme,
            scaffoldBackgroundColor: const Color(0xFFF5F7F8),
            appBarTheme: const AppBarTheme(centerTitle: false),
            cardTheme: CardThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              margin: EdgeInsets.zero,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: lightColorScheme.outlineVariant),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
            appBarTheme: const AppBarTheme(centerTitle: false),
            cardTheme: CardThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              margin: EdgeInsets.zero,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: darkColorScheme.outlineVariant),
              ),
            ),
          ),
          home: SessionFlowScreen(
            onSessionReady: (selection) {
              return MainShell(
                doctorId: selection.doctor.id,
                doctorName: selection.doctor.name,
                isAdmin: selection.doctor.isAdmin,
                selectedPatientId: selection.patientId,
                selectedPatientName: selection.patientName,
              );
            },
          ),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  final int? doctorId;
  final String doctorName;
  final bool isAdmin;
  final int? selectedPatientId;
  final String? selectedPatientName;

  const MainShell({
    super.key,
    required this.doctorId,
    required this.doctorName,
    this.isAdmin = false,
    required this.selectedPatientId,
    this.selectedPatientName,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _db = DatabaseHelper.instance;
  final _themeService = AppThemeService.instance;
  int _currentIndex = 0;
  late int? _activeDoctorId;
  late String _activeDoctorName;
  late bool _activeIsAdmin;
  late int? _activePatientId;
  late String? _activePatientName;
  static const _topLeftClinicIconAsset = 'assets/images/app_icon.png';

  @override
  void initState() {
    super.initState();
    _activeDoctorId = widget.doctorId;
    _activeDoctorName = widget.doctorName;
    _activeIsAdmin = widget.isAdmin;
    _activePatientId = widget.selectedPatientId;
    _activePatientName = widget.selectedPatientName;
  }

  Widget _buildClinicLogo() {
    return Container(
      width: 34,
      height: 34,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Image.asset(
        _topLeftClinicIconAsset,
        fit: BoxFit.contain,
        errorBuilder: (_, error, stackTrace) => const Icon(Icons.local_hospital, size: 18),
      ),
    );
  }

  void _openNewEstimate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateEstimateScreen(
          initialPatientId: _activePatientId,
          activeDoctorId: _activeDoctorId,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _openSessionSwitcher() async {
    final doctors = await _db.getDoctors();
    if (!mounted) return;
    if (doctors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay doctores disponibles para cambiar sesión.')),
      );
      return;
    }

    int? selectedDoctorId = _activeDoctorId ?? doctors.first.id;
    List<Patient> patients = await _db.getPatients(doctorId: selectedDoctorId);
    if (!mounted) return;
    int? selectedPatientId = patients.any((p) => p.id == _activePatientId) ? _activePatientId : null;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Cambiar sesión',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: selectedDoctorId,
                      items: doctors
                          .map((d) => DropdownMenuItem<int>(value: d.id, child: Text(d.name)))
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        selectedDoctorId = value;
                        selectedPatientId = null;
                        setSheetState(() {});
                        final loaded = await _db.getPatients(doctorId: selectedDoctorId);
                        if (!mounted) return;
                        setSheetState(() {
                          patients = loaded;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Doctor',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedPatientId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Sin paciente'),
                        ),
                        ...patients.map(
                          (p) => DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        ),
                      ],
                      onChanged: (value) => setSheetState(() => selectedPatientId = value),
                      decoration: const InputDecoration(
                        labelText: 'Paciente',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: () {
                        final selectedDoctor = doctors.where((d) => d.id == selectedDoctorId).firstOrNull;
                        if (selectedDoctor == null) return;
                        final selectedPatient = patients.where((p) => p.id == selectedPatientId).firstOrNull;

                        setState(() {
                          _activeDoctorId = selectedDoctor.id;
                          _activeDoctorName = selectedDoctor.name;
                          _activeIsAdmin = selectedDoctor.isAdmin;
                          _activePatientId = selectedPatient?.id;
                          _activePatientName = selectedPatient?.name;
                        });

                        Navigator.pop(sheetContext);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Aplicar sesión'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _goBackToSessionFlow() async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionFlowScreen(
          onSessionReady: (selection) {
            return MainShell(
              doctorId: selection.doctor.id,
              doctorName: selection.doctor.name,
              isAdmin: selection.doctor.isAdmin,
              selectedPatientId: selection.patientId,
              selectedPatientName: selection.patientName,
            );
          },
        ),
      ),
    );
  }

  Future<bool> _handleBackPressed() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }

    await _goBackToSessionFlow();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onRefreshParent: () => setState(() {}),
        activeDoctorId: _activeDoctorId,
        isAdmin: _activeIsAdmin,
      ),
      HistoryScreen(
        onRefreshParent: () => setState(() {}),
        activeDoctorId: _activeDoctorId,
        isAdmin: _activeIsAdmin,
      ),
      SettingsScreen(activeDoctorId: _activeDoctorId),
    ];

    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Inicio',
      ),
      NavigationDestination(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history),
        label: 'Historial',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Ajustes',
      ),
    ];

    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    final settingsIndex = screens.length - 1;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        body: screens[_currentIndex],
        floatingActionButton: _currentIndex == settingsIndex
            ? null
            : FloatingActionButton.extended(
                onPressed: _openNewEstimate,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo presupuesto'),
              ),
        appBar: AppBar(
          title: Row(
            children: [
              _buildClinicLogo(),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _openSessionSwitcher,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _activeIsAdmin ? 'Admin' : 'Doctor: $_activeDoctorName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _activeIsAdmin
                                  ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
                                  : null,
                            ),
                            Text(
                              'Paciente: ${_activePatientName ?? 'Sin paciente'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: _currentIndex == settingsIndex
              ? [
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: _themeService.themeMode,
                    builder: (context, mode, _) {
                      final isDark = mode == ThemeMode.dark;
                      return IconButton.filledTonal(
                        tooltip: isDark ? 'Modo claro' : 'Modo oscuro',
                        onPressed: () => _themeService.setDarkMode(!isDark),
                        icon: Icon(isDark ? Icons.light_mode_outlined : Icons.nightlight_round),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                ]
              : null,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: destinations,
        ),
      ),
    );
  }
}
