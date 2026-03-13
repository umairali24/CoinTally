import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BankUtils {
  static String getDisplayName(String fileName) {
    if (fileName.isEmpty) return 'Unknown Bank';
    // Remove .svg or .png extension
    String name = fileName.replaceAll('.svg', '').replaceAll('.png', '');
    
    // Handle special cases
    if (name == 'aft') return 'Advanced Financial';
    if (name == 'ztbl') return 'ZTBL';
    if (name == 'icbc') return 'ICBC';
    if (name == 'idbp') return 'IDBP';
    if (name == 'nrsp') return 'NRSP';
    if (name == 'ubl') return 'UBL';
    if (name == 'hbl') return 'HBL';
    if (name == 'mcb') return 'MCB';
    if (name == 'bank_of_khayber') return 'Bank Of Khyber';
    if (name == 'mashreq-logo-en') return 'Mashreq';

    // Replace underscores with spaces and title case
    return name.split('_').map((word) {
      if (word.isEmpty) return word;
      if (word == 'mf') return 'Microfinance';
      if (word == 'ajk') return 'AJK';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  /// Helper to get the best possible logo widget (prefers PNG, falls back to SVG)
  static Widget getLogoWidget(String? assetPath, {double size = 24, Color? color, String? bankName}) {
    if (assetPath == null || assetPath.isEmpty) {
      return Icon(
        (bankName?.toLowerCase() == 'wallet') ? Icons.account_balance_wallet_rounded : Icons.account_balance_rounded,
        size: size,
        color: color,
      );
    }

    final fileName = assetPath.split('/').last;
    final baseName = fileName.split('.').first;
    
    // On Web, Flutter prepends 'assets/' to the path provided in Image.asset or SvgPicture.asset
    // twice if we start with 'assets/'. We adjust the path here if running on Web.
    final svgPath = kIsWeb ? 'banks/$baseName.svg' : 'assets/banks/$baseName.svg';
    final pngPath = kIsWeb ? 'banks_png/$baseName.png' : 'assets/banks_png/$baseName.png';

    // These logos are known to be true vectors that render well as SVGs
    // and were not extracted as PNGs.
    const trueVectors = {
      'faysal_bank',
      'finja',
      'naya_pay',
      'samba_bank',
      'standard_chartered',
      'mashreq-logo-en',
    };

    if (trueVectors.contains(baseName)) {
      return SvgPicture.asset(
        svgPath,
        width: size,
        height: size,
        placeholderBuilder: (context) => Icon(Icons.account_balance_rounded, size: size, color: color),
      );
    }

    // Default to extracted PNG for maximum compatibility
    return Image.asset(
      pngPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Ultimate fallback to SVG if PNG fails
        return SvgPicture.asset(
          svgPath,
          width: size,
          height: size,
          placeholderBuilder: (context) => Icon(Icons.account_balance_rounded, size: size, color: color),
        );
      },
    );
  }

  static const List<String> bankLogos = [
    'aft.svg', 'al_barakh.svg', 'allied_bank.svg', 'apna_mirofinance_bank.svg',
    'askari_bank.svg', 'bank_al_habib.svg', 'bank_alfalah.svg', 'bank_islami.svg',
    'bank_of_ajk.svg', 'bank_of_khayber.svg', 'bank_of_punjab.svg', 'citi_bank.svg',
    'deutsche_bank_ag.svg', 'dubai_islamic_bank.svg', 'easy_paisa.svg', 'faysal_bank.svg',
    'finca_mirofinance.svg', 'finja.svg', 'first_microfinance_bank_pakistan.svg',
    'first_women_bank.svg', 'habib_metro.svg', 'hbl.svg', 'hbl_mf_bank.svg',
    'icbc.svg', 'idbp.svg', 'jazz_cash.svg', 'js_bank.svg', 'keenu.svg',
    'khushali_micorfinance_bank.svg', 'mashreq-logo-en.svg', 'mcb.svg', 'mcb___airf_habib.svg', 'mcb___islamic.svg',
    'meezan_bank.svg', 'mufg.svg', 'national_bank.svg', 'naya_pay.svg', 'nbp_funds.svg',
    'nrsp.svg', 'nrsp_microfinance_bank.svg', 'paymax.svg', 'sada_pay.svg',
    'samba_bank.svg', 'silk_bank.svg', 'sindh_bank.svg', 'soneri_bank.svg',
    'soneri_mustaqeem.svg', 'standard_chartered.svg', 'summit_bank.svg',
    'telenor_microfinance_bank.svg', 'u_microfinance_bank.svg', 'u_paisa.svg',
    'ubl.svg', 'zindigi.svg', 'ztbl.svg'
  ];
}
