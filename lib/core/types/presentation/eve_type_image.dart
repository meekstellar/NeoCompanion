import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// CCP-served image variants for an inventory type. `icon` is the
/// 64-px square module/item icon, `render` is the rendered 3D model
/// used for ships.
enum EveTypeImageKind { icon, render }

/// Cached `<img>` for an EVE inventory type. Pulls from
/// images.evetech.net and reuses the project-wide CachedNetworkImage
/// disk cache, so the same icon resolves to the same blob across
/// screens.
class EveTypeImage extends StatelessWidget {
  const EveTypeImage({
    super.key,
    required this.typeId,
    this.kind = EveTypeImageKind.icon,
    this.size = 32,
    this.borderRadius,
  });

  final int typeId;
  final EveTypeImageKind kind;
  final double size;
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final variant = kind == EveTypeImageKind.icon ? 'icon' : 'render';
    // Granular dependency — only rebuilds on DPR change, not on every
    // MediaQuery field (orientation, keyboard inset, etc.).
    final pixel = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final clamped = _clampSize(pixel);
    final url =
        'https://images.evetech.net/types/$typeId/$variant?size=$clamped';
    // Cap the in-memory bitmap to avoid keeping a 1024px copy decoded for
    // a 32-px tile on a 4× device.
    final cachedSide = (size * 2).round();
    final placeholder = SizedBox(
      width: size,
      height: size,
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
    final image = CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      memCacheWidth: cachedSide,
      memCacheHeight: cachedSide,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.broken_image_outlined, size: 16),
      ),
    );
    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  /// images.evetech.net only serves powers-of-two between 32 and 1024.
  static int _clampSize(int requested) {
    const allowed = [32, 64, 128, 256, 512, 1024];
    for (final s in allowed) {
      if (s >= requested) return s;
    }
    return 1024;
  }
}
