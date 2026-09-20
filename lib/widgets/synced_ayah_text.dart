import 'dart:async';

import 'package:flutter/material.dart';

import '../data/recitation_timing.dart';
import '../design/tokens.dart';
import '../services/audio_service.dart';

/// The ayah's Arabic text with real-time recitation highlighting: the word
/// currently being recited is emphasised with a green stroke outline
/// (`Dw.ayahGreen` via `TextStyle.foreground` with `PaintingStyle.stroke`),
/// while the rest of the ayah keeps the default ink (`#101010` when no
/// explicit style colour is given). The recited word keeps the same font
/// weight and fill as the rest of the ayah — the emphasis comes from the
/// green outline, not from a heavier weight or a container highlight.
///
/// The text is tokenised on whitespace; pause marks and other letter-less
/// fragments render as-is but are skipped in the word→timing mapping, so
/// the tokens line up with the recitation dataset's orthographic words.
/// When timings are unavailable (offline design ayat, fetch failure) the
/// text renders exactly as before; when the dataset's word numbering differs
/// from the text's, the words are mapped onto it proportionally so the
/// highlight still follows the recitation.
class SyncedAyahText extends StatefulWidget {
  const SyncedAyahText({
    super.key,
    required this.arabic,
    required this.reference,
    required this.audioUrl,
    required this.style,
    this.textDirection = TextDirection.rtl,
    this.textAlign = TextAlign.center,
    this.timingsService,
    this.positionStream,
  });

  final String arabic;

  /// `surah:ayah` of the displayed text — used to fetch timings.
  final String reference;

  /// Recitation stream of this ayah — the highlight only follows the
  /// player while it is buffering this exact URL.
  final String audioUrl;
  final TextStyle style;
  final TextDirection textDirection;
  final TextAlign textAlign;

  /// Injectable for tests; defaults to the shared [RecitationTimingService].
  final RecitationTimingService? timingsService;

  /// Injectable for tests; defaults to the audio service's position ticks.
  final Stream<Duration>? positionStream;

  @override
  State<SyncedAyahText> createState() => _SyncedAyahTextState();
}

class _SyncedAyahTextState extends State<SyncedAyahText> {
  List<AyahWordTiming>? _timings;
  bool _fetching = false;
  String _requestedReference = '';
  StreamSubscription<Duration>? _positionSub;
  final ValueNotifier<int> _activeWord = ValueNotifier<int>(-1);

  // TEMP-DEBUG: heartbeat counters (immune to dropped log lines).
  static int _inits = 0;
  static int _disposes = 0;
  static int _ticks = 0;
  Timer? _heartbeat;

  @override
  void initState() {
    super.initState();
    // TEMP-DEBUG
    _inits++;
    _heartbeat = Timer.periodic(const Duration(seconds: 2), (_) {
      debugPrint(
        'DW-HEART inits=$_inits disposes=$_disposes ticks=$_ticks '
        'live=${_activeWord.value} timings=${_timings?.length} '
        'thisAyah=${AudioService.instance.loadedUrl == widget.audioUrl} '
        'raw=${AudioService.instance.debugTicks} '
        'pstate=${AudioService.instance.debugPstate} '
        'ref=${widget.reference}',
      );
    });
    _loadTimings();
    _listenPosition();
  }

  @override
  void didUpdateWidget(covariant SyncedAyahText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // TEMP-DEBUG
    debugPrint(
      'DW-UPDATE $hashCode ${oldWidget.reference}->${widget.reference}',
    );
    if (widget.reference != oldWidget.reference) {
      _timings = null;
      _activeWord.value = -1;
      _loadTimings();
    }
  }

  @override
  void dispose() {
    // TEMP-DEBUG
    _disposes++;
    debugPrint('DW-DISPOSE $hashCode\n${StackTrace.current}');
    _heartbeat?.cancel();
    _positionSub?.cancel();
    _activeWord.dispose();
    super.dispose();
  }

  void _loadTimings() {
    final reference = widget.reference;
    if (_fetching || _requestedReference == reference) return;
    _requestedReference = reference;
    _fetching = true;
    final service = widget.timingsService ?? RecitationTimingService.instance;
    service.forReference(reference).then((timings) {
      _fetching = false;
      if (!mounted || _requestedReference != reference) return;
      // TEMP-DEBUG
      debugPrint('DW-TIMINGS $reference -> ${timings?.length}');
      setState(() => _timings = timings);
    });
  }

