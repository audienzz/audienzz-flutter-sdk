class PrebidServer {
  const PrebidServer({
    required this.url,
    required this.accountId,
    required this.statusUrl,
  });

  factory PrebidServer.fromJson(Map<String, dynamic> json) {
    final accountIdRaw = json['accountId'];
    final accountId =
        accountIdRaw is int ? accountIdRaw.toString() : accountIdRaw as String;

    return PrebidServer(
      url: json['url'] as String,
      accountId: accountId,
      statusUrl: json['statusUrl'] as String,
    );
  }

  final String url;
  final String accountId;
  final String statusUrl;

  Map<String, dynamic> toJson() => {
        'url': url,
        'accountId': accountId,
        'statusUrl': statusUrl,
      };
}
