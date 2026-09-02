import '../../core/l10n/l10n.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../data/models/history_entry.dart';

/// Critères de tri de l'historique (utilisés par la vue partagée : le
/// destinataire peut réordonner librement). Le nom (`.name`) sert de valeur
/// stable stockée dans le lien de partage.
enum HistorySort { watchedDesc, watchedAsc, titleAsc, releaseDesc, ratingDesc }

/// Reconstruit un [HistorySort] depuis sa valeur stockée ; repli sur le tri
/// chronologique par défaut si la valeur est absente/inconnue.
HistorySort historySortFromName(String? name) =>
    HistorySort.values.asNameMap()[name] ?? HistorySort.watchedDesc;

String historySortLabel(AppLocalizations l10n, HistorySort s) => switch (s) {
      HistorySort.watchedDesc => l10n.sortWatchedDesc,
      HistorySort.watchedAsc => l10n.sortWatchedAsc,
      HistorySort.titleAsc => l10n.sortTitleAsc,
      HistorySort.releaseDesc => l10n.sortReleaseDesc,
      HistorySort.ratingDesc => l10n.sortRatingDesc,
    };

/// Comparateur d'historique pour [sort]. [titleOf] fournit le titre AFFICHÉ
/// (résolu selon la langue de titre courante) pour le tri alphabétique et les
/// départages, afin que l'ordre suive ce qui est montré.
Comparator<HistoryView> historyComparator(
    HistorySort sort, String Function(HistoryView) titleOf) {
  int byTitle(HistoryView a, HistoryView b) =>
      titleOf(a).toLowerCase().compareTo(titleOf(b).toLowerCase());

  int byWatched(HistoryView a, HistoryView b, bool desc) {
    final c = desc
        ? b.watchedAt.compareTo(a.watchedAt)
        : a.watchedAt.compareTo(b.watchedAt);
    return c != 0 ? c : byTitle(a, b);
  }

  return switch (sort) {
    HistorySort.watchedDesc => (a, b) => byWatched(a, b, true),
    HistorySort.watchedAsc => (a, b) => byWatched(a, b, false),
    HistorySort.titleAsc => (a, b) {
        final t = byTitle(a, b);
        return t != 0 ? t : b.watchedAt.compareTo(a.watchedAt);
      },
    HistorySort.releaseDesc => (a, b) {
        final ay = a.film.releaseYear, by = b.film.releaseYear;
        if (ay == null && by == null) return byTitle(a, b);
        if (ay == null) return 1;
        if (by == null) return -1;
        return ay != by ? by.compareTo(ay) : byTitle(a, b);
      },
    HistorySort.ratingDesc => (a, b) {
        final ar = a.rating, br = b.rating;
        if (ar == null && br == null) return b.watchedAt.compareTo(a.watchedAt);
        if (ar == null) return 1;
        if (br == null) return -1;
        return ar != br ? br.compareTo(ar) : byTitle(a, b);
      },
  };
}
