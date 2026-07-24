import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Logo d'attribution TMDB cliquable (lien vers themoviedb.org).
/// Utilise un fond dégradé (compatible Flutter Web HTML renderer).
class TmdbBadge extends StatelessWidget {
  const TmdbBadge({super.key, this.height = 28});

  final double height;

  static const _colors = [
    Color(0xFF90CEA1),
    Color(0xFF3CBEC9),
    Color(0xFF00B3E5),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse('https://www.themoviedb.org/'),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: height * 0.55),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: _colors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(height / 2),
        ),
        alignment: Alignment.center,
        child: Text(
          'TMDB',
          style: TextStyle(
            color: Colors.white,
            fontSize: height * 0.54,
            fontWeight: FontWeight.w900,
            letterSpacing: height * 0.07,
            height: 1,
          ),
        ),
      ),
    );
  }
}
