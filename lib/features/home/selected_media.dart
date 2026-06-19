import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

/// Une entrée de la pile de détail (grand écran) : un film/série ou une personne.
sealed class DetailEntry {
  const DetailEntry();
}

class MediaEntry extends DetailEntry {
  const MediaEntry({
    required this.type,
    required this.id,
    required this.title,
    this.posterPath,
  });
  final String type;
  final int id;
  final String title;
  final String? posterPath;
}

class PersonEntry extends DetailEntry {
  const PersonEntry({
    required this.id,
    required this.name,
    this.profilePath,
  });
  final int id;
  final String name;
  final String? profilePath;
}

/// Pile de fiches ouvertes dans la zone de droite (maître-détail, grand écran).
/// Vide = on affiche l'onglet courant. Le dernier élément est la fiche visible.
final detailStackProvider = StateProvider<List<DetailEntry>>((ref) => const []);

/// Seuil au-delà duquel on utilise la barre latérale + maître-détail.
const double kWideBreakpoint = 720;

bool _isWide(BuildContext context) =>
    MediaQuery.of(context).size.width >= kWideBreakpoint;

/// Ouvre une fiche film : empile (grand écran) ou pousse une route (mobile).
void openMedia(
  BuildContext context,
  WidgetRef ref, {
  required String type,
  required int id,
  required String title,
  String? posterPath,
}) {
  if (_isWide(context)) {
    final stack = ref.read(detailStackProvider);
    ref.read(detailStackProvider.notifier).state = [
      ...stack,
      MediaEntry(type: type, id: id, title: title, posterPath: posterPath),
    ];
  } else {
    context.push('/media/$type/$id');
  }
}

/// Ouvre une fiche personne : empile (grand écran) ou pousse une route (mobile).
void openPerson(
  BuildContext context,
  WidgetRef ref, {
  required int id,
  required String name,
  String? profilePath,
}) {
  if (_isWide(context)) {
    final stack = ref.read(detailStackProvider);
    ref.read(detailStackProvider.notifier).state = [
      ...stack,
      PersonEntry(id: id, name: name, profilePath: profilePath),
    ];
  } else {
    context.push('/person/$id');
  }
}

/// Dépile une fiche (retour à la précédente) dans la pile de droite.
void popDetail(WidgetRef ref) {
  final stack = ref.read(detailStackProvider);
  if (stack.isNotEmpty) {
    ref.read(detailStackProvider.notifier).state =
        stack.sublist(0, stack.length - 1);
  }
}

/// Ferme toutes les fiches (revient à l'onglet).
void closeDetail(WidgetRef ref) {
  ref.read(detailStackProvider.notifier).state = const [];
}
