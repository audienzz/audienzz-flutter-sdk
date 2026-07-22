import 'package:audienzz_sdk_flutter_example/pages/remote_banner_ad_example.dart';
import 'package:flutter/material.dart';

/// Mirrors a publisher's article page: long-form text with in-content banner
/// ads interspersed between paragraphs (like in_content_1..5).
///
/// Recommended 0.1.6 integration: each ad is created **eagerly** (no
/// visibility gating), so every slot loads. The SDK's [AdWidget] handles
/// smart-refresh pausing for off-screen / covered / backgrounded slots — no
/// app-side visibility timers or pause/resume calls needed.
class ArticleInContentExample extends StatelessWidget {
  const ArticleInContentExample({super.key});

  /// Publisher 35 in-content banner slots (in_content_1..5 equivalents).
  static const _adConfigIds = ['46', '48', '49', '50', '46'];

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      const _Headline(),
      const SizedBox(height: 8),
      const _Byline(),
      const SizedBox(height: 20),
    ];

    var adIndex = 0;
    for (var i = 1; i <= 15; i++) {
      rows.add(_Paragraph(index: i));
      rows.add(const SizedBox(height: 16));

      // In-content ad after every 3rd paragraph → 5 ads total.
      if (i % 3 == 0 && adIndex < _adConfigIds.length) {
        rows.add(_InContentAd(
          configId: _adConfigIds[adIndex],
          slot: adIndex + 1,
        ));
        rows.add(const SizedBox(height: 16));
        adIndex++;
      }
    }

    // SingleChildScrollView + Column builds ALL rows eagerly (no viewport
    // virtualization), so every in-content ad mounts and loads immediately —
    // the recommended 0.1.6 pattern. (A lazy ListView.builder would only load
    // ads as they scroll into view.)
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) => const Text(
        'Wie sich der Verkehr in der Innenstadt in den nächsten Jahren '
        'verändern wird',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
      );
}

class _Byline extends StatelessWidget {
  const _Byline();

  @override
  Widget build(BuildContext context) => const Text(
        'Von der Redaktion · 6 Min. Lesezeit',
        style: TextStyle(fontSize: 13, color: Colors.black54),
      );
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.index});

  final int index;

  static const _texts = [
    'Die Debatte um die Zukunft der Mobilität nimmt Fahrt auf. Städte weltweit '
        'experimentieren mit neuen Konzepten, um Staus zu reduzieren und die '
        'Luftqualität zu verbessern.',
    'Experten sind sich einig, dass ein Umdenken notwendig ist. Der '
        'Individualverkehr allein wird die wachsenden Anforderungen nicht mehr '
        'bewältigen können.',
    'Öffentliche Verkehrsmittel spielen dabei eine Schlüsselrolle. Investitionen '
        'in Bus- und Bahnnetze zahlen sich langfristig aus, sowohl ökologisch '
        'als auch ökonomisch.',
    'Gleichzeitig gewinnen Fahrräder und E-Scooter an Bedeutung. Immer mehr '
        'Kommunen bauen ihre Radwegenetze aus und schaffen so Alternativen zum '
        'Auto.',
    'Kritiker warnen jedoch vor überstürzten Entscheidungen. Eine gute '
        'Infrastruktur brauche Zeit, Geld und die Akzeptanz der Bevölkerung.',
  ];

  @override
  Widget build(BuildContext context) => Text(
        _texts[(index - 1) % _texts.length],
        style: const TextStyle(fontSize: 16, height: 1.5),
      );
}

class _InContentAd extends StatelessWidget {
  const _InContentAd({required this.configId, required this.slot});

  final String configId;
  final int slot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: const Color(0xFFF2F2F2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'ANZEIGE · in_content_$slot (config $configId)',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              color: Colors.black45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Eager: RemoteBannerAdExample creates + loads its loader immediately.
        Center(child: RemoteBannerAdExample(configId: configId)),
      ],
    );
  }
}
