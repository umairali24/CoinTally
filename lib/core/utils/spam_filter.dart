class SpamFilter {
  static const List<String> _spamKeywords = [
    "offer",
    "bundle",
    "activation",
    "subscribe",
    "dial",
    "lucky draw",
    "free mb",
    "congrats",
    "winning",
    "super card",
    "off",
    "deal",
    "promo",
    "percentage",
    "limited time",
    "unavailable",
    "scheduled maintenance",
    "usual",
    "services",
    "raast services",
    "maintenance",
    "technical issue",
    "not be available",
    "work as usual",
    "discount",
    "cashback",
    "win",
    "predict",
    "ipad",
    "airpods",
    "prize",
    "results",
    "match",
    "jackpot",
    "dream",
    "winner",
  ];

  static const List<String> _transactionContextWords = [
    "balance",
    "account",
    "a/c",
    "trx",
    "id",
    "paid",
    "received",
    "sent",
    "spent",
    "debited",
    "credited",
    "transfer",
    "from bank",
    "at",
  ];

  static bool isSpam(String text) {
    if (text.isEmpty) return false;
    final lowerText = text.toLowerCase();

    // 1. Promotional Symbol/Phrase Check
    if (lowerText.contains('%')) return true;
    if (lowerText.contains(RegExp(r'just rs\.?\s?\d', caseSensitive: false))) return true;

    // 2. Blacklist Keyword Check (using word boundaries to avoid partial matches)
    for (final keyword in _spamKeywords) {
      if (lowerText.contains(RegExp('\\b${RegExp.escape(keyword)}\\b', caseSensitive: false))) {
        return true;
      }
    }

    // 3. The 'Financial Context' Check
    // If text contains currency symbols but lacks transactional context, mark as spam
    final hasCurrency = lowerText.contains("rs") || lowerText.contains("pkr");
    if (hasCurrency) {
      bool hasTransactionContext = false;
      for (final contextWord in _transactionContextWords) {
        // Use word boundaries here too! 
        // This prevents "match" being seen as containing "at"
        if (lowerText.contains(RegExp('\\b${RegExp.escape(contextWord)}\\b', caseSensitive: false))) {
          hasTransactionContext = true;
          break;
        }
      }
      
      if (!hasTransactionContext) {
        return true;
      }
    }

    return false;
  }
}
