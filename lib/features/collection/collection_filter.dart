import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/collection_entry.dart';
import '../../data/models/film.dart';
import '../../data/models/history_entry.dart';
import '../../data/repositories/collection_repository.dart';

/// Drapeau emoji à partir d'un code pays ISO-3166-1 alpha-2 (ex. « FR » → 🇫🇷).
String countryFlag(String iso) {
  if (iso.length != 2) return '';
  final up = iso.toUpperCase();
  final a = up.codeUnitAt(0), b = up.codeUnitAt(1);
  if (a < 65 || a > 90 || b < 65 || b > 90) return '';
  return String.fromCharCodes([0x1F1E6 + (a - 65), 0x1F1E6 + (b - 65)]);
}

const _countryNames = <String, String>{
  'AD': 'Andorre', 'AE': 'Émirats arabes unis', 'AF': 'Afghanistan',
  'AG': 'Antigua-et-Barbuda', 'AL': 'Albanie', 'AM': 'Arménie',
  'AO': 'Angola', 'AR': 'Argentine', 'AT': 'Autriche',
  'AU': 'Australie', 'AZ': 'Azerbaïdjan',
  'BA': 'Bosnie-Herzégovine', 'BB': 'Barbade', 'BD': 'Bangladesh',
  'BE': 'Belgique', 'BF': 'Burkina Faso', 'BG': 'Bulgarie',
  'BH': 'Bahreïn', 'BI': 'Burundi', 'BJ': 'Bénin',
  'BN': 'Brunei', 'BO': 'Bolivie', 'BR': 'Brésil',
  'BS': 'Bahamas', 'BT': 'Bhoutan', 'BW': 'Botswana',
  'BY': 'Biélorussie', 'BZ': 'Belize',
  'CA': 'Canada', 'CD': 'RD Congo', 'CF': 'Centrafrique',
  'CG': 'Congo', 'CH': 'Suisse', 'CI': "Côte d'Ivoire",
  'CL': 'Chili', 'CM': 'Cameroun', 'CN': 'Chine',
  'CO': 'Colombie', 'CR': 'Costa Rica', 'CU': 'Cuba',
  'CV': 'Cap-Vert', 'CY': 'Chypre', 'CZ': 'République tchèque',
  'DE': 'Allemagne', 'DJ': 'Djibouti', 'DK': 'Danemark',
  'DM': 'Dominique', 'DO': 'République dominicaine', 'DZ': 'Algérie',
  'EC': 'Équateur', 'EE': 'Estonie', 'EG': 'Égypte',
  'ER': 'Érythrée', 'ES': 'Espagne', 'ET': 'Éthiopie',
  'FI': 'Finlande', 'FJ': 'Fidji', 'FM': 'Micronésie', 'FR': 'France',
  'GA': 'Gabon', 'GB': 'Royaume-Uni', 'GD': 'Grenade',
  'GE': 'Géorgie', 'GH': 'Ghana', 'GM': 'Gambie',
  'GN': 'Guinée', 'GQ': 'Guinée équatoriale', 'GR': 'Grèce',
  'GT': 'Guatemala', 'GW': 'Guinée-Bissau', 'GY': 'Guyana',
  'HK': 'Hong Kong', 'HN': 'Honduras', 'HR': 'Croatie',
  'HT': 'Haïti', 'HU': 'Hongrie',
  'ID': 'Indonésie', 'IE': 'Irlande', 'IL': 'Israël',
  'IN': 'Inde', 'IQ': 'Irak', 'IR': 'Iran',
  'IS': 'Islande', 'IT': 'Italie',
  'JM': 'Jamaïque', 'JO': 'Jordanie', 'JP': 'Japon',
  'KE': 'Kenya', 'KG': 'Kirghizistan', 'KH': 'Cambodge',
  'KI': 'Kiribati', 'KM': 'Comores', 'KP': 'Corée du Nord',
  'KR': 'Corée du Sud', 'KW': 'Koweït', 'KZ': 'Kazakhstan',
  'LA': 'Laos', 'LB': 'Liban', 'LC': 'Sainte-Lucie',
  'LI': 'Liechtenstein', 'LK': 'Sri Lanka', 'LR': 'Liberia',
  'LS': 'Lesotho', 'LT': 'Lituanie', 'LU': 'Luxembourg',
  'LV': 'Lettonie', 'LY': 'Libye',
  'MA': 'Maroc', 'MC': 'Monaco', 'MD': 'Moldavie',
  'ME': 'Monténégro', 'MG': 'Madagascar', 'MH': 'Îles Marshall',
  'MK': 'Macédoine du Nord', 'ML': 'Mali', 'MM': 'Myanmar',
  'MN': 'Mongolie', 'MR': 'Mauritanie', 'MT': 'Malte',
  'MU': 'Maurice', 'MV': 'Maldives', 'MW': 'Malawi',
  'MX': 'Mexique', 'MY': 'Malaisie', 'MZ': 'Mozambique',
  'NA': 'Namibie', 'NE': 'Niger', 'NG': 'Nigéria',
  'NI': 'Nicaragua', 'NL': 'Pays-Bas', 'NO': 'Norvège',
  'NP': 'Népal', 'NR': 'Nauru', 'NZ': 'Nouvelle-Zélande',
  'OM': 'Oman',
  'PA': 'Panama', 'PE': 'Pérou', 'PG': 'Papouasie-Nouvelle-Guinée',
  'PH': 'Philippines', 'PK': 'Pakistan', 'PL': 'Pologne',
  'PS': 'Palestine', 'PT': 'Portugal', 'PW': 'Palaos',
  'PY': 'Paraguay',
  'QA': 'Qatar',
  'RO': 'Roumanie', 'RS': 'Serbie', 'RU': 'Russie', 'RW': 'Rwanda',
  'SA': 'Arabie saoudite', 'SB': 'Îles Salomon', 'SC': 'Seychelles',
  'SD': 'Soudan', 'SE': 'Suède', 'SG': 'Singapour',
  'SI': 'Slovénie', 'SK': 'Slovaquie', 'SL': 'Sierra Leone',
  'SM': 'Saint-Marin', 'SN': 'Sénégal', 'SO': 'Somalie',
  'SR': 'Suriname', 'SS': 'Soudan du Sud', 'ST': 'São Tomé-et-Príncipe',
  'SV': 'Salvador', 'SY': 'Syrie', 'SZ': 'Eswatini',
  'TD': 'Tchad', 'TG': 'Togo', 'TH': 'Thaïlande',
  'TJ': 'Tadjikistan', 'TL': 'Timor oriental', 'TM': 'Turkménistan',
  'TN': 'Tunisie', 'TO': 'Tonga', 'TR': 'Turquie',
  'TT': 'Trinité-et-Tobago', 'TV': 'Tuvalu', 'TW': 'Taïwan',
  'TZ': 'Tanzanie',
  'UA': 'Ukraine', 'UG': 'Ouganda', 'US': 'États-Unis',
  'UY': 'Uruguay', 'UZ': 'Ouzbékistan',
  'VA': 'Vatican', 'VC': 'Saint-Vincent-et-les-Grenadines',
  'VE': 'Venezuela', 'VN': 'Viêt Nam', 'VU': 'Vanuatu',
  'WS': 'Samoa',
  'XK': 'Kosovo',
  'YE': 'Yémen',
  'ZA': 'Afrique du Sud', 'ZM': 'Zambie', 'ZW': 'Zimbabwe',
};

