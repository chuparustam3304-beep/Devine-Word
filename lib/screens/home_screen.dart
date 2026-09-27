import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models.dart';
import '../design/screen_frame.dart';
import '../design/tokens.dart';
import '../services/audio_service.dart';
import '../state/app_state_scope.dart';
import '../widgets/dw_svg.dart';
import '../widgets/synced_ayah_text.dart';

const _asset = 'assets/05-home/quran_reader/';
const _green = Color(0xFF1C5C48);

/// Native implementation of the supplied 603 × 1280 HTML artboard.
/// Lettering is live Quran text, never the template's static verse images.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Direction the top card leaves the deck in.
enum _DeckSlide { next, previous }

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _index = 0;
  double _scale = 1;
  TranslationLanguage _language = TranslationLanguage.urdu;

  /// In-flight card swap: the top card slides off in [_slide] while the card
  /// beneath it — already seated in the paper stack — is revealed. The deck
  /// never "arrives" a new ayah; it uncovers one.
  _DeckSlide? _slide;
  int? _pendingIndex;
  late final AnimationController _deck;

  @override
  void initState() {
    super.initState();
    _deck = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addStatusListener(_onDeckSettled);
  }

  /// When the top card has fully left the frame, the revealed card becomes
  /// the top card.
  void _onDeckSettled(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _index = _pendingIndex ?? _index;
      _pendingIndex = null;
      _slide = null;
    });
  }

  @override
  void dispose() {
    _deck.dispose();
    super.dispose();
  }

  Future<void> _rotate(int delta) async {
    if (_slide != null) return;
    final pool = AppStateScope.of(context).repository.loadDailyPool();
    if (pool.length < 2) return;
    setState(() {
      _slide = delta > 0 ? _DeckSlide.next : _DeckSlide.previous;
      _pendingIndex = (_index + delta) % pool.length;
      _deck.value = 0;
    });
    await AudioService.instance.stop();
    if (!mounted) return;
    _deck.forward();
  }

  Future<void> _chooseLanguage() async {
    final language = await showDialog<TranslationLanguage>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: const Color(0xFFF6F4E7),
        title: const Text('Translation language'),
        children: [
          for (final language in TranslationLanguage.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, language),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${language.label} · ${language.nativeLabel}'),
                  ),
                  if (language == _language)
                    const Icon(Icons.check, color: _green),
                ],
              ),
            ),
        ],
      ),
    );
    if (mounted && language != null) setState(() => _language = language);
  }

  Future<void> _share(Ayah ayah, BuildContext anchor) async {
    final box = anchor.findRenderObject()! as RenderBox;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              '${ayah.arabic}\n\n${ayah.translationFor(_language)}\n\n${ayah.surahName} ${ayah.reference}',
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to share this ayah. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pool = AppStateScope.of(context).repository.loadDailyPool();
    return DwScreenFrame(
      designWidth: 603,
      designHeight: 1280,
      background: const Color(0xFFE9E6D9),
      body: (context) => Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-0.42, -0.91),
                  end: Alignment(0.42, 0.91),
                  colors: [
                    Color(0xFFF1EEDF),
                    Color(0xFFEFECDD),
                    Color(0xFFEDEADB),
                  ],
                  stops: [0, 0.63, 1],
                ),
              ),
              child: Opacity(
                opacity: 0.12,
                child: Image.asset(
                  '${_asset}extracted/ui/background-texture-patch.png',
                  repeat: ImageRepeat.repeat,
                ),
              ),
            ),
          ),
          // These layers use the source HTML's exact design-space coordinates.
          _image(
            'extracted/decorations/foliage-left-upper.png',
            0,
            1005,
            60,
            136,
          ),
          _image(
            'extracted/decorations/foliage-right-upper.png',
            547,
            1063,
            56,
            78,
          ),
          _image(
            'extracted/decorations/footer-landscape-visible.png',
            0,
            1141,
            603,
            139,
          ),
          _image('recreated/decorations/paper-stack.svg', 20, 216, 580, 770),
          // The card deck: at rest only the top card shows; on rotate the
          // top card slides off and the card seated beneath is revealed.
          _buildDeck(pool),
          _image('extracted/icons/brand-mark.png', 46, 82, 46, 47),
          _RoundButton(
            left: 506,
            top: 79,
            size: 57,
            label: 'Translation language',
            onTap: _chooseLanguage,
            child: Image.asset(
              '${_asset}extracted/icons/globe.png',
              width: 37,
              height: 37,
            ),
          ),
          _RoundButton(
            left: 444,
            top: 154,
            size: 49,
            label: 'Increase reading size',
            onTap: _scale >= 1.08
                ? null
                : () => setState(
                    () => _scale = (_scale + 0.04).clamp(0.84, 1.08),
                  ),
            child: Image.asset(
              '${_asset}extracted/icons/plus.png',
              width: 26,
              height: 28,
            ),
          ),
          _RoundButton(
            left: 513,
            top: 154,
            size: 49,
            label: 'Decrease reading size',
            onTap: _scale <= 0.84
                ? null
                : () => setState(
                    () => _scale = (_scale - 0.04).clamp(0.84, 1.08),
                  ),
            child: Image.asset(
              '${_asset}extracted/icons/minus.png',
              width: 26,
              height: 16,
            ),
          ),
          _VerseNav(
            previous: true,
            onTap: _slide == null ? () => _rotate(-1) : null,
          ),
          _VerseNav(
            previous: false,
            onTap: _slide == null ? () => _rotate(1) : null,
          ),
          _PlayControl(
            audioUrl:
                pool[(_pendingIndex ?? _index).clamp(0, pool.length - 1)]
                    .recitationUrl,
            enabled: _slide == null,
          ),
        ],
      ),
    );
  }

  /// The card deck over the paper stack: at rest only the top card shows;
  /// during a swap the next card is already seated beneath the top card and
  /// the top card slides off in the swipe direction (next → left, previous
  /// → right), uncovering it — exactly the layered look of the design's
  /// stacked papers.
  Widget _buildDeck(List<Ayah> pool) {
    final revealed = _slide == null
        ? null
        : pool[_pendingIndex!.clamp(0, pool.length - 1)];
    final top = pool[_index.clamp(0, pool.length - 1)];
    return Positioned.fill(
      child: Stack(
        children: [
          if (revealed != null)
            Positioned.fill(child: IgnorePointer(child: _cardStack(revealed))),
          if (_slide != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _deck,
                  builder: (context, child) {
                    final t = Curves.easeInCubic.transform(_deck.value);
                    final shift = _slide == _DeckSlide.next ? -640.0 : 640.0;
                    return Transform.translate(
                      offset: Offset(shift * t, 0),
                      child: child,
                    );
                  },
                  // The leaving card carries its own paper sheet; the stack
                  // beneath shows the revealed card on the stack's front
                  // sheet, so nothing needs to be drawn in for it.
                  child: _cardStack(top, flying: true),
                ),
              ),
            )
          else
            Positioned.fill(child: _cardStack(top)),
        ],
      ),
    );
  }

  /// One card of the deck: everything that belongs to a single ayah — the
  /// corner botanical, header pill, reference, reading blocks, divider and
  /// share line — plus, while it is the one sliding away, the paper sheet
  /// it is printed on. At rest the sheet under the content is the paper
  /// stack's own front sheet, keeping the design pixel-exact.
  Widget _cardStack(Ayah ayah, {bool flying = false}) {
    final translationLanguage = ayah.translations.containsKey(_language)
        ? _language
        : ayah.translations.keys.first;
    final stack = Stack(
      children: [
        if (flying)
          _image('recreated/decorations/paper-front.svg', 52, 222, 518, 734),
        _image('extracted/decorations/top-botanical.png', 78, 221, 88, 65),
        Positioned(
          left: 45,
          top: 155,
          width: 172,
          height: 41,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0x21FFFFF5),
              border: Border.all(color: const Color(0xFFFFFEF1), width: 1.3),
              borderRadius: BorderRadius.circular(28),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                ayah.surahName,
                style: const TextStyle(
                  color: _green,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.4,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 242,
          top: 164,
          child: Text(
            ayah.reference,
            style: const TextStyle(
              color: _green,
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.2,
            ),
          ),
        ),
        _ReadingBlock(
          key: ValueKey('arabic-${ayah.reference}'),
          left: 99,
          top: 302,
          width: 427,
          height: 325,
          child: SyncedAyahText(
            arabic: ayah.arabic,
            reference: ayah.reference,
            audioUrl: ayah.recitationUrl,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: Dw.arabic,
              fontSize: 52 * _scale,
              height: 80 / 52,
              fontWeight: FontWeight.w500,
              color: _green,
            ),
          ),
        ),
        _image('extracted/icons/divider-line.png', 231, 644, 49, 10),
        _image('extracted/icons/divider-sprout.png', 289, 635, 29, 30),
        _image('extracted/icons/divider-line.png', 329, 644, 49, 10),
        _ReadingBlock(
          key: ValueKey('translation-${ayah.reference}-${_language.name}'),
          left: 119,
          top: 680,
          width: 392,
          height: 184,
          child: Text(
            ayah.translationFor(_language),
            textAlign: TextAlign.center,
            textDirection: translationLanguage == TranslationLanguage.urdu
                ? TextDirection.rtl
                : TextDirection.ltr,
            style: TextStyle(
              fontFamily: switch (translationLanguage) {
                TranslationLanguage.urdu => Dw.urdu,
                TranslationLanguage.bengali => 'Noto Sans Bengali',
                TranslationLanguage.english => Dw.ui,
              },
              fontSize: 22 * _scale,
              height: 45 / 22,
              color: _green,
            ),
          ),
        ),
        Positioned(
          left: 227,
          top: 880,
          width: 152,
          height: 52,
          child: Builder(
            builder: (anchor) => Tooltip(
              message: 'Share ayah',
              excludeFromSemantics: true,
              child: Semantics(
                excludeSemantics: true,
                button: true,
                label: 'Share ayah',
                child: InkWell(
                  onTap: () => _share(ayah, anchor),
                  child: Center(
                    child: Text(
                      '—  ${ayah.reference}  —',
                      style: const TextStyle(
                        color: _green,
                        fontSize: 21,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    // While a swap is in flight neither layer takes pointers: the leaving
    // card's share line must not swallow a tap meant for the revealed one.
    return _slide == null && !flying ? stack : IgnorePointer(child: stack);
  }
}

Positioned _image(
  String path,
  double left,
  double top,
  double width,
  double height,
) => Positioned(
  left: left,
  top: top,
  width: width,
  height: height,
  child: IgnorePointer(
    child: ExcludeSemantics(
      child: path.endsWith('.svg')
          ? DwSvg('$_asset$path', width: width, height: height)
          : Image.asset(
              '$_asset$path',
              width: width,
              height: height,
              fit: BoxFit.contain,
            ),
    ),
  ),
);

/// Long verses scroll within their own reading region, never advance the ayah.
class _ReadingBlock extends StatelessWidget {
  const _ReadingBlock({
    super.key,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.child,
  });
  final double left, top, width, height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned(
    left: left,
    top: top,
    width: width,
    height: height,
    child: ClipRect(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Center(child: child),
        ),
      ),
    ),
  );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.left,
    required this.top,
    required this.size,
    required this.label,
    required this.onTap,
    required this.child,
  });
  final double left, top, size;
  final String label;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned(
    left: left,
    top: top,
    width: size,
    height: size,
    child: Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            DwSvg(
              '${_asset}recreated/decorations/round-button.svg',
              width: size,
              height: size,
            ),
            Opacity(opacity: onTap == null ? 0.4 : 1, child: child),
          ],
        ),
      ),
    ),
  );
}

