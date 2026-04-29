class AuthenticatedCharacter {
  const AuthenticatedCharacter({
    required this.id,
    required this.name,
    required this.scopes,
  });

  final int id;
  final String name;
  final List<String> scopes;
}
