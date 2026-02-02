class RemoteAdConfigData {
  const RemoteAdConfigData({
    required this.adType,
    this.refreshTimeSeconds,
  });

  factory RemoteAdConfigData.fromJson(Map<String, dynamic> json) {
    return RemoteAdConfigData(
      adType: json['adType'] as String,
      refreshTimeSeconds: json['refreshTimeSeconds'] as int?,
    );
  }

  final String adType;
  final int? refreshTimeSeconds;

  Map<String, dynamic> toJson() => {
        'adType': adType,
        if (refreshTimeSeconds != null)
          'refreshTimeSeconds': refreshTimeSeconds,
      };
}
