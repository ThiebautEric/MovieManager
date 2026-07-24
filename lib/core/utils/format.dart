import 'package:supabase_flutter/supabase_flutter.dart';

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
