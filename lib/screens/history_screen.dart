import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../database/database_helper.dart';
import '../models/estimate.dart';
import 'estimate_detail_screen.dart';
import 'patient_profile_screen.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback onRefreshParent;

  const HistoryScreen({super.key, required this.onRefreshParent});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;
  final _patientFilterController = TextEditingController();
  late final TabController _tabController;

  bool _loading = true;
  List<EstimateSummary> _items = [];
  String _orderBy = 'fecha';
  bool _descending = true;
  DateTime? _selectedDay;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _patientFilterController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month && left.day == right.day;
  }

  List<EstimateSummary> get _visibleItems {
    final day = _selectedDay;
    if (day == null) return _items;
    return _items.where((item) => _isSameDay(item.date, day)).toList();
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = DateTime(day.year, day.month, day.day);
      _focusedDay = DateTime(day.year, day.month, day.day);
    });
    _tabController.animateTo(0);
  }

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  Map<DateTime, int> get _estimateCountByDay {
    final map = <DateTime, int>{};
    for (final item in _items) {
      final key = _dateOnly(item.date);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  List<Object> _calendarEventsForDay(DateTime day) {
    final count = _estimateCountByDay[_dateOnly(day)] ?? 0;
    if (count <= 0) return const [];
    return List<Object>.filled(count, 'estimate');
  }

  Future<void> _openEstimateDetail(EstimateSummary item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EstimateDetailScreen(estimateId: item.id),
      ),
    );
    await _load();
    widget.onRefreshParent();
  }

  Widget _buildHistoryList({required NumberFormat money, required DateFormat date}) {
    final visible = _visibleItems;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (visible.isEmpty) {
      if (_selectedDay != null) {
        final selectedLabel = DateFormat('dd/MM/yyyy').format(_selectedDay!);
        return Center(child: Text('No hay presupuestos para $selectedLabel.'));
      }
      return const Center(child: Text('No se encontraron presupuestos.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: visible.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final item = visible[index];
        final colorScheme = Theme.of(context).colorScheme;
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: IconButton(
              tooltip: 'Ver perfil del paciente',
              onPressed: () => _openPatientProfile(item),
              icon: const Icon(Icons.person_outline),
            ),
            title: Text(
              item.patientName,
              style: TextStyle(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${date.format(item.date)}\nDoctor: ${item.doctorName ?? 'Sin asignar'}',
            ),
            isThreeLine: true,
            trailing: Text(
              money.format(item.total),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onTap: () => _openEstimateDetail(item),
          ),
        );
      },
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _db.getEstimates(
      patientFilter: _patientFilterController.text,
      doctorFilter: _patientFilterController.text,
      orderBy: _orderBy,
      descending: _descending,
    );
    setState(() {
      _items = rows;
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
    await _load();
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
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _patientFilterController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por paciente o doctor',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _load,
                          ),
                        ),
                        onChanged: (_) => _load(),
                        onSubmitted: (_) => _load(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _orderBy,
                        items: const [
                          DropdownMenuItem(value: 'fecha', child: Text('Ordenar por fecha')),
                          DropdownMenuItem(value: 'paciente', child: Text('Ordenar por paciente')),
                          DropdownMenuItem(value: 'doctor', child: Text('Ordenar por doctor')),
                          DropdownMenuItem(value: 'total', child: Text('Ordenar por total')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _orderBy = value);
                          _load();
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _descending = !_descending);
                        _load();
                      },
                      icon: Icon(_descending ? Icons.south : Icons.north),
                      label: Text(_descending ? 'Desc' : 'Asc'),
                    ),
                  ],
                ),
                if (_selectedDay != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        avatar: const Icon(Icons.calendar_today, size: 16),
                        label: Text('Fecha: ${DateFormat('dd/MM/yyyy').format(_selectedDay!)}'),
                        onDeleted: () => setState(() => _selectedDay = null),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.list_alt_outlined), text: 'Lista'),
              Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Calendario'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHistoryList(money: money, date: date),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Card(
                    child: TableCalendar<Object>(
                      locale: 'es_ES',
                      rowHeight: 34,
                      daysOfWeekHeight: 16,
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2100),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) {
                        final selected = _selectedDay;
                        if (selected == null) return false;
                        return _isSameDay(day, selected);
                      },
                      eventLoader: _calendarEventsForDay,
                      onDaySelected: (selectedDay, focusedDay) {
                        _selectDay(selectedDay);
                        setState(() => _focusedDay = focusedDay);
                      },
                      onPageChanged: (focusedDay) {
                        setState(() => _focusedDay = focusedDay);
                      },
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        headerPadding: EdgeInsets.zero,
                      ),
                      calendarStyle: CalendarStyle(
                        markerDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                        markersMaxCount: 1,
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return const SizedBox.shrink();
                          final count = events.length;
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSecondary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
