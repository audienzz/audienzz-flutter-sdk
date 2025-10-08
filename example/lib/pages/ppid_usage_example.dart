import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

final class PpidUsageExample extends StatefulWidget {
  const PpidUsageExample({super.key});

  @override
  State<PpidUsageExample> createState() => _PpidUsageExampleState();
}

class _PpidUsageExampleState extends State<PpidUsageExample> {
  bool isLoading = true;
  bool currentPpidStatus = false;
  String? currentPpid = 'unknown';

  @override
  void initState() {
    super.initState();
    getPpidStatus();
  }

  Future<void> getPpidStatus() async {
    final currentPpid = await PpidManager.isAutomaticPpidEnabled();

    setState(() {
      currentPpidStatus = currentPpid;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? CircularProgressIndicator()
        : Column(
            children: [
              TextButton(
                onPressed: getPpidStatus,
                child: Text("Get ppid status"),
              ),
              Switch(
                value: currentPpidStatus,
                onChanged: (newValue) async {
                  await PpidManager.setAutomaticPpidEnabled(
                      isAutomaticPpidEnabled: newValue);
                  await getPpidStatus();
                },
              ),
              TextButton(
                onPressed: () async {
                  final ppid = await PpidManager.getPpid();
                  setState(() {
                    currentPpid = ppid;
                  });
                },
                child: Text("Get current ppid"),
              ),
              Text(
                "Current ppid: $currentPpid",
                textAlign: TextAlign.center,
              )
            ],
          );
  }
}
