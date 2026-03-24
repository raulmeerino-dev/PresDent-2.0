import 'package:flutter_test/flutter_test.dart';
import 'package:presdent_2_0/models/treatment.dart';
import 'package:presdent_2_0/services/text_parser_service.dart';

class _ParserCase {
  final String label;
  final String text;
  final int expectedTreatmentId;
  final int expectedQuantity;
  final String? expectedNote;

  const _ParserCase({
    required this.label,
    required this.text,
    required this.expectedTreatmentId,
    this.expectedQuantity = 1,
    this.expectedNote,
  });
}

void main() {
  test('Parser detecta tratamientos y cantidades', () {
    final parser = TextParserService.instance;
    final treatments = [
      const Treatment(id: 1, name: 'Implante dental', price: 750),
      const Treatment(id: 2, name: 'Limpieza dental', price: 60),
      const Treatment(id: 3, name: 'Corona', price: 320),
    ];

    final result = parser.parseTranscription(
      transcribedText: 'dos implantes en 46, limpieza y corona',
      availableTreatments: treatments,
    );

    expect(result.length, 3);
    final implante = result.firstWhere((item) => item.treatment.id == 1);
    expect(implante.quantity, 2);
    expect(implante.note, 'Pieza 46');
  });

  test('Parser prioriza material correcto en puentes por piezas', () {
    final parser = TextParserService.instance;
    final treatments = [
      const Treatment(id: 1, name: 'Puente de 3 piezas de zirconio', price: 1170),
      const Treatment(id: 2, name: 'Puente de 3 piezas metal-cerámica', price: 900),
      const Treatment(id: 3, name: 'Puente de 6 piezas de zirconio', price: 2340),
      const Treatment(id: 4, name: 'Puente de 6 piezas metal-cerámica', price: 1800),
    ];

    final result = parser.parseTranscription(
      transcribedText: 'puente de 3 piezas metal ceramica en 21 y 23; puente de 6 piezas de zirconio',
      availableTreatments: treatments,
    );

    expect(result.any((item) => item.treatment.id == 2), isTrue);
    expect(result.any((item) => item.treatment.id == 3), isTrue);
    expect(result.any((item) => item.treatment.id == 1), isFalse);
    expect(result.any((item) => item.treatment.id == 4), isFalse);
  });

  test('Parser normaliza variantes comunes del dictado', () {
    final parser = TextParserService.instance;
    final treatments = [
      const Treatment(id: 10, name: 'Brackets metálicos', price: 650),
      const Treatment(id: 11, name: 'Brackets de zafiro', price: 850),
    ];

    final result = parser.parseTranscription(
      transcribedText: 'brakets metalicos',
      availableTreatments: treatments,
    );

    expect(result.length, 1);
    expect(result.first.treatment.id, 10);
  });

  test('Parser detecta puente con piezas en texto y rango dental', () {
    final parser = TextParserService.instance;
    final treatments = [
      const Treatment(id: 3, name: 'Puente de 6 piezas de zirconio', price: 2340),
      const Treatment(id: 4, name: 'Puente de 6 piezas metal-cerámica', price: 1800),
    ];

    final result = parser.parseTranscription(
      transcribedText: 'Puente de seis piezas de metal cerámica entre el 21 y el 26',
      availableTreatments: treatments,
    );

    expect(result.length, 1);
    expect(result.first.treatment.id, 4);
    expect(result.first.note, 'Sector 21-26');
  });

  test('Parser detecta puente de 3 piezas zirconio con formato corto', () {
    final parser = TextParserService.instance;
    final treatments = [
      const Treatment(id: 1, name: 'Puente de 3 piezas de zirconio', price: 1170),
      const Treatment(id: 2, name: 'Puente de 3 piezas metal-cerámica', price: 900),
    ];

    final result = parser.parseTranscription(
      transcribedText: 'puente de 3 piezas zirconio entre el 11 y el 13',
      availableTreatments: treatments,
    );

    expect(result.length, 1);
    expect(result.first.treatment.id, 1);
    expect(result.first.note, 'Sector 11-13');
  });

  test('Parser tolera typo piezs y material metal-cerámica', () {
    final parser = TextParserService.instance;
    final treatments = [
      const Treatment(id: 10, name: 'Puente de 4 piezas de zirconio', price: 1560),
      const Treatment(id: 11, name: 'Puente de 4 piezas metal-cerámica', price: 1200),
    ];

    final result = parser.parseTranscription(
      transcribedText: 'puente 4 piezs metal-seramica entre 21 y 24',
      availableTreatments: treatments,
    );

    expect(result.length, 1);
    expect(result.first.treatment.id, 11);
    expect(result.first.note, 'Sector 21-24');
  });

  test('Parser detecta puente usando abreviatura pzs y material porcelana metal', () {
    final parser = TextParserService.instance;
    final treatments = [
      const Treatment(id: 20, name: 'Puente de 4 piezas de zirconio', price: 1560),
      const Treatment(id: 21, name: 'Puente de 4 piezas metal-cerámica', price: 1200),
    ];

    final result = parser.parseTranscription(
      transcribedText: 'puente de 4 pzs porcelana metal entre 24 y 21',
      availableTreatments: treatments,
    );

    expect(result.length, 1);
    expect(result.first.treatment.id, 21);
    expect(result.first.note, 'Sector 21-24');
  });

  test('Parser detecta cantidad con formato x2', () {
    final parser = TextParserService.instance;
    final treatments = [
      const Treatment(id: 30, name: 'Limpieza dental', price: 60),
    ];

    final result = parser.parseTranscription(
      transcribedText: 'limpieza x2',
      availableTreatments: treatments,
    );

    expect(result.length, 1);
    expect(result.first.treatment.id, 30);
    expect(result.first.quantity, 2);
  });

  test('Parser detecta cantidad con formato por 2', () {
    final parser = TextParserService.instance;
    final treatments = [
      const Treatment(id: 31, name: 'Limpieza dental', price: 60),
    ];

    final result = parser.parseTranscription(
      transcribedText: 'limpieza por 2',
      availableTreatments: treatments,
    );

    expect(result.length, 1);
    expect(result.first.treatment.id, 31);
    expect(result.first.quantity, 2);
  });

  test('Parser prioriza endodoncia multirradicular frente a rehacer endodoncia', () {
    final parser = TextParserService.instance;
    final treatments = [
      const Treatment(id: 40, name: 'Endodoncia multirradicular', price: 180),
      const Treatment(id: 41, name: 'Rehacer endodoncia', price: 180),
    ];

    final result = parser.parseTranscription(
      transcribedText: 'endodoncia multi radicular en el 12',
      availableTreatments: treatments,
    );

    expect(result.length, 1);
    expect(result.first.treatment.id, 40);
    expect(result.first.note, 'Pieza 12');
  });

  test('Parser respeta tratamiento de sector en injerto de tejido conectivo', () {
    final parser = TextParserService.instance;
    final treatments = [
      const Treatment(
        id: 50,
        name: 'Injerto de tejido conectivo',
        price: 500,
        pieceType: 'sector',
      ),
    ];

    final result = parser.parseTranscription(
      transcribedText: 'injerto de tejido conectivo entre el 21 y el 23',
      availableTreatments: treatments,
    );

    expect(result.length, 1);
    expect(result.first.treatment.id, 50);
    expect(result.first.note, 'Sector 21-23');
  });

  test('Parser normaliza raspa ge como raspaje', () {
    final parser = TextParserService.instance;
    final treatments = [
      const Treatment(
        id: 60,
        name: 'Raspaje y alisado por cuadrante',
        price: 80,
        pieceType: 'sector',
      ),
    ];

    final result = parser.parseTranscription(
      transcribedText: 'raspa ge y alisado por cuadrante entre 21 y 24',
      availableTreatments: treatments,
    );

    expect(result.length, 1);
    expect(result.first.treatment.id, 60);
    expect(result.first.note, 'Sector 21-24');
  });

  test('Parser dataset amplio de frases reales y typos', () {
    final parser = TextParserService.instance;
    final treatments = [
      const Treatment(id: 101, name: 'Puente de 3 piezas de zirconio', price: 1170),
      const Treatment(id: 102, name: 'Puente de 3 piezas metal-cerámica', price: 900),
      const Treatment(id: 103, name: 'Puente de 4 piezas de zirconio', price: 1560),
      const Treatment(id: 104, name: 'Puente de 4 piezas metal-cerámica', price: 1200),
      const Treatment(id: 105, name: 'Puente de 6 piezas de zirconio', price: 2340),
      const Treatment(id: 106, name: 'Puente de 6 piezas metal-cerámica', price: 1800),
      const Treatment(id: 107, name: 'Implante dental', price: 750),
      const Treatment(id: 108, name: 'Limpieza dental', price: 60),
      const Treatment(id: 109, name: 'Brackets metálicos', price: 650),
      const Treatment(id: 110, name: 'Exodoncia normal', price: 80),
    ];

    final cases = <_ParserCase>[
      const _ParserCase(
        label: 'puente 3 zirconio clasico',
        text: 'puente de 3 piezas zirconio entre 11 y 13',
        expectedTreatmentId: 101,
        expectedNote: 'Sector 11-13',
      ),
      const _ParserCase(
        label: 'puente 3 metal ceramica clasico',
        text: 'puente de 3 piezas metal ceramica entre 11 y 13',
        expectedTreatmentId: 102,
        expectedNote: 'Sector 11-13',
      ),
      const _ParserCase(
        label: 'puente 3 con typo piezs',
        text: 'puente 3 piezs zirconio entre 11 y 13',
        expectedTreatmentId: 101,
        expectedNote: 'Sector 11-13',
      ),
      const _ParserCase(
        label: 'puente 3 con abreviatura pzs',
        text: 'puente 3 pzs zirconio entre 11 y 13',
        expectedTreatmentId: 101,
        expectedNote: 'Sector 11-13',
      ),
      const _ParserCase(
        label: 'puente 4 metal con typo material',
        text: 'puente 4 piezs metal-seramica entre 21 y 24',
        expectedTreatmentId: 104,
        expectedNote: 'Sector 21-24',
      ),
      const _ParserCase(
        label: 'puente 4 metal con porcelana metal',
        text: 'puente de 4 pzs porcelana metal entre 24 y 21',
        expectedTreatmentId: 104,
        expectedNote: 'Sector 21-24',
      ),
      const _ParserCase(
        label: 'puente 4 zirconio con sirconio',
        text: 'puente de 4 piezas sirconio en 21 y 24',
        expectedTreatmentId: 103,
        expectedNote: 'Sector 21-24',
      ),
      const _ParserCase(
        label: 'puente 4 zirconio con circonio',
        text: 'puente de 4 piezas circonio en 21 y 24',
        expectedTreatmentId: 103,
        expectedNote: 'Sector 21-24',
      ),
      const _ParserCase(
        label: 'puente 6 metal por palabras',
        text: 'puente de seis piezas metal ceramica entre 21 y 26',
        expectedTreatmentId: 106,
        expectedNote: 'Sector 21-26',
      ),
      const _ParserCase(
        label: 'puente 6 zirconio por palabras',
        text: 'puente de seis piezas zirconio entre 21 y 26',
        expectedTreatmentId: 105,
        expectedNote: 'Sector 21-26',
      ),
      const _ParserCase(
        label: 'puente 6 zirconio orden inverso',
        text: 'puente de 6 piezas zirconio entre 26 y 21',
        expectedTreatmentId: 105,
        expectedNote: 'Sector 21-26',
      ),
      const _ParserCase(
        label: 'puente 4 metal con pz',
        text: 'puente 4 pz metal ceramica en 21 y 24',
        expectedTreatmentId: 104,
        expectedNote: 'Sector 21-24',
      ),
      const _ParserCase(
        label: 'puente 4 metal con pzas',
        text: 'puente 4 pzas metal ceramica en 21 y 24',
        expectedTreatmentId: 104,
        expectedNote: 'Sector 21-24',
      ),
      const _ParserCase(
        label: 'puente 4 metal con pza',
        text: 'puente 4 pza metal ceramica en 21 y 24',
        expectedTreatmentId: 104,
        expectedNote: 'Sector 21-24',
      ),
      const _ParserCase(
        label: 'implante en pieza',
        text: 'implante en 46',
        expectedTreatmentId: 107,
        expectedQuantity: 1,
        expectedNote: 'Pieza 46',
      ),
      const _ParserCase(
        label: 'dos implantes por palabra',
        text: 'dos implantes en 46',
        expectedTreatmentId: 107,
        expectedQuantity: 2,
        expectedNote: 'Pieza 46',
      ),
      const _ParserCase(
        label: 'implante x2',
        text: 'implante x2 en 46',
        expectedTreatmentId: 107,
        expectedQuantity: 2,
        expectedNote: 'Pieza 46',
      ),
      const _ParserCase(
        label: 'implante por 2',
        text: 'implante por 2 en 46',
        expectedTreatmentId: 107,
        expectedQuantity: 2,
        expectedNote: 'Pieza 46',
      ),
      const _ParserCase(
        label: 'implante 2 unidades',
        text: 'implante 2 unidades en 46',
        expectedTreatmentId: 107,
        expectedQuantity: 2,
        expectedNote: 'Pieza 46',
      ),
      const _ParserCase(
        label: 'limpieza simple',
        text: 'limpieza dental',
        expectedTreatmentId: 108,
        expectedQuantity: 1,
      ),
      const _ParserCase(
        label: 'limpieza x2',
        text: 'limpieza x2',
        expectedTreatmentId: 108,
        expectedQuantity: 2,
      ),
      const _ParserCase(
        label: 'limpieza por 2',
        text: 'limpieza por 2',
        expectedTreatmentId: 108,
        expectedQuantity: 2,
      ),
      const _ParserCase(
        label: 'limpieza 2 veces',
        text: 'limpieza 2 veces',
        expectedTreatmentId: 108,
        expectedQuantity: 2,
      ),
      const _ParserCase(
        label: 'brackets typo brakets',
        text: 'brakets metalicos',
        expectedTreatmentId: 109,
        expectedQuantity: 1,
      ),
      const _ParserCase(
        label: 'extraccion normal',
        text: 'extraccion normal en 18',
        expectedTreatmentId: 110,
        expectedQuantity: 1,
        expectedNote: 'Pieza 18',
      ),
      const _ParserCase(
        label: 'estraccion typo normalizada',
        text: 'estraccion normal en 18',
        expectedTreatmentId: 110,
        expectedQuantity: 1,
        expectedNote: 'Pieza 18',
      ),
    ];

    for (final item in cases) {
      final result = parser.parseTranscription(
        transcribedText: item.text,
        availableTreatments: treatments,
      );

      expect(result, isNotEmpty, reason: item.label);
      final matched = result.where((r) => r.treatment.id == item.expectedTreatmentId).toList();
      expect(matched, isNotEmpty, reason: item.label);

      final first = matched.first;
      expect(first.quantity, item.expectedQuantity, reason: item.label);
      if (item.expectedNote != null) {
        expect(first.note, item.expectedNote, reason: item.label);
      }
    }
  });
}
