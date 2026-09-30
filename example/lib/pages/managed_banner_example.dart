import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:flutter/material.dart';

/// The complete managed integration. This is the pattern to copy.
///
/// The publisher places one widget per slot. There is no loader, no `load()`,
/// no reload after a page impression or an app resume, and no disposal:
/// [AudienzzPage] owns the page identity and [AudienzzBanner] owns the slot's
/// whole lifetime, including reserving its height before anything is requested.
///
/// Focus comes from the navigator. Push another route and this page's banners
/// stand down; come back and they return. Nothing here has to know about that.
class ManagedBannerExample extends StatelessWidget {
  const ManagedBannerExample({required this.configId, super.key});

  final String configId;

  @override
  Widget build(BuildContext context) => AudienzzPage(
        name: 'article',
        child: Scaffold(
          appBar: AppBar(title: const Text('Managed banner (recommended)')),
          body: ListView(
            children: [
              const _Body(),
              // Reserves its height immediately and loads as it nears the
              // viewport, so scrolling past does not reflow the article.
              AudienzzBanner(
                adConfigId: configId,
                slotKey: 'in-content-1',
                placeholderHeight: 250,
              ),
              const _Body(),
              // Same configuration id, different slot: the slot key is what
              // tells two placements of one unit apart.
              AudienzzBanner(
                adConfigId: configId,
                slotKey: 'in-content-2',
                placeholderHeight: 250,
              ),
              const _Body(),
            ],
          ),
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Scroll past a banner and back to watch it pause and resume. Leave '
          'this route for an ad-free one and return: the banners are released '
          'and recreated for the new visit, without any code on this page.\n\n'
          'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras at '
          'ultricies ante. Ut nulla nunc, feugiat sed turpis ut, eleifend '
          'sodales ligula. Duis viverra congue magna, ac egestas risus '
          'facilisis ac. Aenean eget velit vitae libero malesuada luctus. '
          'Aliquam elementum dignissim viverra. Morbi a lacus dolor. Quisque '
          'sapien lorem, scelerisque vitae neque non, rutrum finibus turpis.',
        ),
      );
}

/// An ad-free destination, so the A -> B -> A sequence can be exercised.
///
/// Reporting this route is what releases the previous page's banners. The
/// navigator observer does it; this page carries no ad code at all.
class AdFreeExample extends StatelessWidget {
  const AdFreeExample({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ad-free destination')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No ads here. Going back should give the previous screen a fresh '
              'page impression and a fresh creative.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
