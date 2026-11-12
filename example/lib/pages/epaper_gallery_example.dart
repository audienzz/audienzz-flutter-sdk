import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

/// An ePaper: one tile per printed page, swiped horizontally, with two ad
/// tiles. [AudienzzGalleryAds] requests each ad tile's banner when the reader is
/// within the ad config's `config.preloadDistancePages` (2 by default) of it,
/// not when the ePaper opens and not when the tile is built.
///
/// Tap a printed page to open its article on top, then go back: the gallery
/// ads are kept, not reloaded (`AUDZ gallery hold` on the way out, no new
/// request on the way back).
///
/// Turn diagnostics on to follow it: `AUDZ gallery preload slot=… readerPage=…`
/// when a slot requests, `AUDZ gallery retire …` when it is released.
class EpaperGalleryExample extends StatefulWidget {
  const EpaperGalleryExample({required this.configId, super.key});

  final String configId;

  @override
  State<EpaperGalleryExample> createState() => _EpaperGalleryExampleState();
}

class _EpaperGalleryExampleState extends State<EpaperGalleryExample> {
  static const _tileCount = 16;
  final _controller = PageController();
  final _status = <String, String>{};
  int _page = 0;

  late final List<AudienzzGalleryAdSlot> _slots = [
    AudienzzGalleryAdSlot(
      slotKey: 'epaper-1',
      adConfigId: widget.configId,
      pageIndex: 4,
    ),
    AudienzzGalleryAdSlot(
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

  AudienzzGalleryAdSlot? _slotAt(int index) {
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
                  '${AudienzzGalleryAds.preloadDistanceFor(widget.configId)} '
                  'pages. ${_slots.map((s) => '${s.slotKey}: '
                      '${_status[s.slotKey] ?? 'not requested'}').join(' · ')}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Expanded(
                child: AudienzzGalleryAds(
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
                        return AudienzzGalleryAd(
                          slotKey: slot.slotKey,
                          placeholder: const Center(
                            child: Text('Ad not loaded yet'),
                          ),
                        );
                      }
                      return _Tile(
                        index: index,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            // Named, so the navigator observer reports it as
                            // its own page, as a real article view would be.
                            settings: const RouteSettings(name: 'ePaper article'),
                            builder: (_) => _Article(page: index + 1),
                          ),
                        ),
                      );
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
  const _Tile({required this.index, required this.onTap});

  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(12),
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: Text(
            'Printed page ${index + 1}\n(tap for the article)',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      );
}

/// The mobile article view opened from a printed page. Ad-free here; it is its
/// own page, so opening it makes the ePaper page inactive.
class _Article extends StatelessWidget {
  const _Article({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Article from page $page')),
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Go back: the ePaper ad you saw is still there, no new request.',
          ),
        ),
      );
}
