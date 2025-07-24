import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:zirahomes/main.dart';

void main() {
  testWidgets('WebView renders correctly', (WidgetTester tester) async {
    // Build the WebView app
    await tester.pumpWidget(const ZiraHomesApp());

    // Wait for the widget tree to settle
    await tester.pumpAndSettle();

    // Check that WebViewWidget exists in the widget tree
    expect(find.byType(WebViewWidget), findsOneWidget);
  });
}
