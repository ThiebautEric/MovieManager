import 'package:flutter/material.dart';
import 'yellow_frame_logo.dart';

/// Titre d'AppBar dans le style du wordmark Yellow Frame :
/// majuscules, gras, espacé, couleur accent jaune/or.
class AppBarTitle extends StatelessWidget {
  const AppBarTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? YellowFrameLogo.yellow : YellowFrameLogo.deepGold;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 3,
        color: accent,
      ),
    );
  }
}
