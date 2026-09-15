import 'package:flutter/material.dart';

import 'tokens.dart';

/// Scales the fixed 393x852 reference artboard to any screen while
/// preserving the approved design proportions. The whole UI is laid out
/// in design pixels inside [DwScreenFrame.body].
class DwScreenFrame extends StatelessWidget {
  const DwScreenFrame({super.key, required this.body, this.background});

  /// Builds the 393x852 design-space content.
  final WidgetBuilder body;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background ?? Dw.pageBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = (constraints.maxWidth / Dw.designWidth).clamp(
            0.0,
            constraints.maxHeight / Dw.designHeight,
          );
          return Center(
            child: ClipRect(
              child: SizedBox(
                width: Dw.designWidth * scale,
                height: Dw.designHeight * scale,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: Dw.designWidth,
                    height: Dw.designHeight,
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
