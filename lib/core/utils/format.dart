/// Formatage compact des durées : « 47min », « 2h08 », « 61h »…
String fmtDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}min';
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
}
