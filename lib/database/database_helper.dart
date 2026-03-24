import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/estimate.dart';
import '../models/doctor.dart';
import '../models/patient.dart';
import '../models/treatment.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;
  static const _defaultDoctorName = 'Doctor principal';
  static const _defaultPatientName = 'Paciente general';
  static const _requestedCatalogVersion = '2026-03-24-catalog-v6-acentos-puentes';
  static const List<Map<String, Object?>> _requestedTreatmentCatalog = [
    {'nombre': 'Ventana quirúrgica orto implante', 'precio': 120.0},
    {'nombre': 'Puente de 2 piezas de zirconio', 'precio': 780.0},
    {'nombre': 'Puente de 2 piezas metal-cerámica', 'precio': 600.0},
    {'nombre': 'Puente de 3 piezas de zirconio', 'precio': 1170.0},
    {'nombre': 'Puente de 3 piezas metal-cerámica', 'precio': 900.0},
    {'nombre': 'Puente de 4 piezas de zirconio', 'precio': 1560.0},
    {'nombre': 'Puente de 4 piezas metal-cerámica', 'precio': 1200.0},
    {'nombre': 'Puente de 5 piezas de zirconio', 'precio': 1950.0},
    {'nombre': 'Puente de 5 piezas metal-cerámica', 'precio': 1500.0},
    {'nombre': 'Puente de 6 piezas de zirconio', 'precio': 2340.0},
    {'nombre': 'Puente de 6 piezas metal-cerámica', 'precio': 1800.0},
    {'nombre': 'Puente fijo 12 piezas sobre 6 implantes', 'precio': 3400.0},
    {'nombre': 'Abrasión para obturar', 'precio': 40.0},
    {'nombre': 'Aditamento de teflón', 'precio': 50.0},
    {'nombre': 'Aditamento externo', 'precio': 100.0},
    {'nombre': 'Aditamento para implante integrado', 'precio': 300.0},
    {'nombre': 'Apicectomía', 'precio': 180.0},
    {'nombre': 'Ataches', 'precio': 240.0},
    {'nombre': 'Atención domiciliaria', 'precio': 200.0},
    {'nombre': 'Blanqueamiento externo', 'precio': 300.0},
    {'nombre': 'Blanqueamiento interno', 'precio': 100.0},
    {'nombre': 'Brackets de zafiro', 'precio': 850.0},
    {'nombre': 'Brackets metálicos', 'precio': 650.0},
    {'nombre': 'Brackets transparentes', 'precio': 700.0},
    {'nombre': 'Carilla de zirconio', 'precio': 420.0},
    {'nombre': 'Cementado', 'precio': 20.0},
    {'nombre': 'Cirugía menor', 'precio': 40.0},
    {'nombre': 'Compostura', 'precio': 60.0},
    {'nombre': 'Corona metal-cerámica', 'precio': 300.0},
    {'nombre': 'Corona sobre implante', 'precio': 450.0},
    {'nombre': 'Corona zirconio', 'precio': 390.0},
    {'nombre': 'Desatornillar prótesis y limpieza de implantes', 'precio': 75.0},
    {'nombre': 'Diferencia de reconstrucción', 'precio': 20.0},
    {'nombre': 'Elevación con regeneración', 'precio': 900.0},
    {'nombre': 'Elevación de seno', 'precio': 500.0},
    {'nombre': 'Empaste', 'precio': 50.0},
    {'nombre': 'Endodoncia multirradicular', 'precio': 180.0},
    {'nombre': 'Endodoncia unirradicular', 'precio': 150.0},
    {'nombre': 'Estudio de ortodoncia', 'precio': 50.0},
    {'nombre': 'Exodoncia compleja', 'precio': 120.0},
    {'nombre': 'Exodoncia de tercer molar', 'precio': 100.0},
    {'nombre': 'Exodoncia normal', 'precio': 50.0},
    {'nombre': 'Férula de descarga michigan', 'precio': 250.0},
    {'nombre': 'Férula retenedora de alambre', 'precio': 120.0},
    {'nombre': 'Férula retenedora de ortodoncia', 'precio': 100.0},
    {'nombre': 'Frenectomía', 'precio': 180.0},
    {'nombre': 'Gingivectomía', 'precio': 180.0},
    {'nombre': 'Gran reconstrucción', 'precio': 80.0},
    {'nombre': 'Implante', 'precio': 890.0},
    {'nombre': 'Injerto de tejido conectivo', 'precio': 500.0},
    {'nombre': 'Limpieza', 'precio': 60.0},
    {'nombre': 'Mantenedor de espacio', 'precio': 120.0},
    {'nombre': 'Mesoestructura completa', 'precio': 4200.0},
    {'nombre': 'Perno de cuarzo', 'precio': 100.0},
    {'nombre': 'Perno de titanio', 'precio': 90.0},
    {'nombre': 'Piercing', 'precio': 40.0},
    {'nombre': 'Placa expansora', 'precio': 500.0},
    {'nombre': 'Placa Hawley', 'precio': 400.0},
    {'nombre': 'Prótesis de metal-esquelético', 'precio': 800.0},
    {'nombre': 'Prótesis de resina', 'precio': 700.0},
    {'nombre': 'Prótesis inmediata completa', 'precio': 350.0},
    {'nombre': 'Prótesis inmediata parcial', 'precio': 250.0},
    {'nombre': 'Raspaje y alisado por cuadrante', 'precio': 80.0},
    {'nombre': 'Raspaje y alisado por pieza', 'precio': 20.0},
    {'nombre': 'Reconstrucción endodoncia', 'precio': 60.0},
    {'nombre': 'Reconstrucción estética', 'precio': 120.0},
    {'nombre': 'Regeneración ósea', 'precio': 450.0},
    {'nombre': 'Regularización ósea', 'precio': 200.0},
    {'nombre': 'Rehacer endodoncia', 'precio': 180.0},
    {'nombre': 'Reponer empaste', 'precio': 25.0},
    {'nombre': 'Revisión placa Hawley', 'precio': 30.0},
    {'nombre': 'Revisión placa expansora', 'precio': 50.0},
    {'nombre': 'Sellador', 'precio': 20.0},
    {'nombre': 'Sobredentadura', 'precio': 900.0},
    {'nombre': 'Sobredentadura removible', 'precio': 2340.0},
    {'nombre': 'Tratamiento de ortodoncia de 12 meses', 'precio': 1080.0},
    {'nombre': 'Tratamiento de ortodoncia de 18 meses', 'precio': 1620.0},
    {'nombre': 'Tratamiento de ortodoncia de 24 meses', 'precio': 2160.0},
    {'nombre': 'Tratamiento de ortodoncia con smilers de 18 meses', 'precio': 6300.0},
    {'nombre': 'Tratamiento de ortodoncia con smilers de 12 meses', 'precio': 4200.0},
    {'nombre': 'Tratamiento de ortodoncia con smilers de 6 meses', 'precio': 2100.0},
  ];

  Future<Database> get database async {
    if (_database != null) {
      await ensureDefaults();
      return _database!;
    }
    _database = await _initDb();
    await ensureDefaults();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'odonto_presupuestos.db');

    return openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await _ensureSchemaCompatibility(db);
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE doctores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pacientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        doctor_id INTEGER,
        telefono TEXT,
        notas TEXT,
        FOREIGN KEY (doctor_id) REFERENCES doctores (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE tratamientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_id INTEGER,
        nombre TEXT NOT NULL,
        precio REAL NOT NULL,
        color_hex TEXT,
        icono TEXT,
        pieza_tipo TEXT,
        FOREIGN KEY (doctor_id) REFERENCES doctores (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE presupuestos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        paciente_id INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        total REAL NOT NULL,
        FOREIGN KEY (paciente_id) REFERENCES pacientes (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE presupuesto_detalle (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        presupuesto_id INTEGER NOT NULL,
        tratamiento_id INTEGER NOT NULL,
        cantidad INTEGER NOT NULL,
        precio_unitario REAL NOT NULL,
        pieza_dental TEXT,
        FOREIGN KEY (presupuesto_id) REFERENCES presupuestos (id),
        FOREIGN KEY (tratamiento_id) REFERENCES tratamientos (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        clave TEXT PRIMARY KEY,
        valor TEXT
      )
    ''');

    final defaultDoctorId = await db.insert('doctores', {'nombre': _defaultDoctorName});
    await db.insert('pacientes', {'nombre': _defaultPatientName, 'doctor_id': defaultDoctorId});
    await _seedTreatments(db, doctorId: defaultDoctorId);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE presupuesto_detalle ADD COLUMN pieza_dental TEXT');
    }
    if (oldVersion < 3) {
      await _ensureSchemaCompatibility(db);
    }
    if (oldVersion < 4) {
      await _ensureSchemaCompatibility(db);
    }
    if (oldVersion < 5) {
      await _ensureSchemaCompatibility(db);
    }
    if (oldVersion < 6) {
      await _ensureSchemaCompatibility(db);
    }
  }

  Future<void> _ensureSchemaCompatibility(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS doctores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        clave TEXT PRIMARY KEY,
        valor TEXT
      )
    ''');

    final hasDoctorId = await _columnExists(db, 'pacientes', 'doctor_id');
    if (!hasDoctorId) {
      await db.execute('ALTER TABLE pacientes ADD COLUMN doctor_id INTEGER');
    }

    final hasPhone = await _columnExists(db, 'pacientes', 'telefono');
    if (!hasPhone) {
      await db.execute('ALTER TABLE pacientes ADD COLUMN telefono TEXT');
    }

    final hasNotes = await _columnExists(db, 'pacientes', 'notas');
    if (!hasNotes) {
      await db.execute('ALTER TABLE pacientes ADD COLUMN notas TEXT');
    }

    final hasColorHex = await _columnExists(db, 'tratamientos', 'color_hex');
    if (!hasColorHex) {
      await db.execute('ALTER TABLE tratamientos ADD COLUMN color_hex TEXT');
    }

    final hasIcon = await _columnExists(db, 'tratamientos', 'icono');
    if (!hasIcon) {
      await db.execute('ALTER TABLE tratamientos ADD COLUMN icono TEXT');
    }

    final hasPieceType = await _columnExists(db, 'tratamientos', 'pieza_tipo');
    if (!hasPieceType) {
      await db.execute('ALTER TABLE tratamientos ADD COLUMN pieza_tipo TEXT');
    }

    final hasTreatmentDoctorId = await _columnExists(db, 'tratamientos', 'doctor_id');
    if (!hasTreatmentDoctorId) {
      await db.execute('ALTER TABLE tratamientos ADD COLUMN doctor_id INTEGER');
    }
  }

  Future<bool> _columnExists(Database db, String tableName, String columnName) async {
    final rows = await db.rawQuery('PRAGMA table_info($tableName)');
    return rows.any((row) => (row['name'] as String?) == columnName);
  }

  Future<void> _seedTreatments(Database db, {required int doctorId}) async {
    for (final requested in _requestedTreatmentCatalog) {
      final name = (requested['nombre'] as String?)?.trim();
      final price = (requested['precio'] as num?)?.toDouble();
      if (name == null || name.isEmpty || price == null) continue;
      await db.insert('tratamientos', _buildCatalogTreatmentRecord(name, price, doctorId: doctorId));
    }
  }

  Future<void> ensureDefaults() async {
    final db = _database;
    if (db == null) return;

    await _deduplicateDoctors(db);
    await _deduplicateTreatments(db);

    int? defaultDoctorId;
    final doctorCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM doctores'));
    if ((doctorCount ?? 0) == 0) {
      defaultDoctorId = await db.insert('doctores', {'nombre': _defaultDoctorName});
    } else {
      final doctorRows = await db.query('doctores', columns: ['id'], orderBy: 'id ASC', limit: 1);
      if (doctorRows.isNotEmpty) {
        defaultDoctorId = doctorRows.first['id'] as int;
      }
    }

    final patientCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM pacientes'));
    if ((patientCount ?? 0) == 0) {
      await db.insert('pacientes', {'nombre': _defaultPatientName, 'doctor_id': defaultDoctorId});
    }

    await _ensureDoctorScopedTreatments(db);
    await _syncRequestedTreatmentCatalog(db);

    await _replaceDeprecatedTreatment(
      db,
      fromName: 'Amalgama',
      toName: 'Composite',
    );
  }

  String _normalizedKey(String value) {
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
      'Á': 'a',
      'É': 'e',
      'Í': 'i',
      'Ó': 'o',
      'Ú': 'u',
      'Ü': 'u',
      'Ñ': 'n',
    };

    var normalized = value.trim();
    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    return normalized.toLowerCase();
  }

  Future<void> _syncRequestedTreatmentCatalog(Database db) async {
    await db.transaction((txn) async {
      final doctorRows = await txn.query('doctores', columns: ['id']);
      for (final row in doctorRows) {
        final doctorId = row['id'];
        if (doctorId is! int) continue;
        await _ensureDoctorTreatments(txn, doctorId);
      }

      await txn.insert(
        'app_settings',
        {
          'clave': 'treatments_catalog_version',
          'valor': _requestedCatalogVersion,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> _ensureDoctorScopedTreatments(Database db) async {
    final scopedCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tratamientos WHERE doctor_id IS NOT NULL'),
    );
    if ((scopedCount ?? 0) > 0) return;

    final doctorRows = await db.query('doctores', columns: ['id'], orderBy: 'id ASC');
    if (doctorRows.isEmpty) return;

    final globalRows = await db.query(
      'tratamientos',
      where: 'doctor_id IS NULL',
      orderBy: 'id ASC',
    );

    await db.transaction((txn) async {
      for (final doctor in doctorRows) {
        final doctorId = doctor['id'];
        if (doctorId is! int) continue;

        if (globalRows.isNotEmpty) {
          for (final row in globalRows) {
            final cloned = Map<String, Object?>.from(row)
              ..remove('id')
              ..['doctor_id'] = doctorId;
            await txn.insert('tratamientos', cloned);
          }
          continue;
        }

        await _ensureDoctorTreatments(txn, doctorId);
      }
    });
  }

  Future<void> _ensureDoctorTreatments(DatabaseExecutor db, int doctorId) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM tratamientos WHERE doctor_id = ?',
        [doctorId],
      ),
    );
    if ((count ?? 0) > 0) return;

    await _seedTreatmentsForDoctor(db, doctorId);
  }

  Future<void> _seedTreatmentsForDoctor(DatabaseExecutor db, int doctorId) async {
    for (final requested in _requestedTreatmentCatalog) {
      final name = (requested['nombre'] as String?)?.trim();
      final price = (requested['precio'] as num?)?.toDouble();
      if (name == null || name.isEmpty || price == null) continue;
      await db.insert('tratamientos', _buildCatalogTreatmentRecord(name, price, doctorId: doctorId));
    }
  }

  Map<String, Object?> _buildCatalogTreatmentRecord(String name, double price, {required int doctorId}) {
    final normalized = _normalizedKey(name);
    final icon = _inferCatalogIcon(normalized);
    return {
      'doctor_id': doctorId,
      'nombre': name,
      'precio': price,
      'color_hex': _catalogColorForIcon(icon),
      'icono': icon,
      'pieza_tipo': _inferCatalogPieceType(normalized),
    };
  }

  String _inferCatalogPieceType(String normalizedName) {
    if (normalizedName.contains('puente') ||
        normalizedName.contains('cuadrante') ||
        normalizedName.contains('elevacion') ||
        normalizedName.contains('regeneracion') ||
        normalizedName.contains('gingivectomia') ||
        normalizedName.contains('frenectomia') ||
        normalizedName.contains('injerto')) {
      return 'sector';
    }

    if (normalizedName.contains('protesis') ||
        normalizedName.contains('sobredentadura') ||
        normalizedName.contains('placa') ||
        normalizedName.contains('ferula')) {
      return 'arcada';
    }

    if (normalizedName.contains('ortodoncia') ||
        normalizedName.contains('atencion domiciliaria') ||
        normalizedName.contains('estudio') ||
        normalizedName.contains('revision')) {
      return 'general';
    }

    return 'pieza';
  }

  String _inferCatalogIcon(String normalizedName) {
    if (normalizedName.contains('puente')) return 'bridge';
    if (normalizedName.contains('implante') || normalizedName.contains('aditamento')) return 'implant';
    if (normalizedName.contains('corona')) return 'crown';
    if (normalizedName.contains('bracket') ||
        normalizedName.contains('ortodoncia') ||
        normalizedName.contains('placa') ||
        normalizedName.contains('ferula') ||
        normalizedName.contains('mantenedor') ||
        normalizedName.contains('smilers')) {
      return 'ortho';
    }
    if (normalizedName.contains('endodoncia') || normalizedName.contains('perno') || normalizedName.contains('apicectomia')) {
      return 'root';
    }
    if (normalizedName.contains('exodoncia') ||
        normalizedName.contains('cirugia') ||
        normalizedName.contains('elevacion') ||
        normalizedName.contains('regeneracion') ||
        normalizedName.contains('injerto') ||
        normalizedName.contains('regularizacion')) {
      return 'surgery';
    }
    if (normalizedName.contains('limpieza') || normalizedName.contains('blanqueamiento')) {
      return 'cleaning';
    }
    if (normalizedName.contains('protesis') || normalizedName.contains('sobredentadura') || normalizedName.contains('mesoestructura')) {
      return 'prosthesis_removable';
    }
    if (normalizedName.contains('carilla')) return 'veneer';
    if (normalizedName.contains('sellador')) return 'sealant';
    if (normalizedName.contains('reconstruccion') || normalizedName.contains('empaste') || normalizedName.contains('cementado')) {
      return 'restoration';
    }
    if (normalizedName.contains('raspaje')) return 'periodontics';
    return 'generic';
  }

  String _catalogColorForIcon(String icon) {
    return switch (icon) {
      'implant' => '0E7C7B',
      'bridge' => '355070',
      'crown' => '3A86FF',
      'ortho' => '4D908E',
      'root' => '8338EC',
      'surgery' => 'D90429',
      'cleaning' => '2A9D8F',
      'veneer' => '4895EF',
      'periodontics' => '2D6A4F',
      'prosthesis_removable' => '6D597A',
      'sealant' => '06D6A0',
      'restoration' => '6C757D',
      _ => '6C757D',
    };
  }

  Future<void> _deduplicateDoctors(Database db) async {
    final rows = await db.query(
      'doctores',
      columns: ['id', 'nombre'],
      orderBy: 'id ASC',
    );

    final keepByName = <String, int>{};
    await db.transaction((txn) async {
      for (final row in rows) {
        final id = row['id'];
        final name = (row['nombre'] as String? ?? '').trim();
        if (id is! int || name.isEmpty) continue;

        final key = _normalizedKey(name);
        final keepId = keepByName[key];
        if (keepId == null) {
          keepByName[key] = id;
          continue;
        }

        if (keepId == id) continue;

        await txn.update(
          'pacientes',
          {'doctor_id': keepId},
          where: 'doctor_id = ?',
          whereArgs: [id],
        );
        await txn.delete('doctores', where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Future<void> _replaceDeprecatedTreatment(
    Database db, {
    required String fromName,
    required String toName,
  }) async {
    final doctorRows = await db.query('doctores', columns: ['id']);
    await db.transaction((txn) async {
      for (final doctorRow in doctorRows) {
        final doctorId = doctorRow['id'];
        if (doctorId is! int) continue;

        final toRows = await txn.query(
          'tratamientos',
          columns: ['id'],
          where: 'doctor_id = ? AND LOWER(TRIM(nombre)) = LOWER(TRIM(?))',
          whereArgs: [doctorId, toName],
          orderBy: 'id ASC',
          limit: 1,
        );
        if (toRows.isEmpty) continue;
        final targetId = toRows.first['id'];
        if (targetId is! int) continue;

        final fromRows = await txn.query(
          'tratamientos',
          columns: ['id'],
          where: 'doctor_id = ? AND LOWER(TRIM(nombre)) = LOWER(TRIM(?))',
          whereArgs: [doctorId, fromName],
          orderBy: 'id ASC',
        );

        for (final row in fromRows) {
          final fromId = row['id'];
          if (fromId is! int || fromId == targetId) continue;

          await txn.update(
            'presupuesto_detalle',
            {'tratamiento_id': targetId},
            where: 'tratamiento_id = ?',
            whereArgs: [fromId],
          );
          await txn.delete(
            'tratamientos',
            where: 'id = ?',
            whereArgs: [fromId],
          );
        }
      }
    });
  }

  Future<void> _deduplicateTreatments(Database db) async {
    final rows = await db.query(
      'tratamientos',
      columns: ['id', 'nombre', 'doctor_id'],
      orderBy: 'id ASC',
    );

    final keepByName = <String, int>{};
    await db.transaction((txn) async {
      for (final row in rows) {
        final id = row['id'];
        final name = (row['nombre'] as String? ?? '').trim();
        final doctorId = row['doctor_id'] as int?;
        if (id is! int || name.isEmpty) continue;

        final doctorScope = doctorId?.toString() ?? 'global';
        final key = '$doctorScope|${_normalizedKey(name)}';
        final keepId = keepByName[key];
        if (keepId == null) {
          keepByName[key] = id;
          continue;
        }

        if (keepId == id) continue;

        await txn.update(
          'presupuesto_detalle',
          {'tratamiento_id': keepId},
          where: 'tratamiento_id = ?',
          whereArgs: [id],
        );
        await txn.delete('tratamientos', where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Future<List<Doctor>> getDoctors({String? query}) async {
    final db = await database;
    final where = query != null && query.trim().isNotEmpty ? 'nombre LIKE ?' : null;
    final whereArgs = where != null ? ['%${query!.trim()}%'] : null;

    final rows = await db.query(
      'doctores',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'nombre ASC',
    );
    return rows.map(Doctor.fromMap).toList();
  }

  Future<int> insertDoctor(Doctor doctor) async {
    final db = await database;
    final normalizedName = doctor.name.trim();
    final existing = await db.query(
      'doctores',
      columns: ['id'],
      where: 'LOWER(TRIM(nombre)) = LOWER(TRIM(?))',
      whereArgs: [normalizedName],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final id = existing.first['id'];
      if (id is int) return id;
    }

    final map = doctor.toMap()..remove('id');
    map['nombre'] = normalizedName;
    final newDoctorId = await db.insert('doctores', map);
    await _ensureDoctorTreatments(db, newDoctorId);
    return newDoctorId;
  }

  Future<int> updateDoctor(Doctor doctor) async {
    if (doctor.id == null) return 0;
    final db = await database;
    return db.update(
      'doctores',
      doctor.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [doctor.id],
    );
  }

  Future<int> countPatientsForDoctor(int doctorId) async {
    final db = await database;
    final value = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM pacientes WHERE doctor_id = ?',
        [doctorId],
      ),
    );
    return value ?? 0;
  }

  Future<int> deleteDoctor(int doctorId) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.update(
        'pacientes',
        {'doctor_id': null},
        where: 'doctor_id = ?',
        whereArgs: [doctorId],
      );
      await txn.delete('tratamientos', where: 'doctor_id = ?', whereArgs: [doctorId]);
      return txn.delete('doctores', where: 'id = ?', whereArgs: [doctorId]);
    });
  }

  Future<List<Patient>> getPatients({String? query, int? doctorId}) async {
    final db = await database;
    final clauses = <String>[];
    final whereArgs = <Object?>[];

    if (query != null && query.trim().isNotEmpty) {
      clauses.add('nombre LIKE ?');
      whereArgs.add('%${query.trim()}%');
    }
    if (doctorId != null) {
      clauses.add('(doctor_id = ? OR doctor_id IS NULL)');
      whereArgs.add(doctorId);
    }

    final where = clauses.isEmpty ? null : clauses.join(' AND ');

    final rows = await db.query(
      'pacientes',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'nombre ASC',
    );
    return rows.map(Patient.fromMap).toList();
  }

  Future<Patient?> getPatientById(int patientId) async {
    final db = await database;
    final rows = await db.query(
      'pacientes',
      where: 'id = ?',
      whereArgs: [patientId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Patient.fromMap(rows.first);
  }

  Future<int> insertPatient(Patient patient, {int? doctorId}) async {
    final db = await database;
    final map = patient.toMap()..remove('id');
    map['doctor_id'] = doctorId;
    return db.insert('pacientes', map);
  }

  Future<int> updatePatient(Patient patient) async {
    if (patient.id == null) return 0;
    final db = await database;
    return db.update(
      'pacientes',
      patient.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [patient.id],
    );
  }

  Future<int> countEstimatesForPatient(int patientId) async {
    final db = await database;
    final value = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM presupuestos WHERE paciente_id = ?',
        [patientId],
      ),
    );
    return value ?? 0;
  }

  Future<void> deletePatient(int patientId) async {
    final db = await database;
    await db.transaction((txn) async {
      final estimateRows = await txn.query(
        'presupuestos',
        columns: ['id'],
        where: 'paciente_id = ?',
        whereArgs: [patientId],
      );
      final estimateIds = estimateRows
          .map((row) => row['id'])
          .whereType<int>()
          .toList();

      for (final estimateId in estimateIds) {
        await txn.delete('presupuesto_detalle', where: 'presupuesto_id = ?', whereArgs: [estimateId]);
      }

      await txn.delete('presupuestos', where: 'paciente_id = ?', whereArgs: [patientId]);
      await txn.delete('pacientes', where: 'id = ?', whereArgs: [patientId]);
    });
  }

  Future<List<Treatment>> getTreatments({String? query, int? doctorId}) async {
    final db = await database;
    if (doctorId != null) {
      await _ensureDoctorTreatments(db, doctorId);
    }

    final clauses = <String>[];
    final whereArgs = <Object?>[];

    if (doctorId != null) {
      clauses.add('doctor_id = ?');
      whereArgs.add(doctorId);
    }

    if (query != null && query.trim().isNotEmpty) {
      clauses.add('nombre LIKE ?');
      whereArgs.add('%${query.trim()}%');
    }

    final where = clauses.isEmpty ? null : clauses.join(' AND ');

    final rows = await db.query(
      'tratamientos',
      where: where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'nombre ASC',
    );
    return rows.map(Treatment.fromMap).toList();
  }

  Future<Map<int, int>> getTreatmentUsageCounts({int? doctorId}) async {
    final db = await database;
    final where = doctorId == null ? '' : 'WHERE p.doctor_id = ?';
    final whereArgs = doctorId == null ? const <Object?>[] : <Object?>[doctorId];

    final rows = await db.rawQuery(
      '''
      SELECT pd.tratamiento_id AS treatment_id, SUM(pd.cantidad) AS usage_count
      FROM presupuesto_detalle pd
      INNER JOIN presupuestos pr ON pr.id = pd.presupuesto_id
      INNER JOIN pacientes p ON p.id = pr.paciente_id
      $where
      GROUP BY pd.tratamiento_id
      ''',
      whereArgs,
    );

    final map = <int, int>{};
    for (final row in rows) {
      final treatmentId = row['treatment_id'];
      final usage = row['usage_count'];
      if (treatmentId is int && usage is num) {
        map[treatmentId] = usage.toInt();
      }
    }
    return map;
  }

  Future<int> insertTreatment(Treatment treatment, {required int doctorId}) async {
    final db = await database;
    final normalizedName = treatment.name.trim();
    final existing = await db.query(
      'tratamientos',
      columns: ['id'],
      where: 'doctor_id = ? AND LOWER(TRIM(nombre)) = LOWER(TRIM(?))',
      whereArgs: [doctorId, normalizedName],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final id = existing.first['id'];
      if (id is int) return id;
    }

    final map = treatment.toMap()..remove('id');
    map['doctor_id'] = doctorId;
    map['nombre'] = normalizedName;
    return db.insert('tratamientos', map);
  }

  Future<int> updateTreatment(Treatment treatment, {required int doctorId}) async {
    final db = await database;
    return db.update(
      'tratamientos',
      treatment.toMap()
        ..remove('id')
        ..remove('doctor_id'),
      where: 'id = ? AND doctor_id = ?',
      whereArgs: [treatment.id, doctorId],
    );
  }

  Future<int> deleteTreatment(int id, {required int doctorId}) async {
    final db = await database;
    return db.delete(
      'tratamientos',
      where: 'id = ? AND doctor_id = ?',
      whereArgs: [id, doctorId],
    );
  }

  Future<int> insertEstimate({
    required int patientId,
    required DateTime date,
    required List<EstimateDetail> details,
  }) async {
    final db = await database;

    return db.transaction((txn) async {
      final total = details.fold<double>(0, (sum, item) => sum + item.lineTotal);

      final estimateId = await txn.insert('presupuestos', {
        'paciente_id': patientId,
        'fecha': date.toIso8601String(),
        'total': total,
      });

      for (final detail in details) {
        await txn.insert('presupuesto_detalle', {
          'presupuesto_id': estimateId,
          'tratamiento_id': detail.treatmentId,
          'cantidad': detail.quantity,
          'precio_unitario': detail.unitPrice,
          'pieza_dental': detail.toothCode,
        });
      }

      return estimateId;
    });
  }

  Future<void> updateEstimate({
    required int estimateId,
    required int patientId,
    required DateTime date,
    required List<EstimateDetail> details,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      final total = details.fold<double>(0, (sum, item) => sum + item.lineTotal);

      await txn.update(
        'presupuestos',
        {
          'paciente_id': patientId,
          'fecha': date.toIso8601String(),
          'total': total,
        },
        where: 'id = ?',
        whereArgs: [estimateId],
      );

      await txn.delete('presupuesto_detalle', where: 'presupuesto_id = ?', whereArgs: [estimateId]);

      for (final detail in details) {
        await txn.insert('presupuesto_detalle', {
          'presupuesto_id': estimateId,
          'tratamiento_id': detail.treatmentId,
          'cantidad': detail.quantity,
          'precio_unitario': detail.unitPrice,
          'pieza_dental': detail.toothCode,
        });
      }
    });
  }

  Future<List<EstimateSummary>> getEstimates({
    int? patientId,
    String? patientFilter,
    String? doctorFilter,
    String orderBy = 'fecha',
    bool descending = true,
  }) async {
    final db = await database;

    final clauses = <String>[];
    final whereArgs = <Object?>[];

    if (patientId != null) {
      clauses.add('pr.paciente_id = ?');
      whereArgs.add(patientId);
    }

    final normalizedPatientFilter = patientFilter?.trim() ?? '';
    final normalizedDoctorFilter = doctorFilter?.trim() ?? '';

    if (normalizedPatientFilter.isNotEmpty &&
        normalizedDoctorFilter.isNotEmpty &&
        normalizedPatientFilter.toLowerCase() == normalizedDoctorFilter.toLowerCase()) {
      final query = '%$normalizedPatientFilter%';
      clauses.add('(p.nombre LIKE ? OR COALESCE(d.nombre, \'\') LIKE ?)');
      whereArgs
        ..add(query)
        ..add(query);
    } else {
      if (normalizedPatientFilter.isNotEmpty) {
        clauses.add('p.nombre LIKE ?');
        whereArgs.add('%$normalizedPatientFilter%');
      }
      if (normalizedDoctorFilter.isNotEmpty) {
        clauses.add('COALESCE(d.nombre, \'\') LIKE ?');
        whereArgs.add('%$normalizedDoctorFilter%');
      }
    }

    final orderColumn = switch (orderBy) {
      'paciente' => 'p.nombre',
      'doctor' => 'd.nombre',
      'total' => 'pr.total',
      _ => 'pr.fecha',
    };
    final orderDirection = descending ? 'DESC' : 'ASC';
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';

    final rows = await db.rawQuery(
      '''
      SELECT pr.id, pr.paciente_id, p.nombre AS paciente_nombre, d.nombre AS doctor_nombre, pr.fecha, pr.total
      FROM presupuestos pr
      INNER JOIN pacientes p ON p.id = pr.paciente_id
      LEFT JOIN doctores d ON d.id = p.doctor_id
      $where
      ORDER BY $orderColumn $orderDirection, pr.id DESC
      ''',
      whereArgs.isEmpty ? null : whereArgs,
    );

    return rows.map(EstimateSummary.fromMap).toList();
  }

  Future<EstimateSummary?> getEstimateSummary(int estimateId) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT pr.id, pr.paciente_id, p.nombre AS paciente_nombre, d.nombre AS doctor_nombre, pr.fecha, pr.total
      FROM presupuestos pr
      INNER JOIN pacientes p ON p.id = pr.paciente_id
      LEFT JOIN doctores d ON d.id = p.doctor_id
      WHERE pr.id = ?
      LIMIT 1
      ''',
      [estimateId],
    );

    if (rows.isEmpty) return null;
    return EstimateSummary.fromMap(rows.first);
  }

  Future<List<EstimateDetailView>> getEstimateDetails(int estimateId) async {
    final db = await database;

    final rows = await db.rawQuery(
      '''
      SELECT pd.id, pd.tratamiento_id, t.nombre AS tratamiento_nombre, pd.cantidad, pd.precio_unitario, pd.pieza_dental
      FROM presupuesto_detalle pd
      INNER JOIN tratamientos t ON t.id = pd.tratamiento_id
      WHERE pd.presupuesto_id = ?
      ORDER BY pd.id ASC
      ''',
      [estimateId],
    );

    return rows.map(EstimateDetailView.fromMap).toList();
  }

  Future<void> deleteEstimate(int estimateId) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('presupuesto_detalle', where: 'presupuesto_id = ?', whereArgs: [estimateId]);
      await txn.delete('presupuestos', where: 'id = ?', whereArgs: [estimateId]);
    });
  }

  Future<void> setAppSetting(String key, String? value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'clave': key, 'valor': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getAppSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: ['valor'],
      where: 'clave = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['valor'] as String?;
  }

  Future<Map<String, String>> getAppSettingsByPrefix(String prefix) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      where: 'clave LIKE ?',
      whereArgs: ['$prefix%'],
    );

    return {
      for (final row in rows)
        if (row['clave'] is String && row['valor'] is String)
          row['clave'] as String: row['valor'] as String,
    };
  }
}
