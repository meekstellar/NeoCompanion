import 'dart:convert';

class TokenSet {
  const TokenSet({
    required this.characterId,
    required this.characterName,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.scopes,
  });

  final int characterId;
  final String characterName;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final List<String> scopes;

  static const _expiryLeeway = Duration(seconds: 60);

  bool get isExpired => DateTime.now().isAfter(expiresAt.subtract(_expiryLeeway));

  TokenSet copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    return TokenSet(
      characterId: characterId,
      characterName: characterName,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      scopes: scopes,
    );
  }

  Map<String, dynamic> toJson() => {
        'characterId': characterId,
        'characterName': characterName,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
        'scopes': scopes,
      };

  factory TokenSet.fromJson(Map<String, dynamic> json) => TokenSet(
        characterId: json['characterId'] as int,
        characterName: json['characterName'] as String,
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        scopes: (json['scopes'] as List).cast<String>(),
      );

  String encode() => jsonEncode(toJson());

  factory TokenSet.decode(String raw) =>
      TokenSet.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
