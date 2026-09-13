class AppCurrency {
  final String code;
  final String symbol;
  final String nameEn;
  final String nameAr;
  final String flag;

  const AppCurrency({
    required this.code,
    required this.symbol,
    required this.nameEn,
    required this.nameAr,
    required this.flag,
  });
}

class Currencies {
  static const List<AppCurrency> list = [
    // Major World Currencies
    AppCurrency(
      code: 'USD',
      symbol: r'$',
      nameEn: 'US Dollar',
      nameAr: 'دولار أمريكي',
      flag: '🇺🇸',
    ),
    AppCurrency(
      code: 'EUR',
      symbol: '€',
      nameEn: 'Euro',
      nameAr: 'يورو',
      flag: '🇪🇺',
    ),
    AppCurrency(
      code: 'GBP',
      symbol: '£',
      nameEn: 'British Pound',
      nameAr: 'جنيه إسترليني',
      flag: '🇬🇧',
    ),
    AppCurrency(
      code: 'CAD',
      symbol: r'CA$',
      nameEn: 'Canadian Dollar',
      nameAr: 'دولار كندي',
      flag: '🇨🇦',
    ),
    AppCurrency(
      code: 'AUD',
      symbol: r'AU$',
      nameEn: 'Australian Dollar',
      nameAr: 'دولار أسترالي',
      flag: '🇦🇺',
    ),
    AppCurrency(
      code: 'JPY',
      symbol: '¥',
      nameEn: 'Japanese Yen',
      nameAr: 'ين ياباني',
      flag: '🇯🇵',
    ),
    AppCurrency(
      code: 'CNY',
      symbol: '¥',
      nameEn: 'Chinese Yuan',
      nameAr: 'يوان صيني',
      flag: '🇨🇳',
    ),
    AppCurrency(
      code: 'CHF',
      symbol: 'CHF',
      nameEn: 'Swiss Franc',
      nameAr: 'فرنك سويسري',
      flag: '🇨🇭',
    ),
    AppCurrency(
      code: 'INR',
      symbol: '₹',
      nameEn: 'Indian Rupee',
      nameAr: 'روبية هندية',
      flag: '🇮🇳',
    ),
    AppCurrency(
      code: 'TRY',
      symbol: '₺',
      nameEn: 'Turkish Lira',
      nameAr: 'ليرة تركية',
      flag: '🇹🇷',
    ),

    // Arab & Middle Eastern Currencies
    AppCurrency(
      code: 'SAR',
      symbol: 'ر.س',
      nameEn: 'Saudi Riyal',
      nameAr: 'ريال سعودي',
      flag: '🇸🇦',
    ),
    AppCurrency(
      code: 'AED',
      symbol: 'د.إ',
      nameEn: 'UAE Dirham',
      nameAr: 'درهم إماراتي',
      flag: '🇦🇪',
    ),
    AppCurrency(
      code: 'DZD',
      symbol: 'د.ج',
      nameEn: 'Algerian Dinar',
      nameAr: 'دينار جزائري',
      flag: '🇩🇿',
    ),
    AppCurrency(
      code: 'EGP',
      symbol: 'ج.م',
      nameEn: 'Egyptian Pound',
      nameAr: 'جنيه مصري',
      flag: '🇪🇬',
    ),
    AppCurrency(
      code: 'KWD',
      symbol: 'د.ك',
      nameEn: 'Kuwaiti Dinar',
      nameAr: 'دينار كويتي',
      flag: '🇰🇼',
    ),
    AppCurrency(
      code: 'QAR',
      symbol: 'ر.ق',
      nameEn: 'Qatari Riyal',
      nameAr: 'ريال قطري',
      flag: '🇶🇦',
    ),
    AppCurrency(
      code: 'BHD',
      symbol: 'د.ب',
      nameEn: 'Bahraini Dinar',
      nameAr: 'دينار بحريني',
      flag: '🇧🇭',
    ),
    AppCurrency(
      code: 'OMR',
      symbol: 'ر.ع',
      nameEn: 'Omani Rial',
      nameAr: 'ريال عماني',
      flag: '🇴🇲',
    ),
    AppCurrency(
      code: 'MAD',
      symbol: 'د.م.',
      nameEn: 'Moroccan Dirham',
      nameAr: 'درهم مغربي',
      flag: '🇲🇦',
    ),
    AppCurrency(
      code: 'TND',
      symbol: 'د.ت',
      nameEn: 'Tunisian Dinar',
      nameAr: 'دينار تونسي',
      flag: '🇹🇳',
    ),
    AppCurrency(
      code: 'JOD',
      symbol: 'د.أ',
      nameEn: 'Jordanian Dinar',
      nameAr: 'دينار أردني',
      flag: '🇯🇴',
    ),
    AppCurrency(
      code: 'IQD',
      symbol: 'د.ع',
      nameEn: 'Iraqi Dinar',
      nameAr: 'دينار عراقي',
      flag: '🇮🇶',
    ),
    AppCurrency(
      code: 'LYD',
      symbol: 'د.ل',
      nameEn: 'Libyan Dinar',
      nameAr: 'دينار ليبي',
      flag: '🇱🇾',
    ),
    AppCurrency(
      code: 'LBP',
      symbol: 'ل.ل',
      nameEn: 'Lebanese Pound',
      nameAr: 'ليرة لبنانية',
      flag: '🇱🇧',
    ),
    AppCurrency(
      code: 'SDG',
      symbol: 'ج.س',
      nameEn: 'Sudanese Pound',
      nameAr: 'جنيه سوداني',
      flag: '🇸🇩',
    ),
    AppCurrency(
      code: 'YER',
      symbol: 'ر.ي',
      nameEn: 'Yemeni Rial',
      nameAr: 'ريال يمني',
      flag: '🇾🇪',
    ),
    AppCurrency(
      code: 'SYP',
      symbol: 'ل.س',
      nameEn: 'Syrian Pound',
      nameAr: 'ليرة سورية',
      flag: '🇸🇾',
    ),
    AppCurrency(
      code: 'MRU',
      symbol: 'أ.م',
      nameEn: 'Mauritanian Ouguiya',
      nameAr: 'أوقية موريتانية',
      flag: '🇲🇷',
    ),

    // Other Currencies
    AppCurrency(
      code: 'BRL',
      symbol: r'R$',
      nameEn: 'Brazilian Real',
      nameAr: 'ريال برازيلي',
      flag: '🇧🇷',
    ),
    AppCurrency(
      code: 'MXN',
      symbol: r'Mex$',
      nameEn: 'Mexican Peso',
      nameAr: 'بيزو مكسيكي',
      flag: '🇲🇽',
    ),
    AppCurrency(
      code: 'KRW',
      symbol: '₩',
      nameEn: 'South Korean Won',
      nameAr: 'وون كوري جنوبي',
      flag: '🇰🇷',
    ),
    AppCurrency(
      code: 'IDR',
      symbol: 'Rp',
      nameEn: 'Indonesian Rupiah',
      nameAr: 'روبية إندونيسية',
      flag: '🇮🇩',
    ),
    AppCurrency(
      code: 'MYR',
      symbol: 'RM',
      nameEn: 'Malaysian Ringgit',
      nameAr: 'رينغيت ماليزي',
      flag: '🇲🇾',
    ),
    AppCurrency(
      code: 'PKR',
      symbol: '₨',
      nameEn: 'Pakistani Rupee',
      nameAr: 'روبية باكستانية',
      flag: '🇵🇰',
    ),
    AppCurrency(
      code: 'RUB',
      symbol: '₽',
      nameEn: 'Russian Ruble',
      nameAr: 'روبل روسي',
      flag: '🇷🇺',
    ),
    AppCurrency(
      code: 'ZAR',
      symbol: 'R',
      nameEn: 'South African Rand',
      nameAr: 'راند جنوب أفريقي',
      flag: '🇿🇦',
    ),
  ];

  static AppCurrency getByCode(String code) {
    return list.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => list.first, // Default fallback
    );
  }
}
