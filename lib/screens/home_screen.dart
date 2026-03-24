import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/estimate.dart';
import 'estimate_detail_screen.dart';
import 'patient_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onRefreshParent;
  final int? activeDoctorId;
  final bool isAdmin;

  const HomeScreen({
    super.key,
    required this.onRefreshParent,
    required this.activeDoctorId,
    required this.isAdmin,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  final _filterController = TextEditingController();

  List<EstimateSummary> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    setState(() => _loading = true);
    final rows = await _db.getEstimates(
      patientFilter: _filterController.text,
      doctorId: widget.isAdmin ? null : widget.activeDoctorId,
    );
    setState(() {
      _recent = rows.take(20).toList();
      _loading = false;
    });
  }

  Future<void> _openPatientProfile(EstimateSummary item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientProfileScreen(
          patientId: item.patientId,
          patientName: item.patientName,
          doctorName: item.doctorName,
        ),
      ),
    );
    await _loadRecent();
    widget.onRefreshParent();
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final date = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _filterController,
              decoration: InputDecoration(
                hintText: 'Filtrar por paciente',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _loadRecent(),
              onSubmitted: (_) => _loadRecent(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadRecent,
                    child: _recent.isEmpty
                        ? const ListTile(
                            title: Text('No hay presupuestos todavía'),
                            subtitle: Text('Pulsa "Nuevo presupuesto" para crear uno.'),
                          )
                        : ListView.separated(
                            itemCount: _recent.length,
                            separatorBuilder: (_, index) => const Divider(height: 1),
                            itemBuilder: (_, index) {
                              final item = _recent[index];
                              return ListTile(
                                leading: IconButton(
                                  tooltip: 'Ver perfil del paciente',
                                  onPressed: () => _openPatientProfile(item),
                                  icon: const Icon(Icons.person_outline),
                                ),
                                title: Text(item.patientName),
                                subtitle: Text(date.format(item.date)),
                                trailing: Text(money.format(item.total)),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => EstimateDetailScreen(estimateId: item.id),
                                    ),
                                  );
                                  await _loadRecent();
                                  widget.onRefreshParent();
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
