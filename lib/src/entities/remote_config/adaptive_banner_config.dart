enum WidthStrategy {
  fullWidth('FULL_WIDTH'),
  custom('CUSTOM');

  const WidthStrategy(this.value);

  final String value;

  static WidthStrategy? fromValue(String? value) {
    if (value == null) {
      return null;
    }
    try {
      return WidthStrategy.values.firstWhere((e) => e.value == value);
    } on Object catch (_) {
      return null;
    }
  }
}

class AdaptiveBannerConfig {
  const AdaptiveBannerConfig({
    required this.enabled,
    this.type,
    this.widthStrategy,
    this.customWidth,
    this.maxHeight,
    this.orientationHandling,
    this.includeReservationSizes,
  });

  factory AdaptiveBannerConfig.fromJson(Map<String, dynamic> json) {
    return AdaptiveBannerConfig(
      enabled: json['enabled'] as bool? ?? false,
      type: json['type'] as String?,
      widthStrategy: WidthStrategy.fromValue(json['widthStrategy'] as String?),
      customWidth: (json['customWidth'] as num?)?.toDouble(),
      maxHeight: (json['maxHeight'] as num?)?.toDouble(),
      orientationHandling: json['orientationHandling'] as String?,
      includeReservationSizes: json['includeReservationSizes'] as bool?,
    );
  }

  final bool enabled;
  final String? type;
  final WidthStrategy? widthStrategy;
  final double? customWidth;
  final double? maxHeight;
  final String? orientationHandling;
  final bool? includeReservationSizes;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (type != null) 'type': type,
        if (widthStrategy != null) 'widthStrategy': widthStrategy!.value,
        if (customWidth != null) 'customWidth': customWidth,
        if (maxHeight != null) 'maxHeight': maxHeight,
        if (orientationHandling != null)
          'orientationHandling': orientationHandling,
        if (includeReservationSizes != null)
          'includeReservationSizes': includeReservationSizes,
      };
}
