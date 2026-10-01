import 'package:equatable/equatable.dart';

import '../../../core/api/api_client.dart';

class LeaderRow extends Equatable {
  const LeaderRow({required this.userId, required this.name, required this.employeeId, required this.score, required this.streak, required this.xp, required this.rank});
  final String userId, name, employeeId;
  final int score, streak, xp, rank;

  factory LeaderRow.fromJson(Map<String, dynamic> j) => LeaderRow(
        userId: j['userId'].toString(),
        name: j['name'] as String? ?? '',
        employeeId: j['employeeId'] as String? ?? '',
        score: (j['score'] as num?)?.toInt() ?? 0,
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        rank: (j['rank'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [userId, score, streak, xp, rank];
}

class MyStanding extends Equatable {
  const MyStanding({this.rank, this.total = 0, this.score = 0, this.streak = 0, this.xp = 0, this.badges = const [], this.gapToNext = 0});
  final int? rank;
  final int total, score, streak, xp, gapToNext;
  final List<String> badges;

  factory MyStanding.fromJson(Map<String, dynamic> j) => MyStanding(
        rank: (j['rank'] as num?)?.toInt(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        score: (j['score'] as num?)?.toInt() ?? 0,
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        badges: ((j['badges'] as List?) ?? const []).map((b) => (b as Map)['key'].toString()).toList(),
        gapToNext: (j['gapToNext'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [rank, total, score, streak, xp, badges, gapToNext];
}

const badgeLabels = {
  'STREAK_7': '7-day streak',
  'STREAK_30': '30-day streak',
  'PERFECT_WEEK': 'Perfect week',
  'HAZARD_HERO': 'Hazard hero',
  'FIRST_PASS_PRO': 'First-pass pro',
};

class LeaderboardRepository {
  LeaderboardRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  Future<List<LeaderRow>> workers() async => (await _api.getList('/api/leaderboard')).map((e) => LeaderRow.fromJson((e as Map).cast<String, dynamic>())).toList();
  Future<List<LeaderRow>> supervisors() async => (await _api.getList('/api/leaderboard/supervisors')).map((e) => LeaderRow.fromJson((e as Map).cast<String, dynamic>())).toList();
  Future<MyStanding> me() async => MyStanding.fromJson(await _api.getJson('/api/leaderboard/me'));
}
