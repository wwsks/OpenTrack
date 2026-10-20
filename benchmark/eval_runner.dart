// 短信解析评测基准运行器（OpenTrack benchmark suite）
//
// 用法（仓库根目录）：
//   dart run benchmark/eval_runner.dart            # 离线：正则引擎指标 + 分组指标
//   dart run benchmark/eval_runner.dart --llm      # 增强：额外跑 LLM 兜底提取与归一化（需 API Key）
//
// 环境变量（--llm 时）：
//   SILICONFLOW_API_KEY / LLM_API_KEY  必填
//   LLM_BASE_URL  默认 https://api.siliconflow.cn/v1
//   LLM_MODEL     默认 deepseek-ai/DeepSeek-V3
//
// 设计原则：本文件只依赖纯 Dart 组件（sms_parser / llm_prompts / sms_fallback_extractor），
// 不引入 Flutter 插件，因此可以直接 `dart run`。

import 'dart:convert';
import 'dart:io';

import 'package:opentrack/models/sms_model.dart';
import 'package:opentrack/services/llm_service.dart';
import 'package:opentrack/utils/llm_prompts.dart';
import 'package:opentrack/utils/sms_fallback_extractor.dart';
import 'package:opentrack/utils/sms_parser.dart';

/// 数据集单条样本（jsonl 行）
class EvalSample {
  final String id;
  final String body;

  /// 标准驿站名（分组真值）
  final String station;

  /// 分类：standard / nonstandard-code / hard / negative
  final String category;

  /// 标注：期望提取的取件码 / 地址 / 柜号 / 发送方（code 为空 = 负样本，不应提取）
  final String code;
  final String address;
  final String locker;
  final String sender;

  /// 地址可接受集合（短信里同一地点有多种写法时使用）
  final List<String> addressAny;

  EvalSample({
    required this.id,
    required this.body,
    required this.station,
    required this.category,
    required this.code,
    required this.address,
    required this.locker,
    required this.sender,
    this.addressAny = const [],
  });

  bool get isNegative => code.isEmpty;

  /// 提取地址是否可接受（等于标注地址或任一可接受写法）
  bool addressAccepted(String extracted) {
    if (extracted == address) return true;
    return addressAny.contains(extracted);
  }

