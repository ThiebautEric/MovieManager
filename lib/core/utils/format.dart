import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Formatage de date fixe pour l'export CSV (dd/MM/yyyy).
String fmtDateCsv(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Formatage de date localisé selon la locale du contexte (ex. « 03/08/2026 »).
String fmtDateLocalized(BuildContext context, DateTime d) =>
    DateFormat.yMd(Localizations.localeOf(context).toString()).format(d);

/// Formatage compact des durées : « 47min », « 2h08 », « 61h »…
String fmtDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}min';
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
}

/// Convertit une exception en message lisible par l'utilisateur.
/// Masque les détails internes des erreurs Supabase/base de données.
String friendlyError(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is StorageException) return e.message;
  if (e is AuthException) return e.message;
  return e.toString();
}
