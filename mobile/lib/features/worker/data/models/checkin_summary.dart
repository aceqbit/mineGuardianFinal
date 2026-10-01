import 'package:equatable/equatable.dart';

import '../../../../contracts/enums.dart';

/// Item of GET /api/checkins/mine: a check-in plus its review summary (if any).
class CheckinSummary extends Equatable {
  const CheckinSummary({
    required this.id,
    required this.capturedAt,
    required this.status,
    this.thumbUrl,
    this.verdict,
    this.finalVerdict,
    this.decisionAction,
    this.missing = const [],
  });

  final String id;
  final DateTime capturedAt;
  final CheckinStatus status;
  final String? thumbUrl;
  final Verdict? verdict;
  final Verdict? finalVerdict;
  final DecisionAction? decisionAction;
  final List<PpeKey> missing;

  factory CheckinSummary.fromJson(Map<String, dynamic> j) {
    final review = (j['review'] as Map?)?.cast<String, dynamic>();
    Verdict? v(dynamic w) => w is String ? Verdict.fromWire(w) : null;
    return CheckinSummary(
      id: (j['id'] ?? j['_id']).toString(),
      capturedAt: DateTime.tryParse((j['capturedAt'] ?? j['receivedAt'] ?? j['createdAt'] ?? '').toString()) ?? DateTime.now().toUtc(),
      status: CheckinStatus.fromWire(j['status'] as String? ?? 'RECEIVED'),
      thumbUrl: (j['imageUrl'] ?? j['thumbUrl']) as String?,
      verdict: v(review?['verdict']),
      finalVerdict: v(review?['finalVerdict']),
      decisionAction: review?['decisionAction'] is String ? DecisionAction.fromWire(review!['decisionAction'] as String) : null,
      missing: ((review?['missing'] as List?) ?? const []).map((e) => PpeKey.fromWire(e as String)).toList(),
    );
  }

  CheckinSummary copyWith({CheckinStatus? status, Verdict? verdict, Verdict? finalVerdict, DecisionAction? decisionAction, List<PpeKey>? missing}) => CheckinSummary(
        id: id,
        capturedAt: capturedAt,
        status: status ?? this.status,
        thumbUrl: thumbUrl,
        verdict: verdict ?? this.verdict,
        finalVerdict: finalVerdict ?? this.finalVerdict,
        decisionAction: decisionAction ?? this.decisionAction,
        missing: missing ?? this.missing,
      );

  @override
  List<Object?> get props => [id, capturedAt, status, thumbUrl, verdict, finalVerdict, decisionAction, missing];
}

class WorkerStats extends Equatable {
  const WorkerStats({required this.score, required this.rank, required this.xp, required this.streak});
  final int score;
  final int rank;
  final int xp;
  final int streak;

  factory WorkerStats.fromJson(Map<String, dynamic> j) => WorkerStats(
        score: (j['score'] as num?)?.round() ?? 0,
        rank: (j['rank'] as num?)?.round() ?? 0,
        xp: (j['xp'] as num?)?.round() ?? 0,
        streak: (j['streak'] as num?)?.round() ?? 0,
      );

  @override
  List<Object?> get props => [score, rank, xp, streak];
}
