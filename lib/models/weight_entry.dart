class WeightEntry {
  final String id;
  final DateTime date;
  final double kg;

  WeightEntry({required this.id, required this.date, required this.kg});

  factory WeightEntry.fromMap(Map<String, dynamic> map) => WeightEntry(
        id: map['id'] as String,
        date: DateTime.parse(map['date'] as String),
        kg: (map['kg'] as num).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String().substring(0, 10),
        'kg': kg,
      };
}
