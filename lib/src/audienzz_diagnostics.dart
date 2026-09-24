import 'package:flutter/foundation.dart';

/// One greppable line per decision the SDK makes about a slot.
///
/// This exists so a run on a device can be captured, sent to someone who was
/// not holding the phone, and read back as a sequence: which page became
/// current, which slot belongs to it, when an auction actually started, and —
/// the part that is otherwise invisible — *why* one did not.
///
/// Flutter needs its own channel rather than only forwarding the switch to the
/// natives, because the decisions that matter most here are taken in Dart: the
/// page wrapper owns focus, and the banner widget owns the viewport gate. A
/// native-only log shows the request and not the reason it was or was not made.
///
/// Off by default. Turn it on with
/// `AudienzzSdkFlutter.instance.setDiagnosticsEnabled(true)`, which also
/// switches on the iOS and Android SDKs, whose lines share this format.
///
/// Format: `AUDZ <subsystem> <event> key=value key=value`
/// Keys are stable; new keys may be added, so parse by key, not by position.
class AudienzzDiagnostics {
  const AudienzzDiagnostics._();

  static bool isEnabled = false;

  /// Where a line goes. Replaceable so a host can route diagnostics into its
  /// own file — `debugPrint` reaches the console, but not something a tester in
  /// the field can send back.
  static void Function(String line) sink = debugPrint;

  /// Log an action the PERSON took, into the same stream as the SDK's own decisions.
  ///
  /// For example and QA apps. A captured log then reads back as a sequence — "navigated to
  /// settings", then what the SDK did about it — instead of needing someone to remember what they
  /// tapped and in what order. A no-op unless diagnostics are on, like everything else here.
  static void logAppAction(String action, [Map<String, Object?> fields = const {}]) =>
      log('app', action, fields);

  static void log(
    String subsystem,
    String event, [
    Map<String, Object?> fields = const {},
  ]) {
    if (!isEnabled) {
      return;
    }
    final buffer = StringBuffer('AUDZ $subsystem $event');
    fields.forEach((key, value) {
      if (value == null) {
        return;
      }
      final text = '$value';
      // Bare unless it contains a space, which would break key=value parsing.
      buffer.write(text.contains(' ') ? ' $key="$text"' : ' $key=$text');
    });
    sink(buffer.toString());
  }
}
