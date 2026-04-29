class CharacterPortrait {
  const CharacterPortrait({
    required this.px64,
    required this.px128,
    required this.px256,
    required this.px512,
  });

  final String px64;
  final String px128;
  final String px256;
  final String px512;

  factory CharacterPortrait.fromJson(Map<String, dynamic> json) {
    return CharacterPortrait(
      px64: json['px64x64'] as String,
      px128: json['px128x128'] as String,
      px256: json['px256x256'] as String,
      px512: json['px512x512'] as String,
    );
  }
}
