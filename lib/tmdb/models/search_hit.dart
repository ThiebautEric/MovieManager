import 'media_summary.dart';
import 'person_summary.dart';

/// Un résultat de recherche TMDB : soit un média (film/série), soit une
/// personnalité. Permet de mêler les deux dans une même liste de résultats.
sealed class SearchHit {
  const SearchHit();
}

class MediaHit extends SearchHit {
  const MediaHit(this.media);
  final MediaSummary media;
}

class PersonHit extends SearchHit {
  const PersonHit(this.person);
  final PersonSummary person;
}
