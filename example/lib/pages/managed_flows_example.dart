import 'dart:async';

import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

/// Every managed flow the reviews asked about, in one screen, each reachable in two taps.
///
/// Navigation is real `Navigator` pushes under [AudienzzNavigatorObserver], so focus behaves
/// exactly as it does in an app — the ad-free destination genuinely releases, and returning
/// genuinely recreates.
///
/// Each action logs one `AUDZ app …` line, so a captured log reads back as a sequence without
/// anyone having to remember what they tapped.
class ManagedFlowsExample extends StatelessWidget {
  const ManagedFlowsExample({required this.configId, super.key});

  final String configId;

  void _push(BuildContext context, String name, Widget page) {
    AudienzzDiagnostics.logAppAction('navigate', {'to': name});
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (_) => page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Managed test flows')),
        body: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Each entry is one of the flows under review. Capture the log with '
                '`flutter logs | grep AUDZ` while you walk through them.',
              ),
            ),
            _Tile(
              title: 'Article (scrolling, 2 slots, cover, pause)',
              subtitle: 'Scroll a slot off and back; report a cover; pause refresh',
              onTap: () => _push(context, 'article-1',
                  _ArticlePage(configId: configId, label: 'article-1')),
            ),
            _Tile(
              title: 'A second article with the same name',
              subtitle: 'Two routes called "article" must own their banners separately',
              onTap: () => _push(context, 'article-2',
                  _ArticlePage(configId: configId, label: 'article-2')),
            ),
            _Tile(
              title: 'Ad-free destination',
              subtitle: 'Push from an article and come back: release, then recreate',
              onTap: () => _push(context, 'settings', const _AdFreePage()),
            ),
            _Tile(
              title: 'Article whose content arrives after 3s',
              subtitle: 'Navigate away before it lands — it must not reclaim the foreground',
              onTap: () => _push(context, 'article-delayed',
                  _DelayedArticlePage(configId: configId)),
            ),
            _Tile(
              title: 'Retained tabs',
              subtitle: 'Both tabs stay built; only the selected one owns an ad',
              onTap: () => _push(context, 'tabs', _TabsPage(configId: configId)),
            ),
          ],
        ),
      );
}

/// A scrolling article with two in-content slots, a host-reported cover and a publisher pause.
class _ArticlePage extends StatefulWidget {
  const _ArticlePage({required this.configId, required this.label});

  final String configId;
  final String label;

  @override
  State<_ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<_ArticlePage> {
  final _controller = AudienzzBannerController();
  bool _covered = false;
  bool _paused = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleCover() async {
    final next = !_covered;
    AudienzzDiagnostics.logAppAction('cover', {'slot': 'in-content-1', 'covered': next});
    // Geometry and hit testing cannot see a pointer-transparent veil, so the host reports it.
    await _controller.reportCover(covered: next);
    setState(() => _covered = next);
  }

  Future<void> _togglePause() async {
    final next = !_paused;
    AudienzzDiagnostics.logAppAction('publisherPause', {'slot': 'in-content-1', 'paused': next});
    if (next) {
      await _controller.stopAutoRefresh();
    } else {
      await _controller.resumeAutoRefresh();
    }
    setState(() => _paused = next);
  }

  @override
  Widget build(BuildContext context) => AudienzzPage(
        name: 'article',
        child: Scaffold(
          appBar: AppBar(title: Text(widget.label)),
          body: ListView(
            children: [
              OverflowBar(
                alignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _toggleCover,
                    child: Text(_covered ? 'Remove cover' : 'Report cover'),
                  ),
                  OutlinedButton(
                    onPressed: _togglePause,
                    child: Text(_paused ? 'Resume refresh' : 'Pause refresh'),
                  ),
                ],
              ),
              Stack(
                children: [
                  AudienzzBanner(
                    adConfigId: widget.configId,
                    slotKey: 'in-content-1',
                    placeholderHeight: 250,
                    controller: _controller,
                  ),
                  if (_covered)
                    // A painted veil: visible to the reader, invisible to any geometry check.
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: Color(0x8C000000),
                          child: Center(
                            child: Text('covered by the host',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const _Body(),
              const _Body(),
              // Far enough down that reaching it is a real scroll — the offscreen-return case.
              AudienzzBanner(
                adConfigId: widget.configId,
                slotKey: 'in-content-2',
                placeholderHeight: 250,
              ),
              const _Body(),
            ],
          ),
        ),
      );
}

/// An ad-free destination. Reporting it is what releases the previous page's banners.
class _AdFreePage extends StatelessWidget {
  const _AdFreePage();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings (ad-free)')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No ads here. Going back should release the article\'s banners and recreate them '
              'for the new visit — watch for `slot release` then `slot recreate`.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}

/// The article's body — and its ad slots — arrive after the route does, which is what a real
/// article screen does while it fetches. Navigate away before it lands.
class _DelayedArticlePage extends StatefulWidget {
  const _DelayedArticlePage({required this.configId});

  final String configId;

  @override
  State<_DelayedArticlePage> createState() => _DelayedArticlePageState();
}

class _DelayedArticlePageState extends State<_DelayedArticlePage> {
  bool _ready = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    AudienzzDiagnostics.logAppAction('delayedContent.start', {'seconds': 3});
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      AudienzzDiagnostics.logAppAction('delayedContent.arrived');
      setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Delayed article')),
        body: _ready
            ? AudienzzPage(
                name: 'article',
                child: ListView(
                  children: [
                    AudienzzBanner(
                      adConfigId: widget.configId,
                      slotKey: 'in-content-1',
                      placeholderHeight: 250,
                    ),
                    const _Body(),
                  ],
                ),
              )
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Loading article… Pop this route now: when the content lands it must NOT '
                    'reclaim the foreground or create an ad.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
      );
}

/// Two tabs on one route. Both stay built; only the selected one owns an ad.
class _TabsPage extends StatefulWidget {
  const _TabsPage({required this.configId});

  final String configId;

  @override
  State<_TabsPage> createState() => _TabsPageState();
}

class _TabsPageState extends State<_TabsPage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Retained tabs')),
        body: Column(
          children: [
            OverflowBar(
              alignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 2; i++)
                  OutlinedButton(
                    onPressed: () {
                      AudienzzDiagnostics.logAppAction('selectTab', {'tab': 'tab-$i'});
                      setState(() => _selected = i);
                    },
                    child: Text(_selected == i ? '• Tab $i' : 'Tab $i'),
                  ),
              ],
            ),
            Expanded(
              child: IndexedStack(
                index: _selected,
                children: [
                  for (var i = 0; i < 2; i++)
                    // One page per tab, and only the selected one is active. Two retained tabs
                    // are two screens; sharing the route's identity would merge them.
                    AudienzzPage(
                      name: 'tab-$i',
                      active: _selected == i,
                      child: ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('Tab $i — both tabs stay built.'),
                          ),
                          AudienzzBanner(
                            adConfigId: widget.configId,
                            slotKey: 'tab-$i-slot',
                            placeholderHeight: 250,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.title, required this.subtitle, required this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      );
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras at ultricies ante. '
          'Ut nulla nunc, feugiat sed turpis ut, eleifend sodales ligula. Duis viverra congue '
          'magna, ac egestas risus facilisis ac. Aenean eget velit vitae libero malesuada luctus. '
          'Aliquam elementum dignissim viverra. Morbi a lacus dolor. Quisque sapien lorem, '
          'scelerisque vitae neque non, rutrum finibus turpis.',
        ),
      );
}
