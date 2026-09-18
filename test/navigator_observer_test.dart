import 'dart:async';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter/src/constants/constants.dart';
import 'package:audienzz_sdk_flutter/src/message_codec/ad_message_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The navigation adapter must cover every operation that changes which route
/// is on top — not only push and pop — and must separate two routes that share
/// a name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channel = MethodChannel(
    Constants.methodChannelName,
    StandardMethodCodec(AdMessageCodec()),
  );
  late List<Map<dynamic, dynamic>> reports;

  setUp(() {
    reports = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pageImpression') {
        reports.add(call.arguments as Map);
      }
      return null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<NavigatorState> pumpApp(WidgetTester tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      navigatorObservers: [AudienzzNavigatorObserver()],
      routes: {
        '/': (_) => const Scaffold(body: Text('home')),
        '/article': (_) => const Scaffold(body: Text('article')),
        '/settings': (_) => const Scaffold(body: Text('settings')),
      },
    ));
    await tester.pumpAndSettle();
    return key.currentState!;
  }

  testWidgets('reports the initial route', (tester) async {
    await pumpApp(tester);
    expect(reports, hasLength(1));
    expect(reports.single['name'], '/');
  });

  testWidgets('identifies a route by its name by default', (tester) async {
    // So this observer, AudienzzPage and pageImpression(name) all agree.
    final nav = await pumpApp(tester);
    unawaited(nav.pushNamed<void>('/article'));
    await tester.pumpAndSettle();
    unawaited(nav.pushNamed<void>('/article'));
    await tester.pumpAndSettle();

    final articles = reports.where((r) => r['name'] == '/article').toList();
    expect(articles, hasLength(2));
    expect(articles.map((r) => r['pageId']), ['/article', '/article']);
  });

  testWidgets('separates two article routes when perInstance is opted into',
      (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      navigatorObservers: [AudienzzNavigatorObserver(perInstance: true)],
      routes: {
        '/': (_) => const Scaffold(body: Text('home')),
        '/article': (_) => const Scaffold(body: Text('article')),
      },
    ));
    await tester.pumpAndSettle();
    unawaited(key.currentState!.pushNamed<void>('/article'));
    await tester.pumpAndSettle();
    unawaited(key.currentState!.pushNamed<void>('/article'));
    await tester.pumpAndSettle();

    final articles = reports.where((r) => r['name'] == '/article').toList();
    expect(articles, hasLength(2));
    expect(articles[0]['pageId'], isNot(articles[1]['pageId']));
  });

  testWidgets('removing a buried route leaves the visible page alone',
      (tester) async {
    final nav = await pumpApp(tester);
    final middle = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/article'),
      builder: (_) => const Scaffold(body: Text('middle')),
    );
    unawaited(nav.push<void>(middle));
    await tester.pumpAndSettle();
    unawaited(nav.pushNamed<void>('/settings'));
    await tester.pumpAndSettle();
    final before = reports.length;

    nav.removeRoute(middle);
    await tester.pumpAndSettle();

    expect(reports, hasLength(before),
        reason: 'the reader never left /settings; reporting the route below '
            'the removed one released the banners of the visible screen');
  });

  testWidgets('reports the revealed route on pop', (tester) async {
    final nav = await pumpApp(tester);
    unawaited(nav.pushNamed<void>('/article'));
    await tester.pumpAndSettle();
    nav.pop();
    await tester.pumpAndSettle();

    expect(reports.map((r) => r['name']), ['/', '/article', '/']);
  });

  testWidgets('reports a replacement', (tester) async {
    final nav = await pumpApp(tester);
    unawaited(nav.pushReplacementNamed<void, void>('/article'));
    await tester.pumpAndSettle();

    expect(reports.map((r) => r['name']), ['/', '/article']);
  });

  testWidgets('reports a destination that carries no ads', (tester) async {
    // Moving to an ad-free screen is what releases the previous page's banners.
    final nav = await pumpApp(tester);
    unawaited(nav.pushNamed<void>('/settings'));
    await tester.pumpAndSettle();

    expect(reports.map((r) => r['name']), ['/', '/settings']);
  });

  testWidgets('returning to the same route instance is a new visit',
      (tester) async {
    final nav = await pumpApp(tester);
    unawaited(nav.pushNamed<void>('/article'));
    await tester.pumpAndSettle();
    nav.pop();
    await tester.pumpAndSettle();
    unawaited(nav.pushNamed<void>('/article'));
    await tester.pumpAndSettle();

    expect(reports, hasLength(4),
        reason: 'each transition is a visit, including the return');
  });

  testWidgets('an unnamed route still reports something stable',
      (tester) async {
    final nav = await pumpApp(tester);
    unawaited(nav.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('unnamed')),
    )));
    await tester.pumpAndSettle();

    expect(reports, hasLength(2));
    expect(reports.last['name'], isNotEmpty);
  });

  testWidgets('a rebuild is not a navigation event', (tester) async {
    await pumpApp(tester);
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [AudienzzNavigatorObserver()],
      routes: {'/': (_) => const Scaffold(body: Text('home rebuilt'))},
    ));
    await tester.pumpAndSettle();

    // The second MaterialApp installs a fresh observer, which reports its own
    // initial route. What must NOT happen is the first observer reporting again
    // for a rebuild of a route it already reported.
    expect(reports.where((r) => r['name'] == '/'), hasLength(2));
  });
}
