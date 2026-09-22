import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_nebula/components/ip_form_field.dart';
import 'package:mobile_nebula/screens/siteConfig/relay_screen.dart';

RelaySettings _settings({bool useRelays = true, bool amRelay = false, List<String> relays = const []}) =>
    RelaySettings(useRelays: useRelays, amRelay: amRelay, relays: List.of(relays));

void main() {
  Future<void> pumpRelayScreen(
    WidgetTester tester, {
    RelaySettings? settings,
    ValueChanged<RelaySettings>? onSave,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RelayScreen(
          settings: settings ?? _settings(),
          onSave: onSave,
        ),
      ),
    );
    await tester.pump();
  }

  group('RelayScreen', () {
    testWidgets('shows toggles and configured relays', (tester) async {
      await pumpRelayScreen(tester, settings: _settings(relays: ['10.1.1.1']));

      expect(find.text('Use relays'), findsOneWidget);
      expect(find.text('Act as relay'), findsOneWidget);
      expect(find.text('Nebula IPs of relays peers can use to reach this host.'), findsOneWidget);
      expect(find.byType(IPFormField), findsOneWidget);
      expect(find.text('Add another'), findsOneWidget);

      // use_relays defaults to on and am_relay to off, so exactly one checkmark
      expect(find.byIcon(Icons.check), findsOneWidget);

      // no edits yet, so no save button
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('toggling use relays and saving returns updated settings', (tester) async {
      RelaySettings? saved;
      await pumpRelayScreen(tester, onSave: (settings) => saved = settings);

      await tester.tap(find.text('Use relays'));
      await tester.pump();

      expect(find.text('Save'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.useRelays, false);
      expect(saved!.amRelay, false);
      expect(saved!.relays, isEmpty);
    });

    testWidgets('acting as relay hides the relay list and clears it on save', (tester) async {
      RelaySettings? saved;
      await pumpRelayScreen(tester, settings: _settings(relays: ['10.1.1.1']), onSave: (settings) => saved = settings);

      expect(find.byType(IPFormField), findsOneWidget);

      await tester.tap(find.text('Act as relay'));
      await tester.pump();

      expect(find.byType(IPFormField), findsNothing);
      expect(find.text('Unavailable while acting as a relay'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.useRelays, true);
      expect(saved!.amRelay, true);
      expect(saved!.relays, isEmpty);
    });

    testWidgets('add another appends a relay field', (tester) async {
      await pumpRelayScreen(tester);

      expect(find.byType(IPFormField), findsNothing);

      await tester.tap(find.text('Add another'));
      await tester.pump();

      expect(find.byType(IPFormField), findsOneWidget);
    });

    testWidgets('saving a typed relay address', (tester) async {
      RelaySettings? saved;
      await pumpRelayScreen(tester, onSave: (settings) => saved = settings);

      await tester.tap(find.text('Add another'));
      await tester.pump();

      await tester.enterText(
        find.descendant(of: find.byType(IPFormField), matching: find.byType(EditableText)),
        '10.1.1.5',
      );
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.relays, ['10.1.1.5']);
    });

    testWidgets('is read only when onSave is null', (tester) async {
      await pumpRelayScreen(tester, settings: _settings(relays: ['10.1.1.1']));

      expect(find.text('Add another'), findsNothing);
      expect(find.byIcon(Icons.remove_circle), findsNothing);

      await tester.tap(find.text('Use relays'));
      await tester.pump();

      expect(find.text('Save'), findsNothing);
    });
  });
}
