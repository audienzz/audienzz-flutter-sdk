///Defines key-value pairs that convey specific units of data
final class DataObjectSegment {
  const DataObjectSegment({
    this.id,
    this.name,
    this.value,
  });

  /// ID of the data segment specific to the data provider.
  final String? id;

  /// Name of the data segment specific to the data provider.
  final String? name;

  /// String representation of the data segment value.
  final String? value;
}
