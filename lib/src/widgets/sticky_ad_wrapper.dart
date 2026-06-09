import 'dart:async';

import 'package:audienzz_sdk_flutter/src/remote_config/audienzz_remote_config.dart';
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
    this.maxHeight,
    this.enabled = true,
    this.adConfigId,
  });

  /// The ad widget to display (e.g. [AdWidget]).
  final Widget child;

  /// Optional scroll controller provided by the publisher.
  /// If set, the wrapper listens to it for scroll events.
  final ScrollController? scrollController;

  /// Offset from the top of the viewport where the ad should stick.
  ///
  /// Leave `null` to use the backend-configured value (requires [adConfigId]),
  /// falling back to `MediaQuery.padding.top`. A non-null value always wins
  /// over the backend setting.
  final double? stickyTopOffset;

  /// Reserved height for the wrapper.
  ///
  /// Leave `null` to use the backend-configured value (requires [adConfigId]),
  /// falling back to 600. A non-null value always wins over the backend setting.
  final double? maxHeight;

  /// Enables or disables sticky behavior.
  final bool enabled;

  /// Remote ad-unit config ID. When provided the SDK reads `stickyMaxHeight`
  /// and `stickyTopOffset` from the cached remote config and uses them as
  /// fallback values (publisher-supplied [maxHeight] / [stickyTopOffset] win).
  final String? adConfigId;

  @override
  State<AudienzzStickyAdWrapper> createState() =>
      _AudienzzStickyAdWrapperState();
}

final class _AudienzzStickyAdWrapperState extends State<AudienzzStickyAdWrapper>
    with SingleTickerProviderStateMixin {
  static const double _defaultMaxHeight = 600.0;

  final GlobalKey _wrapperKey = GlobalKey();
  final ValueNotifier<double> _topOffset = ValueNotifier<double>(0);
  double _childHeight = 0;
  ScrollPosition? _scrollPosition;
  late final Ticker _ticker;

  /// Resolved max height: publisher override → remote config → SDK default.
  late double _effectiveMaxHeight;

  /// Resolved sticky top offset: publisher override → remote config → null (uses safe-area).
  double? _effectiveStickyTopOffset;

  @override
  void initState() {
    super.initState();
    _resolveRemoteConfig();
    _ticker = createTicker((_) => _updatePosition());
    widget.scrollController?.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachPosition());
  }

  void _resolveRemoteConfig() {
    final remoteConfig = widget.adConfigId != null
        ? AudienzzRemoteConfig.instance.remoteConfigFor(widget.adConfigId!)?.config
        : null;

    // maxHeight: publisher override → remote config → SDK default.
    _effectiveMaxHeight = widget.maxHeight ??
        remoteConfig?.stickyMaxHeight?.toDouble() ??
        _defaultMaxHeight;

    // stickyTopOffset: publisher override → remote config → null (falls back to safe-area in _updatePosition).
    _effectiveStickyTopOffset = widget.stickyTopOffset ??
        remoteConfig?.stickyTopOffset?.toDouble();
  }

  @override
  void didUpdateWidget(AudienzzStickyAdWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adConfigId != widget.adConfigId ||
        oldWidget.maxHeight != widget.maxHeight ||
        oldWidget.stickyTopOffset != widget.stickyTopOffset) {
      setState(() => _resolveRemoteConfig());
    }
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
        _effectiveStickyTopOffset ?? MediaQuery.of(this.context).padding.top;

    final childHeight = _childHeight > 0 ? _childHeight : renderBox.size.height;
    final maxTop = (_effectiveMaxHeight - childHeight).clamp(0.0, _effectiveMaxHeight);

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
  }

  @override
  Widget build(BuildContext context) {
    final stack = SizedBox(
      key: _wrapperKey,
      height: _effectiveMaxHeight,
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
