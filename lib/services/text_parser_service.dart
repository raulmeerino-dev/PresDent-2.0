import '../models/estimate.dart';
import '../models/treatment.dart';

class TextParserService {
  TextParserService._();

  static final TextParserService instance = TextParserService._();
  ParseSource _lastParseSource = ParseSource.localOnly;

  static const Set<String> _validFdiToothCodes = {
    '11', '12', '13', '14', '15', '16', '17', '18',
    '21', '22', '23', '24', '25', '26', '27', '28',
    '31', '32', '33', '34', '35', '36', '37', '38',
    '41', '42', '43', '44', '45', '46', '47', '48',
  };

  static const Map<String, String> _spokenFdiToothCode = {
    'once': '11',
    'doce': '12',
    'trece': '13',
    'catorce': '14',
    'quince': '15',
    'dieciseis': '16',
    'diecisiete': '17',
    'dieciocho': '18',
    'veintiuno': '21',
    'veintidos': '22',
    'veintitres': '23',
    'veinticuatro': '24',
    'veinticinco': '25',
    'veintiseis': '26',
    'veintisiete': '27',
    'veintiocho': '28',
    'treinta y uno': '31',
    'treinta y dos': '32',
    'treinta y tres': '33',
    'treinta y cuatro': '34',
    'treinta y cinco': '35',
    'treinta y seis': '36',
    'treinta y siete': '37',
    'treinta y ocho': '38',
    'cuarenta y uno': '41',
    'cuarenta y dos': '42',
    'cuarenta y tres': '43',
    'cuarenta y cuatro': '44',
    'cuarenta y cinco': '45',
    'cuarenta y seis': '46',
    'cuarenta y siete': '47',
    'cuarenta y ocho': '48',
  };

  static const Map<String, int> _wordToNumber = {
    'un': 1,
    'una': 1,
    'uno': 1,
    'dos': 2,
    'tres': 3,
    'cuatro': 4,
    'cinco': 5,
    'seis': 6,
    'siete': 7,
    'ocho': 8,
    'nueve': 9,
    'diez': 10,
  };

  static const Map<int, String> _numberToWord = {
    1: 'uno',
    2: 'dos',
    3: 'tres',
    4: 'cuatro',
    5: 'cinco',
    6: 'seis',
    7: 'siete',
    8: 'ocho',
    9: 'nueve',
    10: 'diez',
  };

  static const Map<String, List<String>> _synonymByCanonical = {
    'implante': ['implante', 'implantes', 'poner implante', 'colocar implante'],
    'limpieza': ['limpieza', 'profilaxis', 'higiene dental'],
    'corona': ['corona', 'coronas', 'funda dental'],
    'obturacion': ['obturacion', 'obturación', 'empaste', 'empastes'],
    'endodoncia': ['endodoncia', 'tratamiento de conducto', 'conducto'],
    'extraccion': ['extraccion', 'extracción', 'sacar muela', 'extraccion dental'],
    'blanqueamiento': ['blanqueamiento', 'blanqueamiento dental'],
    'protesis': ['protesis', 'prótesis', 'dentadura'],
  };

  ParseSource get lastParseSource => _lastParseSource;

  Future<List<ParsedTreatment>> parseTranscriptionSmart({
    required String transcribedText,
    required List<Treatment> availableTreatments,
  }) async {
    final local = parseTranscription(
      transcribedText: transcribedText,
      availableTreatments: availableTreatments,
    );
    _lastParseSource = ParseSource.localOnly;
    return local;
  }

