/// Detailed layout of a single PI colony, returned by
/// `/characters/{id}/planets/{planet_id}/`.
class PlanetLayout {
  const PlanetLayout({
    required this.pins,
    required this.routes,
    required this.links,
  });

  final List<PlanetPin> pins;
  final List<PlanetRoute> routes;
  final List<PlanetLink> links;

  factory PlanetLayout.fromJson(Map<String, dynamic> json) {
    return PlanetLayout(
      pins: (json['pins'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(PlanetPin.fromJson)
          .toList(),
      routes: (json['routes'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(PlanetRoute.fromJson)
          .toList(),
      links: (json['links'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(PlanetLink.fromJson)
          .toList(),
    );
  }
}

/// One structure on a planet — command center, storage, launchpad,
/// extractor head, or factory. The `type_id` identifies the structure
/// itself; `schematicId` (factories) and `extractor` (extractor heads)
/// describe what's currently programmed on top.
class PlanetPin {
  const PlanetPin({
    required this.pinId,
    required this.typeId,
    required this.latitude,
    required this.longitude,
    required this.installTime,
    required this.expiryTime,
    required this.lastCycleStart,
    required this.schematicId,
    required this.extractor,
    required this.contents,
  });

  final int pinId;
  final int typeId;
  final double latitude;
  final double longitude;
  final DateTime? installTime;

  /// Set on extractor heads — when the program is scheduled to run dry.
  final DateTime? expiryTime;
  final DateTime? lastCycleStart;
  final int? schematicId;
  final ExtractorDetails? extractor;
  final List<PinContent> contents;

  factory PlanetPin.fromJson(Map<String, dynamic> json) {
    DateTime? parseOpt(Object? v) =>
        v is String && v.isNotEmpty ? DateTime.parse(v) : null;
    final ext = json['extractor_details'];
    final fac = json['factory_details'];
    return PlanetPin(
      pinId: (json['pin_id'] as num).toInt(),
      typeId: (json['type_id'] as num).toInt(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      installTime: parseOpt(json['install_time']),
      expiryTime: parseOpt(json['expiry_time']),
      lastCycleStart: parseOpt(json['last_cycle_start']),
      schematicId: (fac is Map ? fac['schematic_id'] : json['schematic_id'])
          as int?,
      extractor: ext is Map<String, dynamic>
          ? ExtractorDetails.fromJson(ext)
          : null,
      contents: (json['contents'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(PinContent.fromJson)
          .toList(),
    );
  }
}

class ExtractorDetails {
  const ExtractorDetails({
    required this.productTypeId,
    required this.cycleTime,
    required this.qtyPerCycle,
  });

  final int? productTypeId;
  final int? cycleTime;
  final int? qtyPerCycle;

  factory ExtractorDetails.fromJson(Map<String, dynamic> json) {
    return ExtractorDetails(
      productTypeId: (json['product_type_id'] as num?)?.toInt(),
      cycleTime: (json['cycle_time'] as num?)?.toInt(),
      qtyPerCycle: (json['qty_per_cycle'] as num?)?.toInt(),
    );
  }
}

class PinContent {
  const PinContent({required this.typeId, required this.amount});
  final int typeId;
  final int amount;

  factory PinContent.fromJson(Map<String, dynamic> json) {
    return PinContent(
      typeId: (json['type_id'] as num).toInt(),
      amount: (json['amount'] as num).toInt(),
    );
  }
}

class PlanetRoute {
  const PlanetRoute({
    required this.routeId,
    required this.sourcePinId,
    required this.destinationPinId,
    required this.contentTypeId,
    required this.quantity,
  });

  final int routeId;
  final int sourcePinId;
  final int destinationPinId;
  final int contentTypeId;
  final double quantity;

  factory PlanetRoute.fromJson(Map<String, dynamic> json) {
    return PlanetRoute(
      routeId: (json['route_id'] as num).toInt(),
      sourcePinId: (json['source_pin_id'] as num).toInt(),
      destinationPinId: (json['destination_pin_id'] as num).toInt(),
      contentTypeId: (json['content_type_id'] as num).toInt(),
      quantity: (json['quantity'] as num).toDouble(),
    );
  }
}

class PlanetLink {
  const PlanetLink({
    required this.sourcePinId,
    required this.destinationPinId,
    required this.linkLevel,
  });

  final int sourcePinId;
  final int destinationPinId;
  final int linkLevel;

  factory PlanetLink.fromJson(Map<String, dynamic> json) {
    return PlanetLink(
      sourcePinId: (json['source_pin_id'] as num).toInt(),
      destinationPinId: (json['destination_pin_id'] as num).toInt(),
      linkLevel: (json['link_level'] as num?)?.toInt() ?? 0,
    );
  }
}
