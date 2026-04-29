import 'package:flutter_test/flutter_test.dart';

import 'package:neocom/core/config/app_config.dart';
import 'package:neocom/core/config/flavor.dart';
import 'package:neocom/main.dart';

void main() {
  testWidgets('App boots and shows placeholder', (tester) async {
    await tester.pumpWidget(
      NeocomApp(config: AppConfig.forFlavor(Flavor.dev)),
    );
    expect(find.text('Neocom'), findsOneWidget);
  });
}