  List<ParsedTreatment> parseTranscription({
    required String transcribedText,
    required List<Treatment> availableTreatments,
  }) {
    final normalizedText = _normalize(transcribedText);
    if (normalizedText.isEmpty) return [];

    final structured = _parseStructuredPairs(
      transcribedText: transcribedText,
      availableTreatments: availableTreatments,
    );
    if (structured.isNotEmpty) {
      return _mergeByTreatment(structured);
    }

    final matches = <ParsedTreatment>[];
    final segments = _splitSegments(normalizedText);

    for (final segment in segments) {
      final toothMentions = _extractToothMentions(segment);
      final archMention = _extractArchMention(segment);
      final bridgeByRange = _resolveBridgeTreatmentForSegment(
        segment: segment,
        availableTreatments: availableTreatments,
        toothMentions: toothMentions,
      );
      if (bridgeByRange != null) {
        matches.add(
          ParsedTreatment(
            treatment: bridgeByRange,
            quantity: 1,
            note: _buildBridgeRangeNote(toothMentions),
          ),
        );
        continue;
      }

      var treatmentMentions = _findTreatmentMentions(segment, availableTreatments);
      if (treatmentMentions.isEmpty) {
        final fallbackTreatment = _resolveTreatmentByName(segment, availableTreatments);
        if (fallbackTreatment == null) continue;
        treatmentMentions = [
          _TreatmentMention(
            treatment: fallbackTreatment,
            alias: _normalize(fallbackTreatment.name),
            start: 0,
            end: segment.length,
          ),
        ];
      }

      for (var i = 0; i < treatmentMentions.length; i++) {
        final mention = treatmentMentions[i];
        final resolvedTreatment = _resolveTreatmentByContext(
          segment: segment,
          baseTreatment: mention.treatment,
          availableTreatments: availableTreatments,
          toothMentions: toothMentions,
        );
        final prevEnd = i > 0 ? treatmentMentions[i - 1].end : 0;
        final nextStart = i < treatmentMentions.length - 1 ? treatmentMentions[i + 1].start : segment.length;
        final quantityScope = segment.substring(prevEnd, nextStart).trim();

        final teethAfterMention = toothMentions
            .where((tooth) => tooth.position >= mention.end && tooth.position < nextStart)
            .map((tooth) => tooth.code)
            .toSet()
            .toList();

        final teethBeforeMention = toothMentions
            .where((tooth) => tooth.position >= prevEnd && tooth.position < mention.start)
            .map((tooth) => tooth.code)
            .toSet()
            .toList();

        final localToothCodes = teethAfterMention.isNotEmpty
            ? teethAfterMention
            : teethBeforeMention;

        final quantity = _detectQuantity(quantityScope, [mention.alias]) ?? 1;

        if (_isSectorTreatment(resolvedTreatment)) {
          final sectorNote = _buildSectorNoteFromToothCodes(
            localToothCodes.isNotEmpty
                ? localToothCodes
                : toothMentions.map((tooth) => tooth.code),
          );
          if (sectorNote != null) {
            matches.add(
              ParsedTreatment(
                treatment: resolvedTreatment,
                quantity: quantity,
                note: sectorNote,
              ),
            );
            continue;
          }
        }

        if (_isArcadaTreatment(resolvedTreatment) && archMention != null) {
          matches.add(
            ParsedTreatment(
              treatment: resolvedTreatment,
              quantity: quantity,
              note: archMention == '+' ? 'Arcada superior' : 'Arcada inferior',
            ),
          );
          continue;
        }

        if (_isBridgeTreatment(resolvedTreatment) && toothMentions.length >= 2) {
          matches.add(
            ParsedTreatment(
              treatment: resolvedTreatment,
              quantity: 1,
              note: _buildBridgeRangeNote(toothMentions),
            ),
          );
          continue;
        }

        if (localToothCodes.isEmpty) {
          if (treatmentMentions.length == 1 && toothMentions.isNotEmpty) {
            for (final toothCode in toothMentions.map((t) => t.code).toSet()) {
              matches.add(
                ParsedTreatment(
                  treatment: resolvedTreatment,
                  quantity: quantity,
                  note: 'Pieza $toothCode',
                ),
              );
            }
            continue;
          }

          matches.add(
            ParsedTreatment(
              treatment: resolvedTreatment,
              quantity: quantity,
              note: null,
            ),
          );
          continue;
        }

        for (final toothCode in localToothCodes) {
          matches.add(
            ParsedTreatment(
              treatment: resolvedTreatment,
              quantity: quantity,
              note: 'Pieza $toothCode',
            ),
          );
        }
      }
    }

    return _mergeByTreatment(matches);
  }

