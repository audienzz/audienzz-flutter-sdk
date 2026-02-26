import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Wraps an ad widget and keeps it "sticky" within a reserved area.
///
/// The wrapper reserves [maxHeight] in the layout, and positions the [child]
/// inside a Stack so that it sticks to the top of the viewport while the user
/// scrolls through the wrapper region.
final class AudienzzStickyAdWrapper extends StatefulWidget {
  const AudienzzStickyAdWrapper({
    required this.child,
    super.key,
    this.scrollController,
    this.stickyTopOffset,
    this.maxHeight = 600,
    this.enabled = true,
    this.debugLog = true,
  });

  /// The ad widget to display (e.g. [AdWidget]).
  final Widget child;

  /// Optional scroll controller provided by the publisher.
  /// If set, the wrapper listens to it for scroll events.
  final ScrollController? scrollController;

  /// Offset from the top of the viewport where the ad should stick.
  /// Defaults to `MediaQuery.padding.top`.
  final double? stickyTopOffset;

  /// Reserved height for the wrapper.
  final double maxHeight;

  /// Enables or disables sticky behavior.
  final bool enabled;

  /// Enables verbose debug logging for sticky calculations.
  final bool debugLog;

  @override
  State<AudienzzStickyAdWrapper> createState() =>
      _AudienzzStickyAdWrapperState();
}

final class _AudienzzStickyAdWrapperState extends State<AudienzzStickyAdWrapper>
    with SingleTickerProviderStateMixin {
  final GlobalKey _wrapperKey = GlobalKey();
  final ValueNotifier<double> _topOffset = ValueNotifier<double>(0);
  double _childHeight = 0;
  ScrollPosition? _scrollPosition;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _updatePosition());
    widget.scrollController?.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachPosition());
  }

  @override
  void didUpdateWidget(AudienzzStickyAdWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_handleScroll);
      widget.scrollController?.addListener(_handleScroll);
      _detachPosition();
      WidgetsBinding.instance.addPostFrameCallback((_) => _attachPosition());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _updatePosition());
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_handleScroll);
    _detachPosition();
    _ticker.dispose();
    _topOffset.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!widget.enabled) return;
    _updatePosition();
  }

  void _attachPosition() {
    if (!mounted) return;
    final position =
        widget.scrollController?.position ?? Scrollable.of(context)?.position;
    if (position == null || position == _scrollPosition) return;
    _scrollPosition = position;
    _scrollPosition?.isScrollingNotifier.addListener(_onScrollStateChanged);
    _onScrollStateChanged();
    _updatePosition();
  }

  void _detachPosition() {
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollStateChanged);
    _scrollPosition = null;
  }

  void _onScrollStateChanged() {
    final position = _scrollPosition;
    if (position == null || !widget.enabled) {
      if (_ticker.isActive) _ticker.stop();
      return;
    }
    if (position.isScrollingNotifier.value) {
      if (!_ticker.isActive) _ticker.start();
    } else {
      if (_ticker.isActive) _ticker.stop();
    }
  }

  void _onChildSizeChanged(Size size) {
    if (!mounted) return;
    if (size.height != _childHeight) {
      setState(() {
        _childHeight = size.height;
      });
      _updatePosition();
    }
  }

  void _updatePosition() {
    if (!mounted || !widget.enabled) return;
    final context = _wrapperKey.currentContext;
    if (context == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final position = _scrollPosition ??
        widget.scrollController?.position ??
        Scrollable.of(context)?.position;
    if (position == null) return;

    final viewport = RenderAbstractViewport.of(renderBox);
    if (viewport == null) return;

    final revealOffset = viewport.getOffsetToReveal(renderBox, 0.0).offset;
    final wrapperTop = revealOffset - position.pixels;
    final wrapperBottom = wrapperTop + renderBox.size.height;
    final topOffset =
        widget.stickyTopOffset ?? MediaQuery.of(this.context).padding.top;

    final childHeight = _childHeight > 0 ? _childHeight : renderBox.size.height;
    final maxTop = (widget.maxHeight - childHeight).clamp(0.0, widget.maxHeight);

    double nextTop;
    if (wrapperTop >= topOffset) {
      nextTop = 0;
    } else if (wrapperBottom <= topOffset + childHeight) {
      nextTop = maxTop;
    } else {
      nextTop = topOffset - wrapperTop;
    }
    nextTop = nextTop.clamp(0.0, maxTop);
    if ((nextTop - _topOffset.value).abs() > 0.5) {
      _topOffset.value = nextTop;
    }

    if (widget.debugLog) {
      final scrollOffset = position.pixels;
      debugPrint(
        '[AudienzzStickyAdWrapper] '
        'scroll=${scrollOffset?.toStringAsFixed(1)} '
        'wrapperTop=${wrapperTop.toStringAsFixed(1)} '
        'wrapperBottom=${wrapperBottom.toStringAsFixed(1)} '
        'topOffset=${topOffset.toStringAsFixed(1)} '
        'childH=${childHeight.toStringAsFixed(1)} '
        'maxTop=${maxTop.toStringAsFixed(1)} '
        'nextTop=${nextTop.toStringAsFixed(1)}',
      );
    }

  }

  @override
  Widget build(BuildContext context) {
    final stack = SizedBox(
      key: _wrapperKey,
      height: widget.maxHeight,
      child: ValueListenableBuilder<double>(
        valueListenable: _topOffset,
        builder: (_, top, child) {
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: top,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
            ],
          );
        },
        child: _MeasureSize(
          onChange: _onChildSizeChanged,
          child: widget.child,
        ),
      ),
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (widget.enabled && widget.scrollController == null) {
          _updatePosition();
        }
        return false;
      },
      child: stack,
    );
  }
}

final class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({
    required this.onChange,
    required super.child,
  });

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

final class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = child?.size ?? Size.zero;
    if (_oldSize == newSize) return;
    _oldSize = newSize;
    scheduleMicrotask(() => onChange(newSize));
  }
}
