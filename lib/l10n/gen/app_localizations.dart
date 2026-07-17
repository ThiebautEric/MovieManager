import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Movie Manager'**
  String get appTitle;

  /// No description provided for @themeTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Thème'**
  String get themeTooltip;

  /// No description provided for @themeSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In fr, this message translates to:
  /// **'Clair'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In fr, this message translates to:
  /// **'Sombre'**
  String get themeDark;

  /// No description provided for @languageTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get languageTooltip;

  /// No description provided for @languageSystem.
  ///
  /// In fr, this message translates to:
  /// **'Système'**
  String get languageSystem;

  /// No description provided for @titleModeLocalizedTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Titres traduits (langue de l\'appli) — toucher pour les titres originaux'**
  String get titleModeLocalizedTooltip;

  /// No description provided for @titleModeOriginalTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Titres originaux — toucher pour les titres anglais'**
  String get titleModeOriginalTooltip;

  /// No description provided for @titleModeEnglishTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Titres anglais — toucher pour les titres traduits'**
  String get titleModeEnglishTooltip;

  /// Abréviation « version originale » affichée sur le bouton de mode des titres
  ///
  /// In fr, this message translates to:
  /// **'VO'**
  String get titleModeOriginalShort;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @add.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter'**
  String get add;

  /// No description provided for @film.
  ///
  /// In fr, this message translates to:
  /// **'Film'**
  String get film;

  /// No description provided for @serie.
  ///
  /// In fr, this message translates to:
  /// **'Série'**
  String get serie;

  /// No description provided for @searchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get searchTitle;

  /// No description provided for @historyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get historyTitle;

  /// No description provided for @collectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Collection'**
  String get collectionTitle;

  /// No description provided for @statsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Statistiques'**
  String get statsTitle;

  /// No description provided for @favoritesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get favoritesTitle;

  /// No description provided for @adminTitle.
  ///
  /// In fr, this message translates to:
  /// **'Administration'**
  String get adminTitle;

  /// No description provided for @friendsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes amis'**
  String get friendsTitle;

  /// No description provided for @detailsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Détails'**
  String get detailsTitle;

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get logout;

  /// No description provided for @errorMessage.
  ///
  /// In fr, this message translates to:
  /// **'Erreur : {message}'**
  String errorMessage(String message);

  /// No description provided for @searchHint.
  ///
  /// In fr, this message translates to:
  /// **'Film, série ou personnalité…'**
  String get searchHint;

  /// No description provided for @searchError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de recherche : {message}'**
  String searchError(String message);

  /// No description provided for @searchStartTyping.
  ///
  /// In fr, this message translates to:
  /// **'Commencez à taper pour rechercher.'**
  String get searchStartTyping;

  /// No description provided for @searchNoResults.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat.'**
  String get searchNoResults;

  /// No description provided for @searchPersonBadge.
  ///
  /// In fr, this message translates to:
  /// **'Personne'**
  String get searchPersonBadge;

  /// No description provided for @searchActor.
  ///
  /// In fr, this message translates to:
  /// **'Acteur / Actrice'**
  String get searchActor;

  /// No description provided for @searchPersonality.
  ///
  /// In fr, this message translates to:
  /// **'Personnalité'**
  String get searchPersonality;

  /// No description provided for @detailsOriginalTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre original : {title}'**
  String detailsOriginalTitle(String title);

  /// No description provided for @detailsTranslatedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Titre traduit : {title}'**
  String detailsTranslatedTitle(String title);

  /// No description provided for @detailsEpisodeCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} épisode} other{{count} épisodes}}'**
  String detailsEpisodeCount(int count);

  /// No description provided for @detailsMinutesPerEpisode.
  ///
  /// In fr, this message translates to:
  /// **'{count} min/épisode'**
  String detailsMinutesPerEpisode(int count);

  /// No description provided for @detailsDirectorLabel.
  ///
  /// In fr, this message translates to:
  /// **'Réalisation :'**
  String get detailsDirectorLabel;

  /// No description provided for @detailsCreatorLabel.
  ///
  /// In fr, this message translates to:
  /// **'Création :'**
  String get detailsCreatorLabel;

  /// No description provided for @detailsSynopsis.
  ///
  /// In fr, this message translates to:
  /// **'Synopsis'**
  String get detailsSynopsis;

  /// No description provided for @detailsTrailers.
  ///
  /// In fr, this message translates to:
  /// **'Bandes-annonces'**
  String get detailsTrailers;

  /// No description provided for @detailsCastTitle.
  ///
  /// In fr, this message translates to:
  /// **'Casting ({count})'**
  String detailsCastTitle(int count);

  /// No description provided for @detailsCollapse.
  ///
  /// In fr, this message translates to:
  /// **'Réduire'**
  String get detailsCollapse;

  /// No description provided for @detailsShowAll.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get detailsShowAll;

  /// No description provided for @detailsWholeSeries.
  ///
  /// In fr, this message translates to:
  /// **'Série entière'**
  String get detailsWholeSeries;

  /// No description provided for @detailsSeasonNumber.
  ///
  /// In fr, this message translates to:
  /// **'Saison {number}'**
  String detailsSeasonNumber(int number);

  /// No description provided for @detailsSeasonsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Saisons'**
  String get detailsSeasonsTitle;

  /// No description provided for @detailsSeasonsHint.
  ///
  /// In fr, this message translates to:
  /// **'Suis cette série saison par saison : possession et visionnages se gèrent pour chaque saison.'**
  String get detailsSeasonsHint;

  /// No description provided for @detailsSeasonNotTracked.
  ///
  /// In fr, this message translates to:
  /// **'Non suivie'**
  String get detailsSeasonNotTracked;

  /// No description provided for @detailsMediaCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} support} other{{count} supports}}'**
  String detailsMediaCount(int count);

  /// No description provided for @detailsViewingCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, one{{count} visionnage} other{{count} visionnages}}'**
  String detailsViewingCount(int count);

  /// No description provided for @detailsAddViewing.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un visionnage'**
  String get detailsAddViewing;

  /// No description provided for @detailsRateEpisode.
  ///
  /// In fr, this message translates to:
  /// **'Noter un épisode'**
  String get detailsRateEpisode;

  /// No description provided for @detailsEditViewing.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le visionnage'**
  String get detailsEditViewing;

  /// No description provided for @detailsRemoveCollectionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de la collection ?'**
  String get detailsRemoveCollectionTitle;

  /// No description provided for @detailsRemoveCollectionBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette possession est retirée de ta collection. Ton historique de visionnage n\'est pas affecté.'**
  String get detailsRemoveCollectionBody;

  /// No description provided for @detailsRemoveAction.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get detailsRemoveAction;

  /// No description provided for @detailsDeleteViewingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce visionnage ?'**
  String get detailsDeleteViewingTitle;

  /// No description provided for @detailsDeleteViewingBody.
  ///
  /// In fr, this message translates to:
  /// **'Cette séance est définitivement supprimée de l\'historique. Action irréversible.'**
  String get detailsDeleteViewingBody;

  /// No description provided for @detailsDeleteViewingTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ce visionnage'**
  String get detailsDeleteViewingTooltip;

  /// No description provided for @detailsMyCollection.
  ///
  /// In fr, this message translates to:
  /// **'Ma collection'**
  String get detailsMyCollection;

  /// No description provided for @detailsNotInCollection.
  ///
  /// In fr, this message translates to:
  /// **'Pas dans ta collection.'**
  String get detailsNotInCollection;

  /// No description provided for @detailsAcquiredOn.
  ///
  /// In fr, this message translates to:
  /// **'Acquis le {date}'**
  String detailsAcquiredOn(String date);

  /// No description provided for @detailsRemoveFromCollectionTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Retirer de la collection'**
  String get detailsRemoveFromCollectionTooltip;

  /// No description provided for @detailsViewingHistoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Historique de visionnage ({count})'**
  String detailsViewingHistoryTitle(int count);

  /// No description provided for @detailsViewingButton.
  ///
  /// In fr, this message translates to:
  /// **'Visionnage'**
  String get detailsViewingButton;

  /// No description provided for @detailsNoViewings.
  ///
  /// In fr, this message translates to:
  /// **'Aucun visionnage enregistré.'**
  String get detailsNoViewings;

  /// No description provided for @detailsWatchedOn.
  ///
  /// In fr, this message translates to:
  /// **'Vu le {date}'**
  String detailsWatchedOn(String date);

  /// No description provided for @detailsAddToCollection.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter à la collection'**
  String get detailsAddToCollection;

  /// No description provided for @detailsMediumLabel.
  ///
  /// In fr, this message translates to:
  /// **'Support'**
  String get detailsMediumLabel;

  /// No description provided for @detailsRatingLabel.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get detailsRatingLabel;

  /// No description provided for @detailsRatingNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune'**
  String get detailsRatingNone;

  /// No description provided for @detailsCommentLabel.
  ///
  /// In fr, this message translates to:
  /// **'Commentaire (facultatif)'**
  String get detailsCommentLabel;

  /// No description provided for @detailsCommentHint.
  ///
  /// In fr, this message translates to:
  /// **'Ex. vu au cinéma, revu avec les enfants…'**
  String get detailsCommentHint;

  /// No description provided for @detailsEditButton.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get detailsEditButton;

  /// No description provided for @personTitle.
  ///
  /// In fr, this message translates to:
  /// **'Acteur'**
  String get personTitle;

  /// No description provided for @personAddFavoriteTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter aux favoris'**
  String get personAddFavoriteTooltip;

  /// No description provided for @personRemoveFavoriteTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Retirer des favoris'**
  String get personRemoveFavoriteTooltip;

  /// No description provided for @personFilmsSection.
  ///
  /// In fr, this message translates to:
  /// **'Films'**
  String get personFilmsSection;

  /// No description provided for @personSeriesSection.
  ///
  /// In fr, this message translates to:
  /// **'Séries'**
  String get personSeriesSection;

  /// No description provided for @personDocumentariesSection.
  ///
  /// In fr, this message translates to:
  /// **'Reportages'**
  String get personDocumentariesSection;

  /// No description provided for @personOthersSection.
  ///
  /// In fr, this message translates to:
  /// **'Autres'**
  String get personOthersSection;

  /// No description provided for @personInYourLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Dans ta bibliothèque'**
  String get personInYourLibrary;

  /// No description provided for @personBirth.
  ///
  /// In fr, this message translates to:
  /// **'Naissance : {date}'**
  String personBirth(String date);

  /// No description provided for @personDeath.
  ///
  /// In fr, this message translates to:
  /// **'Décès : {date}'**
  String personDeath(String date);

  /// No description provided for @personAge.
  ///
  /// In fr, this message translates to:
  /// **'{age, plural, one{{age} an} other{{age} ans}}'**
  String personAge(int age);

  /// No description provided for @personAgeAtDeath.
  ///
  /// In fr, this message translates to:
  /// **'{age, plural, one{{age} an à son décès} other{{age} ans à son décès}}'**
  String personAgeAtDeath(int age);

  /// No description provided for @personBiography.
  ///
  /// In fr, this message translates to:
  /// **'Biographie'**
  String get personBiography;

  /// No description provided for @personFilmography.
  ///
  /// In fr, this message translates to:
  /// **'Filmographie'**
  String get personFilmography;

  /// No description provided for @personShowMore.
  ///
  /// In fr, this message translates to:
  /// **'Voir plus'**
  String get personShowMore;

  /// No description provided for @personShowLess.
  ///
  /// In fr, this message translates to:
  /// **'Voir moins'**
  String get personShowLess;

  /// No description provided for @personWatchedBadge.
  ///
  /// In fr, this message translates to:
  /// **'Vu'**
  String get personWatchedBadge;

  /// No description provided for @historyExportTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Exporter en CSV (provisoire)'**
  String get historyExportTooltip;

  /// No description provided for @historyExportedSnack.
  ///
  /// In fr, this message translates to:
  /// **'Historique exporté (historique.csv)'**
  String get historyExportedSnack;

  /// En-tête des colonnes du CSV exporté (séparateur ;)
  ///
  /// In fr, this message translates to:
  /// **'Numero;Titre;Saison;Note;Date'**
  String get historyCsvHeader;

  /// No description provided for @historyEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun visionnage à afficher.\nAjoute un film ou une saison à ton historique (ou ajuste les filtres).'**
  String get historyEmpty;

  /// Abréviation de « jour » dans les durées cumulées, ex. « 3j 7h »
  ///
  /// In fr, this message translates to:
  /// **'j'**
  String get historyDayAbbrev;

  /// No description provided for @historyDurationLine.
  ///
  /// In fr, this message translates to:
  /// **'total : {total} ({details})'**
  String historyDurationLine(String total, String details);

  /// No description provided for @historyDurationFilms.
  ///
  /// In fr, this message translates to:
  /// **'films : {duration}'**
  String historyDurationFilms(String duration);

  /// No description provided for @historyDurationSeries.
  ///
  /// In fr, this message translates to:
  /// **'séries : {duration}'**
  String historyDurationSeries(String duration);

  /// No description provided for @historyTotalCount.
  ///
  /// In fr, this message translates to:
  /// **'{n} au total'**
  String historyTotalCount(int n);

  /// No description provided for @historyFilmsWatched.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, one{{n} film vu (dont {inCollection} dans la collection)} other{{n} films vus (dont {inCollection} dans la collection)}}'**
  String historyFilmsWatched(int n, int inCollection);

  /// No description provided for @historySeriesWatched.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, one{{n} série vue (dont {inCollection} dans la collection)} other{{n} séries vues (dont {inCollection} dans la collection)}}'**
  String historySeriesWatched(int n, int inCollection);

  /// No description provided for @collEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun titre dans ta collection.\nSur une fiche, ajoute un support (DVD, Blu-ray ou Digital), ou ajuste les filtres.'**
  String get collEmpty;

  /// No description provided for @collSeasonLabel.
  ///
  /// In fr, this message translates to:
  /// **'Saison {n}'**
  String collSeasonLabel(int n);

  /// No description provided for @filterTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer'**
  String get filterTooltip;

  /// No description provided for @filterTitle.
  ///
  /// In fr, this message translates to:
  /// **'Filtres'**
  String get filterTitle;

  /// No description provided for @filterReset.
  ///
  /// In fr, this message translates to:
  /// **'Réinitialiser'**
  String get filterReset;

  /// No description provided for @filterType.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get filterType;

  /// No description provided for @filterAll.
  ///
  /// In fr, this message translates to:
  /// **'Tous'**
  String get filterAll;

  /// Variante féminine de « Tous » (ex. toutes les années)
  ///
  /// In fr, this message translates to:
  /// **'Toutes'**
  String get filterAllFeminine;

  /// No description provided for @filterFilms.
  ///
  /// In fr, this message translates to:
  /// **'Films'**
  String get filterFilms;

  /// No description provided for @filterSeries.
  ///
  /// In fr, this message translates to:
  /// **'Séries'**
  String get filterSeries;

  /// No description provided for @filterGenre.
  ///
  /// In fr, this message translates to:
  /// **'Genre'**
  String get filterGenre;

  /// Libellé de repli quand le nom du genre TMDB est inconnu
  ///
  /// In fr, this message translates to:
  /// **'Genre {id}'**
  String filterGenreFallback(int id);

  /// No description provided for @filterCountry.
  ///
  /// In fr, this message translates to:
  /// **'Pays d\'origine'**
  String get filterCountry;

  /// No description provided for @filterYear.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get filterYear;

  /// No description provided for @filterFavoriteActor.
  ///
  /// In fr, this message translates to:
  /// **'Acteur favori'**
  String get filterFavoriteActor;

  /// No description provided for @filterMinRating.
  ///
  /// In fr, this message translates to:
  /// **'Note minimale du visionnage : {rating}'**
  String filterMinRating(String rating);

  /// No description provided for @filterRatingNone.
  ///
  /// In fr, this message translates to:
  /// **'aucune'**
  String get filterRatingNone;

  /// No description provided for @authEmailLabel.
  ///
  /// In fr, this message translates to:
  /// **'E-mail'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get authPasswordLabel;

  /// No description provided for @authEmailInvalid.
  ///
  /// In fr, this message translates to:
  /// **'E-mail invalide'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In fr, this message translates to:
  /// **'6 caractères minimum'**
  String get authPasswordTooShort;

  /// No description provided for @authSignIn.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get authSignIn;

  /// No description provided for @authSignUp.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get authSignUp;

  /// No description provided for @authAlreadyHaveAccount.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai déjà un compte'**
  String get authAlreadyHaveAccount;

  /// No description provided for @authAccountCreated.
  ///
  /// In fr, this message translates to:
  /// **'Compte créé. Vérifiez votre e-mail pour confirmer, puis connectez-vous.'**
  String get authAccountCreated;

  /// No description provided for @adminCreateUser.
  ///
  /// In fr, this message translates to:
  /// **'Créer un utilisateur'**
  String get adminCreateUser;

  /// No description provided for @adminCreate.
  ///
  /// In fr, this message translates to:
  /// **'Créer'**
  String get adminCreate;

  /// No description provided for @adminEmailExists.
  ///
  /// In fr, this message translates to:
  /// **'Cet e-mail existe déjà.'**
  String get adminEmailExists;

  /// No description provided for @adminHttpError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur {status}'**
  String adminHttpError(int status);

  /// No description provided for @adminLoadFailed.
  ///
  /// In fr, this message translates to:
  /// **'Chargement impossible : {message}'**
  String adminLoadFailed(String message);

  /// No description provided for @adminRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get adminRetry;

  /// No description provided for @adminUserCreated.
  ///
  /// In fr, this message translates to:
  /// **'Utilisateur {email} créé.'**
  String adminUserCreated(String email);

  /// No description provided for @adminActionFailed.
  ///
  /// In fr, this message translates to:
  /// **'Échec : {message}'**
  String adminActionFailed(String message);

  /// No description provided for @adminLastSignIn.
  ///
  /// In fr, this message translates to:
  /// **'dernière connexion {date}'**
  String adminLastSignIn(String date);

  /// No description provided for @adminNeverSignedIn.
  ///
  /// In fr, this message translates to:
  /// **'jamais connecté'**
  String get adminNeverSignedIn;

  /// No description provided for @adminBadge.
  ///
  /// In fr, this message translates to:
  /// **'admin'**
  String get adminBadge;

  /// No description provided for @adminYou.
  ///
  /// In fr, this message translates to:
  /// **'(vous)'**
  String get adminYou;

  /// No description provided for @adminCreatedOn.
  ///
  /// In fr, this message translates to:
  /// **'Créé le {date}'**
  String adminCreatedOn(String date);

  /// No description provided for @adminCannotDelete.
  ///
  /// In fr, this message translates to:
  /// **'Suppression impossible (admin)'**
  String get adminCannotDelete;

  /// No description provided for @adminDeleteUserTitle.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer {email} ?'**
  String adminDeleteUserTitle(String email);

  /// No description provided for @adminDeleteUserWarning.
  ///
  /// In fr, this message translates to:
  /// **'Toutes ses données (collection, historique, favoris) seront définitivement effacées.'**
  String get adminDeleteUserWarning;

  /// No description provided for @navStats.
  ///
  /// In fr, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// No description provided for @navViewingAs.
  ///
  /// In fr, this message translates to:
  /// **'Consultation : {email} (lecture seule)'**
  String navViewingAs(String email);

  /// No description provided for @navQuit.
  ///
  /// In fr, this message translates to:
  /// **'Quitter'**
  String get navQuit;

  /// No description provided for @navCloseDetail.
  ///
  /// In fr, this message translates to:
  /// **'Fermer la fiche'**
  String get navCloseDetail;

  /// No description provided for @wishlistTitle.
  ///
  /// In fr, this message translates to:
  /// **'Pense-bête'**
  String get wishlistTitle;

  /// No description provided for @wishlistEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Rien dans le pense-bête.\nDepuis une fiche ou un résultat de recherche, touche le marque-page pour garder un titre à voir ou à acheter.'**
  String get wishlistEmpty;

  /// No description provided for @wishlistAddTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter au pense-bête'**
  String get wishlistAddTooltip;

  /// No description provided for @wishlistRemoveTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Retirer du pense-bête'**
  String get wishlistRemoveTooltip;

  /// No description provided for @wishlistToHistory.
  ///
  /// In fr, this message translates to:
  /// **'Vu'**
  String get wishlistToHistory;

  /// No description provided for @wishlistToCollection.
  ///
  /// In fr, this message translates to:
  /// **'Acquis'**
  String get wishlistToCollection;

  /// No description provided for @wishlistAddedOn.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté le {date}'**
  String wishlistAddedOn(String date);

  /// No description provided for @top10Title.
  ///
  /// In fr, this message translates to:
  /// **'Top 10'**
  String get top10Title;

  /// No description provided for @top10Hint.
  ///
  /// In fr, this message translates to:
  /// **'Classement selon ta note moyenne, bonifiée par le nombre de visionnages.'**
  String get top10Hint;

  /// No description provided for @top10Empty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun titre noté pour l\'instant.\nNote tes visionnages pour construire ton top 10.'**
  String get top10Empty;

  /// No description provided for @statsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune donnée à afficher.'**
  String get statsEmpty;

  /// No description provided for @statsWatchedUnwatched.
  ///
  /// In fr, this message translates to:
  /// **'Vus / non vus'**
  String get statsWatchedUnwatched;

  /// No description provided for @statsTopGenres.
  ///
  /// In fr, this message translates to:
  /// **'Top genres'**
  String get statsTopGenres;

  /// No description provided for @statsCardTitles.
  ///
  /// In fr, this message translates to:
  /// **'Titres'**
  String get statsCardTitles;

  /// No description provided for @statsCardWatched.
  ///
  /// In fr, this message translates to:
  /// **'Vus'**
  String get statsCardWatched;

  /// No description provided for @statsCardViews.
  ///
  /// In fr, this message translates to:
  /// **'Visionnages'**
  String get statsCardViews;

  /// No description provided for @statsCardOwned.
  ///
  /// In fr, this message translates to:
  /// **'Possédés'**
  String get statsCardOwned;

  /// No description provided for @statsCardAvgRating.
  ///
  /// In fr, this message translates to:
  /// **'Note moy.'**
  String get statsCardAvgRating;

  /// No description provided for @statsLegendWatched.
  ///
  /// In fr, this message translates to:
  /// **'Vus ({count})'**
  String statsLegendWatched(int count);

  /// No description provided for @statsLegendUnwatched.
  ///
  /// In fr, this message translates to:
  /// **'Non vus ({count})'**
  String statsLegendUnwatched(int count);

  /// No description provided for @statsNoGenres.
  ///
  /// In fr, this message translates to:
  /// **'Pas de genres renseignés.'**
  String get statsNoGenres;

  /// No description provided for @favEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune personne favorite.\nOuvrez la fiche d\'un acteur (depuis le casting d\'un film) et touchez l\'étoile pour l\'ajouter ici.'**
  String get favEmpty;

  /// No description provided for @friendsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun autre utilisateur pour le moment.'**
  String get friendsEmpty;

  /// No description provided for @friendsViewLibrary.
  ///
  /// In fr, this message translates to:
  /// **'Voir sa bibliothèque (lecture seule)'**
  String get friendsViewLibrary;

  /// No description provided for @friendsLoadError.
  ///
  /// In fr, this message translates to:
  /// **'Chargement impossible : {error}'**
  String friendsLoadError(String error);

  /// No description provided for @friendsRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get friendsRetry;

  /// No description provided for @friendsNoEmail.
  ///
  /// In fr, this message translates to:
  /// **'(sans e-mail)'**
  String get friendsNoEmail;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
