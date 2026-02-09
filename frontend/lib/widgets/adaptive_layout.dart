import 'package:flutter/material.dart';

class AdaptiveLayout extends StatefulWidget {
  const AdaptiveLayout({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.actions,
    this.padding = const EdgeInsets.all(24),
    this.maxWidth = 900,
    this.showAppBar = true,
    this.scrollController,
    this.centerContent = true,
    this.useScrollView = true,
    this.animate = true,
  });

  final Widget child;
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final EdgeInsets padding;
  final double maxWidth;
  final bool showAppBar;
  final ScrollController? scrollController;
  final bool centerContent;
  final bool useScrollView;
  final bool animate;

  @override
  State<AdaptiveLayout> createState() => _AdaptiveLayoutState();
}

class _AdaptiveLayoutState extends State<AdaptiveLayout>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    if (widget.animate) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveController = widget.scrollController ?? ScrollController();

    Widget bodyContent = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 0, maxWidth: widget.maxWidth),
        child: widget.centerContent
            ? Center(child: widget.child)
            : widget.child,
      ),
    );

    if (widget.useScrollView) {
      bodyContent = LayoutBuilder(
        builder: (context, viewportConstraints) {
          return SingleChildScrollView(
            controller: effectiveController,
            physics: const BouncingScrollPhysics(),
            padding: widget.padding,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: widget.centerContent
                      ? viewportConstraints.maxHeight - widget.padding.vertical
                      : 0,
                  maxWidth: widget.maxWidth,
                ),
                child: widget.centerContent
                    ? Center(child: widget.child)
                    : widget.child,
              ),
            ),
          );
        },
      );
    } else {
      bodyContent = Padding(padding: widget.padding, child: bodyContent);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: widget.showAppBar
          ? AppBar(
              title: widget.title != null ? Text(widget.title!) : null,
              leading: widget.leading,
              actions: widget.actions,
              centerTitle: true,
            )
          : null,
      body: SafeArea(
        child: Scrollbar(
          controller: effectiveController,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: bodyContent,
            ),
          ),
        ),
      ),
    );
  }
}
