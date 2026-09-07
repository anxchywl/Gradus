import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

// one duration for the whole motion, two speeds read as a wobble
const Duration focusModeDuration = Duration(milliseconds: 240);

const Curve focusModeCurve = Curves.easeOutCubic;

// a sheet that swaps its whole body travels further than a folding field
const Duration chooserDuration = Duration(milliseconds: 340);

// a sheet keeps the wrong half of itself when the keyboard takes the rest
class SheetFocusMode extends ChangeNotifier {
  final Map<Object, FocusNode> _nodes = {};
  Object? _typingIn;
  bool _keyboardVisible = false;
  bool _autofocusTaken = false;

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
    // a tap straight to another field lands the gain before the loss
    final next = node.hasFocus ? id : (_typingIn == id ? null : _typingIn);
    if (next == _typingIn) return;
    _typingIn = next;
    notifyListeners();
  }

  // a second autofocus would take the keyboard straight back with no way out
  bool takeAutofocus() {
    if (_autofocusTaken) return false;
    _autofocusTaken = true;
    return true;
  }

  // a folded field is out of the tree, so the request waits for it to come back
  void moveTo(Object id) {
    if (_typingIn == id) return;
    _typingIn = id;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => nodeFor(id).requestFocus(),
    );
  }

  void release() {
    for (final node in _nodes.values) {
      if (node.hasFocus) node.unfocus();
    }
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

// one animator for the sheet: nested ones fight over the same height change
class FocusModeBody extends StatelessWidget {
  const FocusModeBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: focusModeDuration,
    curve: focusModeCurve,
    // the bottom edge rides the keyboard, a top anchor leaves a gap under it
    alignment: Alignment.bottomCenter,
    child: child,
  );
}

// collapses on the frame it is told to, FocusModeBody carries the movement
class FocusFold extends StatelessWidget {
  const FocusFold({super.key, required this.hidden, required this.child});

  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      hidden ? const SizedBox(width: double.infinity) : child;
}

// nothing left to separate once everything but one field has folded away
class FocusGap extends StatelessWidget {
  const FocusGap({
    super.key,
    required this.hidden,
    this.height = AppSpacing.md,
  });

  final bool hidden;
  final double height;

  @override
  Widget build(BuildContext context) => FocusFold(
    hidden: hidden,
    child: SizedBox(height: height),
  );
}

// while typing, the only thing worth offering is the way back out
class FocusModeActions extends StatelessWidget {
  const FocusModeActions({
    super.key,
    required this.isTyping,
    required this.doneLabel,
    required this.onDone,
    required this.actions,
  });

  final bool isTyping;
  final String doneLabel;
  final VoidCallback onDone;

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
            key: const ValueKey<String>('focus-mode-done'),
            text: doneLabel,
            onPressed: onDone,
          )
        : KeyedSubtree(
            key: const ValueKey<String>('focus-mode-actions'),
            child: actions,
          ),
  );
}
