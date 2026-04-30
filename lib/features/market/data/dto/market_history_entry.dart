/// One daily row from `/markets/{region}/history/?type_id=`.
/// `average` is what most callers actually plot; `highest`/`lowest` are
/// the day's extremes; `volume` is unit count traded; `orderCount` the
/// number of distinct orders involved.
class MarketHistoryEntry {
  const MarketHistoryEntry({
    required this.date,
    required this.average,
    required this.highest,
    required this.lowest,
    required this.volume,
    required this.orderCount,
  });

  final DateTime date;
  final double average;
  final double highest;
  final double lowest;
  final int volume;
  final int orderCount;

  factory MarketHistoryEntry.fromJson(Map<String, dynamic> json) {
    return MarketHistoryEntry(
      date: DateTime.parse(json['date'] as String),
      average: (json['average'] as num).toDouble(),
      highest: (json['highest'] as num).toDouble(),
      lowest: (json['lowest'] as num).toDouble(),
      volume: (json['volume'] as num).toInt(),
      orderCount: (json['order_count'] as num).toInt(),
    );
  }
}
