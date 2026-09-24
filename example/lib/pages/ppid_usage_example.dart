import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

/// A PPID is always attached to ad requests — the SDK generates and persists
/// one when you don't supply your own, so there is nothing to switch on. This
/// screen shows the PPID currently in use and lets you override it with your
/// own identifier (e.g. a hashed e-mail).
final class PpidUsageExample extends StatefulWidget {
  const PpidUsageExample({super.key});

  @override
  State<PpidUsageExample> createState() => _PpidUsageExampleState();
}

class _PpidUsageExampleState extends State<PpidUsageExample> {
  final _controller = TextEditingController();
  String? currentPpid = 'unknown';

  @override
  void initState() {
    super.initState();
    refreshPpid();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> refreshPpid() async {
    final ppid = await PpidManager.getPpid();

    if (!mounted) {
      return;
    }
    setState(() => currentPpid = ppid);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Current ppid: $currentPpid',
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: refreshPpid,
          child: const Text('Refresh current ppid'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Your own PPID (e.g. a hashed e-mail)',
            ),
          ),
        ),
        TextButton(
          onPressed: () async {
            await PpidManager.setPublisherPpid(_controller.text);
            await refreshPpid();
          },
          child: const Text('Use my ppid'),
        ),
        TextButton(
          onPressed: () async {
            // Passing null clears the override and falls back to the
            // SDK-generated UUID.
            await PpidManager.setPublisherPpid(null);
            await refreshPpid();
          },
          child: const Text('Clear my ppid (back to generated)'),
        ),
      ],
    );
  }
}
