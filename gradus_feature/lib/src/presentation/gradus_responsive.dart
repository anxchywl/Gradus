import 'package:flutter/widgets.dart';

// these are decisions about these screens, not spacing tokens for the kit
const double _mediumWidth = 600;
const double _expandedWidth = 1024;

const double gradusReadingWidth = 720;
const double gradusGridWidth = 1060;

enum GradusWidth { compact, medium, expanded }

GradusWidth gradusWidthOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= _expandedWidth) return GradusWidth.expanded;
  if (width >= _mediumWidth) return GradusWidth.medium;
  return GradusWidth.compact;
}

extension GradusWidthLayout on GradusWidth {
  int get columns => this == GradusWidth.compact ? 1 : 2;

  double get contentWidth =>
      this == GradusWidth.compact ? gradusReadingWidth : gradusGridWidth;
}

class CenteredContent extends StatelessWidget {
  const CenteredContent({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? gradusWidthOf(context).contentWidth,
      ),
      child: child,
    ),
  );
}

// a Wrap not a grid: the cards differ in height and a grid pads to the tallest
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children, required this.spacing});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final columns = gradusWidthOf(context).columns;
    if (columns == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in children)
            Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: child,
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
