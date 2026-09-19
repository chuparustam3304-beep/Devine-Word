import 'package:flutter/foundation.dart' show visibleForTesting;

import 'models.dart';

/// Source of Quran text for the application.
///
/// CONTENT DEPENDENCY — verified Quran dataset:
/// The design handoff (`source-handoff-notes.md`) requires that final Quran
/// text comes from a verified dataset and must not be extracted from the
/// approved screen previews. No such dataset file was supplied with the
/// design pack, so the only authoritative text available today is the small
/// set of ayat that the approved HTML/CSS screens themselves display
/// verbatim (Ash-Sharh 94:6, Ar-Ra'd 13:28, Ta-Ha 20:114) together with
/// their approved on-screen translations.
///
/// Before release, wire a complete, verified dataset into
/// [loadDailyPool] (e.g. the Tanzil verified Uthmani text with licensed
/// translations). The interface is intentionally narrow so that swap is a
/// data-only change.
class QuranRepository {
  const QuranRepository();

  static List<Ayah>? _livePool;

  static void setLivePool(List<Ayah> ayahs) {
    _livePool = List<Ayah>.unmodifiable(ayahs);
  }

  /// Grows the live pool with freshly fetched ayat (one per home-screen
  /// swipe), skipping any whose reference is already in circulation. When
  /// no live pool exists yet (offline launch), the approved design set is
  /// the base the new ayat are appended to.
  static void appendLivePool(List<Ayah> ayahs) {
    final current = _livePool ?? _approvedDesignAyat;
    final seen = current.map((ayah) => ayah.reference).toSet();
    final fresh = ayahs.where((ayah) => seen.add(ayah.reference)).toList();
    if (fresh.isEmpty) return;
    _livePool = List<Ayah>.unmodifiable([...current, ...fresh]);
  }

  /// Test hook: clears the live pool so [loadDailyPool] falls back to the
  /// approved design set again, keeping tests hermetic against the static
  /// pool state.
  @visibleForTesting
  static void resetLivePoolForTest() {
    _livePool = null;
  }

  /// The ayat currently available to the home feed, in circulation order.
  ///
  /// This is the approved design content only — NOT a complete Quran.
  static const List<Ayah> _approvedDesignAyat = [
    Ayah(
      reference: '94:6',
      surahName: 'ASH-SHARH',
      arabic: 'إِنَّ مَعَ الْعُسْرِ يُسْرًا',
      translations: {
        TranslationLanguage.urdu: 'بے شک مشکل کے ساتھ آسانی ہے۔',
        TranslationLanguage.english: 'Indeed, with hardship comes ease.',
        TranslationLanguage.bengali: 'নিশ্চয়ই কষ্টের সাথে স্বস্তি রয়েছে।',
      },
    ),
    Ayah(
      reference: '13:28',
      surahName: 'AR-RA’D',
      arabic: 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
      translations: {
        TranslationLanguage.urdu: 'سنو! اللہ کے ذکر سے دلیں اطمینان پاتی ہیں۔',
        TranslationLanguage.english:
            'Verily, in the remembrance of Allah do hearts find rest.',
        TranslationLanguage.bengali:
            'জেনে রাখো, আল্লাহর স্মরণেই অন্তরসমূহ প্রশান্ত হয়।',
      },
    ),
    Ayah(
      reference: '20:114',
      surahName: 'TA-HA',
      arabic: 'رَبِّ زِدْنِي عِلْمًا',
      translations: {
        TranslationLanguage.urdu: 'میرے رب! میرے علم میں اضافہ فرما۔',
        TranslationLanguage.english: 'My Lord, increase me in knowledge.',
        TranslationLanguage.bengali: 'হে আমার রব, আমার জ্ঞান বৃদ্ধি করুন।',
      },
    ),
    Ayah(
      reference: '2:255',
      surahName: 'AL-BAQARAH',
      arabic:
          'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ ۚ لَا تَأْخُذُهُ '
          'سِنَةٌ وَلَا نَوْمٌ ۚ لَهُ مَا فِي السَّمَاوَاتِ وَمَا فِي الْأَرْضِ ۗ '
          'مَنْ ذَا الَّذِي يَشْفَعُ عِنْدَهُ إِلَّا بِإِذْنِهِ ۚ يَعْلَمُ مَا '
          'بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَيْءٍ مِنْ '
          'عِلْمِهِ إِلَّا بِمَا شَاءَ ۚ وَسِعَ كُرْسِيُّهُ السَّمَاوَاتِ '
          'وَالْأَرْضَ ۖ وَلَا يَئُودُهُ حِفْظُهُمَا ۚ وَهُوَ الْعَلِيُّ الْعَظِيمُ',
      translations: {
        TranslationLanguage.english:
            'Allah — there is no deity except Him, the Ever-Living, the '
            'Sustainer of existence. Neither drowsiness overtakes Him nor '
            'sleep. To Him belongs whatever is in the heavens and whatever is '
            'on the earth. Who is it that can intercede with Him except by His '
            'permission? He knows what is before them and what will be after '
            'them, and they encompass not a thing of His knowledge except for '
            'what He wills. His Kursi extends over the heavens and the earth, '
            'and their preservation tires Him not. And He is the Most High, '
            'the Most Great.',
        TranslationLanguage.urdu:
            'اللہ — اس کے سوا کوئی معبود نہیں، وہ زندہ ہے، سب کا نگہبان۔ اسے '
            'نہ اونگھ آتی ہے نہ نیند۔ آسمانوں اور زمین میں جو کچھ ہے سب اسی '
            'کا ہے۔ کون ہے جو اس کی اجازت کے بغیر اس کے سامنے سفارش کرے؟ وہ '
            'جانتا ہے جو کچھ ان کے آگے ہے اور جو کچھ ان کے پیچھے ہے، حالانکہ '
            'وہ اس کے علم میں سے کسی چیز کا احاطہ نہیں کر سکتے سوائے اس کے جس '
            'تک وہ چاہے۔ اس کی کرسی آسمانوں اور زمین کو گھیرے ہوئے ہے، اور ان '
            'کی حفاظت اسے تھکاتی نہیں۔ اور وہ بلند، عظیم ہے۔',
        TranslationLanguage.bengali:
            'আল্লাহ — তিনি ছাড়া কোনো উপাস্য নেই, তিনি চিরঞ্জীব, সর্বজনীন '
            'রক্ষাকর্তা। তাকে ক্লান্তি বা ঘুম স্পর্শ করে না। আকাশসমূহে ও '
            'পৃথিবীতে যা কিছু আছে তা সবই তাঁর। তাঁর অনুমতি ছাড়া কে তাঁর কাছে '
            'সুপারিশ করতে পারে? তিনি জানেন তাদের সামনে যা আছে এবং পিছনে যা '
            'আছে। আর তাঁর জ্ঞানের কোনো বিষয় তারা আয়ত্ত করতে পারে না, তিনি যা '
            'চান তা ছাড়া। তাঁর কুরসি আকাশসমূহ ও পৃথিবীকে বেষ্টন করে আছে, আর '
            'তাদের রক্ষা করা তাঁকে ক্লান্ত করে না। তিনিই সর্বোচ্চ, মহান।',
      },
    ),
  ];

  /// Returns the pool of ayat the daily feed rotates through.
  List<Ayah> loadDailyPool() => _livePool ?? _approvedDesignAyat;

  /// Finds an ayah by its `surah:ayah` reference, or null when absent.
  Ayah? findByReference(String reference) {
    for (final ayah in loadDailyPool()) {
      if (ayah.reference == reference) return ayah;
    }
    return null;
  }
}