  factory EvalSample.fromJson(Map<String, dynamic> json) {
    final label = (json['label'] as Map?)?.cast<String, dynamic>() ?? {};
    return EvalSample(
      id: json['id'] as String,
      body: json['body'] as String,
      station: (json['station'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'standard',
      code: (label['code'] as String?) ?? '',
      address: (label['address'] as String?) ?? '',
      locker: (label['locker'] as String?) ?? '',
      sender: (label['sender'] as String?) ?? '',
      addressAny: ((label['address_any'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

/// 一次提取结果（正则或 LLM）
class Extraction {
  final String code;
  final String address;
  final String locker;
  const Extraction({required this.code, required this.address, this.locker = ''});
}

/// 离线（正则）评测指标
class RegexMetrics {
  final int total;
  final int valid;
  final int negatives;
  final int parseSuccess; // 正则解析成功的条数（含提取不准的）
  final int exactCorrect; // 取件码 + 地址都对
  final int falsePositives; // 负样本被提取出取件码
  final double groupingPrecision;
  final double groupingRecall;
  final double groupingF1;
  final int predictedGroups; // 精确匹配分组产生的组数
  final int trueGroups; // 真实驿站组数

  const RegexMetrics({
    required this.total,
    required this.valid,
    required this.negatives,
    required this.parseSuccess,
    required this.exactCorrect,
    required this.falsePositives,
    required this.groupingPrecision,
    required this.groupingRecall,
    required this.groupingF1,
    required this.predictedGroups,
    required this.trueGroups,
  });

  double get exactRate => valid == 0 ? 0 : exactCorrect / valid;
  double get parseRate => valid == 0 ? 0 : parseSuccess / valid;
  double get falsePositiveRate => negatives == 0 ? 0 : falsePositives / negatives;
}

/// 读取 jsonl 数据集
List<EvalSample> loadDataset(File file) {
  final samples = <EvalSample>[];
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    samples.add(EvalSample.fromJson(
        json.decode(trimmed) as Map<String, dynamic>));
  }
  return samples;
}

/// 正则提取一条短信
Extraction? extractByRegex(SmsParser parser, String body) {
  final r = parser.parseSms(body);
  if (!r.success || r.code.isEmpty) return null;
  return Extraction(code: r.code, address: r.address, locker: r.lockerNumber);
}

/// 分组 pairwise 指标：样本两两之间"是否同组"的判断质量
double _precision(int tp, int fp) => (tp + fp) == 0 ? 1.0 : tp / (tp + fp);
double _recall(int tp, int fn) => (tp + fn) == 0 ? 1.0 : tp / (tp + fn);
double _f1(double p, double r) => (p + r) == 0 ? 0 : 2 * p * r / (p + r);

/// 计算分组成对指标
({double precision, double recall, double f1, int predictedGroups})
    groupingScore(
  List<EvalSample> samples,
  String Function(EvalSample) groupKeyOf,
) {
  var tp = 0, fp = 0, fn = 0;
  final groups = <String>{};
  for (var i = 0; i < samples.length; i++) {
    for (var j = i + 1; j < samples.length; j++) {
      final truthSame = samples[i].station == samples[j].station;
      final predSame = groupKeyOf(samples[i]) == groupKeyOf(samples[j]);
      if (truthSame && predSame) {
        tp++;
      } else if (!truthSame && predSame) {
        fp++;
      } else if (truthSame && !predSame) {
        fn++;
      }
    }
    groups.add(groupKeyOf(samples[i]));
  }
  final p = _precision(tp, fp);
  final r = _recall(tp, fn);
  return (precision: p, recall: r, f1: _f1(p, r), predictedGroups: groups.length);
}

/// 离线评测：正则引擎识别率、误提取率、精确匹配分组质量
RegexMetrics runRegexEval(List<EvalSample> samples, {SmsParser? parser}) {
  final p = parser ?? SmsParser();
  final valid = samples.where((s) => !s.isNegative).toList();
  final negatives = samples.where((s) => s.isNegative).toList();

  var parseSuccess = 0, exactCorrect = 0, falsePositives = 0;
  final extracted = <String, Extraction>{}; // sampleId -> extraction

  for (final s in valid) {
    final e = extractByRegex(p, s.body);
    if (e == null) continue;
    parseSuccess++;
    extracted[s.id] = e;
    if (e.code == s.code && s.addressAccepted(e.address)) exactCorrect++;
  }
  for (final s in negatives) {
    final e = extractByRegex(p, s.body);
    if (e != null && e.code.isNotEmpty) falsePositives++;
  }

  // 分组指标：只对"提取成功"的样本评价（模拟 App 中进入分组的条目）
  final grouped = valid.where((s) => extracted.containsKey(s.id)).toList();
  final score = groupingScore(grouped, (s) => extracted[s.id]!.address);
  final trueGroups = valid.map((s) => s.station).toSet().length;

  return RegexMetrics(
    total: samples.length,
    valid: valid.length,
    negatives: negatives.length,
    parseSuccess: parseSuccess,
    exactCorrect: exactCorrect,
    falsePositives: falsePositives,
    groupingPrecision: score.precision,
    groupingRecall: score.recall,
    groupingF1: score.f1,
    predictedGroups: score.predictedGroups,
    trueGroups: trueGroups,
  );
}

/// LLM 增强评测：兜底恢复率 + 归一化后的分组质量
class LlmMetrics {
  final int fallbackCandidates;
  final int fallbackRecovered;
  final int llmBatches;
  final double groupingPrecision;
  final double groupingRecall;
  final double groupingF1;
  final int normalizedGroups;
  final int trueGroups;

  const LlmMetrics({
    required this.fallbackCandidates,
    required this.fallbackRecovered,
    required this.llmBatches,
    required this.groupingPrecision,
    required this.groupingRecall,
    required this.groupingF1,
    required this.normalizedGroups,
    required this.trueGroups,
  });

  double get recoveryRate =>
      fallbackCandidates == 0 ? 0 : fallbackRecovered / fallbackCandidates;
}

/// 用真实 LLM 跑增强评测（网络调用，需 API Key）
Future<LlmMetrics> runLlmEval(List<EvalSample> samples, LlmService llm) async {
  final parser = SmsParser();
  final valid = samples.where((s) => !s.isNegative).toList();

  // 1) 兜底提取：候选 = 正则解析失败的正样本
  final candidates = <EvalSample>[];
  final extracted = <String, Extraction>{};
  for (final s in valid) {
    final e = extractByRegex(parser, s.body);
    if (e != null) {
      extracted[s.id] = e;
    } else {
      candidates.add(s);
    }
  }

  var batches = 0;
  var recovered = 0;
  for (var start = 0;
      start < candidates.length;
      start += LlmSmsFallbackExtractor.maxBatchSize) {
    final end =
        (start + LlmSmsFallbackExtractor.maxBatchSize).clamp(0, candidates.length);
    final chunk = candidates.sublist(start, end);
    batches++;
    final raw = await llm.chat(
      system: kFallbackExtractSystemPrompt,
      user: buildFallbackExtractPrompt(
          chunk.map((s) => SmsModel(id: s.id, body: s.body, timestamp: 0)).toList()),
      jsonMode: true,
    );
    final parsed = LlmService.tryParseJsonObject(raw);
    if (parsed == null) continue;
    for (final entry in parsed.entries) {
      final idx = int.tryParse(entry.key);
      if (idx == null || idx < 1 || idx > chunk.length) continue;
      final v = entry.value;
      if (v is! Map) continue;
      final code = v['code'];
      if (code is! String || code.trim().isEmpty) continue;
      final s = chunk[idx - 1];
      final addr = v['address'];
      final e = Extraction(
        code: code.trim(),
        address: (addr is String && addr.trim().isNotEmpty) ? addr.trim() : '未知地址',
      );
      extracted[s.id] = e;
      if (e.code == s.code && s.addressAccepted(e.address)) recovered++;
    }
  }

  // 2) 归一化：对所有已提取地址批量归一，再算分组质量
  final grouped = valid.where((s) => extracted.containsKey(s.id)).toList();
  final addresses = grouped.map((s) => extracted[s.id]!.address).toSet().toList();
  var mapping = <String, String>{};
  if (addresses.isNotEmpty) {
    batches++;
    final raw = await llm.chat(
      system: kNormalizeSystemPrompt,
      user: buildNormalizePrompt(addresses),
      jsonMode: true,
    );
    final parsed = LlmService.tryParseJsonObject(raw);
    if (parsed != null) {
      for (final e in parsed.entries) {
        if (addresses.contains(e.key) && e.value is String) {
          mapping[e.key] = e.value as String;
        }
      }
    }
  }

  final score = groupingScore(
    grouped,
    (s) => mapping[extracted[s.id]!.address] ?? extracted[s.id]!.address,
  );
  final trueGroups = valid.map((s) => s.station).toSet().length;

  return LlmMetrics(
    fallbackCandidates: candidates.length,
    fallbackRecovered: recovered,
    llmBatches: batches,
    groupingPrecision: score.precision,
    groupingRecall: score.recall,
    groupingF1: score.f1,
    normalizedGroups: score.predictedGroups,
    trueGroups: trueGroups,
  );
}

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

/// 分类分解：各分类的解析率/精确识别率（负样本报告误提取率）
String categoryBreakdown(List<EvalSample> samples) {
  final parser = SmsParser();
  final byCat = <String, List<EvalSample>>{};
  for (final s in samples) {
    byCat.putIfAbsent(s.category, () => []).add(s);
  }
  const notes = {
    'standard': '标准格式（主流快递模板）',
    'nonstandard-code': '非标准取件码格式（如 B26）',
    'hard': '口语化/无签名等难例（兜底提取目标）',
    'negative': '负样本（不应提取出取件码）',
  };
  final b = StringBuffer()
    ..writeln('| 分类 | 样本数 | 解析率 | 精确识别率 / 误提取率 | 说明 |')
    ..writeln('|---|---|---|---|---|');
  for (final cat in ['standard', 'nonstandard-code', 'hard', 'negative']) {
    final list = byCat[cat];
    if (list == null || list.isEmpty) continue;
    if (cat == 'negative') {
      var fp = 0;
      for (final s in list) {
        final e = extractByRegex(parser, s.body);
        if (e != null && e.code.isNotEmpty) fp++;
      }
      b.writeln('| $cat | ${list.length} | — | 误提取率 ${_pct(fp / list.length)} | ${notes[cat]} |');
    } else {
      var parseOk = 0, exact = 0;
      for (final s in list) {
        final e = extractByRegex(parser, s.body);
        if (e == null) continue;
        parseOk++;
        if (e.code == s.code && s.addressAccepted(e.address)) exact++;
      }
      b.writeln('| $cat | ${list.length} | ${_pct(parseOk / list.length)} | '
          '${_pct(exact / list.length)} | ${notes[cat]} |');
    }
  }
  return b.toString();
}

/// 组装 markdown 报告
String buildReport(RegexMetrics m, List<EvalSample> samples, {LlmMetrics? llm}) {
  final b = StringBuffer()
    ..writeln('# 短信解析评测基准结果')
    ..writeln()
    ..writeln('生成时间：${DateTime.now().toIso8601String()}')
    ..writeln()
    ..writeln('## 数据集')
    ..writeln()
    ..writeln('| 项 | 值 |')
    ..writeln('|---|---|')
    ..writeln('| 样本总数 | ${m.total} |')
    ..writeln('| 有效样本（标注含取件码） | ${m.valid} |')
    ..writeln('| 负样本（不应提取） | ${m.negatives} |')
    ..writeln('| 真实驿站组数 | ${m.trueGroups} |')
    ..writeln()
    ..writeln('## 正则引擎（离线）')
    ..writeln()
    ..writeln('| 指标 | 结果 |')
    ..writeln('|---|---|')
    ..writeln('| 解析成功率 | ${_pct(m.parseRate)}（${m.parseSuccess}/${m.valid}） |')
    ..writeln('| 精确识别率（码+地址全对） | ${_pct(m.exactRate)}（${m.exactCorrect}/${m.valid}） |')
    ..writeln('| 负样本误提取率 | ${_pct(m.falsePositiveRate)}（${m.falsePositives}/${m.negatives}） |')
    ..writeln('| 分组精确匹配 pairwise P/R/F1 | ${_pct(m.groupingPrecision)} / ${_pct(m.groupingRecall)} / ${_pct(m.groupingF1)} |')
    ..writeln('| 精确匹配产生的组数（vs 真实 ${m.trueGroups} 组） | ${m.predictedGroups} 组（> 真实值即同站被拆分） |')
    ..writeln()
    ..writeln('### 分类分解')
    ..writeln()
    ..write(categoryBreakdown(samples));

  if (llm != null) {
    b
      ..writeln()
      ..writeln('## LLM 增强（兜底提取 + 归一化）')
      ..writeln()
      ..writeln('| 指标 | 结果 |')
      ..writeln('|---|---|')
      ..writeln('| 兜底候选（正则失败的正样本） | ${llm.fallbackCandidates} |')
      ..writeln('| 兜底正确恢复 | ${llm.fallbackRecovered}（${_pct(llm.recoveryRate)}） |')
      ..writeln('| 归一化后分组 pairwise P/R/F1 | ${_pct(llm.groupingPrecision)} / ${_pct(llm.groupingRecall)} / ${_pct(llm.groupingF1)} |')
      ..writeln('| 归一化后组数（vs 真实 ${llm.trueGroups} 组） | ${llm.normalizedGroups} 组 |')
      ..writeln('| LLM 调用批次数 | ${llm.llmBatches} |');
  }
  return b.toString();
}

Future<void> main(List<String> args) async {
  final useLlm = args.contains('--llm');
  final audit = args.contains('--audit');

  // 优先脚本相对路径，兼容从仓库根目录运行
  final scriptDir = File.fromUri(Platform.script).parent.path;
  var datasetFile = File('$scriptDir/sms_dataset.jsonl');
  if (!datasetFile.existsSync()) {
    datasetFile = File('benchmark/sms_dataset.jsonl');
  }
  if (!datasetFile.existsSync()) {
    stderr.writeln('找不到数据集 sms_dataset.jsonl');
    exit(1);
  }

  final samples = loadDataset(datasetFile);
  final regex = runRegexEval(samples);
  stdout.writeln('数据集：${samples.length} 条（有效 ${regex.valid} / 负样本 ${regex.negatives}）');
  stdout.writeln('正则：解析率 ${_pct(regex.parseRate)}，精确识别率 ${_pct(regex.exactRate)}，'
      '误提取率 ${_pct(regex.falsePositiveRate)}，分组 F1 ${_pct(regex.groupingF1)}'
      '（${regex.predictedGroups} 组 vs 真实 ${regex.trueGroups} 组）');

  if (audit) {
    final parser = SmsParser();
    stdout.writeln('\n--- 审计：未精确解析的样本 ---');
    for (final s in samples.where((s) => !s.isNegative)) {
      final e = extractByRegex(parser, s.body);
      final ok = e != null && e.code == s.code && s.addressAccepted(e.address);
      if (ok) continue;
      final got = e == null
          ? '(解析失败)'
          : 'code=${e.code} address=${e.address}';
      stdout.writeln('${s.id}: 期望 code=${s.code} address=${s.address} | 得到 $got');
      stdout.writeln('    ${s.body}');
    }
    stdout.writeln('--- 审计：负样本被提取 ---');
    for (final s in samples.where((s) => s.isNegative)) {
      final e = extractByRegex(parser, s.body);
      if (e == null || e.code.isEmpty) continue;
      stdout.writeln('${s.id}: 得到 code=${e.code} address=${e.address}');
      stdout.writeln('    ${s.body}');
    }
  }

  LlmMetrics? llm;
  if (useLlm) {
    final key = Platform.environment['SILICONFLOW_API_KEY'] ??
        Platform.environment['LLM_API_KEY'] ??
        '';
    if (key.isEmpty) {
      stderr.writeln('--llm 需要环境变量 SILICONFLOW_API_KEY（或 LLM_API_KEY）');
      exit(1);
    }
    final llmService = LlmService(
      baseUrl: Platform.environment['LLM_BASE_URL'] ??
          'https://api.siliconflow.cn/v1',
      model: Platform.environment['LLM_MODEL'] ?? 'deepseek-ai/DeepSeek-V3',
      apiKey: key,
    );
    llm = await runLlmEval(samples, llmService);
    stdout.writeln('LLM：兜底恢复 ${llm.fallbackRecovered}/${llm.fallbackCandidates}'
        '（${_pct(llm.recoveryRate)}），归一化分组 F1 ${_pct(llm.groupingF1)}'
        '（${llm.normalizedGroups} 组 vs 真实 ${llm.trueGroups} 组），调用 ${llm.llmBatches} 批');
  }

  final report = buildReport(regex, samples, llm: llm);
  final resultsDir = Directory('${datasetFile.parent.path}/results');
  resultsDir.createSync(recursive: true);
  final stamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '')
      .split('.')
      .first;
  final outFile = File('${resultsDir.path}/eval_$stamp.md');
  outFile.writeAsStringSync(report);
  stdout.writeln('报告已写入：${outFile.path}');
}
