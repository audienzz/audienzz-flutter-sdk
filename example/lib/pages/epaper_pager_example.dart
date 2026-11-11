import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

/// An ePaper: one tile per printed page, swiped horizontally, with two ad
/// tiles. [AudienzzPagerAds] requests each ad tile's banner when the reader is
/// within the ad config's `config.preloadDistancePages` (2 by default) of it,
/// not when the ePaper opens and not when the tile is built.
///
/// Turn diagnostics on to follow it: `AUDZ pager preload slot=… readerPage=…`
/// when a slot requests, `AUDZ pager retire …` when it is released.
class EpaperPagerExample extends StatefulWidget {
  const EpaperPagerExample({required this.configId, super.key});

  final String configId;

  @override
  State<EpaperPagerExample> createState() => _EpaperPagerExampleState();
}

class _EpaperPagerExampleState extends State<EpaperPagerExample> {
  static const _tileCount = 16;
  final _controller = PageController();
  final _status = <String, String>{};
  int _page = 0;

  late final List<AudienzzPagerAdSlot> _slots = [
    AudienzzPagerAdSlot(
      slotKey: 'epaper-1',
      adConfigId: widget.configId,
      pageIndex: 4,
    ),
    AudienzzPagerAdSlot(
      slotKey: 'epaper-2',
      adConfigId: widget.configId,
      pageIndex: 12,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  AudienzzPagerAdSlot? _slotAt(int index) {
    for (final slot in _slots) {
      if (slot.pageIndex == index) return slot;
    }
    return null;
  }

  void _setStatus(String slotKey, String status) {
    if (mounted) setState(() => _status[slotKey] = status);
  }

  @override
  Widget build(BuildContext context) => AudienzzPage(
        name: 'epaper',
        child: Scaffold(
          appBar: AppBar(
            title: Text('ePaper — page ${_page + 1}/$_tileCount'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Ads on pages 5 and 13. Preload distance: '
                  '${AudienzzPagerAds.preloadDistanceFor(widget.configId)} '
                  'pages. ${_slots.map((s) => '${s.slotKey}: '
                      '${_status[s.slotKey] ?? 'not requested'}').join(' · ')}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: AudienzzPagerAds(
                  controller: _controller,
                  slots: _slots,
                  onAdLoaded: (key) => _setStatus(key, 'loaded'),
                  onAdFailedToLoad: (key, error) =>
                      _setStatus(key, 'failed (${error?.message ?? ''})'),
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _tileCount,
                    onPageChanged: (page) => setState(() => _page = page),
                    itemBuilder: (context, index) {
                      final slot = _slotAt(index);
                      if (slot != null) {
                        return AudienzzPagerAd(
                          slotKey: slot.slotKey,
                          placeholder: const Center(
                            child: Text('Ad not loaded yet'),
                          ),
                        );
                      }
                      return _Tile(index: index);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(12),
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Text(
          'Printed page ${index + 1}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      );
}
