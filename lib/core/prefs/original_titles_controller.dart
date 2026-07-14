import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/collection_repository.dart'
    show sharedPreferencesProvider;

/// Affichage des titres originaux (au lieu des titres localisés) sur les
/// vignettes et fiches. Persisté localement, comme le thème.
class OriginalTitlesController extends Notifier<bool> {
  static const _key = 'show_original_titles';

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> toggle() async {
    state = !state;
    await ref.read(sharedPreferencesProvider).setBool(_key, state);
  }
}

final showOriginalTitlesProvider =
    NotifierProvider<OriginalTitlesController, bool>(
        OriginalTitlesController.new);

/// Choisit le titre à afficher selon la préférence « titres originaux ».
String pickTitle(String title, String? originalTitle, bool showOriginal) =>
    showOriginal && originalTitle != null && originalTitle.isNotEmpty
        ? originalTitle
        : title;
