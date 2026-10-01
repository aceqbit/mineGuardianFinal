import 'package:equatable/equatable.dart';

import '../../../../contracts/enums.dart';

DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toUtc();
double? _d(dynamic v) => (v as num?)?.toDouble();

class ItemRegion extends Equatable {
  const ItemRegion(this.x, this.y, this.w, this.h);
  final double x, y, w, h;
  static ItemRegion? from(dynamic j) => j is Map ? ItemRegion(_d(j['x']) ?? 0, _d(j['y']) ?? 0, _d(j['w']) ?? 0, _d(j['h']) ?? 0) : null;
  @override
  List<Object?> get props => [x, y, w, h];
}

class AiItem extends Equatable {
  const AiItem({required this.key, required this.required, required this.status, required this.confidence, required this.evidence, this.region, this.source = 'gemini'});
  final PpeKey key;
  final bool required;
  final PpeStatus status;
  final double confidence;
  final String evidence;
  final ItemRegion? region;
  final String source;

  factory AiItem.fromJson(Map<String, dynamic> j) => AiItem(
        key: PpeKey.fromWire(j['key'] as String),
        required: j['required'] == true,
        status: PpeStatus.fromWire(j['status'] as String? ?? 'UNCERTAIN'),
        confidence: _d(j['confidence']) ?? 0,
        evidence: j['evidence'] as String? ?? '',
        region: ItemRegion.from(j['region']),
        source: j['source'] as String? ?? 'gemini',
      );

  /// Pre-selected from the AI only for PRESENT / ABSENT at confidence >= 0.60.
  bool get preselectable => (status == PpeStatus.present || status == PpeStatus.absent) && confidence >= 0.6;

  @override
  List<Object?> get props => [key, required, status, confidence, evidence, region, source];
}

class YoloBox extends Equatable {
  const YoloBox({required this.label, required this.confidence, required this.region});
  final String label;
  final double confidence;
  final ItemRegion region;
  @override
  List<Object?> get props => [label, confidence, region];
}

class ToolTraceEntry extends Equatable {
  const ToolTraceEntry({required this.name, required this.ms, required this.status, required this.calledBy});
  final String name;
  final int ms;
  final String status;
  final String calledBy;
  @override
  List<Object?> get props => [name, ms, status, calledBy];
}

class AiResult extends Equatable {
  const AiResult({
    this.verdict,
    this.confidence = 0,
    this.critLevel = Criticality.none,
    this.critScore = 0,
    this.drivers = const [],
    this.emergencyDetected = false,
    this.emergencyPossible = false,
    this.emergencyType = EmergencyType.none,
    this.emergencyEvidence = '',
    this.items = const [],
    this.summary = '',
    this.observations = const [],
    this.risks = const [],
    this.actions = const [],
    this.conflicts = const [],
    this.limitations = const [],
    this.yolo = const [],
    this.imageQuality = const {},
    this.tools = const [],
    this.model = '',
    this.yoloProvider = 'none',
    this.latencyMs = 0,
    this.error,
  });

  final Verdict? verdict;
  final double confidence;
  final Criticality critLevel;
  final int critScore;
  final List<String> drivers;
  final bool emergencyDetected;
  final bool emergencyPossible;
  final EmergencyType emergencyType;
  final String emergencyEvidence;
  final List<AiItem> items;
  final String summary;
  final List<String> observations;
  final List<String> risks;
  final List<String> actions;
  final List<String> conflicts;
  final List<String> limitations;
  final List<YoloBox> yolo;
  final Map<String, dynamic> imageQuality;
  final List<ToolTraceEntry> tools;
  final String model;
  final String yoloProvider;
  final int latencyMs;
  final String? error;

  List<AiItem> get requiredItems => items.where((i) => i.required).toList();
  List<AiItem> get otherItems => items.where((i) => !i.required).toList();

  static List<String> _s(dynamic v) => ((v as List?) ?? const []).map((e) => '$e').toList();

