import 'package:flutter/material.dart';

import '../../tmdb/models/media_details.dart';
import '../../tmdb/models/media_summary.dart';

/// Support physique/numérique d'une possession.
enum Medium {
  dvd,
  bluray,
  digital;

  static Medium fromName(String? n) => switch (n) {
        'bluray' => Medium.bluray,
        'digital' => Medium.digital,
        _ => Medium.dvd,
      };

  String get label => switch (this) {
        Medium.dvd => 'DVD',
        Medium.bluray => 'Blu-ray',
        Medium.digital => 'Digital',
      };

  IconData get icon => switch (this) {
        Medium.dvd => Icons.album,
        Medium.bluray => Icons.disc_full,
        Medium.digital => Icons.cloud_done,
      };
}

/// Catalogue : métadonnées TMDB d'un titre (film ou série). Aucune donnée
/// utilisateur ici — la possession est dans `collection`, les visionnages dans
/// `history`. Une ligne sans aucune référence est supprimée automatiquement
/// (trigger `gc_orphan_films`).
class Film {
  Film({
    this.id,
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.originalTitle,
    this.posterPath,
    this.releaseYear,
    this.runtime,
    this.overview,
    this.originCountry,
    this.genres = const [],
    this.castIds = const [],
  });

  final String? id; // null avant insertion (généré par Supabase)
  final int tmdbId;
  final String mediaType; // 'movie' | 'tv'
  final String title;
  final String? originalTitle;
  final String? posterPath;
  final int? releaseYear;
  final int? runtime;
  final String? overview;

  /// Pays d'origine principal (code ISO-3166-1, ex. « US », « FR »), ou null.
  final String? originCountry;
  final List<int> genres;

  /// Identifiants TMDB des acteurs principaux (pour le filtre « favoris »).
  final List<int> castIds;

  bool get isMovie => mediaType == 'movie';

  /// Clé d'identité TMDB (indépendante de l'`id` Supabase).
  String get mediaKey => '$mediaType:$tmdbId';

  factory Film.fromJson(Map<String, dynamic> json) => Film(
        id: json['id'] as String?,
        tmdbId: (json['tmdb_id'] as num).toInt(),
        mediaType: json['media_type'] as String,
        title: (json['title'] as String?) ?? 'Sans titre',
        originalTitle: json['original_title'] as String?,
        posterPath: json['poster_path'] as String?,
        releaseYear: (json['release_year'] as num?)?.toInt(),
        runtime: (json['runtime'] as num?)?.toInt(),
        overview: json['overview'] as String?,
        originCountry: json['origin_country'] as String?,
        genres:
            (json['genres'] as List<dynamic>? ?? []).map((e) => e as int).toList(),
        castIds: (json['cast_ids'] as List<dynamic>? ?? [])
            .map((e) => (e as num).toInt())
            .toList(),
      );

  /// Payload pour insert/upsert dans `films` (`user_id` injecté par le repo).
  Map<String, dynamic> toUpsertJson() => {
        'tmdb_id': tmdbId,
        'media_type': mediaType,
        'title': title,
        'original_title': originalTitle,
        'poster_path': posterPath,
        'release_year': releaseYear,
        'runtime': runtime,
        'overview': overview,
        'origin_country': originCountry,
        'genres': genres,
        'cast_ids': castIds,
      };

  /// JSON complet (avec `id`) pour la persistance locale.
  Map<String, dynamic> toFullJson() => {...toUpsertJson(), 'id': id};

  factory Film.fromSummary(MediaSummary s) => Film(
        tmdbId: s.tmdbId,
        mediaType: s.mediaType,
        title: s.title,
        posterPath: s.posterPath,
        releaseYear: s.releaseYear,
        overview: s.overview,
        genres: s.genreIds,
      );

  factory Film.fromDetails(MediaDetails d) => Film(
        tmdbId: d.tmdbId,
        mediaType: d.mediaType,
        title: d.title,
        originalTitle: d.originalTitle.isEmpty ? null : d.originalTitle,
        // Affiche en langue originale (stable quelle que soit la langue de
        // l'appli au moment de l'ajout).
        posterPath: d.libraryPosterPath,
        releaseYear: d.releaseYear,
        runtime: d.runtime,
        overview: d.overview,
        originCountry: d.originCountry,
        genres: d.genreIds,
        // « Personnes » du film pour le filtre favoris : acteurs ET
        // réalisateurs/créateurs (un favori peut être l'un ou l'autre).
        castIds: <int>{
          ...d.cast.map((c) => c.id),
          ...d.directors.map((c) => c.id),
        }.where((id) => id != 0).toList(),
      );
}
