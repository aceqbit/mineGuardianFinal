import 'package:equatable/equatable.dart';

import '../../../core/api/api_client.dart';

class RewardItem extends Equatable {
  const RewardItem({required this.id, required this.month, required this.title, required this.rank, required this.score, required this.stars, required this.amountInr, required this.extraHolidays, required this.workerName, required this.employeeId, required this.userId});
  final String id, month, title, workerName, employeeId, userId;
  final int rank, score, stars, amountInr, extraHolidays;

  factory RewardItem.fromJson(Map<String, dynamic> j) => RewardItem(
        id: (j['id'] ?? j['_id']).toString(),
        month: j['month'] as String? ?? '',
        title: j['title'] as String? ?? 'Honour',
        rank: (j['rank'] as num?)?.toInt() ?? 0,
        score: (j['score'] as num?)?.toInt() ?? 0,
        stars: (j['stars'] as num?)?.toInt() ?? 0,
        amountInr: (j['amountInr'] as num?)?.toInt() ?? 0,
        extraHolidays: (j['extraHolidays'] as num?)?.toInt() ?? 0,
        workerName: j['workerName'] as String? ?? '',
        employeeId: j['employeeId'] as String? ?? '',
        userId: j['userId'].toString(),
      );

  @override
  List<Object?> get props => [id, month, rank, userId];
}

class RewardsData extends Equatable {
  const RewardsData({this.months = const [], this.rewards = const []});
  final List<String> months;
  final List<RewardItem> rewards;
  @override
  List<Object?> get props => [months, rewards];
}

class RewardsRepository {
  RewardsRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  Future<RewardsData> list({String? month}) async {
    final j = await _api.getJson('/api/rewards', query: {'month': ?month});
    return RewardsData(
      months: ((j['months'] as List?) ?? const []).map((e) => '$e').toList(),
      rewards: ((j['rewards'] as List?) ?? const []).map((e) => RewardItem.fromJson((e as Map).cast<String, dynamic>())).toList(),
    );
  }

  /// Admin only. Idempotent on the server.
  Future<Map<String, dynamic>> publish(String month) => _api.postJson('/api/rewards/publish', query: {'month': month});
}
