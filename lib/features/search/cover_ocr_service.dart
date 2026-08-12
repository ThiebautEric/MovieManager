import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';

class _WordInfo {
  _WordInfo({
    required this.text,
    required this.height,
    required this.centerY,
    required this.minX,
  });
  final String text;
  final double height;
  final double centerY;
  final double minX;
}

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
    final annotations = _getAnnotations(response.data);
    if (annotations == null || annotations.isEmpty) return null;
    return _extractTitleFromAnnotations(annotations);
  }

  static List? _getAnnotations(Map<String, dynamic>? data) {
    try {
      return data!['responses'][0]['textAnnotations'] as List?;
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

  /// Stratégie principale : utiliser les bounding boxes des mots individuels
  /// pour identifier la taille de police. Le titre d'une jaquette est presque
  /// toujours le texte à la plus grande taille de police.
  static String? _extractTitleFromAnnotations(List annotations) {
    if (annotations.isEmpty) return null;

    // annotations[0] = texte brut complet
    final raw = (annotations[0]['description'] as String?) ?? '';
    if (raw.trim().isEmpty) return null;

    // Construire la liste des mots avec leur hauteur de bounding box.
    final words = <_WordInfo>[];
    for (final ann in annotations.skip(1)) {
      final text = (ann['description'] as String?)?.trim() ?? '';
      if (text.isEmpty || _isNoise(text)) continue;

      final verts = (ann['boundingPoly']?['vertices'] as List?) ?? [];
      if (verts.length < 2) continue;

      double maxY = 0, minY = double.infinity, minX = double.infinity;
      for (final v in verts) {
        final y = (v['y'] as num?)?.toDouble() ?? 0;
        final x = (v['x'] as num?)?.toDouble() ?? 0;
        if (y > maxY) maxY = y;
        if (y < minY) minY = y;
        if (x < minX) minX = x;
      }
      final height = maxY - minY;
      if (height <= 0) continue;

      words.add(_WordInfo(
        text: text,
        height: height,
        centerY: (maxY + minY) / 2,
        minX: minX,
      ));
    }

    if (words.isEmpty) return _extractTitleFallback(raw);

    // Hauteur maximale = taille de police du titre.
    final maxH = words.map((w) => w.height).reduce(math.max);

    // Garder uniquement les mots à ≥ 70 % de la hauteur max.
    final titleWords = words.where((w) => w.height >= maxH * 0.70).toList();
    if (titleWords.isEmpty) return _extractTitleFallback(raw);

    // Trier spatialement : ligne par ligne (tolérance = 50 % de hauteur max),
    // puis de gauche à droite dans chaque ligne.
    titleWords.sort((a, b) {
      final diff = (a.centerY - b.centerY).abs();
      if (diff > maxH * 0.5) return a.centerY.compareTo(b.centerY);
      return a.minX.compareTo(b.minX);
    });

    final titleText = titleWords.map((w) => w.text).join(' ').trim();
    if (titleText.isEmpty) return _extractTitleFallback(raw);
    return _finalize(titleText);
  }

  /// Fallback si pas de bounding boxes utilisables : premier bloc court.
  static String? _extractTitleFallback(String raw) {
    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return null;

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
      for (final block in blocks) {
        final candidate = block.take(2).join(' ').trim();
        if (candidate.length <= 50) return _finalize(candidate);
      }
      return _finalize(blocks.first.first);
    }

    final fallback = lines.firstWhere(
      (l) => !_isNoise(l),
      orElse: () => lines.first,
    );
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
