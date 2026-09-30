import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

/// Mount pages (and their ads) only after native initialization succeeds.
/// A completed Future with fallbackPolling/fail is not a ready SDK.
class SdkInitializationGate extends StatefulWidget {
  const SdkInitializationGate({
    required this.initialize,
    required this.readyBuilder,
    super.key,
  });

  final Future<InitializationStatus> Function() initialize;
  final WidgetBuilder readyBuilder;

  @override
  State<SdkInitializationGate> createState() => _SdkInitializationGateState();
}

class _SdkInitializationGateState extends State<SdkInitializationGate> {
  late Future<InitializationStatus> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = Future.sync(widget.initialize);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<InitializationStatus>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
            );
          }
          if (!snapshot.hasError &&
              snapshot.data == InitializationStatus.success) {
            return widget.readyBuilder(context);
          }
          return MaterialApp(
            home: Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('SDK initialization is not ready.'),
                        if (snapshot.hasError) Text('${snapshot.error}'),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => setState(() {
                            _initialization = Future.sync(widget.initialize);
                          }),
                          child: const Text('Retry initialization'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
