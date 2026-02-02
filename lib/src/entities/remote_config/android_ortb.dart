class AndroidOrtb {
  const AndroidOrtb({
    required this.bundleName,
    required this.storeUrl,
  });

  factory AndroidOrtb.fromJson(Map<String, dynamic> json) {
    return AndroidOrtb(
      bundleName: json['bundleName'] as String?,
      storeUrl: json['storeUrl'] as String?,
    );
  }

  final String? bundleName;
  final String? storeUrl;

  Map<String, dynamic> toJson() => {
        'bundleName': bundleName,
        'storeUrl': storeUrl,
      };
}
