import 'package:flutter/material.dart';

/// Titre de vignette limité à deux lignes, avec tooltip contenant le texte
/// intégral quand il est tronqué (survol sur web/desktop, appui long sur
/// mobile).
class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: text,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: style,
        ),
      );
}
