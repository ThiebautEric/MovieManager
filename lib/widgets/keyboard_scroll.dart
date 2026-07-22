import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Ajoute le défilement clavier à n'importe quel scrollable.
/// Usage :
///   KeyboardScroll(
///     builder: (ctrl) => ListView.builder(controller: ctrl, ...),
///   )
class KeyboardScroll extends StatefulWidget {
  const KeyboardScroll({super.key, required this.builder});

  final Widget Function(ScrollController controller) builder;

  @override
  State<KeyboardScroll> createState() => _KeyboardScrollState();
}

class _KeyboardScrollState extends State<KeyboardScroll> {
  final _ctrl  = ScrollController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_ctrl.hasClients) return KeyEventResult.ignored;

    final page = MediaQuery.of(context).size.height * 0.85;
    final max  = _ctrl.position.maxScrollExtent;
    final cur  = _ctrl.offset;

    double? target;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.pageDown:
        target = (cur + page).clamp(0.0, max);
      case LogicalKeyboardKey.pageUp:
        target = (cur - page).clamp(0.0, max);
      case LogicalKeyboardKey.home:
        target = 0;
      case LogicalKeyboardKey.end:
        target = max;
      case LogicalKeyboardKey.arrowDown:
        target = (cur + 80).clamp(0.0, max);
      case LogicalKeyboardKey.arrowUp:
        target = (cur - 80).clamp(0.0, max);
      default:
        return KeyEventResult.ignored;
    }

    _ctrl.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        onTap: _focus.requestFocus,
        behavior: HitTestBehavior.translucent,
        child: widget.builder(_ctrl),
      ),
    );
  }
}
