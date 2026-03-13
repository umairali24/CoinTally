import 'package:cointally/domain/entities/transaction_entity.dart';

class TransactionParser {
  static TransactionEntity? parse(String? title, String? body, {DateTime? notificationDate}) {
    // Combine title and body to handle cases where info is split
    final String fullText = "${title ?? ''} ${body ?? ''}".trim();
    if (fullText.isEmpty) return null;

    final String text = fullText.replaceAll(',', ''); // Remove commas for easier parsing

    // 1. Amount Parsing
    // Strategy A: Explicit Currency (Rs. 500, PKR 500, PKR. 5000, PKR-8990)
    final RegExp explicitRegex = RegExp(r'(?:Rs\.?|PKR\.?)\s?-?\s?(\d+(?:\.\d{1,2})?)', caseSensitive: false);
    Match? amountMatch = explicitRegex.firstMatch(text);

    double? finalAmount;
    if (amountMatch != null) {
        finalAmount = double.parse(amountMatch.group(1)!);
    } else {
       // Strategy B: Implicit Amount (text contains keywords AND a number)
       final bool isTransactionText = 
          text.toLowerCase().contains(RegExp(r'\b(paid|received|sent|spent|bill|credited|debited|transfer|trf|tx|amt|balance|charged|deducted|withdrawn|payment|purchased)\b'));
       
       if (isTransactionText) {
          final RegExp numberRegex = RegExp(r'\b(\d+(?:\.\d{1,2})?)\b');
          final Iterable<Match> matches = numberRegex.allMatches(text);
          
          for (final m in matches) {
             final val = double.tryParse(m.group(1)!);
             if (val == null || val <= 0) continue;

             // Heuristic: Ignore numbers that are likely dates, times or years
             final matchIndex = m.start;
             final textBefore = text.substring(0, matchIndex).toLowerCase();
             final textAfter = text.substring(m.end).toLowerCase();

             // 1. Ignore if followed by AM/PM or time range
             if (textAfter.contains(RegExp(r'^\s?(am|pm)')) || textBefore.contains(RegExp(r'\bfrom\b\s*$'))) {
                continue;
             }

             // 2. Ignore if followed by common Month names (Date pattern like "14 Feb")
             if (textAfter.contains(RegExp(r'^\s?(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)'))) {
                continue;
             }

             // 3. Ignore common years (2024, 2025, 2026)
             if (val >= 2024 && val <= 2030) continue;

             // 4. Ignore tiny numbers (often part of info messages like "5AM" or "1LINK")
             if (val < 10) continue;

             finalAmount = val; 
             break; // Take the first reasonable number that passed filters
          }
       }
    }

    if (finalAmount == null) return null; // No amount found
    
    final double amount = finalAmount;

    // 2. Type Detection
    String type = 'EXPENSE'; // Default
    final String lowerText = text.toLowerCase();
    
    // Income Keywords
    if (lowerText.contains('received') ||
        lowerText.contains('credited') ||
        lowerText.contains('added') ||
        lowerText.contains('deposit')) {
      type = 'INCOME';
    } 
    // Expense Keywords are default but we implicitly check logic:
    // "sent", "debited", "purchase", "withdrawal", "paid", "transferred to", "charged", "deducted" imply expense.
    
    // 3. Merchant / Source Extraction
    String? merchant;
    
    // Priority 1: Clearer prepositions (sent to, received from, from, to)
    final RegExp priorityMerchantRegex = RegExp(
      r'(?:from|to|paid to|received from|sent to|transfer to|transferred to|performed an?|using)\s+([A-Za-z0-9\s\.\/&\*#\-\:]+?)(?:(?:\s(?:on|using|via|with|date|for|at|of))|\s\d|$)', 
      caseSensitive: false
    );
    
    // Priority 2: Generic "at" (often for locations or times, so we need to be careful)
    final RegExp genericAtRegex = RegExp(
      r'at\s+([A-Za-z0-9\s\.\/&\*#\-\:]+?)(?:(?:\s(?:on|using|via|with|date|for))|\s\d|$)', 
      caseSensitive: false
    );

    // Try priority match first
    Match? merchantMatch = priorityMerchantRegex.firstMatch(text);
    
    // If no priority match, try generic "at"
    if (merchantMatch == null) {
      merchantMatch = genericAtRegex.firstMatch(text);
    }
    
    if (merchantMatch != null) {
      merchant = merchantMatch.group(1)?.trim();
      
      // Specifically check for and ignore timestamps (like "15:19", "00:38:02" or "03:45 PM")
      if (merchant != null && RegExp(r'^\d{1,2}:\d{2}(:\d{2})?(\s?[AP]M)?$', caseSensitive: false).hasMatch(merchant)) {
         merchant = null;
      }
    }
    
    // Raast / Specific Pakistani pattern: "... received from [Name] A/C via Raast"
    if (lowerText.contains('raast') && lowerText.contains('received from')) {
       final raastRegex = RegExp(r'received from\s+([A-Za-z0-9\s\.\/&\*#\-]+?)(?:\s+A\/C|via|on|$)', caseSensitive: false);
       final raastMatch = raastRegex.firstMatch(text);
       if (raastMatch != null) {
          merchant = raastMatch.group(1)?.trim();
       }
    }

    // Clean up merchant name (remove extra spaces and common filler)
    if (merchant != null) {
      merchant = merchant.replaceAll(RegExp(r'\s+'), ' ').trim();
      // If it's just "A/C" or something very short, discard it
      if (merchant.length < 2) merchant = null;
    }
    
    // Fallback Merchant
    if (merchant == null || merchant.isEmpty) {
        // If title is app name or generic, use 'Unknown', else use Title as fallback
        if (title != null && title.isNotEmpty) {
           // Skip numeric titles (like 14250) if they are just the shortcode
           if (RegExp(r'^\d+$').hasMatch(title)) {
              merchant = 'Unknown';
           } else {
              merchant = title;
           }
        } else {
           merchant = 'Unknown';
        }
    }

    return TransactionEntity(
      amount: amount,
      type: type,
      category: type == 'INCOME' ? 'Salary' : 'Shopping', // Default categories
      date: notificationDate ?? DateTime.now(),
      merchantName: merchant,
      isAutoDetected: true,
    );
  }
}
