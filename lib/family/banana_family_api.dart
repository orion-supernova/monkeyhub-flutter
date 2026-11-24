import '../backend/convex_client.dart';

/// A child's open banana request, as `bananaRequests:mine` returns it.
class OpenBananaRequest {
  OpenBananaRequest({
    required this.id,
    required this.item,
    required this.price,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String item;
  final int price;
  final String status;
  final DateTime createdAt;

  static OpenBananaRequest? fromJson(Map<String, dynamic> j) {
    final item = j['item'];
    final id = j['_id'] ?? j['requestId'];
    if (item is! String || id == null) return null;
    return OpenBananaRequest(
      id: id.toString(),
      item: item,
      price: ((j['price'] ?? 0) as num).toInt(),
      status: (j['status'] ?? 'open') as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          ((j['createdAt'] ?? 0) as num).toInt()),
    );
  }
}

/// A guardian's banana rules for one child, as `family:bananaRules` returns
/// them, with the child's balance.
class BananaRules {
  const BananaRules({
    this.ask = true,
    this.spend = 'lifelines',
    this.allowancePerWeek = 0,
    this.autoYesPerWeek = 0,
    this.balance = 0,
  });

  final bool ask;

  /// `all`, `lifelines` or `none`.
  final String spend;
  final int allowancePerWeek;
  final int autoYesPerWeek;
  final int balance;

  BananaRules copyWith({
    bool? ask,
    String? spend,
    int? allowancePerWeek,
    int? autoYesPerWeek,
    int? balance,
  }) =>
      BananaRules(
        ask: ask ?? this.ask,
        spend: spend ?? this.spend,
        allowancePerWeek: allowancePerWeek ?? this.allowancePerWeek,
        autoYesPerWeek: autoYesPerWeek ?? this.autoYesPerWeek,
        balance: balance ?? this.balance,
      );

  /// Tolerant of the server spelling the switch either way round (`ask` on,
  /// or `askOff` set), since the stored field is the latter.
  static BananaRules fromJson(Map<String, dynamic> j) => BananaRules(
        ask: j['ask'] is bool ? j['ask'] as bool : j['askOff'] != true,
        spend: switch (j['spend']) {
          'lifelines' => 'lifelines',
          'none' => 'none',
          'all' => 'all',
          _ => 'lifelines',
        },
        allowancePerWeek: ((j['allowancePerWeek'] ?? 0) as num).toInt(),
        autoYesPerWeek: ((j['autoYesPerWeek'] ?? 0) as num).toInt(),
        balance: ((j['balance'] ?? 0) as num).toInt(),
      );
}

/// One row of a child's banana ledger.
class BananaLedgerRow {
  BananaLedgerRow({
    required this.kind,
    required this.amount,
    required this.at,
    this.item,
  });

  final String kind;

  /// Signed: positive earned, negative spent.
  final int amount;
  final DateTime at;
  final String? item;

  static BananaLedgerRow fromJson(Map<String, dynamic> j) => BananaLedgerRow(
        kind: (j['kind'] ?? '') as String,
        amount: ((j['amount'] ?? 0) as num).toInt(),
        at: DateTime.fromMillisecondsSinceEpoch(((j['at'] ?? 0) as num).toInt()),
        item: j['item'] as String?,
      );
}

/// The banana half of the family surface: guardian rules, gifts and answers,
/// and the child's own open requests. Plain query/mutation calls, no
/// subscriptions: the guardian queue already carries the requests live, and
/// these screens read once on open.
class BananaFamilyApi {
  const BananaFamilyApi._();

  static ConvexBackend get _cv => ConvexBackend.instance;

  static Future<List<OpenBananaRequest>> mine(String userId) async {
    final res = await _cv.query('bananaRequests:mine', {'userId': userId});
    return [
      for (final e in (res as List?) ?? const [])
        if (e is Map) ?OpenBananaRequest.fromJson(e.cast<String, dynamic>()),
    ];
  }

  static Future<void> withdraw(String userId, String requestId) async {
    await _cv.mutation(
        'bananaRequests:withdraw', {'userId': userId, 'requestId': requestId});
  }

  /// [action] is `approve`, `decline` or `gift` (with [amount]). Throws the
  /// server's code (`NO_BANANAS`, `ALREADY_ANSWERED`, ...) in its text.
  static Future<void> answer({
    required String guardianId,
    required String requestId,
    required String action,
    int? amount,
  }) async {
    await _cv.mutation('bananaRequests:answer', {
      'userId': guardianId,
      'requestId': requestId,
      'action': action,
      'amount': ?amount,
    });
  }

  static Future<BananaRules> rules(String guardianId, String childId) async {
    final res = await _cv.query(
        'family:bananaRules', {'guardianId': guardianId, 'childId': childId});
    return res is Map
        ? BananaRules.fromJson(res.cast<String, dynamic>())
        : const BananaRules();
  }

  static Future<void> setRules({
    required String guardianId,
    required String childId,
    bool? ask,
    String? spend,
    int? allowancePerWeek,
    int? autoYesPerWeek,
  }) async {
    await _cv.mutation('family:setBananaRules', {
      'guardianId': guardianId,
      'childId': childId,
      'ask': ?ask,
      'spend': ?spend,
      'allowancePerWeek': ?allowancePerWeek,
      'autoYesPerWeek': ?autoYesPerWeek,
    });
  }

  static Future<void> sendBananas({
    required String guardianId,
    required String childId,
    required int amount,
  }) async {
    await _cv.mutation('family:sendBananas',
        {'guardianId': guardianId, 'childId': childId, 'amount': amount});
  }

  static Future<List<BananaLedgerRow>> history(
      String guardianId, String childId) async {
    final res = await _cv.query('family:bananaHistory',
        {'guardianId': guardianId, 'childId': childId});
    return [
      for (final e in (res as List?) ?? const [])
        if (e is Map) BananaLedgerRow.fromJson(e.cast<String, dynamic>()),
    ];
  }
}
