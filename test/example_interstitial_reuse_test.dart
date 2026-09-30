// ignore_for_file: avoid_relative_lib_imports
import 'package:audienzz_sdk_flutter/src/ad_instance_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../example/lib/pages/interstitial_ad_example.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  final channel = adInstanceManager.methodChannel;
  testWidgets('cached prefetch remains ready and three manual show cycles work',
      (tester) async {
    final calls = <MethodCall>[];
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: InterstitialAdExample())),);
    final ids = <int>{};
    for (var cycle = 1; cycle <= 3; cycle++) {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Prefetch'));
      await tester.pump();
      final loads =
          calls.where((c) => c.method == 'loadInterstitialAd').toList();
      expect(loads.length, cycle);
      final id = (loads.last.arguments as Map)['adId'] as int;
      expect(ids.add(id), isTrue,
          reason: 'A consumed Google ad must not be reused',);
      Future<void> event(String name) => messenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
              MethodCall('onAdEvent', {'adId': id, 'eventName': name}),),
          (_) {},);
      await event('onAdLoaded');
      await tester.pumpAndSettle();
      expect(find.text('ready to show'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Prefetch'));
      await tester.pumpAndSettle();
      expect(
          calls.where((c) => c.method == 'loadInterstitialAd').length, cycle,);
      expect(find.text('ready to show'), findsOneWidget);
      if (cycle == 2) {
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Show'));
        await tester.pumpAndSettle();
        expect(
            find.text('opportunity skipped — ready to show'), findsOneWidget,);
        expect(calls.where((c) => c.method == 'showAdWithoutView').length,
            cycle - 1,);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
      await tester.tap(find.widgetWithText(ElevatedButton, 'Show'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'showAdWithoutView').length, cycle);
      await event('onAdOpened');
      await event('onAdClosed');
      await tester.pumpAndSettle();
      expect(find.text('closed — not loaded'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
