import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Masque la barre de navigation système Android quand on défile vers le bas,
/// et la fait réapparaître quand on remonte — comme dans d'autres apps
/// (lecture immersive). La barre de statut (haut) reste toujours visible.
///
/// Sans effet hors Android (les autres plateformes n'ont pas cette barre).
class ImmersiveOnScroll extends StatefulWidget {
  const ImmersiveOnScroll({super.key, required this.child});

  final Widget child;

  @override
  State<ImmersiveOnScroll> createState() => _ImmersiveOnScrollState();
}

class _ImmersiveOnScrollState extends State<ImmersiveOnScroll> {
  static const _shown = [SystemUiOverlay.top, SystemUiOverlay.bottom];
  static const _navHidden = [SystemUiOverlay.top];

  bool _navBarHidden = false;

  bool get _enabled => defaultTargetPlatform == TargetPlatform.android;

  void _setHidden(bool hide) {
    if (!_enabled || hide == _navBarHidden) return;
    _navBarHidden = hide;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: hide ? _navHidden : _shown,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    return NotificationListener<UserScrollNotification>(
      onNotification: (n) {
        // reverse = on fait défiler le contenu vers le haut (on « descend »).
        if (n.direction == ScrollDirection.reverse) {
          _setHidden(true);
        } else if (n.direction == ScrollDirection.forward) {
          _setHidden(false);
        }
        return false;
      },
      child: widget.child,
    );
  }
}
