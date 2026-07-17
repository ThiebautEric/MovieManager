// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Movie Manager';

  @override
  String get themeTooltip => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get languageTooltip => 'Sprache';

  @override
  String get languageSystem => 'System';

  @override
  String get titleModeLocalizedTooltip =>
      'Übersetzte Titel (App-Sprache) – tippen für Originaltitel';

  @override
  String get titleModeOriginalTooltip =>
      'Originaltitel – tippen für englische Titel';

  @override
  String get titleModeEnglishTooltip =>
      'Englische Titel – tippen für übersetzte Titel';

  @override
  String get titleModeOriginalShort => 'OV';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get close => 'Schließen';

  @override
  String get add => 'Hinzufügen';

  @override
  String get film => 'Film';

  @override
  String get serie => 'Serie';

  @override
  String get searchTitle => 'Suchen';

  @override
  String get historyTitle => 'Verlauf';

  @override
  String get collectionTitle => 'Sammlung';

  @override
  String get statsTitle => 'Statistiken';

  @override
  String get favoritesTitle => 'Favoriten';

  @override
  String get adminTitle => 'Verwaltung';

  @override
  String get friendsTitle => 'Meine Freunde';

  @override
  String get detailsTitle => 'Details';

  @override
  String get logout => 'Abmelden';

  @override
  String errorMessage(String message) {
    return 'Fehler: $message';
  }

  @override
  String get searchHint => 'Film, Serie oder Person…';

  @override
  String searchError(String message) {
    return 'Fehler bei der Suche: $message';
  }

  @override
  String get searchStartTyping => 'Tippe los, um zu suchen.';

  @override
  String get searchNoResults => 'Keine Ergebnisse.';

  @override
  String get searchPersonBadge => 'Person';

  @override
  String get searchActor => 'Schauspieler/in';

  @override
  String get searchPersonality => 'Persönlichkeit';

  @override
  String detailsOriginalTitle(String title) {
    return 'Originaltitel: $title';
  }

  @override
  String detailsTranslatedTitle(String title) {
    return 'Übersetzter Titel: $title';
  }

  @override
  String detailsEpisodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Folgen',
      one: '$count Folge',
    );
    return '$_temp0';
  }

  @override
  String detailsMinutesPerEpisode(int count) {
    return '$count Min./Folge';
  }

  @override
  String get detailsDirectorLabel => 'Regie:';

  @override
  String get detailsCreatorLabel => 'Idee:';

  @override
  String get detailsSynopsis => 'Handlung';

  @override
  String get detailsTrailers => 'Trailer';

  @override
  String detailsCastTitle(int count) {
    return 'Besetzung ($count)';
  }

  @override
  String get detailsCollapse => 'Einklappen';

  @override
  String get detailsShowAll => 'Alle anzeigen';

  @override
  String get detailsWholeSeries => 'Ganze Serie';

  @override
  String detailsSeasonNumber(int number) {
    return 'Staffel $number';
  }

  @override
  String get detailsSeasonsTitle => 'Staffeln';

  @override
  String get detailsSeasonsHint =>
      'Verfolge diese Serie Staffel für Staffel: Besitz und Sichtungen werden pro Staffel verwaltet.';

  @override
  String get detailsSeasonNotTracked => 'Nicht verfolgt';

  @override
  String detailsMediaCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Medien',
      one: '$count Medium',
    );
    return '$_temp0';
  }

  @override
  String detailsViewingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Sichtungen',
      one: '$count Sichtung',
    );
    return '$_temp0';
  }

  @override
  String get detailsAddViewing => 'Sichtung hinzufügen';

  @override
  String get detailsRateEpisode => 'Eine Folge bewerten';

  @override
  String get detailsEditViewing => 'Sichtung bearbeiten';

  @override
  String get detailsRemoveCollectionTitle => 'Aus der Sammlung entfernen?';

  @override
  String get detailsRemoveCollectionBody =>
      'Dieses Exemplar wird aus deiner Sammlung entfernt. Dein Sichtungsverlauf bleibt unberührt.';

  @override
  String get detailsRemoveAction => 'Entfernen';

  @override
  String get detailsDeleteViewingTitle => 'Diese Sichtung löschen?';

  @override
  String get detailsDeleteViewingBody =>
      'Diese Sichtung wird endgültig aus dem Verlauf gelöscht. Das kann nicht rückgängig gemacht werden.';

  @override
  String get detailsDeleteViewingTooltip => 'Diese Sichtung löschen';

  @override
  String get detailsMyCollection => 'Meine Sammlung';

  @override
  String get detailsNotInCollection => 'Nicht in deiner Sammlung.';

  @override
  String detailsAcquiredOn(String date) {
    return 'Erworben am $date';
  }

  @override
  String get detailsRemoveFromCollectionTooltip => 'Aus der Sammlung entfernen';

  @override
  String detailsViewingHistoryTitle(int count) {
    return 'Sichtungsverlauf ($count)';
  }

  @override
  String get detailsViewingButton => 'Sichtung';

  @override
  String get detailsNoViewings => 'Keine Sichtungen erfasst.';

  @override
  String detailsWatchedOn(String date) {
    return 'Gesehen am $date';
  }

  @override
  String get detailsAddToCollection => 'Zur Sammlung hinzufügen';

  @override
  String get detailsMediumLabel => 'Medium';

  @override
  String get detailsRatingLabel => 'Bewertung';

  @override
  String get detailsRatingNone => 'Keine';

  @override
  String get detailsCommentLabel => 'Kommentar (optional)';

  @override
  String get detailsCommentHint =>
      'z. B. im Kino gesehen, mit den Kindern noch mal geschaut…';

  @override
  String get detailsEditButton => 'Ändern';

  @override
  String get personTitle => 'Schauspieler';

  @override
  String get personAddFavoriteTooltip => 'Zu Favoriten hinzufügen';

  @override
  String get personRemoveFavoriteTooltip => 'Aus Favoriten entfernen';

  @override
  String get personFilmsSection => 'Filme';

  @override
  String get personSeriesSection => 'Serien';

  @override
  String get personDocumentariesSection => 'Dokus & Reportagen';

  @override
  String get personOthersSection => 'Sonstiges';

  @override
  String get personInYourLibrary => 'In deiner Bibliothek';

  @override
  String personBirth(String date) {
    return 'Geboren: $date';
  }

  @override
  String personDeath(String date) {
    return 'Gestorben: $date';
  }

  @override
  String personAge(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age Jahre alt',
      one: '$age Jahr alt',
    );
    return '$_temp0';
  }

  @override
  String personAgeAtDeath(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: 'im Alter von $age Jahren verstorben',
      one: 'im Alter von $age Jahr verstorben',
    );
    return '$_temp0';
  }

  @override
  String get personBiography => 'Biografie';

  @override
  String get personFilmography => 'Filmografie';

  @override
  String get personShowMore => 'Mehr anzeigen';

  @override
  String get personShowLess => 'Weniger anzeigen';

  @override
  String get personWatchedBadge => 'Gesehen';

  @override
  String get historyExportTooltip => 'Als CSV exportieren (vorläufig)';

  @override
  String get historyExportedSnack => 'Verlauf exportiert (historique.csv)';

  @override
  String get historyCsvHeader => 'Nummer;Titel;Staffel;Bewertung;Datum';

  @override
  String get historyEmpty =>
      'Keine Sichtungen anzuzeigen.\nFüge einen Film oder eine Staffel zu deinem Verlauf hinzu (oder passe die Filter an).';

  @override
  String get historyDayAbbrev => 'T';

  @override
  String historyDurationLine(String total, String details) {
    return 'gesamt: $total ($details)';
  }

  @override
  String historyDurationFilms(String duration) {
    return 'Filme: $duration';
  }

  @override
  String historyDurationSeries(String duration) {
    return 'Serien: $duration';
  }

  @override
  String historyTotalCount(int n) {
    return '$n insgesamt';
  }

  @override
  String historyFilmsWatched(int n, int inCollection) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Filme gesehen (davon $inCollection in der Sammlung)',
      one: '$n Film gesehen (davon $inCollection in der Sammlung)',
    );
    return '$_temp0';
  }

  @override
  String historySeriesWatched(int n, int inCollection) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n Serien gesehen (davon $inCollection in der Sammlung)',
      one: '$n Serie gesehen (davon $inCollection in der Sammlung)',
    );
    return '$_temp0';
  }

  @override
  String get collEmpty =>
      'Keine Titel in deiner Sammlung.\nFüge auf einer Detailseite ein Medium hinzu (DVD, Blu-ray oder Digital) oder passe die Filter an.';

  @override
  String collSeasonLabel(int n) {
    return 'Staffel $n';
  }

  @override
  String get filterTooltip => 'Filtern';

  @override
  String get filterTitle => 'Filter';

  @override
  String get filterReset => 'Zurücksetzen';

  @override
  String get filterType => 'Typ';

  @override
  String get filterAll => 'Alle';

  @override
  String get filterAllFeminine => 'Alle';

  @override
  String get filterFilms => 'Filme';

  @override
  String get filterSeries => 'Serien';

  @override
  String get filterGenre => 'Genre';

  @override
  String filterGenreFallback(int id) {
    return 'Genre $id';
  }

  @override
  String get filterCountry => 'Herkunftsland';

  @override
  String get filterYear => 'Jahr';

  @override
  String get filterFavoriteActor => 'Lieblingsschauspieler';

  @override
  String filterMinRating(String rating) {
    return 'Mindestbewertung der Sichtung: $rating';
  }

  @override
  String get filterRatingNone => 'keine';

  @override
  String get authEmailLabel => 'E-Mail';

  @override
  String get authPasswordLabel => 'Passwort';

  @override
  String get authEmailInvalid => 'Ungültige E-Mail';

  @override
  String get authPasswordTooShort => 'Mindestens 6 Zeichen';

  @override
  String get authSignIn => 'Anmelden';

  @override
  String get authSignUp => 'Konto erstellen';

  @override
  String get authAlreadyHaveAccount => 'Ich habe schon ein Konto';

  @override
  String get authAccountCreated =>
      'Konto erstellt. Bestätige deine E-Mail und melde dich dann an.';

  @override
  String get adminCreateUser => 'Benutzer erstellen';

  @override
  String get adminCreate => 'Erstellen';

  @override
  String get adminEmailExists => 'Diese E-Mail existiert bereits.';

  @override
  String adminHttpError(int status) {
    return 'Fehler $status';
  }

  @override
  String adminLoadFailed(String message) {
    return 'Laden nicht möglich: $message';
  }

  @override
  String get adminRetry => 'Erneut versuchen';

  @override
  String adminUserCreated(String email) {
    return 'Benutzer $email erstellt.';
  }

  @override
  String adminActionFailed(String message) {
    return 'Fehlgeschlagen: $message';
  }

  @override
  String adminLastSignIn(String date) {
    return 'letzte Anmeldung $date';
  }

  @override
  String get adminNeverSignedIn => 'nie angemeldet';

  @override
  String get adminBadge => 'Admin';

  @override
  String get adminYou => '(du)';

  @override
  String adminCreatedOn(String date) {
    return 'Erstellt am $date';
  }

  @override
  String get adminCannotDelete => 'Löschen nicht möglich (Admin)';

  @override
  String adminDeleteUserTitle(String email) {
    return '$email löschen?';
  }

  @override
  String get adminDeleteUserWarning =>
      'Alle zugehörigen Daten (Sammlung, Verlauf, Favoriten) werden endgültig gelöscht.';

  @override
  String get navStats => 'Stats';

  @override
  String navViewingAs(String email) {
    return 'Ansicht: $email (nur Lesen)';
  }

  @override
  String get navQuit => 'Verlassen';

  @override
  String get navCloseDetail => 'Detailansicht schließen';

  @override
  String get wishlistTitle => 'Merkliste';

  @override
  String get wishlistEmpty =>
      'Nichts auf der Merkliste.\nTippe auf einer Detailseite oder in den Suchergebnissen auf das Lesezeichen, um dir einen Titel zu merken.';

  @override
  String get wishlistAddTooltip => 'Zur Merkliste hinzufügen';

  @override
  String get wishlistRemoveTooltip => 'Von der Merkliste entfernen';

  @override
  String get wishlistToHistory => 'Gesehen';

  @override
  String get wishlistToCollection => 'Gekauft';

  @override
  String wishlistAddedOn(String date) {
    return 'Hinzugefügt am $date';
  }

  @override
  String get top10Title => 'Top 10';

  @override
  String get top10Hint =>
      'Rangfolge nach deiner Durchschnittsnote, verstärkt durch die Anzahl der Sichtungen.';

  @override
  String get top10Empty =>
      'Noch keine bewerteten Titel.\nBewerte deine Sichtungen, um dein Top 10 aufzubauen.';

  @override
  String get statsEmpty => 'Keine Daten zum Anzeigen.';

  @override
  String get statsWatchedUnwatched => 'Gesehen / ungesehen';

  @override
  String get statsTopGenres => 'Top-Genres';

  @override
  String get statsCardTitles => 'Titel';

  @override
  String get statsCardWatched => 'Gesehen';

  @override
  String get statsCardViews => 'Sichtungen';

  @override
  String get statsCardOwned => 'Im Besitz';

  @override
  String get statsCardAvgRating => 'Ø-Note';

  @override
  String statsLegendWatched(int count) {
    return 'Gesehen ($count)';
  }

  @override
  String statsLegendUnwatched(int count) {
    return 'Ungesehen ($count)';
  }

  @override
  String get statsNoGenres => 'Keine Genres hinterlegt.';

  @override
  String get favEmpty =>
      'Noch keine Lieblingspersonen.\nÖffne die Seite eines Schauspielers (über die Besetzung eines Films) und tippe auf den Stern, um ihn hier hinzuzufügen.';

  @override
  String get friendsEmpty => 'Im Moment keine anderen Nutzer.';

  @override
  String get friendsViewLibrary => 'Bibliothek ansehen (nur Lesezugriff)';

  @override
  String friendsLoadError(String error) {
    return 'Laden fehlgeschlagen: $error';
  }

  @override
  String get friendsRetry => 'Erneut versuchen';

  @override
  String get friendsNoEmail => '(ohne E-Mail)';
}
