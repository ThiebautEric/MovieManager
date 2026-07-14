import 'package:flutter/material.dart';

/// Logo « The Yellow Frame » : porte entrouverte, projecteur en contre-jour,
/// faisceau au sol, puis le mot-symbole. Dessiné en code (net à toutes les
/// tailles) et décliné automatiquement selon le thème clair/sombre.
class YellowFrameLogo extends StatelessWidget {
  const YellowFrameLogo({super.key, this.width = 220, this.wordmark = true});

  final double width;

  /// Affiche le texte sous l'illustration (THE YELLOW FRAME · FILM DATABASE).
  final bool wordmark;

  static const yellow = Color(0xFFF2C40F);
  static const deepGold = Color(0xFFB8890B);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? const Color(0xFF0B0A08) : const Color(0xFF1D1A15);
    final accent = dark ? yellow : deepGold;
    final textColor = dark ? const Color(0xFFFBF6EA) : ink;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          height: width * 830 / 720,
          child: CustomPaint(painter: _DoorPainter(dark: dark)),
        ),
        if (wordmark) ...[
          const SizedBox(height: 10),
          Text('THE',
              style: TextStyle(
                  fontSize: width * .075,
                  letterSpacing: width * .045,
                  color: textColor)),
          Text('YELLOW',
              style: TextStyle(
                  fontSize: width * .175,
                  fontWeight: FontWeight.w700,
                  letterSpacing: width * .02,
                  height: 1.1,
                  color: accent)),
          Text('FRAME',
              style: TextStyle(
                  fontSize: width * .125,
                  letterSpacing: width * .06,
                  height: 1.1,
                  color: textColor)),
          const SizedBox(height: 8),
          Container(width: width * .35, height: 2, color: accent),
          const SizedBox(height: 8),
          Text('FILM DATABASE',
              style: TextStyle(
                  fontSize: width * .05,
                  letterSpacing: width * .028,
                  color: accent)),
        ],
      ],
    );
  }
}

/// Illustration seule (coordonnées logiques 720 × 830, cf. maquette SVG).
class _DoorPainter extends CustomPainter {
  const _DoorPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 720;
    canvas.scale(s);
    // Décale l'illustration vers la gauche pour la centrer optiquement
    // (la porte déborde à droite dans les coordonnées de la maquette).
    canvas.translate(-80, -60);

    final ink = dark ? const Color(0xFF0B0A08) : const Color(0xFF1D1A15);
    final doorFill = dark ? const Color(0xFF12100C) : const Color(0xFF1D1A15);
    final doorStroke =
        dark ? YellowFrameLogo.yellow : YellowFrameLogo.deepGold;
    final panelStroke =
        dark ? const Color(0xFF7A6207) : YellowFrameLogo.deepGold;

    Path poly(List<Offset> pts) => Path()..addPolygon(pts, true);

    // Encadrement charbon de la porte (utile sur fond clair uniquement).
    if (!dark) {
      canvas.drawPath(
        poly(const [
          Offset(224, 120), Offset(460, 128), Offset(460, 648), Offset(224, 640),
        ]),
        Paint()..color = ink,
      );
    }

    // Ouverture lumineuse.
    final glow = poly(const [
      Offset(236, 132), Offset(448, 140), Offset(448, 636), Offset(236, 628),
    ]);
    canvas.drawPath(
      glow,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFDA45), YellowFrameLogo.yellow],
        ).createShader(const Rect.fromLTRB(236, 132, 448, 636)),
    );

    // Faisceau au sol.
    final wedge = poly(const [
      Offset(238, 628), Offset(448, 636), Offset(634, 806), Offset(306, 796),
    ]);
    canvas.drawPath(
      wedge,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            YellowFrameLogo.yellow.withValues(alpha: dark ? .95 : .85),
            YellowFrameLogo.yellow.withValues(alpha: 0),
          ],
        ).createShader(const Rect.fromLTRB(238, 628, 634, 806)),
    );

    // Projecteur en silhouette.
    final inkPaint = Paint()..color = ink;
    canvas.drawCircle(const Offset(330, 436), 40, inkPaint);
    canvas.drawCircle(const Offset(398, 450), 30, inkPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(296, 470, 110, 66), const Radius.circular(8)),
        inkPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(404, 488, 26, 30), const Radius.circular(4)),
        inkPaint);
    canvas.drawRect(const Rect.fromLTWH(282, 536, 130, 10), inkPaint);
    canvas.drawRect(const Rect.fromLTWH(292, 546, 10, 70), inkPaint);
    canvas.drawRect(const Rect.fromLTWH(392, 546, 10, 72), inkPaint);

    // Rayons et moyeux des bobines.
    final spokes = Paint()
      ..color = YellowFrameLogo.yellow
      ..strokeWidth = 7;
    canvas.drawLine(const Offset(330, 414), const Offset(330, 458), spokes);
    canvas.drawLine(const Offset(308, 436), const Offset(352, 436), spokes);
    canvas.drawLine(const Offset(398, 434), const Offset(398, 466), spokes);
    canvas.drawLine(const Offset(382, 450), const Offset(414, 450), spokes);
    final hub = Paint()..color = YellowFrameLogo.yellow;
    canvas.drawCircle(const Offset(330, 436), 8, hub);
    canvas.drawCircle(const Offset(398, 450), 6, hub);

    // Battant de porte ouvert.
    final door = poly(const [
      Offset(458, 118), Offset(652, 74), Offset(652, 714), Offset(458, 650),
    ]);
    canvas.drawPath(door, Paint()..color = doorFill);
    canvas.drawPath(
        door,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..color = doorStroke);
    final panelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = panelStroke;
    canvas.drawPath(
        poly(const [
          Offset(482, 168), Offset(626, 136), Offset(626, 340), Offset(482, 352),
        ]),
        panelPaint);
    canvas.drawPath(
        poly(const [
          Offset(482, 392), Offset(626, 388), Offset(626, 606), Offset(482, 568),
        ]),
        panelPaint);
    // Poignée.
    canvas.drawOval(Rect.fromCenter(
        center: const Offset(474, 382), width: 18, height: 26), hub);
  }

  @override
  bool shouldRepaint(_DoorPainter oldDelegate) => oldDelegate.dark != dark;
}
