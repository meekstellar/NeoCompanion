/// Pure helper: which scopes from [required] are not present in [have]?
/// Used to detect characters that need re-authorization when the app's
/// scope list grows beyond what was granted at the original sign-in.
List<String> missingScopes({
  required Iterable<String> have,
  required Iterable<String> required,
}) {
  final present = have.toSet();
  return required.where((r) => !present.contains(r)).toList();
}
