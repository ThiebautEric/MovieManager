import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../widgets/yellow_frame_logo.dart';

/// Écran de démarrage « The Yellow Frame ».
///
/// Affiché ~1 s au lancement, par-dessus l'application, puis retiré en fondu.
/// Réutilise le logo officiel [YellowFrameLogo] (porte + projecteur + mot-symbole)
/// sur fond noir de marque.
///
/// **Jamais sur le web** (à la demande) : sur cette plateforme, la porte laisse
/// simplement passer l'app sans splash.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  // Durées : plein écran opaque, puis fondu de sortie.
  static const _hold = Duration(milliseconds: 1000);
  static const _fade = Duration(milliseconds: 350);

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _opaque = true; // splash pleinement visible
  bool _present = true; // splash encore dans l'arbre

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _present = false; // pas de splash sur le web
      return;
    }
    Future.delayed(SplashGate._hold, () {
      if (mounted) setState(() => _opaque = false);
    });
    Future.delayed(SplashGate._hold + SplashGate._fade, () {
      if (mounted) setState(() => _present = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return widget.child;
    return Stack(
      children: [
        widget.child,
        if (_present)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _opaque ? 1 : 0,
              duration: SplashGate._fade,
              child: const _SplashView(),
            ),
          ),
      ],
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  static const _bg = Color(0xFF0A0A0A);

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final logoWidth = (screenW * 0.55).clamp(160.0, 240.0);
    // Force le rendu sombre du logo (accents jaunes sur fond noir), quel que
    // soit le thème courant de l'app.
    return Theme(
      data: ThemeData(brightness: Brightness.dark),
      child: Material(
        color: _bg,
        child: Center(child: YellowFrameLogo(width: logoWidth)),
      ),
    );
  }
}
