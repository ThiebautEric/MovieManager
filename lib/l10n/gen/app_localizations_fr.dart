// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Movie Manager';

  @override
  String get themeTooltip => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get languageTooltip => 'Langue';

  @override
  String get languageSystem => 'Système';

  @override
  String get titleModeLocalizedTooltip =>
      'Titres traduits (langue de l\'appli) — toucher pour les titres originaux';

  @override
  String get titleModeOriginalTooltip =>
      'Titres originaux — toucher pour les titres anglais';

  @override
  String get titleModeEnglishTooltip =>
      'Titres anglais — toucher pour les titres traduits';

  @override
  String get titleModeOriginalShort => 'VO';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get close => 'Fermer';

  @override
  String get add => 'Ajouter';

  @override
  String get film => 'Film';

  @override
  String get serie => 'Série';

  @override
  String get searchTitle => 'Rechercher';

  @override
  String get historyTitle => 'Historique';

  @override
  String get collectionTitle => 'Collection';

  @override
  String get statsTitle => 'Statistiques';

  @override
  String get favoritesTitle => 'Favoris';

  @override
  String get adminTitle => 'Administration';

  @override
  String get friendsTitle => 'Mes amis';

  @override
  String get detailsTitle => 'Détails';

  @override
  String get logout => 'Se déconnecter';

  @override
  String errorMessage(String message) {
    return 'Erreur : $message';
  }

  @override
  String get searchHint => 'Film, série ou personnalité…';

  @override
  String searchError(String message) {
    return 'Erreur de recherche : $message';
  }

  @override
  String get searchStartTyping => 'Commencez à taper pour rechercher.';

  @override
  String get searchNoResults => 'Aucun résultat.';

  @override
  String get searchPersonBadge => 'Personne';

  @override
  String get searchActor => 'Acteur / Actrice';

  @override
  String get searchPersonality => 'Personnalité';

  @override
  String detailsOriginalTitle(String title) {
    return 'Titre original : $title';
  }

  @override
  String detailsTranslatedTitle(String title) {
    return 'Titre traduit : $title';
  }

  @override
  String detailsEpisodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count épisodes',
      one: '$count épisode',
    );
    return '$_temp0';
  }

  @override
  String detailsMinutesPerEpisode(int count) {
    return '$count min/épisode';
  }

  @override
  String get detailsDirectorLabel => 'Réalisation :';

  @override
  String get detailsCreatorLabel => 'Création :';

  @override
  String get detailsSynopsis => 'Synopsis';

  @override
  String get detailsTrailers => 'Bandes-annonces';

  @override
  String detailsCastTitle(int count) {
    return 'Casting ($count)';
  }

  @override
  String get detailsCollapse => 'Réduire';

  @override
  String get detailsShowAll => 'Voir tout';

  @override
  String get detailsWholeSeries => 'Série entière';

  @override
  String detailsSeasonNumber(int number) {
    return 'Saison $number';
  }

  @override
  String get detailsSeasonsTitle => 'Saisons';

  @override
  String get detailsSeasonsHint =>
      'Suis cette série saison par saison : possession et visionnages se gèrent pour chaque saison.';

  @override
  String get detailsSeasonNotTracked => 'Non suivie';

  @override
  String detailsMediaCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count supports',
      one: '$count support',
    );
    return '$_temp0';
  }

  @override
  String detailsViewingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count visionnages',
      one: '$count visionnage',
    );
    return '$_temp0';
  }

  @override
  String get detailsAddViewing => 'Ajouter un visionnage';

  @override
  String get detailsRateEpisode => 'Noter un épisode';

  @override
  String get detailsEditViewing => 'Modifier le visionnage';

  @override
  String get detailsRemoveCollectionTitle => 'Retirer de la collection ?';

  @override
  String get detailsRemoveCollectionBody =>
      'Cette possession est retirée de ta collection. Ton historique de visionnage n\'est pas affecté.';

  @override
  String get detailsRemoveAction => 'Retirer';

  @override
  String get detailsDeleteViewingTitle => 'Supprimer ce visionnage ?';

  @override
  String get detailsDeleteViewingBody =>
      'Cette séance est définitivement supprimée de l\'historique. Action irréversible.';

  @override
  String get detailsDeleteViewingTooltip => 'Supprimer ce visionnage';

  @override
  String get detailsMyCollection => 'Ma collection';

  @override
  String get detailsNotInCollection => 'Pas dans ta collection.';

  @override
  String detailsAcquiredOn(String date) {
    return 'Acquis le $date';
  }

  @override
  String get detailsRemoveFromCollectionTooltip => 'Retirer de la collection';

  @override
  String detailsViewingHistoryTitle(int count) {
    return 'Historique de visionnage ($count)';
  }

  @override
  String get detailsViewingButton => 'Visionnage';

  @override
  String get detailsNoViewings => 'Aucun visionnage enregistré.';

  @override
  String detailsWatchedOn(String date) {
    return 'Vu le $date';
  }

  @override
  String get detailsAddToCollection => 'Ajouter à la collection';

  @override
  String get detailsMediumLabel => 'Support';

  @override
  String get detailsRatingLabel => 'Note';

  @override
  String get detailsRatingNone => 'Aucune';

  @override
  String get detailsCommentLabel => 'Commentaire (facultatif)';

  @override
  String get detailsCommentHint => 'Ex. vu au cinéma, revu avec les enfants…';

  @override
  String get detailsEditButton => 'Modifier';

  @override
  String get personTitle => 'Acteur';

  @override
  String get personAddFavoriteTooltip => 'Ajouter aux favoris';

  @override
  String get personRemoveFavoriteTooltip => 'Retirer des favoris';

  @override
  String get personFilmsSection => 'Films';

  @override
  String get personSeriesSection => 'Séries';

  @override
  String get personDocumentariesSection => 'Reportages';

  @override
  String get personOthersSection => 'Autres';

  @override
  String get personInYourLibrary => 'Dans ta bibliothèque';

  @override
  String personBirth(String date) {
    return 'Naissance : $date';
  }

  @override
  String personDeath(String date) {
    return 'Décès : $date';
  }

  @override
  String personAge(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age ans',
      one: '$age an',
    );
    return '$_temp0';
  }

  @override
  String personAgeAtDeath(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age ans à son décès',
      one: '$age an à son décès',
    );
    return '$_temp0';
  }

  @override
  String get personBiography => 'Biographie';

  @override
  String get personFilmography => 'Filmographie';

  @override
  String get personShowMore => 'Voir plus';

  @override
  String get personShowLess => 'Voir moins';

  @override
  String get personWatchedBadge => 'Vu';

  @override
  String get historyExportTooltip => 'Exporter en CSV (provisoire)';

  @override
  String get historyExportedSnack => 'Historique exporté (historique.csv)';

  @override
  String get historyCsvHeader => 'Numero;Titre;Saison;Note;Date';

  @override
  String get historyEmpty =>
      'Aucun visionnage à afficher.\nAjoute un film ou une saison à ton historique (ou ajuste les filtres).';

  @override
  String get historyDayAbbrev => 'j';

  @override
  String historyDurationLine(String total, String details) {
    return 'total : $total ($details)';
  }

  @override
  String historyDurationFilms(String duration) {
    return 'films : $duration';
  }

  @override
  String historyDurationSeries(String duration) {
    return 'séries : $duration';
  }

  @override
  String historyTotalCount(int n) {
    return '$n au total';
  }

  @override
  String historyFilmsWatched(int n, int inCollection) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n films vus (dont $inCollection dans la collection)',
      one: '$n film vu (dont $inCollection dans la collection)',
    );
    return '$_temp0';
  }

  @override
  String historySeriesWatched(int n, int inCollection) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n séries vues (dont $inCollection dans la collection)',
      one: '$n série vue (dont $inCollection dans la collection)',
    );
    return '$_temp0';
  }

  @override
  String get collEmpty =>
      'Aucun titre dans ta collection.\nSur une fiche, ajoute un support (DVD, Blu-ray ou Digital), ou ajuste les filtres.';

  @override
  String collSeasonLabel(int n) {
    return 'Saison $n';
  }

  @override
  String get filterTooltip => 'Filtrer';

  @override
  String get filterTitle => 'Filtres';

  @override
  String get filterReset => 'Réinitialiser';

  @override
  String get filterType => 'Type';

  @override
  String get filterAll => 'Tous';

  @override
  String get filterAllFeminine => 'Toutes';

  @override
  String get filterFilms => 'Films';

  @override
  String get filterSeries => 'Séries';

  @override
  String get filterGenre => 'Genre';

  @override
  String filterGenreFallback(int id) {
    return 'Genre $id';
  }

  @override
  String get filterCountry => 'Pays d\'origine';

  @override
  String get filterYear => 'Année';

  @override
  String get filterFavoriteActor => 'Acteur favori';

  @override
  String filterMinRating(String rating) {
    return 'Note minimale du visionnage : $rating';
  }

  @override
  String get filterRatingNone => 'aucune';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Mot de passe';

  @override
  String get authEmailInvalid => 'E-mail invalide';

  @override
  String get authPasswordTooShort => '6 caractères minimum';

  @override
  String get authSignIn => 'Se connecter';

  @override
  String get authSignUp => 'Créer un compte';

  @override
  String get authAlreadyHaveAccount => 'J\'ai déjà un compte';

  @override
  String get authAccountCreated =>
      'Compte créé. Vérifiez votre e-mail pour confirmer, puis connectez-vous.';

  @override
  String get adminCreateUser => 'Créer un utilisateur';

  @override
  String get adminCreate => 'Créer';

  @override
  String get adminEmailExists => 'Cet e-mail existe déjà.';

  @override
  String adminHttpError(int status) {
    return 'Erreur $status';
  }

  @override
  String adminLoadFailed(String message) {
    return 'Chargement impossible : $message';
  }

  @override
  String get adminRetry => 'Réessayer';

  @override
  String adminUserCreated(String email) {
    return 'Utilisateur $email créé.';
  }

  @override
  String adminActionFailed(String message) {
    return 'Échec : $message';
  }

  @override
  String adminLastSignIn(String date) {
    return 'dernière connexion $date';
  }

  @override
  String get adminNeverSignedIn => 'jamais connecté';

  @override
  String get adminBadge => 'admin';

  @override
  String get adminYou => '(vous)';

  @override
  String adminCreatedOn(String date) {
    return 'Créé le $date';
  }

  @override
  String get adminCannotDelete => 'Suppression impossible (admin)';

  @override
  String adminDeleteUserTitle(String email) {
    return 'Supprimer $email ?';
  }

  @override
  String get adminDeleteUserWarning =>
      'Toutes ses données (collection, historique, favoris) seront définitivement effacées.';

  @override
  String get navStats => 'Stats';

  @override
  String navViewingAs(String email) {
    return 'Consultation : $email (lecture seule)';
  }

  @override
  String get navQuit => 'Quitter';

  @override
  String get navCloseDetail => 'Fermer la fiche';

  @override
  String get wishlistTitle => 'Pense-bête';

  @override
  String get wishlistEmpty =>
      'Rien dans le pense-bête.\nDepuis une fiche ou un résultat de recherche, touche le marque-page pour garder un titre à voir ou à acheter.';

  @override
  String get wishlistAddTooltip => 'Ajouter au pense-bête';

  @override
  String get wishlistRemoveTooltip => 'Retirer du pense-bête';

  @override
  String get wishlistToHistory => 'Vu';

  @override
  String get wishlistToCollection => 'Acquis';

  @override
  String wishlistAddedOn(String date) {
    return 'Ajouté le $date';
  }

  @override
  String get top10Title => 'Top 10';

  @override
  String get top10Hint =>
      'Classement selon ta note moyenne, bonifiée par le nombre de visionnages.';

  @override
  String get top10Empty =>
      'Aucun titre noté pour l\'instant.\nNote tes visionnages pour construire ton top 10.';

  @override
  String get statsEmpty => 'Aucune donnée à afficher.';

  @override
  String get statsWatchedUnwatched => 'Vus / non vus';

  @override
  String get statsTopGenres => 'Top genres';

  @override
  String get statsCardTitles => 'Titres';

  @override
  String get statsCardWatched => 'Vus';

  @override
  String get statsCardViews => 'Visionnages';

  @override
  String get statsCardOwned => 'Possédés';

  @override
  String get statsCardAvgRating => 'Note moy.';

  @override
  String statsLegendWatched(int count) {
    return 'Vus ($count)';
  }

  @override
  String statsLegendUnwatched(int count) {
    return 'Non vus ($count)';
  }

  @override
  String get statsNoGenres => 'Pas de genres renseignés.';

  @override
  String get favEmpty =>
      'Aucune personne favorite.\nOuvrez la fiche d\'un acteur (depuis le casting d\'un film) et touchez l\'étoile pour l\'ajouter ici.';

  @override
  String get friendsEmpty => 'Aucun autre utilisateur pour le moment.';

  @override
  String get friendsViewLibrary => 'Voir sa bibliothèque (lecture seule)';

  @override
  String friendsLoadError(String error) {
    return 'Chargement impossible : $error';
  }

  @override
  String get friendsRetry => 'Réessayer';

  @override
  String get friendsNoEmail => '(sans e-mail)';
}
