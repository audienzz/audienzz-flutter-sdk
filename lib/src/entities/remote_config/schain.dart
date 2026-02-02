class Schain {
  const Schain({
    required this.sellerId,
    required this.advertisingSystemDomain,
  });

  factory Schain.fromJson(Map<String, dynamic> json) {
    return Schain(
      sellerId: json['sellerId'] as String,
      advertisingSystemDomain: json['advertisingSystemDomain'] as String,
    );
  }

  final String sellerId;
  final String advertisingSystemDomain;

  Map<String, dynamic> toJson() => {
        'sellerId': sellerId,
        'advertisingSystemDomain': advertisingSystemDomain,
      };
}
