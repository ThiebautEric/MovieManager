// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Movie Manager';

  @override
  String get themeTooltip => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageTooltip => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get titleModeLocalizedTooltip =>
      'Translated titles (app language) — tap for original titles';

  @override
  String get titleModeOriginalTooltip =>
      'Original titles — tap for English titles';

  @override
  String get titleModeEnglishTooltip =>
      'English titles — tap for translated titles';

  @override
  String get titleModeOriginalShort => 'OV';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get close => 'Close';

  @override
  String get add => 'Add';

  @override
  String get film => 'Movie';

  @override
  String get serie => 'Series';

  @override
  String get searchTitle => 'Search';

  @override
  String get historyTitle => 'History';

  @override
  String get collectionTitle => 'Collection';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get adminTitle => 'Administration';

  @override
  String get friendsTitle => 'My friends';

  @override
  String get detailsTitle => 'Details';

  @override
  String get logout => 'Sign out';

  @override
  String errorMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get searchHint => 'Movie, series or person…';

  @override
  String searchError(String message) {
    return 'Search error: $message';
  }

  @override
  String get searchStartTyping => 'Start typing to search.';

  @override
  String get searchNoResults => 'No results.';

  @override
  String get searchPersonBadge => 'Person';

  @override
  String get searchActor => 'Actor / Actress';

  @override
  String get searchPersonality => 'Personality';

  @override
  String detailsOriginalTitle(String title) {
    return 'Original title: $title';
  }

  @override
  String detailsTranslatedTitle(String title) {
    return 'Translated title: $title';
  }

  @override
  String detailsEpisodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodes',
      one: '$count episode',
    );
    return '$_temp0';
  }

  @override
  String detailsMinutesPerEpisode(int count) {
    return '$count min/episode';
  }

  @override
  String get detailsDirectorLabel => 'Directed by:';

  @override
  String get detailsCreatorLabel => 'Created by:';

  @override
  String get detailsSynopsis => 'Synopsis';

  @override
  String get detailsTrailers => 'Trailers';

  @override
  String detailsCastTitle(int count) {
    return 'Cast ($count)';
  }

  @override
  String get detailsCollapse => 'Collapse';

  @override
  String get detailsShowAll => 'Show all';

  @override
  String get detailsWholeSeries => 'Whole series';

  @override
  String detailsSeasonNumber(int number) {
    return 'Season $number';
  }

  @override
  String get detailsSeasonsTitle => 'Seasons';

  @override
  String get detailsSeasonsHint =>
      'Track this series season by season: ownership and viewings are managed per season.';

  @override
  String get detailsSeasonNotTracked => 'Not tracked';

  @override
  String detailsMediaCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copies',
      one: '$count copy',
    );
    return '$_temp0';
  }

  @override
  String detailsViewingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count viewings',
      one: '$count viewing',
    );
    return '$_temp0';
  }

  @override
  String get detailsAddViewing => 'Add a viewing';

  @override
  String get detailsRateEpisode => 'Rate an episode';

  @override
  String get detailsEditViewing => 'Edit viewing';

  @override
  String get detailsRemoveCollectionTitle => 'Remove from collection?';

  @override
  String get detailsRemoveCollectionBody =>
      'This copy is removed from your collection. Your viewing history is not affected.';

  @override
  String get detailsRemoveAction => 'Remove';

  @override
  String get detailsDeleteViewingTitle => 'Delete this viewing?';

  @override
  String get detailsDeleteViewingBody =>
      'This viewing is permanently deleted from the history. This cannot be undone.';

  @override
  String get detailsDeleteViewingTooltip => 'Delete this viewing';

  @override
  String get detailsMyCollection => 'My collection';

  @override
  String get detailsNotInCollection => 'Not in your collection.';

  @override
  String detailsAcquiredOn(String date) {
    return 'Acquired on $date';
  }

  @override
  String get detailsRemoveFromCollectionTooltip => 'Remove from collection';

  @override
  String detailsViewingHistoryTitle(int count) {
    return 'Viewing history ($count)';
  }

  @override
  String get detailsViewingButton => 'Viewing';

  @override
  String get detailsNoViewings => 'No viewings recorded.';

  @override
  String detailsWatchedOn(String date) {
    return 'Watched on $date';
  }

  @override
  String get detailsAddToCollection => 'Add to collection';

  @override
  String get detailsMediumLabel => 'Format';

  @override
  String get detailsRatingLabel => 'Rating';

  @override
  String get detailsRatingNone => 'None';

  @override
  String get detailsCommentLabel => 'Comment (optional)';

  @override
  String get detailsCommentHint =>
      'E.g. seen at the cinema, rewatched with the kids…';

  @override
  String get detailsEditButton => 'Change';

  @override
  String get personTitle => 'Actor';

  @override
  String get personAddFavoriteTooltip => 'Add to favorites';

  @override
  String get personRemoveFavoriteTooltip => 'Remove from favorites';

  @override
  String get personFilmsSection => 'Movies';

  @override
  String get personSeriesSection => 'Series';

  @override
  String get personDocumentariesSection => 'Documentaries';

  @override
  String get personOthersSection => 'Other';

  @override
  String get personInYourLibrary => 'In your library';

  @override
  String personBirth(String date) {
    return 'Born: $date';
  }

  @override
  String personDeath(String date) {
    return 'Died: $date';
  }

  @override
  String personAge(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age years old',
      one: '$age year old',
    );
    return '$_temp0';
  }

  @override
  String personAgeAtDeath(int age) {
    String _temp0 = intl.Intl.pluralLogic(
      age,
      locale: localeName,
      other: '$age years old at death',
      one: '$age year old at death',
    );
    return '$_temp0';
  }

  @override
  String get personBiography => 'Biography';

  @override
  String get personFilmography => 'Filmography';

  @override
  String get personShowMore => 'Show more';

  @override
  String get personShowLess => 'Show less';

  @override
  String get personWatchedBadge => 'Watched';

  @override
  String get historyExportTooltip => 'Export as CSV (temporary)';

  @override
  String get historyExportedSnack => 'History exported (historique.csv)';

  @override
  String get historyCsvHeader => 'Number;Title;Season;Rating;Date';

  @override
  String get historyEmpty =>
      'No viewings to display.\nAdd a movie or a season to your history (or adjust the filters).';

  @override
  String get historyDayAbbrev => 'd';

  @override
  String historyDurationLine(String total, String details) {
    return 'total: $total ($details)';
  }

  @override
  String historyDurationFilms(String duration) {
    return 'movies: $duration';
  }

  @override
  String historyDurationSeries(String duration) {
    return 'series: $duration';
  }

  @override
  String historyTotalCount(int n) {
    return '$n in total';
  }

  @override
  String historyFilmsWatched(int n, int inCollection) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n movies watched ($inCollection of them in the collection)',
      one: '$n movie watched ($inCollection of them in the collection)',
    );
    return '$_temp0';
  }

  @override
  String historySeriesWatched(int n, int inCollection) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n series watched ($inCollection of them in the collection)',
      one: '$n series watched ($inCollection of them in the collection)',
    );
    return '$_temp0';
  }

  @override
  String get collEmpty =>
      'No titles in your collection.\nOn a details page, add a format (DVD, Blu-ray or Digital), or adjust the filters.';

  @override
  String collSeasonLabel(int n) {
    return 'Season $n';
  }

  @override
  String get filterTooltip => 'Filter';

  @override
  String get filterTitle => 'Filters';

  @override
  String get filterReset => 'Reset';

  @override
  String get filterType => 'Type';

  @override
  String get filterAll => 'All';

  @override
  String get filterAllFeminine => 'All';

  @override
  String get filterFilms => 'Movies';

  @override
  String get filterSeries => 'Series';

  @override
  String get filterGenre => 'Genre';

  @override
  String filterGenreFallback(int id) {
    return 'Genre $id';
  }

  @override
  String get filterCountry => 'Country of origin';

  @override
  String get filterYear => 'Year';

  @override
  String get filterFavoriteActor => 'Favorite actor';

  @override
  String get filterRating => 'Viewing rating';

  @override
  String filterMinRating(String rating) {
    return 'Minimum viewing rating: $rating';
  }

  @override
  String filterMaxRating(String rating) {
    return 'Maximum viewing rating: $rating';
  }

  @override
  String get filterRatingNone => 'none';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authEmailInvalid => 'Invalid email';

  @override
  String get authPasswordTooShort => 'At least 6 characters';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignUp => 'Create an account';

  @override
  String get authAlreadyHaveAccount => 'I already have an account';

  @override
  String get authAccountCreated =>
      'Account created. Check your email to confirm, then sign in.';

  @override
  String get adminCreateUser => 'Create user';

  @override
  String get adminCreate => 'Create';

  @override
  String get adminEmailExists => 'This email already exists.';

  @override
  String adminHttpError(int status) {
    return 'Error $status';
  }

  @override
  String adminLoadFailed(String message) {
    return 'Loading failed: $message';
  }

  @override
  String get adminRetry => 'Retry';

  @override
  String adminUserCreated(String email) {
    return 'User $email created.';
  }

  @override
  String adminActionFailed(String message) {
    return 'Failed: $message';
  }

  @override
  String adminLastSignIn(String date) {
    return 'last sign-in $date';
  }

  @override
  String get adminNeverSignedIn => 'never signed in';

  @override
  String get adminBadge => 'admin';

  @override
  String get adminYou => '(you)';

  @override
  String adminCreatedOn(String date) {
    return 'Created on $date';
  }

  @override
  String get adminCannotDelete => 'Cannot delete (admin)';

  @override
  String adminDeleteUserTitle(String email) {
    return 'Delete $email?';
  }

  @override
  String get adminDeleteUserWarning =>
      'All of their data (collection, history, favorites) will be permanently deleted.';

  @override
  String get navStats => 'Stats';

  @override
  String navViewingAs(String email) {
    return 'Viewing: $email (read-only)';
  }

  @override
  String get navQuit => 'Exit';

  @override
  String get navCloseDetail => 'Close details';

  @override
  String get wishlistTitle => 'Watchlist';

  @override
  String get wishlistEmpty =>
      'Nothing on your watchlist.\nFrom a details page or a search result, tap the bookmark to keep a title to watch or buy.';

  @override
  String get wishlistAddTooltip => 'Add to watchlist';

  @override
  String get wishlistRemoveTooltip => 'Remove from watchlist';

  @override
  String get wishlistToHistory => 'Watched';

  @override
  String get wishlistToCollection => 'Acquired';

  @override
  String wishlistAddedOn(String date) {
    return 'Added on $date';
  }

  @override
  String get top10Title => 'Top 10';

  @override
  String get top10Hint =>
      'Ranked by your average rating, boosted by the number of viewings.';

  @override
  String get top10Empty =>
      'No rated titles yet.\nRate your viewings to build your top 10.';

  @override
  String get statsEmpty => 'No data to display.';

  @override
  String get statsWatchedUnwatched => 'Watched / unwatched';

  @override
  String get statsTopGenres => 'Top genres';

  @override
  String get statsCardTitles => 'Titles';

  @override
  String get statsCardWatched => 'Watched';

  @override
  String get statsCardViews => 'Viewings';

  @override
  String get statsCardOwned => 'Owned';

  @override
  String get statsCardAvgRating => 'Avg. rating';

  @override
  String statsLegendWatched(int count) {
    return 'Watched ($count)';
  }

  @override
  String statsLegendUnwatched(int count) {
    return 'Unwatched ($count)';
  }

  @override
  String get statsNoGenres => 'No genres recorded.';

  @override
  String get favEmpty =>
      'No favorite people yet.\nOpen an actor\'s page (from a film\'s cast) and tap the star to add them here.';

  @override
  String get friendsEmpty => 'No other users yet.';

  @override
  String get friendsViewLibrary => 'View their library (read-only)';

  @override
  String friendsLoadError(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get friendsRetry => 'Retry';

  @override
  String get friendsNoEmail => '(no email)';
}
