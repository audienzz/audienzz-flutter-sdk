import 'package:audienzz_sdk_flutter/audienzz_sdk_flutter.dart';
import 'package:audienzz_sdk_flutter_example/ad/example_banner_ad.dart';
import 'package:flutter/material.dart';

final class ListWithAdsExample extends StatelessWidget {
  const ListWithAdsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (_, index) {
        if (index % 10 == 0) {
          return ExampleBannerAd(
            id: index,
            adUnitId: '/96628199/testapp_publisher/banner_test_ad_unit',
            adConfigId: '15624474',
            adSize: AdSize(height: 50, width: 320),
          );
        }

        return Material(
          child: ListTile(
            title: Text(
                '''Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.'''),
          ),
        );
      },
      itemCount: 100,
    );
  }
}