/// Nom complet du pays en français ; retourne le code ISO si inconnu.
String countryName(String iso) => _countryNames[iso.toUpperCase()] ?? iso;

/// Libellé pays : drapeau + nom complet (ex. « 🇫🇷 France »).
String countryLabel(String iso) {
  final flag = countryFlag(iso);
  final name = countryName(iso);
  return flag.isEmpty ? name : '$flag $name';
}

/// Filtres communs aux deux vues (collection / historique). Les champs non
/// pertinents pour une vue sont simplement ignorés (ex. la note pour la
/// collection).
class CollectionFilter {
  const CollectionFilter({
    this.mediaType,
    this.genreId,
    this.country,
    this.year,
    this.minRating = 0,
    this.favoritePersonId,
  });

  final String? mediaType; // 'movie' | 'tv' | null (tous)
  final int? genreId;
  final String? country; // code ISO pays d'origine
  final int? year;
  final double minRating; // note minimale du visionnage (historique)
  final int? favoritePersonId; // id TMDB d'une personne favorite (casting)

  CollectionFilter copyWith({
    String? mediaType,
    bool clearMediaType = false,
    int? genreId,
    bool clearGenre = false,
    String? country,
    bool clearCountry = false,
    int? year,
    bool clearYear = false,
    double? minRating,
    int? favoritePersonId,
    bool clearFavorite = false,
  }) {
    return CollectionFilter(
      mediaType: clearMediaType ? null : (mediaType ?? this.mediaType),
      genreId: clearGenre ? null : (genreId ?? this.genreId),
      country: clearCountry ? null : (country ?? this.country),
      year: clearYear ? null : (year ?? this.year),
      minRating: minRating ?? this.minRating,
      favoritePersonId:
          clearFavorite ? null : (favoritePersonId ?? this.favoritePersonId),
    );
  }

  /// Critères portant sur le film (type, genre, pays, année, acteur favori).
  bool matchesFilm(Film f) {
    if (mediaType != null && f.mediaType != mediaType) return false;
    if (genreId != null && !f.genres.contains(genreId)) return false;
    if (country != null && f.originCountry != country) return false;
    if (year != null && f.releaseYear != year) return false;
    if (favoritePersonId != null && !f.castIds.contains(favoritePersonId)) {
      return false;
    }
    return true;
  }

  /// Visionnage : critères film + note minimale de la séance.
  bool matchesHistory(HistoryView v) {
    if (!matchesFilm(v.film)) return false;
    if (minRating > 0 && (v.rating ?? 0) < minRating) return false;
    return true;
  }

  bool get isActive =>
      mediaType != null ||
      genreId != null ||
      country != null ||
      year != null ||
      minRating > 0 ||
      favoritePersonId != null;
}

/// Filtre de l'onglet Historique (indépendant de la collection).
final historyFilterProvider =
    StateProvider<CollectionFilter>((ref) => const CollectionFilter());

/// Filtre de l'onglet Collection (indépendant de l'historique).
final collectionFilterProvider =
    StateProvider<CollectionFilter>((ref) => const CollectionFilter());

/// Historique filtré, du plus récent au plus ancien.
final filteredHistoryProvider = Provider<List<HistoryView>>((ref) {
  final all = ref.watch(historyStreamProvider).value ?? [];
  final filter = ref.watch(historyFilterProvider);
  return all.where(filter.matchesHistory).toList();
});

/// Collection filtrée (tous supports).
final filteredCollectionProvider = Provider<List<CollectionView>>((ref) {
  final all = ref.watch(collectionStreamProvider).value ?? [];
  final filter = ref.watch(collectionFilterProvider);
  return all.where((c) => filter.matchesFilm(c.film)).toList();
});
