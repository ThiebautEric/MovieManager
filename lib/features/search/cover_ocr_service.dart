import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';

/// Envoie les bytes d'une image à la Cloud Vision API et extrait un titre de
/// film/série à partir du texte détecté sur la jaquette.
///
/// Aucune image n'est stockée : le [Uint8List] est encodé en base64 pour l'appel
/// HTTP et n'est jamais écrit sur disque ni transmis à un autre service.
class CoverOcrService {
  CoverOcrService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://vision.googleapis.com/v1',
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
            ));

  final Dio _dio;

  /// Envoie [bytes] à Vision TEXT_DETECTION, retourne le titre candidat ou
  /// null si rien n'est utilisable.
  Future<String?> extractTitle(Uint8List bytes) async {
    final b64 = base64Encode(bytes);
    final response = await _dio.post<Map<String, dynamic>>(
      '/images:annotate',
      queryParameters: {'key': AppConfig.visionApiKey},
      data: {
        'requests': [
          {
            'image': {'content': b64},
            'features': [
              {'type': 'TEXT_DETECTION', 'maxResults': 1}
            ],
          }
        ]
      },
    );
    final raw = _rawText(response.data);
    if (raw == null || raw.trim().isEmpty) return null;
    return _extractTitle(raw);
  }

  static String? _rawText(Map<String, dynamic>? data) {
    try {
      return (data!['responses'][0]['textAnnotations'][0]['description']
          as String?);
    } catch (_) {
      return null;
    }
  }

  // Termes de bruit courants sur les jaquettes DVD/Blu-ray.
  static const _noiseTerms = {
    'blu-ray', 'blu ray', '4k', 'uhd', '4k ultra hd', 'ultra hd', 'dvd',
    'hdr', 'dolby', 'atmos', 'dts', 'digital', 'edition', 'édition',
    'collector', 'steelbook', 'lenticular', 'limited', 'director', 'extended',
    'theatrical', 'bonus', 'special', 'unrated', 'version longue',
    '18+', '16+', '12+', '10+', 'pg', 'pg-13', 'nc-17', 'fsk', 'bbfc',
    'www.', 'http', '©', '®', '™', 'all rights', 'tous droits',
  };

  static bool _isNoise(String line) {
    final t = line.trim();
    if (t.length < 2) return true;
    // Lignes composées uniquement de chiffres / ponctuation (durée, année…)
    if (RegExp(r'^[\d\s:.\-/|,]+$').hasMatch(t)) return true;
    final lower = t.toLowerCase();
    return _noiseTerms.any((n) => lower == n || lower.startsWith('$n '));
  }

  static String? _extractTitle(String raw) {
    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return null;

    // Regrouper les lignes non-bruit en blocs contigus.
    final blocks = <List<String>>[];
    var current = <String>[];
    for (final line in lines) {
      if (_isNoise(line)) {
        if (current.isNotEmpty) {
          blocks.add(current);
          current = [];
        }
      } else {
        current.add(line);
      }
    }
    if (current.isNotEmpty) blocks.add(current);

    // Parmi les blocs propres, prendre le plus long (le titre est souvent
    // le texte le plus long sur la jaquette).
    if (blocks.isNotEmpty) {
      final best = blocks
          .map((b) => b.join(' ').trim())
          .where((s) => s.isNotEmpty)
          .reduce((a, b) => a.length >= b.length ? a : b);
      if (best.isNotEmpty) return _finalize(best);
    }

    // Fallback : aucun bloc propre trouvé — retourner la ligne non-bruit
    // la plus longue pour laisser TMDB tenter quand même.
    final fallback = lines
        .where((l) => !_isNoise(l))
        .fold<String>('', (best, l) => l.length > best.length ? l : best);
    if (fallback.isNotEmpty) return _finalize(fallback);

    // Dernier recours : première ligne brute.
    return _finalize(lines.first);
  }

  static String _finalize(String text) {
    final normalized = _normalize(text);
    return normalized.length > 100
        ? normalized.substring(0, 100).trim()
        : normalized;
  }

  /// Si le texte est entièrement en majuscules, le convertit en title-case.
  static String _normalize(String text) {
    final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t == t.toUpperCase() && t.contains(RegExp(r'[A-ZÀÂÉÈÊËÎÏÔÙÛÜ]'))) {
      return t.split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1).toLowerCase();
      }).join(' ');
    }
    return t;
  }
}
