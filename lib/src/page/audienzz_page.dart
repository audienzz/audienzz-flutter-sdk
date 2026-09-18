import 'package:audienzz_sdk_flutter/src/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/page/audienzz_page_handle.dart';
import 'package:flutter/widgets.dart';

/// What a managed banner needs to know about the page it is on.
///
/// [isActive] is deliberately separate from mounting. A retained tab stays
/// mounted while another tab is on screen, and an `IndexedStack` builds every
/// child. Mounting is not navigating.
@immutable
class AudienzzPageScope extends InheritedWidget {
  const AudienzzPageScope({
    required this.page,
    required this.isActive,
    required super.child,
    super.key,
  });

  final AudienzzPageHandle page;
  final bool isActive;

  static AudienzzPageScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AudienzzPageScope>();

  @override
  bool updateShouldNotify(AudienzzPageScope oldWidget) =>
      oldWidget.page != page || oldWidget.isActive != isActive;
}

/// Binds everything inside it to one page instance.
///
/// The handle is minted once per mounted route instance and published through
/// the element tree, so a descendant banner learns which page owns it while it
/// is being built — not from whichever page a parent happened to report last.
///
/// Activation happens in a post-frame callback rather than during build,
/// because reporting a page is a side effect and `build` must not have any. A
/// managed banner creates nothing until [AudienzzPageScope.isActive] is true,
/// so the page is always reported before its ads exist.
class AudienzzPage extends StatefulWidget {
  const AudienzzPage({
    required this.name,
    required this.child,
    this.active = true,
    super.key,
  });

  /// Analytics screen name. May repeat across routes; identity is separate.
  final String name;

  /// Whether this page currently owns the screen. The default is right for a
  /// plain route, where building *is* navigating. For a tab or an
  /// `IndexedStack`, pass whether this tab is the selected one, so a
  /// pre-built tab does not claim the active page.
  final bool active;

  final Widget child;

  @override
  State<AudienzzPage> createState() => _AudienzzPageState();
}

class _AudienzzPageState extends State<AudienzzPage> {
  late final AudienzzPageHandle _page = createAudienzzPage(widget.name);
  bool _isActive = false;
  bool _activationScheduled = false;

  @override
  void initState() {
    super.initState();
    _maybeActivate();
  }

  @override
  void didUpdateWidget(AudienzzPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _maybeActivate();
    }
  }

  void _maybeActivate() {
    if (!widget.active || _isActive || _activationScheduled) {
      return;
    }
    _activationScheduled = true;
    // After the frame, so this never runs during build. Descendants that were
    // built in the same frame have not created an ad yet, because they wait on
    // `isActive`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      AudienzzSdkFlutter.instance.activatePage(_page);
      setState(() {
        _isActive = true;
        _activationScheduled = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) => AudienzzPageScope(
        page: _page,
        isActive: _isActive,
        child: widget.child,
      );
}