  factory AiResult.fromJson(Map<String, dynamic> j) {
    final crit = (j['criticality'] as Map?)?.cast<String, dynamic>() ?? const {};
    final em = (j['emergency'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rep = (j['report'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AiResult(
      verdict: j['overallVerdict'] is String ? Verdict.fromWire(j['overallVerdict'] as String) : null,
      confidence: _d(j['overallConfidence']) ?? 0,
      critLevel: crit['level'] is String ? Criticality.fromWire(crit['level'] as String) : Criticality.none,
      critScore: (crit['score'] as num?)?.round() ?? 0,
      drivers: _s(crit['drivers']),
      emergencyDetected: em['detected'] == true,
      emergencyPossible: em['possible'] == true,
      emergencyType: em['type'] is String ? EmergencyType.fromWire(em['type'] as String) : EmergencyType.none,
      emergencyEvidence: em['evidence'] as String? ?? '',
      items: ((j['items'] as List?) ?? const []).map((e) => AiItem.fromJson((e as Map).cast<String, dynamic>())).toList(),
      summary: j['summary'] as String? ?? '',
      observations: _s(rep['observations']),
      risks: _s(rep['risks']),
      actions: _s(rep['recommendedActions']),
      conflicts: _s(j['conflicts']),
      limitations: _s(j['limitations']),
      yolo: ((j['yoloDetections'] as List?) ?? const []).map((e) {
        final m = (e as Map).cast<String, dynamic>();
        final b = ItemRegion.from(m['box']) ?? const ItemRegion(0, 0, 0, 0);
        return YoloBox(label: m['label'] as String? ?? '', confidence: _d(m['confidence']) ?? 0, region: b);
      }).toList(),
      imageQuality: (j['imageQuality'] as Map?)?.cast<String, dynamic>() ?? const {},
      tools: ((j['toolTrace'] as List?) ?? const []).map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return ToolTraceEntry(name: m['name'] as String? ?? '', ms: (m['ms'] as num?)?.toInt() ?? 0, status: m['status'] as String? ?? '', calledBy: m['calledBy'] as String? ?? 'model');
      }).toList(),
      model: j['model'] as String? ?? '',
      yoloProvider: j['yoloProvider'] as String? ?? 'none',
      latencyMs: (j['latencyMs'] as num?)?.toInt() ?? 0,
      error: (j['error'] as Map?)?['message'] as String?,
    );
  }

  @override
  List<Object?> get props => [verdict, confidence, critLevel, critScore, items, summary, emergencyDetected, emergencyPossible, error];
}

class DecisionInfo extends Equatable {
  const DecisionInfo({required this.action, required this.finalVerdict, required this.note, this.decidedAt, this.agreedWithAi = false, this.decidedByName});
  final DecisionAction action;
  final Verdict finalVerdict;
  final String note;
  final DateTime? decidedAt;
  final bool agreedWithAi;
  final String? decidedByName;
  @override
  List<Object?> get props => [action, finalVerdict, note, decidedAt, agreedWithAi, decidedByName];
}

class RecentDecision extends Equatable {
  const RecentDecision({this.date, this.verdict, this.missing = const []});
  final DateTime? date;
  final Verdict? verdict;
  final List<PpeKey> missing;
  @override
  List<Object?> get props => [date, verdict, missing];
}

class CheckInFacts extends Equatable {
  const CheckInFacts({this.imageUrl, this.capturedAt, this.uploadedAt, this.receivedAt, this.clockSkewSec = 0, this.source = 'camera', this.accuracyM, this.insideZone, this.withinShift, this.flags = const [], this.imageAspect = 0.75});
  final String? imageUrl;
  final DateTime? capturedAt;
  final DateTime? uploadedAt;
  final DateTime? receivedAt;
  final int clockSkewSec;
  final String source;
  final double? accuracyM;
  final bool? insideZone;
  final bool? withinShift;
  final List<IntegrityFlag> flags;
  final double imageAspect;
  @override
  List<Object?> get props => [imageUrl, capturedAt, uploadedAt, receivedAt, clockSkewSec, source, accuracyM, insideZone, withinShift, flags, imageAspect];
}

class ReviewData extends Equatable {
  const ReviewData({required this.reviewId, required this.checkInId, required this.decided, required this.ai, required this.facts, required this.workerName, required this.employeeId, required this.zoneCode, required this.zoneName, required this.requiredPpe, this.decision, this.recent = const []});
  final String reviewId;
  final String checkInId;
  final bool decided;
  final AiResult ai;
  final CheckInFacts facts;
  final String workerName;
  final String employeeId;
  final String zoneCode;
  final String zoneName;
  final List<PpeKey> requiredPpe;
  final DecisionInfo? decision;
  final List<RecentDecision> recent;

  factory ReviewData.fromJson(Map<String, dynamic> j) {
    final review = (j['review'] as Map).cast<String, dynamic>();
    final ci = (j['checkIn'] as Map?)?.cast<String, dynamic>() ?? const {};
    final worker = (j['worker'] as Map?)?.cast<String, dynamic>() ?? const {};
    final zone = (j['zone'] as Map?)?.cast<String, dynamic>() ?? const {};
    final dec = (review['decision'] as Map?)?.cast<String, dynamic>();
    final sq = (ci['serverQuality'] as Map?)?.cast<String, dynamic>() ?? const {};
    final w = _d(sq['width']) ?? 3, h = _d(sq['height']) ?? 4;
    return ReviewData(
      reviewId: (review['id'] ?? review['_id']).toString(),
      checkInId: (ci['id'] ?? ci['_id'] ?? review['checkInId']).toString(),
      decided: review['status'] == 'DECIDED',
      ai: AiResult.fromJson((review['ai'] as Map?)?.cast<String, dynamic>() ?? const {}),
      facts: CheckInFacts(
        imageUrl: ci['imageUrl'] as String?,
        capturedAt: _dt(ci['capturedAt']),
        uploadedAt: _dt(ci['uploadStartedAt']),
        receivedAt: _dt(ci['receivedAt']),
        clockSkewSec: (ci['clockSkewSec'] as num?)?.toInt() ?? 0,
        source: ci['source'] as String? ?? 'camera',
        accuracyM: _d(ci['accuracyM']),
        insideZone: ci['insideZone'] as bool?,
        withinShift: ci['withinShift'] as bool?,
        flags: ((ci['integrityFlags'] as List?) ?? const []).map((e) => IntegrityFlag.fromWire(e as String)).toList(),
        imageAspect: h == 0 ? 0.75 : w / h,
      ),
      workerName: worker['fullName'] as String? ?? '',
      employeeId: worker['employeeId'] as String? ?? '',
      zoneCode: zone['code'] as String? ?? '',
      zoneName: zone['name'] as String? ?? '',
      requiredPpe: ((zone['requiredPpe'] as List?) ?? const []).map((e) => PpeKey.fromWire(e as String)).toList(),
      decision: dec == null
          ? null
          : DecisionInfo(
              action: DecisionAction.fromWire(dec['action'] as String),
              finalVerdict: Verdict.fromWire(dec['finalVerdict'] as String),
              note: dec['note'] as String? ?? '',
              decidedAt: _dt(dec['decidedAt']),
              agreedWithAi: dec['agreedWithAi'] == true,
            ),
      recent: ((j['recentDecisions'] as List?) ?? const []).map((e) {
        final m = (e as Map).cast<String, dynamic>();
        return RecentDecision(date: _dt(m['date']), verdict: m['finalVerdict'] is String ? Verdict.fromWire(m['finalVerdict'] as String) : null, missing: ((m['missing'] as List?) ?? const []).map((k) => PpeKey.fromWire(k as String)).toList());
      }).toList(),
    );
  }

  @override
  List<Object?> get props => [reviewId, checkInId, decided, ai, facts, workerName, zoneCode, decision, recent];
}
