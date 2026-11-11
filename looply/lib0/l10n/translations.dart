// Catálogos de idioma do BrowseIt. Cada idioma é mantido num ficheiro separado.
import 'pt.dart' as pt;
import 'en.dart' as en;
import 'es.dart' as es;
import 'fr.dart' as fr;
import 'de.dart' as de;
import 'it.dart' as it;
import 'ar.dart' as ar;
import 'zh.dart' as zh;
import 'ja.dart' as ja;
import 'ru.dart' as ru;
import 'hi.dart' as hi;
import 'tr.dart' as tr;

const Map<String, Map<String, String>> appTranslations = <String, Map<String, String>>{
  'pt': pt.ptTranslations,
  'en': en.enTranslations,
  'es': es.esTranslations,
  'fr': fr.frTranslations,
  'de': de.deTranslations,
  'it': it.itTranslations,
  'ar': ar.arTranslations,
  'zh': zh.zhTranslations,
  'ja': ja.jaTranslations,
  'ru': ru.ruTranslations,
  'hi': hi.hiTranslations,
  'tr': tr.trTranslations,
};
