import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter_example/pages/remote_banner_ad_example.dart';
import 'package:flutter/material.dart';

final class ListWithAdsExample extends StatefulWidget {
  const ListWithAdsExample({super.key});

  @override
  State<ListWithAdsExample> createState() => _ListWithAdsExampleState();
}

final class _ListWithAdsExampleState extends State<ListWithAdsExample> {
  final ScrollController _scrollController = ScrollController();
  static const _adSlots = <int>{5, 10, 15, 20, 25};
  static const _configIds = ['46', '48', '49', '50'];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      const Text(
        'Sticky Ad Example',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      const Text(
        'Scroll down — each banner stays pinned within its reserved area as you scroll past it, then exits at the bottom.',
        style: TextStyle(fontSize: 14, color: Colors.black54),
      ),
      const SizedBox(height: 16),
    ];

    var adIndex = 0;
    for (var i = 1; i <= 30; i++) {
      rows.add(_ArticleParagraph(index: i));

      if (_adSlots.contains(i)) {
        final configId = _configIds[adIndex % _configIds.length];
        adIndex++;
        rows.add(
          AudienzzStickyAdWrapper(
            scrollController: _scrollController,
            stickyTopOffset: 0,
            maxHeight: 450,
            child: RemoteBannerAdExample(configId: configId),
          ),
        );
        rows.add(const SizedBox(height: 16));
      }
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: rows,
    );
  }
}

final class _ArticleParagraph extends StatelessWidget {
  const _ArticleParagraph({required this.index});

  final int index;

  static const _lorem =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. '
      'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Paragraph $index — $_lorem',
        style: const TextStyle(fontSize: 14, height: 1.35),
      ),
    );
  }
}
