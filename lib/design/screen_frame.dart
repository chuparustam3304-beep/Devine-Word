import 'package:flutter/material.dart';

import 'tokens.dart';

/// Scales a fixed reference artboard to any screen while preserving the
/// approved design proportions. The whole UI is laid out in design pixels
/// inside [DwScreenFrame.body].
///
/// Most screens use the 393×852 artboard from the original design pack;
/// the quranic onboarding screens ship their own 440×956 artboard and pass
/// it through [designWidth]/[designHeight].
class DwScreenFrame extends StatelessWidget {
  const DwScreenFrame({
    super.key,
    required this.body,
    this.background,
    this.designWidth = Dw.designWidth,
    this.designHeight = Dw.designHeight,
  });

  /// Builds the design-space content.
  final WidgetBuilder body;
  final Color? background;
  final double designWidth;
  final double designHeight;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background ?? Dw.pageBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = (constraints.maxWidth / designWidth).clamp(
            0.0,
            constraints.maxHeight / designHeight,
          );
          return Center(
            child: ClipRect(
              child: SizedBox(
                width: designWidth * scale,
                height: designHeight * scale,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: designWidth,
                    height: designHeight,
                    child: Builder(builder: body),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
