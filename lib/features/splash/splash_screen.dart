import 'package:flutter/material.dart';

/// Écran de démarrage « The Yellow Frame ».
///
/// Affiché ~1 s au lancement, par-dessus l'application, puis retiré en fondu.
/// Indépendant de la plateforme (Android/Windows/iOS/web) et du thème clair/
/// sombre : couleurs de marque figées (fond noir, or). Ne dépend d'aucun asset —
/// le nom est encadré d'un cadre jaune, en écho au nom de l'app.
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
    Future.delayed(SplashGate._hold, () {
      if (mounted) setState(() => _opaque = false);
    });
    Future.delayed(SplashGate._hold + SplashGate._fade, () {
      if (mounted) setState(() => _present = false);
    });
  }

  @override
  Widget build(BuildContext context) {
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

  static const _gold = Color(0xFFF2C40F);
  static const _bg = Color(0xFF0A0A0A);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(color: _gold, width: 2.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'THE YELLOW FRAME',
            style: TextStyle(
              color: _gold,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
            ),
          ),
        ),
      ),
    );
  }
}
