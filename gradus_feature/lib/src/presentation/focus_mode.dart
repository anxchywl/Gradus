import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

// one duration for a fold, the sheet resizing around it and the buttons
// swapping underneath: any two at different speeds read as a wobble
const Duration focusModeDuration = Duration(milliseconds: 240);

const Curve focusModeCurve = Curves.easeOutCubic;

// which field of a sheet holds the keyboard. a sheet on a phone gives up most
// of its height to the keyboard, and what is left is usually the wrong half, so
// while a field is being typed into everything else folds away. taken from
// muto's sheets, so the apps behave alike
class SheetFocusMode extends ChangeNotifier {
  final Map<Object, FocusNode> _nodes = {};
  Object? _typingIn;
  bool _keyboardVisible = false;
  bool _autofocusTaken = false;

  // keyed on the keyboard being on screen, not on focus alone: a field can hold
  // focus with no keyboard showing, as on a simulator with a hardware keyboard,
  // and then there is no height to recover
  bool get isTyping => _typingIn != null && _keyboardVisible;

  bool hides(Object id) => isTyping && _typingIn != id;

  bool get hidesChrome => isTyping;

  // the view insets are the only honest signal that the keyboard is up
  void setKeyboardVisible(bool value) {
    if (value == _keyboardVisible) return;
    _keyboardVisible = value;
    if (!value) _typingIn = null;
  }

  // the same node every time, so a rebuilt field does not drop focus
  FocusNode nodeFor(Object id) => _nodes.putIfAbsent(id, () {
    final node = FocusNode(debugLabel: 'SheetFocusMode($id)');
    node.addListener(() => _focusChanged(id, node));
    return node;
  });

  void _focusChanged(Object id, FocusNode node) {
    final Object? next;
    if (node.hasFocus) {
      next = id;
    } else if (_typingIn == id && !_keyboardVisible) {
      // a tap straight from one field to another can land the loss before the
      // gain; while the keyboard stays up, focus mode holds rather than blinking
      next = null;
    } else {
      next = _typingIn;
    }
    if (next == _typingIn) return;
    _typingIn = next;
    notifyListeners();
  }

  // once only: a field that opens the form comes back after a fold, and taking
  // the keyboard again then would leave no way out of focus mode
  bool takeAutofocus() {
    if (_autofocusTaken) return false;
    _autofocusTaken = true;
    return true;
  }

  // a folded field is out of the tree, so the next-field key opens its fold
  // first and asks for focus once it is back
  void moveTo(Object id) {
    if (_typingIn == id) return;
    _typingIn = id;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => nodeFor(id).requestFocus(),
    );
  }

  // what Back does: the keyboard goes, and the whole form comes back with it
  // at once rather than waiting for the keyboard to finish leaving
  void release() {
    for (final node in _nodes.values) {
      if (node.hasFocus) node.unfocus();
    }
    if (_typingIn == null) return;
    _typingIn = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    _nodes.clear();
    super.dispose();
  }
}

// folds out of the way while the keyboard belongs to something else,
// collapsing vertically so the content slides up under its own top edge
class FocusFold extends StatelessWidget {
  const FocusFold({
    super.key,
    required this.hidden,
    required this.child,
    this.animateSize = true,
  });

  final bool hidden;
  final Widget child;

  // false inside a sheet that already animates its own height: two nested
  // AnimatedSizes reacting to one change fight, and the outer one snaps
  final bool animateSize;

  @override
  Widget build(BuildContext context) {
    final folded = hidden ? const SizedBox(width: double.infinity) : child;
    if (!animateSize) return folded;
    return AnimatedSize(
      duration: focusModeDuration,
      curve: focusModeCurve,
      alignment: Alignment.topCenter,
      child: folded,
    );
  }
}

// the space between two fields is chrome too: with one field left there is
// nothing for it to separate
class FocusGap extends StatelessWidget {
  const FocusGap({
    super.key,
    required this.hidden,
    this.height = AppSpacing.df,
    this.animateSize = true,
  });

  final bool hidden;
  final double height;
  final bool animateSize;

  @override
  Widget build(BuildContext context) => FocusFold(
    hidden: hidden,
    animateSize: animateSize,
    child: SizedBox(height: height),
  );
}

// while typing, the one button on offer leads back out to the whole form; it
// takes the place of the sheet's own actions, at the same height
class FocusModeActions extends StatelessWidget {
  const FocusModeActions({
    super.key,
    required this.isTyping,
    required this.backLabel,
    required this.onBack,
    required this.actions,
  });

  final bool isTyping;
  final String backLabel;
  final VoidCallback onBack;

  // what sits there when the keyboard is down
  final Widget actions;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: focusModeDuration,
    switchInCurve: focusModeCurve,
    switchOutCurve: Curves.easeInCubic,
    // the outgoing button is held out of the layout so it never sets the height
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.topCenter,
      children: [
        for (final child in previous)
          Positioned(top: 0, left: 0, right: 0, child: child),
        ?current,
      ],
    ),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: isTyping
        ? AppPrimaryButton(
            key: const ValueKey<String>('focus-mode-back'),
            text: backLabel,
            onPressed: onBack,
          )
        : KeyedSubtree(
            key: const ValueKey<String>('focus-mode-actions'),
            child: actions,
          ),
  );
}
