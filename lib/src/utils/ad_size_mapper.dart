import 'package:audienzz_sdk_flutter/src/entities/ad_size.dart';

class AdSizeMapper {
  AdSizeMapper._();

  static Set<AdSize> map(List<String> adSizes) {
    final sizes = <AdSize>{};
    for (final sizeString in adSizes) {
      final parts = sizeString.toLowerCase().split('x');
      if (parts.length == 2) {
        final width = int.tryParse(parts[0]);
        final height = int.tryParse(parts[1]);
        if (width != null && height != null) {
          sizes.add(AdSize(width: width, height: height));
        }
      }
    }
    return sizes;
  }
}
