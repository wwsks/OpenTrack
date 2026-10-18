import '../models/sms_data.dart';

/// 地址归一化 system prompt：三条规则逐字写入，防止误合并
const String kNormalizeSystemPrompt = '''
你是驿站地址归一化助手。请把下面给出的驿站地址归一到标准名称，遵守以下三条规则：
1. 同一物理站点的不同表述归一到信息最全的名称（优先含菜鸟驿站/妈妈驿站/快递超市/丰巢/服务站等通名的完整写法）。
2. 不同站点绝不合并（如两个不同的菜鸟驿站门店）。
3. 拿不准保留原名（宁可不合并，不可误合并）。
只输出 JSON：{"原地址":"标准名"}，键必须覆盖输入的每个地址，不要输出任何解释文字。
''';

/// 构造地址归一化的用户消息：逐行输出地址
String buildNormalizePrompt(List<String> addresses) => addresses.join('\n');

/// 取件清单 system prompt：生成到驿站一次性取完的简短清单，纯文本输出
const String kPickupListSystemPrompt = '''
你是取件清单助手。请把下面给出的待取件信息整理成到驿站一次性取完的简短清单，遵守以下规则：
1. 按驿站分组输出，每个驿站一段，段首写驿站名称。
2. 同一站内的取件码按柜号升序排列，无柜号的排在最后。
3. 末尾附总计（N 个驿站 M 件）。
只输出纯文本清单，不要输出任何解释文字。
''';

/// 构造取件清单的用户消息：每项输出「驿站：{address}｜取件码：{code}｜柜号：{lockerNumber}」，
/// 柜号为空则省略柜号段；取件码原样透传（可能含多码）
String buildPickupListPrompt(List<SmsData> items) => items.map((item) {
      final locker =
          item.lockerNumber.isEmpty ? '' : '｜柜号：${item.lockerNumber}';
      return '驿站：${item.address}｜取件码：${item.code}$locker';
    }).join('\n');