  Treatment _resolveTreatmentByContext({
    required String segment,
    required Treatment baseTreatment,
    required List<Treatment> availableTreatments,
    required List<_ToothMention> toothMentions,
  }) {
    if (!_isBridgeTreatment(baseTreatment)) {
      return baseTreatment;
    }

    final desiredPieces = _extractBridgePieceCount(segment, toothMentions);
    if (desiredPieces == null) {
      return baseTreatment;
    }

    final desiredMaterial = _extractBridgeMaterial(segment);
    final candidates = availableTreatments
        .where((treatment) {
          if (!_isBridgeTreatment(treatment)) return false;
          return _extractPieceCountFromTreatmentName(treatment.name) == desiredPieces;
        })
        .toList();

    if (candidates.isEmpty) {
      return baseTreatment;
    }

    if (desiredMaterial != null) {
      final materialMatches = candidates
          .where((treatment) => _bridgeMaterialFromTreatment(treatment) == desiredMaterial)
          .toList();
      if (materialMatches.isNotEmpty) {
        return _pickBridgeCandidate(
          candidates: materialMatches,
          segment: segment,
          fallback: baseTreatment,
        );
      }
    }

    if (candidates.any((treatment) => treatment.id == baseTreatment.id)) {
      return baseTreatment;
    }

    return _pickBridgeCandidate(
      candidates: candidates,
      segment: segment,
      fallback: baseTreatment,
    );
  }

  Treatment? _resolveBridgeTreatmentForSegment({
    required String segment,
    required List<Treatment> availableTreatments,
    required List<_ToothMention> toothMentions,
  }) {
    final normalized = _normalize(segment);
    if (!normalized.contains('puente')) return null;

    final desiredPieces = _extractBridgePieceCount(segment, toothMentions);
    if (desiredPieces == null) return null;

    final desiredMaterial = _extractBridgeMaterial(segment);

    Treatment? best;
    for (final treatment in availableTreatments) {
      if (!_isBridgeTreatment(treatment)) continue;
      final piecesInName = _extractPieceCountFromTreatmentName(treatment.name);
      if (piecesInName == desiredPieces) {
        if (desiredMaterial != null && _bridgeMaterialFromTreatment(treatment) != desiredMaterial) {
          continue;
        }
        if (best == null || _normalize(treatment.name).length < _normalize(best.name).length) {
          best = treatment;
        }
      }
    }

    return best;
  }

  String? _extractBridgeMaterial(String text) {
    final normalized = _normalize(text);
    if (normalized.contains('zirconio')) {
      return 'zirconio';
    }

    final hasMetalCeramica = normalized.contains('metal ceramica') ||
        (normalized.contains('metal') && normalized.contains('ceramica')) ||
        normalized.contains('metal porcelana') ||
        normalized.contains('porcelana metal');
    if (hasMetalCeramica) {
      return 'metal_ceramica';
    }

    return null;
  }

  String? _bridgeMaterialFromTreatment(Treatment treatment) {
    final normalized = _normalize(treatment.name);
    if (normalized.contains('zirconio')) {
      return 'zirconio';
    }

    final hasMetalCeramica = normalized.contains('metal ceramica') ||
        (normalized.contains('metal') && normalized.contains('ceramica')) ||
        normalized.contains('metal porcelana') ||
        normalized.contains('porcelana metal');
    if (hasMetalCeramica) {
      return 'metal_ceramica';
    }

    return null;
  }

  Treatment _pickBridgeCandidate({
    required List<Treatment> candidates,
    required String segment,
    required Treatment fallback,
  }) {
    final normalizedSegment = _normalize(segment);

    Treatment? best;
    int? bestScore;
    for (final treatment in candidates) {
      final canonical = _normalize(treatment.name);
      var score = 0;

      if (canonical == normalizedSegment) {
        score += 100;
      }
      if (normalizedSegment.contains(canonical)) {
        score += 50;
      }
      if (canonical.contains(normalizedSegment)) {
        score += 20;
      }

      final aliases = _buildAliases(canonical);
      for (final alias in aliases) {
        if (normalizedSegment.contains(alias)) {
          score += alias.length;
        }
      }

      if (best == null || (bestScore != null && score > bestScore)) {
        best = treatment;
        bestScore = score;
      }
    }

    return best ?? fallback;
  }

  bool _isBridgeTreatment(Treatment treatment) {
    return _normalize(treatment.name).contains('puente');
  }

  bool _isSectorTreatment(Treatment treatment) {
    return _normalize(treatment.pieceType ?? '') == 'sector';
  }

  bool _isArcadaTreatment(Treatment treatment) {
    return _normalize(treatment.pieceType ?? '') == 'arcada';
  }

