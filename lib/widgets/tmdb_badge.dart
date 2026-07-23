import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _gradient = LinearGradient(
  colors: [Color(0xFF90CEA1), Color(0xFF3CBEC9), Color(0xFF00B3E5)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

/// Logo d'attribution TMDB cliquable (lien vers themoviedb.org).
/// Reproduit le wordmark officiel « TMDB » + badge pill en dégradé vert→bleu.
class TmdbBadge extends StatelessWidget {
  const TmdbBadge({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse('https://www.themoviedb.org/'),
        mode: LaunchMode.externalApplication,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (b) => _gradient.createShader(b),
            blendMode: BlendMode.srcIn,
            child: Text(
              'TMDB',
              style: TextStyle(
                color: Colors.white,
                fontSize: height * 0.82,
                fontWeight: FontWeight.w900,
                letterSpacing: height * 0.04,
                height: 1,
              ),
            ),
          ),
          SizedBox(width: height * 0.3),
          Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: height * 0.38),
            decoration: BoxDecoration(
              gradient: _gradient,
              borderRadius: BorderRadius.circular(height / 2),
            ),
            alignment: Alignment.center,
            child: Text(
              'tmdb',
              style: TextStyle(
                color: Colors.white,
                fontSize: height * 0.46,
                fontWeight: FontWeight.bold,
                letterSpacing: height * 0.02,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
