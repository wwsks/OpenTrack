class ParseResult {
  final String address;
  final String code;
  final String lockerNumber;
  final bool success;
  final String sender;

  ParseResult({
    required this.address,
    required this.code,
    required this.lockerNumber,
    required this.success,
    this.sender = '',
  });
}

class SmsParser {
  bool preferLockerAddress = true;

  static final RegExp _lockerPattern = RegExp(
    r'([0-9]+)号(?:柜|快递柜|丰巢柜|蜂巢柜|熊猫柜|兔喜快递柜)',
    caseSensitive: false,
  );

  static final RegExp _addressPattern = RegExp(
    r'(地址|收货地址|送货地址|位于|放至|已到达|到达|已到|送达|到|已放入|已存放至|已存放|放入)'
    r'[\s\S]*?'
    r'([一-鿿\w\s-]+?(?:门牌|驿站|快递点|门面|柜|,|，|。|$))',
    caseSensitive: false,
  );

  static final RegExp _codePattern = RegExp(
    r'(请用|取件码为|提货号为|取货码为|提货码为'
    r'|取件码（|提货号（|取货码（|提货码（'
    r'|取件码『|提货号『|取货码『|提货码『'
    r'|取件码【|提货号【|取货码【|提货码【'
    r'|取件码\(|提货号\(|取货码\(|提货码\('
    r'|取件码\[|提货号\[|取货码\[|提货码\['
    r'|取件码|提货号|取货码|提货码'
    r'|凭|快递|京东|天猫|中通|顺丰|韵达|德邦|菜鸟|拼多多|EMS|闪送|美团|饿了么|盒马|叮咚买菜|UU跑腿'
    r'|签收码|签收编号|操作码|提货编码|收货编码|签收编码'
    r'|取件編號|提貨號碼|運單碼|快遞碼|快件碼|包裹碼|貨品碼'
    r')\s*[A-Za-z0-9\s-]{2,}(?:[，,、][A-Za-z0-9\s-]{2,})*',
    caseSensitive: false,
  );

  static final Map<String, String> companyNames = {
    '极兔': '极兔速递',
    '京东': '京东快递',
    '圆通': '圆通速递',
    '中通': '中通快递',
    '申通': '申通快递',
    '韵达': '韵达快递',
    '顺丰': '顺丰速运',
    '德邦': '德邦快递',
    '菜鸟': '菜鸟驿站',
    '邮政': '邮政快递',
    'EMS': 'EMS',
    '天猫': '天猫',
    '拼多多': '拼多多',
    '百世': '百世快递',
    '丰巢': '丰巢柜',
  };

  final List<String> customAddressPatterns = [];
  final List<RegExp> customCodePatterns = [];
  final List<String> ignoreKeywords = [];

  void addCustomAddressPattern(String pattern) {
    customAddressPatterns.add(pattern);
  }

  void addCustomCodePattern(String pattern) {
    customCodePatterns.add(RegExp(pattern));
  }

  void addIgnoreKeyword(String keyword) {
    if (keyword.trim().isNotEmpty && !ignoreKeywords.contains(keyword)) {
      ignoreKeywords.add(keyword);
    }
  }

  void removeIgnoreKeyword(String keyword) {
    ignoreKeywords.remove(keyword);
  }

  List<String> getIgnoreKeywords() => List.unmodifiable(ignoreKeywords);

  void clearAllCustomPatterns() {
    customAddressPatterns.clear();
    customCodePatterns.clear();
    ignoreKeywords.clear();
  }

  String extractCompany(String smsBody) {
    for (final entry in companyNames.entries) {
      if (smsBody.contains(entry.key)) {
        return entry.value;
      }
    }
    return '';
  }

  ParseResult parseSms(String sms) {
    String foundAddress = '';
    String foundCode = '';

    // Step 1: 忽略关键词
    for (final keyword in ignoreKeywords) {
      if (keyword.trim().isNotEmpty &&
          sms.toLowerCase().contains(keyword.toLowerCase())) {
        return ParseResult(address: '', code: '', lockerNumber: '', success: false);
      }
    }

    // Step 2: 自定义地址模式
    for (final pattern in customAddressPatterns) {
      if (sms.toLowerCase().contains(pattern.toLowerCase())) {
        foundAddress = pattern;
        break;
      }
    }

    // Step 3: 自定义码模式
    for (final pattern in customCodePatterns) {
      final match = pattern.firstMatch(sms);
      if (match != null) {
        foundCode = match.group(1)?.toString() ?? '';
        break;
      }
    }

    // Step 4: 内置地址提取
    if (foundAddress.isEmpty) {
      if (preferLockerAddress) {
        final lockerMatch = _lockerPattern.firstMatch(sms);
        foundAddress = lockerMatch?.group(0) ?? '';
      }
      if (foundAddress.isEmpty) {
        String longestAddress = '';
        for (final match in _addressPattern.allMatches(sms)) {
          final current = match.group(2)?.toString() ?? '';
          if (current.length > longestAddress.length) {
            longestAddress = current;
          }
        }
        foundAddress = longestAddress;
      }
    }

    // Step 5: 柜号数字
    final lockerMatch = _lockerPattern.firstMatch(sms);
    final lockerNumber = lockerMatch?.group(1) ?? '';

    // Step 6: 内置取件码提取
    if (foundCode.isEmpty) {
      Match? lastMatch;
      for (final match in _codePattern.allMatches(sms)) {
        lastMatch = match;
      }
      if (lastMatch != null) {
        final match = lastMatch.group(0);
        final codes = match?.split(RegExp(r'[，,、]'));
        foundCode = codes?.map((c) => c.trim()).join(', ') ?? '';
        foundCode = foundCode.replaceAll(RegExp(r'[^A-Za-z0-9-, ]'), '');
      }
    }

    // Step 7: 地址清理
    foundAddress = foundAddress.replaceAll(RegExp(r'[，,。]'), '');
    foundAddress = foundAddress.replaceAll('取件', '');

    final company = extractCompany(sms);

    return ParseResult(
      address: foundAddress,
      code: foundCode,
      lockerNumber: lockerNumber,
      success: foundAddress.isNotEmpty && foundCode.isNotEmpty,
      sender: company,
    );
  }
}
