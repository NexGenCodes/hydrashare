import 'package:flutter/material.dart';

class AdaptiveLayout extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final bool showAppBar;
  final bool centerContent;
  final ScrollController? scrollController;

  const AdaptiveLayout({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.actions,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    this.maxWidth = 900,
    this.showAppBar = true,
    this.scrollController,
    this.centerContent = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveController = scrollController ?? ScrollController();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: showAppBar
          ? AppBar(
              title: title != null ? Text(title!) : null,
              leading: leading,
              actions: actions,
            )
          : null,
      body: SafeArea(
        child: Scrollbar(
          controller: effectiveController,
          child: LayoutBuilder(
            builder: (context, viewportConstraints) {
              return SingleChildScrollView(
                controller: effectiveController,
                physics: const BouncingScrollPhysics(),
                padding: padding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: centerContent
                          ? viewportConstraints.maxHeight - padding.vertical
                          : 0,
                      maxWidth: maxWidth,
                    ),
                    child: centerContent ? Center(child: child) : child,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
