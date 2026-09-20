import 'package:flutter_test/flutter_test.dart';

import 'package:devine_word/data/api_quran_repository.dart';
import 'package:devine_word/data/recitation_timing.dart';

void main() {
  test('LIVE probe: timings resolve for real ayat', () async {
    final service = RecitationTimingService();

    // 1) Does the real endpoint return parseable segments for a real ayah?
    for (final ref in ['94:6', '2:255', '1:1', '112:1']) {
      final timings = await service.forReference(ref);
      // ignore: avoid_print
      print('TIMINGS $ref -> ${timings?.length ?? 'null'} '
          '${timings?.map((t) => '${t.word}:${t.startMs}-${t.endMs}').join(' ')}');
    }

    // 2) What does a LIVE fetched ayah's text tokenise to, vs its segments?
    final repo = ApiQuranRepository();
    for (var i = 0; i < 8; i++) {
      final ayah = await repo.fetchRandomAyah();
      if (ayah == null) {
        // ignore: avoid_print
        print('LIVE fetch returned null');
        continue;
      }
      final timings = await service.forReference(ayah.reference);
      final tokens = ayah.arabic.split(RegExp(r'\s+'));
      var words = 0;
      for (final token in tokens) {
        for (final code in token.codeUnits) {
          if ((code >= 0x0621 && code <= 0x064A) ||
              (code >= 0x0670 && code <= 0x06D3)) {
            words++;
            break;
          }
        }
      }
      // ignore: avoid_print
      print('LIVE ${ayah.reference} textWords=$words '
          'segments=${timings?.length ?? 'null'} '
          'url=${ayah.recitationUrl}');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
