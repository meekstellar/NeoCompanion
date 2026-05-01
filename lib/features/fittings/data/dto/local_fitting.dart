import 'fitting.dart';

/// User-authored fitting that lives in the local app DB. Distinct from
/// [Fitting] (which is the ESI-side immutable representation) so the
/// editor can mutate it freely without round-tripping to CCP.
class LocalFitting {
  const LocalFitting({
    required this.id,
    required this.name,
    required this.description,
    required this.shipTypeId,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String description;
  final int shipTypeId;
  final List<FittingItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  LocalFitting copyWith({
    String? name,
    String? description,
    List<FittingItem>? items,
    DateTime? updatedAt,
  }) {
    return LocalFitting(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      shipTypeId: shipTypeId,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
