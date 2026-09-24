import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/ has no deprecated API use on the current Flutter SDK', () async {
    final result = await Process.run(
        'dart', ['analyze', '--format=machine', 'lib'],
        runInShell: true);
    final out = '${result.stdout}${result.stderr}';
    expect(out.contains('DEPRECATED_MEMBER_USE'), isFalse, reason: out);
    expect(out.toUpperCase().contains('|ERROR|'), isFalse, reason: out);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('lib/ avoids the Color getters deprecated in Flutter 3.27', () {
    // The analyzer test above is authoritative; this one is a quick guard
    // that does not need the SDK on PATH.
    final banned =
        RegExp(r'withOpacity\(|\.opacity\b|\.value\s*\.toRadixString');
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        expect(banned.hasMatch(line), isFalse,
            reason: '${f.path}:${i + 1}: $line');
      }
    }
  });
}
