/// Class for describing reward item received from rewarded ad
final class RewardItem {
  const RewardItem({
    required this.amount,
    required this.type,
  });

  /// Amount of the reward item
  final num amount;

  /// Type of the reward item
  final String type;
}