  String? _extractArchMention(String text) {
    final normalized = _normalize(text);

    if (RegExp(r'\barcada\s+superior\b').hasMatch(normalized) ||
        RegExp(r'\barriba\b').hasMatch(normalized)) {
      return '+';
    }

    if (RegExp(r'\barcada\s+inferior\b').hasMatch(normalized) ||
        RegExp(r'\babajo\b').hasMatch(normalized)) {
      return '-';
    }

    return null;
  }

  String? _buildSectorNoteFromToothCodes(Iterable<String> toothCodes) {
    final unique = <String>[];
    for (final code in toothCodes) {
      final normalizedCode = code.trim();
      if (_validFdiToothCodes.contains(normalizedCode) && !unique.contains(normalizedCode)) {
        unique.add(normalizedCode);
      }
    }

    if (unique.isEmpty) return null;
    if (unique.length == 1) return 'Pieza ${unique.first}';

    final ordered = unique
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    return 'Sector ${ordered.first}-${ordered.last}';
  }

  int? _extractPieceCountFromTreatmentName(String treatmentName) {
    final normalized = _normalize(treatmentName);

    final digitMatch = RegExp(r'\b(\d+)\s+(?:piez(?:a|as|s|az|za)?|pz|pza|pzas|pzs)\b').firstMatch(normalized);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(1)!);
    }

    final wordMatch = RegExp(r'\b([a-z]+)\s+(?:piez(?:a|as|s|az|za)?|pz|pza|pzas|pzs)\b').firstMatch(normalized);
    if (wordMatch != null) {
      return _wordToNumber[_normalize(wordMatch.group(1)!)];
    }

    return null;
  }

  int? _extractBridgePieceCount(String segment, List<_ToothMention> toothMentions) {
    final normalized = _normalize(segment);

    final digitMatch = RegExp(r'\b(\d+)\s+(?:piez(?:a|as|s|az|za)?|pz|pza|pzas|pzs)\b').firstMatch(normalized);
    if (digitMatch != null) {
      final parsed = int.tryParse(digitMatch.group(1)!);
      if (parsed != null && parsed >= 2 && parsed <= 8) {
        return parsed;
      }
    }

    final wordMatch = RegExp(r'\b([a-z]+)\s+(?:piez(?:a|as|s|az|za)?|pz|pza|pzas|pzs)\b').firstMatch(normalized);
    if (wordMatch != null) {
      final word = _normalize(wordMatch.group(1)!);
      final parsed = _wordToNumber[word];
      if (parsed != null && parsed >= 2 && parsed <= 8) {
        return parsed;
      }
    }

    final uniqueTeeth = toothMentions.map((m) => m.code).toSet().toList();
    if (uniqueTeeth.length >= 2) {
      final first = int.tryParse(uniqueTeeth.first);
      final last = int.tryParse(uniqueTeeth.last);
      if (first != null && last != null) {
        final inferred = (first - last).abs() + 1;
        if (inferred >= 2 && inferred <= 8) {
          return inferred;
        }
      }
    }

    return null;
  }

  String _buildBridgeRangeNote(List<_ToothMention> toothMentions) {
    final uniqueByOrder = <String>[];
    for (final mention in toothMentions) {
      if (!uniqueByOrder.contains(mention.code)) {
        uniqueByOrder.add(mention.code);
      }
    }

    if (uniqueByOrder.isEmpty) return 'Sector';
    if (uniqueByOrder.length == 1) return 'Pieza ${uniqueByOrder.first}';
    final ordered = uniqueByOrder
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    return 'Sector ${ordered.first}-${ordered.last}';
  }

  List<ParsedTreatment> _parseStructuredPairs({
    required String transcribedText,
    required List<Treatment> availableTreatments,
  }) {
    final pairPattern = RegExp(
      r'\b(tratamiento|pieza|cantidad)\s*:\s*([^,;\n]+)',
      caseSensitive: false,
    );

    final matches = pairPattern.allMatches(transcribedText).toList();
    if (matches.isEmpty) return const [];

    String? treatmentRaw;
    int? quantityRaw;
    final teeth = <String>[];
    String? archRaw;
    final parsed = <ParsedTreatment>[];

    void flushCurrent() {
      if (treatmentRaw == null || treatmentRaw!.trim().isEmpty) {
        treatmentRaw = null;
        quantityRaw = null;
        teeth.clear();
        archRaw = null;
        return;
      }

      final treatment = _resolveTreatmentByName(treatmentRaw!, availableTreatments);
      if (treatment == null) {
        treatmentRaw = null;
        quantityRaw = null;
        teeth.clear();
        archRaw = null;
        return;
      }

      final sanitizedQuantity = _sanitizeQuantity(quantityRaw, teeth: teeth);
      final uniqueTeeth = teeth.toSet().toList();
      if (_isArcadaTreatment(treatment) && archRaw != null) {
        parsed.add(
          ParsedTreatment(
            treatment: treatment,
            quantity: sanitizedQuantity,
            note: archRaw == '+' ? 'Arcada superior' : 'Arcada inferior',
          ),
        );
      } else if (uniqueTeeth.isEmpty) {
        parsed.add(
          ParsedTreatment(
            treatment: treatment,
            quantity: sanitizedQuantity,
          ),
        );
      } else if (_isSectorTreatment(treatment)) {
        final sectorNote = _buildSectorNoteFromToothCodes(uniqueTeeth);
        parsed.add(
          ParsedTreatment(
            treatment: treatment,
            quantity: sanitizedQuantity,
            note: sectorNote,
          ),
        );
      } else {
        for (final tooth in uniqueTeeth) {
          parsed.add(
            ParsedTreatment(
              treatment: treatment,
              quantity: sanitizedQuantity,
              note: 'Pieza $tooth',
            ),
          );
        }
      }

      treatmentRaw = null;
      quantityRaw = null;
      teeth.clear();
      archRaw = null;
    }

    for (final match in matches) {
      final key = _normalize(match.group(1) ?? '');
      final value = (match.group(2) ?? '').trim();
      if (value.isEmpty) continue;

      if (key == 'tratamiento') {
        if (treatmentRaw != null) {
          flushCurrent();
        }
        treatmentRaw = value;
        continue;
      }

      if (key == 'cantidad') {
        final digits = RegExp(r'\d+').firstMatch(value)?.group(0);
        if (digits != null) {
          quantityRaw = int.tryParse(digits);
        } else {
          quantityRaw = _wordToNumber[_normalize(value)];
        }
        continue;
      }

      if (key == 'pieza') {
        final normalizedValue = _normalize(value);
        archRaw ??= _extractArchMention(normalizedValue);
        final codes = _extractToothMentions(normalizedValue).map((item) => item.code);
        for (final code in codes) {
          if (_validFdiToothCodes.contains(code)) {
            teeth.add(code);
          }
        }
      }
    }

    flushCurrent();
    return parsed;
  }

  Treatment? _resolveTreatmentByName(String rawName, List<Treatment> availableTreatments) {
    final target = _normalize(rawName);
    if (target.isEmpty) return null;
    final ambiguousBaseAliases = _buildAmbiguousBaseAliases(availableTreatments);

    Treatment? fuzzyBest;
    int? fuzzyBestDistance;

    for (final treatment in availableTreatments) {
      final canonical = _normalize(treatment.name);
      final aliases = _buildAliases(canonical);
      for (final alias in aliases) {
        if (_isAmbiguousGenericAlias(alias, canonical, ambiguousBaseAliases)) {
          continue;
        }

        if (target == alias || target.contains(alias) || alias.contains(target)) {
          return treatment;
        }

        final distance = _levenshteinDistance(target, alias);
        if (!_isAcceptableFuzzyDistance(target, alias, distance)) continue;
        if (fuzzyBestDistance == null || distance < fuzzyBestDistance) {
          fuzzyBest = treatment;
          fuzzyBestDistance = distance;
        }
      }
    }

    return fuzzyBest;
  }

  List<String> _splitSegments(String text) {
    return text
        .split(RegExp(r'\s*(?:,|;|luego|mas|ademas)\s*'))
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
  }

  List<_TreatmentMention> _findTreatmentMentions(String segment, List<Treatment> treatments) {
    final mentions = <_TreatmentMention>[];
    final ambiguousBaseAliases = _buildAmbiguousBaseAliases(treatments);

    for (final treatment in treatments) {
      final canonical = _normalize(treatment.name);
      final aliases = _buildAliases(canonical);

      for (final alias in aliases) {
        if (_isAmbiguousGenericAlias(alias, canonical, ambiguousBaseAliases)) {
          continue;
        }

        final pattern = RegExp('(^|\\s)${RegExp.escape(alias)}(\\s|${r'$'})');
        for (final match in pattern.allMatches(segment)) {
          final start = match.start + (match.group(1)?.length ?? 0);
          mentions.add(
            _TreatmentMention(
              treatment: treatment,
              alias: alias,
              start: start,
              end: start + alias.length,
            ),
          );
        }
      }
    }

    mentions.sort((a, b) {
      final startComparison = a.start.compareTo(b.start);
      if (startComparison != 0) return startComparison;
      return b.alias.length.compareTo(a.alias.length);
    });

    final bestBySpan = <String, _TreatmentMention>{};
    for (final mention in mentions) {
      final key = '${mention.start}:${mention.end}';
      final current = bestBySpan[key];
      if (current == null || _mentionPriority(mention) > _mentionPriority(current)) {
        bestBySpan[key] = mention;
      }
    }

    final disambiguated = bestBySpan.values.toList()
      ..sort((a, b) {
        final startComparison = a.start.compareTo(b.start);
        if (startComparison != 0) return startComparison;
        return b.alias.length.compareTo(a.alias.length);
      });

    final deduped = <_TreatmentMention>[];
    for (final mention in disambiguated) {
      final alreadyCovered = deduped.any(
        (existing) =>
            mention.start >= existing.start &&
            mention.end <= existing.end,
      );
      if (!alreadyCovered) {
        deduped.add(mention);
      }
    }

    return deduped;
  }

  Set<String> _buildAmbiguousBaseAliases(List<Treatment> treatments) {
    final counts = <String, int>{};
    for (final treatment in treatments) {
      final canonical = _normalize(treatment.name);
      final parts = canonical.split(' ');
      if (parts.length < 2) continue;
      final base = parts.first;
      counts[base] = (counts[base] ?? 0) + 1;
    }

    return counts.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toSet();
  }

  bool _isAmbiguousGenericAlias(String alias, String canonical, Set<String> ambiguousBaseAliases) {
    final parts = canonical.split(' ');
    if (parts.length < 2) return false;
    final base = parts.first;
    return alias == base && ambiguousBaseAliases.contains(base);
  }

  int _mentionPriority(_TreatmentMention mention) {
    final canonical = _normalize(mention.treatment.name);
    var score = 0;
    if (canonical == mention.alias) {
      score += 100;
    } else if (canonical.startsWith('${mention.alias} ')) {
      score += 40;
    }

    score -= canonical.length;
    return score;
  }

  List<String> _buildAliases(String canonical) {
    final direct = <String>[canonical];

    if (canonical.contains('unirradicular')) {
      direct.add(canonical.replaceAll('unirradicular', 'uni radicular'));
      direct.add(canonical.replaceAll('unirradicular', 'uniradicular'));
    }
    if (canonical.contains('multirradicular')) {
      direct.add(canonical.replaceAll('multirradicular', 'multi radicular'));
      direct.add(canonical.replaceAll('multirradicular', 'multiradicular'));
    }

    final baseParts = canonical.split(' ');
    if (baseParts.isNotEmpty) {
      direct.add(baseParts.first);
      if (baseParts.first.endsWith('es')) {
        direct.add(baseParts.first.substring(0, baseParts.first.length - 2));
      } else if (baseParts.first.endsWith('s') && baseParts.first.length > 3) {
        direct.add(baseParts.first.substring(0, baseParts.first.length - 1));
      }
    }

    final synonymEntry = _synonymByCanonical.entries.firstWhere(
      (entry) => canonical.contains(_normalize(entry.key)) || _normalize(entry.key).contains(canonical),
      orElse: () => const MapEntry('', []),
    );

    final synonyms = synonymEntry.value.map(_normalize).toList();
    if (canonical.contains('puente')) {
      final pieces = _extractPieceCountFromTreatmentName(canonical);
      final material = _extractBridgeMaterial(canonical);
      if (pieces != null) {
        final pieceTokens = <String>{pieces.toString()};
        final pieceWord = _numberToWord[pieces];
        if (pieceWord != null) {
          pieceTokens.add(pieceWord);
        }

        for (final pieceToken in pieceTokens) {
          direct.add('puente $pieceToken piezas');
          direct.add('puente de $pieceToken piezas');
          direct.add('puente $pieceToken pzs');
          direct.add('puente de $pieceToken pzs');
          if (material == 'zirconio') {
            direct.add('puente $pieceToken piezas zirconio');
            direct.add('puente de $pieceToken piezas zirconio');
            direct.add('puente $pieceToken pzs zirconio');
            direct.add('puente de $pieceToken pzs zirconio');
          }
          if (material == 'metal_ceramica') {
            direct.add('puente $pieceToken piezas metal ceramica');
            direct.add('puente de $pieceToken piezas metal ceramica');
            direct.add('puente $pieceToken piezas metalceramica');
            direct.add('puente de $pieceToken piezas metalceramica');
            direct.add('puente $pieceToken pzs metal ceramica');
            direct.add('puente de $pieceToken pzs metal ceramica');
            direct.add('puente $pieceToken pzs metal porcelana');
            direct.add('puente de $pieceToken pzs metal porcelana');
          }
        }
      }
    }

    return {...direct, ...synonyms}.toList();
  }

  int? _detectQuantity(String text, List<String> aliases) {
    final prefixedMultiplier = RegExp(r'\bx\s*(\d+)\b').firstMatch(text);
    if (prefixedMultiplier != null) {
      final parsed = int.tryParse(prefixedMultiplier.group(1)!);
      final safe = _sanitizeQuantity(parsed, teeth: const []);
      if (safe != 1 || parsed == 1) return safe;
    }

    final porQuantity = RegExp(r'\bpor\s+(\d+)\b').firstMatch(text);
    if (porQuantity != null) {
      final parsed = int.tryParse(porQuantity.group(1)!);
      final safe = _sanitizeQuantity(parsed, teeth: const []);
      if (safe != 1 || parsed == 1) return safe;
    }

    final unidadesQuantity = RegExp(r'\b(\d+)\s+(?:unidad|unidades|veces)\b').firstMatch(text);
    if (unidadesQuantity != null) {
      final parsed = int.tryParse(unidadesQuantity.group(1)!);
      final safe = _sanitizeQuantity(parsed, teeth: const []);
      if (safe != 1 || parsed == 1) return safe;
    }

    for (final alias in aliases) {
      final escapedAlias = RegExp.escape(alias);

      final withDigit = RegExp('(\\d+)\\s+$escapedAlias');
      final digitMatch = withDigit.firstMatch(text);
      if (digitMatch != null) {
        final parsed = int.tryParse(digitMatch.group(1)!);
        final safe = _sanitizeQuantity(parsed, teeth: const []);
        if (safe != 1 || parsed == 1) return safe;
      }

      final withWord = RegExp('([a-záéíóúñ]+)\\s+$escapedAlias');
      final wordMatch = withWord.firstMatch(text);
      if (wordMatch != null) {
        final word = _normalize(wordMatch.group(1)!);
        if (_wordToNumber.containsKey(word)) return _wordToNumber[word];
      }

      final afterAliasDigit = RegExp('$escapedAlias\\s+(\\d+)');
      final afterDigitMatch = afterAliasDigit.firstMatch(text);
      if (afterDigitMatch != null) {
        final parsed = int.tryParse(afterDigitMatch.group(1)!);
        final safe = _sanitizeQuantity(parsed, teeth: const []);
        if (safe != 1 || parsed == 1) return safe;
      }
    }

    return null;
  }

  int _sanitizeQuantity(int? raw, {required List<String> teeth}) {
    final parsed = raw ?? 1;
    if (parsed <= 0) return 1;

    if (_validFdiToothCodes.contains(parsed.toString())) {
      return 1;
    }

    if (teeth.isNotEmpty && parsed > 8) {
      return 1;
    }

    return parsed;
  }

  List<_ToothMention> _extractToothMentions(String text) {
    final found = <_ToothMention>[];

    final contextualPattern = RegExp(
      r'\b(?:en|pieza|diente|muela)\s*(?:numero|número|num|#)?\s*(?:el|la)?\s*(\d{2})\b',
    );
    for (final match in contextualPattern.allMatches(text)) {
      final code = match.group(1);
      if (code != null && _validFdiToothCodes.contains(code)) {
        found.add(_ToothMention(code: code, position: match.start));
      }
    }

    final standalonePattern = RegExp(r'\b(\d{2})\b');
    for (final match in standalonePattern.allMatches(text)) {
      final code = match.group(1);
      if (code != null && _validFdiToothCodes.contains(code)) {
        found.add(_ToothMention(code: code, position: match.start));
      }
    }

    for (final entry in _spokenFdiToothCode.entries) {
      final pattern = RegExp('(^|\\s)${RegExp.escape(entry.key)}(\\s|${r'$'})');
      for (final match in pattern.allMatches(text)) {
        final start = match.start + (match.group(1)?.length ?? 0);
        found.add(_ToothMention(code: entry.value, position: start));
      }
    }

    found.sort((a, b) => a.position.compareTo(b.position));

    final deduped = <_ToothMention>[];
    for (final mention in found) {
      final exists = deduped.any((item) => item.code == mention.code && item.position == mention.position);
      if (!exists) {
        deduped.add(mention);
      }
    }

    return deduped;
  }

  List<ParsedTreatment> _mergeByTreatment(List<ParsedTreatment> parsed) {
    final map = <String, ParsedTreatment>{};

    for (final item in parsed) {
      final key = '${item.treatment.id ?? -1}|${item.note ?? ''}';
      if (!map.containsKey(key)) {
        map[key] = item;
      } else {
        final existing = map[key]!;
        map[key] = ParsedTreatment(
          treatment: existing.treatment,
          quantity: existing.quantity + item.quantity,
          note: existing.note ?? item.note,
        );
      }
    }

    return map.values.toList();
  }

  bool _isAcceptableFuzzyDistance(String left, String right, int distance) {
    final minLen = left.length < right.length ? left.length : right.length;
    if (minLen < 5) return false;

    final allowed = minLen >= 12
        ? 3
        : minLen >= 8
            ? 2
            : 1;
    return distance <= allowed;
  }

  int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        final substitution = previous[j - 1] + cost;
        current[j] = deletion < insertion
            ? (deletion < substitution ? deletion : substitution)
            : (insertion < substitution ? insertion : substitution);
      }
      previous = current;
    }
    return previous[b.length];
  }

  String _normalize(String value) {
    var normalized = value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('-', ' ')
        .replaceAll(',', ' ')
        .replaceAll('.', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    normalized = normalized
        .replaceAll('compossite', 'composite')
        .replaceAll('compozite', 'composite')
        .replaceAll('endodonsia', 'endodoncia')
        .replaceAll('multi radicular', 'multirradicular')
        .replaceAll('multi rradicular', 'multirradicular')
        .replaceAll('multiradicular', 'multirradicular')
        .replaceAll('uni radicular', 'unirradicular')
        .replaceAll('uni rradicular', 'unirradicular')
        .replaceAll('uniradicular', 'unirradicular')
        .replaceAll('estraccion', 'extraccion')
        .replaceAll('extraccion normal', 'exodoncia normal')
        .replaceAll('extraccion compleja', 'exodoncia compleja')
        .replaceAll('extraccion de tercer molar', 'exodoncia de tercer molar')
        .replaceAll('protezis', 'protesis')
        .replaceAll('blanqueamento', 'blanqueamiento')
        .replaceAll('brakets', 'brackets')
        .replaceAll('raspa ge', 'raspaje')
        .replaceAll('piezs', 'piezas')
        .replaceAll('piezaz', 'piezas')
        .replaceAll('pza', 'pieza')
        .replaceAll('pzas', 'piezas')
        .replaceAll('pzs', 'piezas')
        .replaceAll('pz', 'pieza')
        .replaceAll('metalseramica', 'metal ceramica')
        .replaceAll('seramica', 'ceramica')
        .replaceAll('ceramca', 'ceramica')
        .replaceAll('metalceramica', 'metal ceramica')
        .replaceAll('metal ceramico', 'metal ceramica')
        .replaceAll('metal porcelana', 'metal ceramica')
        .replaceAll('porcelana metal', 'metal ceramica')
        .replaceAll('sirconio', 'zirconio')
        .replaceAll('circonio', 'zirconio')
        .replaceAll('ceramico', 'ceramica')
        .replaceAll('zirconia', 'zirconio');

    return normalized;
  }
}

class _TreatmentMention {
  final Treatment treatment;
  final String alias;
  final int start;
  final int end;

  const _TreatmentMention({
    required this.treatment,
    required this.alias,
    required this.start,
    required this.end,
  });
}

enum ParseSource {
  localOnly,
}

class _ToothMention {
  final String code;
  final int position;

  const _ToothMention({
    required this.code,
    required this.position,
  });
}