  void _listenPosition() {
    final stream =
        widget.positionStream ?? AudioService.instance.positionStream;
    _positionSub = stream.listen((position) {
      final timings = _timings;
      if (timings == null || timings.isEmpty) return;
      // Follow only while the buffered recitation is this ayah's audio.
      final isThisAyah = AudioService.instance.loadedUrl == widget.audioUrl;
      final index = isThisAyah
          ? activeWordIndex(timings, position.inMilliseconds)
          : -1;
      if (_activeWord.value != index) {
        // TEMP-DEBUG
        _ticks++;
        _activeWord.value = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final timings = _timings;
    if (timings == null || timings.isEmpty) {
      // TEMP-DEBUG
      debugPrint(
        'DW-BUILD $hashCode PLAIN ref=${widget.reference} '
        'timings=${timings?.length}',
      );
      return _plain();
    }
    final tokens = widget.arabic.split(RegExp(r'\s+'));
    final tokenWords = List<int>.filled(tokens.length, -1);
    var wordCount = 0;
    for (var i = 0; i < tokens.length; i++) {
      if (_hasArabicLetter(tokens[i])) {
        wordCount++;
        tokenWords[i] = wordCount;
      }
    }
    if (wordCount == 0) return _plain();
    // TEMP-DEBUG
    debugPrint(
      'DW-BUILD $hashCode RICH ref=${widget.reference} '
      'timings=${timings.length} words=$wordCount '
      'map=${segmentWordsForTextWords(timings, wordCount)} '
      'active=${_activeWord.value} '
      'url=${widget.audioUrl} loaded=${AudioService.instance.loadedUrl}',
    );
    // The recitation's word numbering need not match the displayed text's —
    // a few ayat carry more segments than words (a word recited across
    // several segments) and some text editions add words the audio does not
    // cover. Map the display words onto the timing words so the highlight
    // always follows the recitation instead of being switched off.
    final segmentForWord = segmentWordsForTextWords(timings, wordCount);
    // Default Arabic text colour when the caller does not specify one:
    // `Dw.arabicBase` (~#101010). The highlighted word is always emphasised
    // with a green stroke outline (`Dw.ayahGreen` via `PaintingStyle.stroke`),
    // not a container fill or a heavier weight.
    final baseStyle = widget.style.color != null
        ? widget.style
        : widget.style.copyWith(color: Dw.arabicBase);
    final recitedStyle = baseStyle.copyWith(
      color: null,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..color = Dw.ayahGreen
        ..strokeWidth = 1.0
        ..strokeJoin = StrokeJoin.round,
    );
    return ValueListenableBuilder<int>(
      valueListenable: _activeWord,
      builder: (context, activeWord, _) {
        return _line(tokens, (i) {
          final word = tokenWords[i];
          final isActive =
              word > 0 && segmentForWord[word - 1] - 1 == activeWord;
          return isActive ? recitedStyle : baseStyle;
        });
      },
    );
  }

  /// One laid-out pass of the ayah. [styleFor] styles an individual word;
  /// returning null leaves that word on the widget's [SyncedAyahText.style].
  Text _line(List<String> tokens, TextStyle? Function(int index) styleFor) {
    final spans = <InlineSpan>[];
    for (var i = 0; i < tokens.length; i++) {
      spans.add(TextSpan(text: tokens[i], style: styleFor(i)));
      if (i < tokens.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }
    return Text.rich(
      TextSpan(children: spans),
      textDirection: widget.textDirection,
      textAlign: widget.textAlign,
      style: widget.style,
    );
  }

  Widget _plain() {
    return Text(
      widget.arabic,
      textDirection: widget.textDirection,
      textAlign: widget.textAlign,
      style: widget.style,
    );
  }
}

/// True when [token] carries at least one Arabic letter — pause marks and
/// other diacritic-only fragments are skipped in the word→timing mapping.
bool _hasArabicLetter(String token) {
  for (final code in token.codeUnits) {
    if ((code >= 0x0621 && code <= 0x064A) ||
        (code >= 0x0670 && code <= 0x06D3)) {
      return true;
    }
  }
  return false;
}
