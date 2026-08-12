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

    if (blocks.isNotEmpty) {
      // Stratégie : premier bloc court (≤ 50 chars) = titre.
      // Les titres sont courts ; taglines et descriptions sont longs.
      for (final block in blocks) {
        final candidate = block.take(2).join(' ').trim();
        if (candidate.length <= 50) return _finalize(candidate);
      }
      // Tous les blocs sont longs : prendre juste la 1re ligne du 1er bloc.
      return _finalize(blocks.first.first);
    }

    // Fallback : première ligne non-bruit, ou première ligne brute.
    final fallback = lines.firstWhere((l) => !_isNoise(l), orElse: () => lines.first);
    return _finalize(fallback);
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
