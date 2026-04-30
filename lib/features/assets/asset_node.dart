import 'data/dto/asset_item.dart';

/// Node in the rendered asset tree. Wraps one [AssetItem] plus its
/// direct children (other items whose `locationId` equals this node's
/// `itemId`). Construction is one in-memory pass over the flat ESI
/// list; see [buildAssetTree].
class AssetNode {
  AssetNode(this.item, {List<AssetNode>? children})
      : children = children ?? <AssetNode>[];

  final AssetItem item;
  final List<AssetNode> children;

  /// Total number of leaf+branch entries below this node, recursively.
  /// Cached on first read; the tree is immutable from the UI's
  /// perspective so caching is safe.
  int get totalDescendants {
    return _totalDescendants ??= _computeTotal();
  }

  int? _totalDescendants;
  int _computeTotal() {
    var n = children.length;
    for (final c in children) {
      n += c.totalDescendants;
    }
    return n;
  }
}

class AssetTree {
  const AssetTree({required this.rootsByLocation});

  /// Top-level nodes grouped by their outermost station / system /
  /// structure id. Each list contains items directly anchored at that
  /// location (loose items + ships + containers); descendants live in
  /// `node.children` recursively.
  final Map<int, List<AssetNode>> rootsByLocation;
}

/// Builds the recursive container tree out of a flat ESI asset list.
/// One pass to wrap each item in a node keyed by id, a second to link
/// each node into its parent's `children` list (when the parent is in
/// our map), and the leftovers — items whose `locationId` isn't a
/// known asset — become roots grouped by location id (station /
/// system / structure).
AssetTree buildAssetTree(List<AssetItem> items) {
  final byId = <int, AssetNode>{
    for (final item in items) item.itemId: AssetNode(item),
  };
  final rootsByLocation = <int, List<AssetNode>>{};
  for (final node in byId.values) {
    final parent = byId[node.item.locationId];
    if (parent != null) {
      parent.children.add(node);
    } else {
      rootsByLocation
          .putIfAbsent(node.item.locationId, () => <AssetNode>[])
          .add(node);
    }
  }
  return AssetTree(rootsByLocation: rootsByLocation);
}