/// Previous/next deck control. Pressing tilts the hand toward its swipe
/// direction (pivoting on the wrist) and tints arrow + hand with the
/// card's leaf amber, the botanical's golden.
class _VerseNav extends StatefulWidget {
  const _VerseNav({required this.previous, required this.onTap});
  final bool previous;
  final VoidCallback? onTap;

  @override
  State<_VerseNav> createState() => _VerseNavState();
}

class _VerseNavState extends State<_VerseNav> {
  bool _pressed = false;

  /// Press tilt in turns (~4.3°) — previous leans left, next leans right.
  static const double _tiltTurns = 0.012;

  Widget _navImage(
    String path,
    double left,
    double top,
    double width,
    double height,
  ) {
    final Widget image = path.endsWith('.svg')
        ? DwSvg('$_asset$path', width: width, height: height)
        : Image.asset(
            '$_asset$path',
            width: width,
            height: height,
            fit: BoxFit.contain,
          );
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: _pressed
          ? ColorFiltered(
              colorFilter: const ColorFilter.mode(Dw.leafAmber, BlendMode.srcIn),
              child: image,
            )
          : image,
    );
  }

  @override
  Widget build(BuildContext context) {
    final previous = widget.previous;
    return Positioned(
      left: previous ? 117 : 404,
      top: 1027,
      width: 89,
      height: 113,
      child: Semantics(
        button: true,
        enabled: widget.onTap != null,
        excludeSemantics: true,
        label: previous ? 'Previous ayah' : 'Next ayah',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown:
              widget.onTap == null ? null : (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedRotation(
            turns: _pressed ? (previous ? -_tiltTurns : _tiltTurns) : 0,
            alignment: Alignment.bottomCenter,
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _navImage(
                  'extracted/icons/arrow-${previous ? 'left' : 'right'}.png',
                  previous ? 23 : 27,
                  3,
                  35,
                  25,
                ),
                _image('recreated/decorations/hand-halo.svg', 4, 34, 82, 47),
                _navImage(
                  'extracted/icons/hand-${previous ? 'previous' : 'next'}.png',
                  21,
                  27,
                  previous ? 42 : 46,
                  previous ? 53 : 55,
                ),
                Positioned(
                  left: -3,
                  top: 83,
                  width: 95,
                  child: Text(
                    previous ? 'Previous' : 'Next',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'DM Serif Display',
                      color: _green,
                      fontSize: 24,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayControl extends StatefulWidget {
  const _PlayControl({required this.audioUrl, required this.enabled});
  final String audioUrl;
  final bool enabled;

  @override
  State<_PlayControl> createState() => _PlayControlState();
}

class _PlayControlState extends State<_PlayControl> {
  StreamSubscription<bool>? _subscription;
  bool _playing = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _playing =
        AudioService.instance.isPlaying &&
        AudioService.instance.loadedUrl == widget.audioUrl;
    _subscription = AudioService.instance.stateStream.listen((playing) {
      if (mounted) {
        setState(
          () => _playing =
              playing && AudioService.instance.loadedUrl == widget.audioUrl,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant _PlayControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl) _playing = false;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy || !widget.enabled) return;
    setState(() => _busy = true);
    final audio = AudioService.instance;
    try {
      if (_playing) {
        await audio.pause();
      } else if (!audio.canResume(widget.audioUrl) || !await audio.resume()) {
        await audio.play(widget.audioUrl);
      }
      if (mounted) {
        setState(
          () =>
              _playing = audio.isPlaying && audio.loadedUrl == widget.audioUrl,
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't load the recitation — check your connection.",
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 232,
    top: 1030,
    width: 143,
    height: 84,
    child: Semantics(
      button: true,
      enabled: widget.enabled && !_busy,
      label: _playing ? 'Pause recitation' : 'Play recitation',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Stack(
          children: [
            _image('extracted/icons/play-sprig-left.png', 0, 17, 43, 55),
            _image('extracted/icons/play-sprig-right.png', 97, 15, 46, 58),
            _image('recreated/decorations/play-disc.svg', 30, 1, 80, 80),
            // Both glyphs' ink is centred on the disc centre (70, 41) so the
            // icon never jumps when play/pause toggles: play's ink centre
            // sits 23/42 down its box, pause's 21/42.
            if (_playing)
              _image('recreated/icons/pause.svg', 53, 20, 34, 42)
            else
              _image('extracted/icons/play-triangle.png', 53, 18, 34, 42),
          ],
        ),
      ),
    ),
  );
}
