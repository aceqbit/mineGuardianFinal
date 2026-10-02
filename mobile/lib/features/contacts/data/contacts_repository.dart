import 'package:equatable/equatable.dart';

import '../../../contracts/enums.dart';
import '../../../core/api/api_client.dart';

class EmergencyContactItem extends Equatable {
  const EmergencyContactItem({required this.id, required this.category, required this.name, required this.displayNumber, this.notes = '', this.dialE164});
  final String id, name, displayNumber, notes;
  final ContactCategory category;

  /// Only admins receive this.
  final String? dialE164;

  factory EmergencyContactItem.fromJson(Map<String, dynamic> j) => EmergencyContactItem(
        id: j['id'].toString(),
        category: ContactCategory.fromWire(j['category'] as String),
        name: j['name'] as String? ?? '',
        displayNumber: j['displayNumber'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        dialE164: j['dialE164'] as String?,
      );

  /// A `tel:` target made from the display number's digits (first number if two are listed).
  String get telUri => 'tel:${displayNumber.split('/').first.replaceAll(RegExp(r'[^0-9+]'), '')}';

  @override
  List<Object?> get props => [id, category, name, displayNumber];
}

class ContactActionResult extends Equatable {
  const ContactActionResult({required this.ok, required this.dryRun, this.count});
  final bool ok, dryRun;
  final int? count;
  @override
  List<Object?> get props => [ok, dryRun, count];
}

class ContactsRepository {
  ContactsRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  Future<List<EmergencyContactItem>> list() async => (await _api.getList('/api/contacts')).map((e) => EmergencyContactItem.fromJson((e as Map).cast<String, dynamic>())).toList();

  Future<ContactActionResult> call(String id, {String? message}) async {
    final r = await _api.postJson('/api/contacts/$id/call', body: {'message': ?message});
    return ContactActionResult(ok: r['ok'] == true, dryRun: r['dryRun'] == true);
  }

  Future<ContactActionResult> sms(String id, {String? message}) async {
    final r = await _api.postJson('/api/contacts/$id/sms', body: {'message': ?message});
    return ContactActionResult(ok: r['ok'] == true, dryRun: r['dryRun'] == true);
  }

  Future<ContactActionResult> notifyAll({String? message}) async {
    final r = await _api.postJson('/api/contacts/notify-all', body: {'message': ?message});
    return ContactActionResult(ok: true, dryRun: r['dryRun'] == true, count: (r['contacts'] as num?)?.toInt());
  }
}
