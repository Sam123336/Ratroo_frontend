/// A transport operator, described only by what the data says about it.
///
/// The reference board shows a star rating and review count per operator.
/// Ratroo has no ratings and no reviews, so this model carries none — a
/// fabricated "4.2 ★ (128)" would be a claim about a real company.
class TransitProvider {
  final String code;

  /// The operator's full name, or its code when it is not registered.
  final String name;
  final String? website;

  /// True when the operator has a row in the providers table, i.e. a
  /// human-readable name and a confirmed website.
  final bool registered;
  final int routeCount;
  final int stopCount;
  final List<String> modes;

  /// Districts or cities its stops fall in. Empty when none are recorded.
  final List<String> coverage;
  final DateTime? lastUpdated;

  const TransitProvider({
    required this.code,
    required this.name,
    this.website,
    this.registered = false,
    this.routeCount = 0,
    this.stopCount = 0,
    this.modes = const [],
    this.coverage = const [],
    this.lastUpdated,
  });

  /// "Bus operator", "Bus and ferry operator" — from the modes it runs.
  String get roleLabel {
    if (modes.isEmpty) return 'Transport operator';
    if (modes.length == 1) return '${_titleCase(modes.first)} operator';
    final rest = [...modes];
    final last = rest.removeLast();
    return '${_titleCase(rest.join(', '))} and $last operator';
  }

  static String _titleCase(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  factory TransitProvider.fromJson(Map<String, dynamic> json) {
    List<String> strings(dynamic raw) =>
        raw is List ? raw.whereType<String>().toList() : const [];

    return TransitProvider(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? json['code'] as String? ?? 'Unknown operator',
      website: json['website'] as String?,
      registered: json['registered'] == true,
      routeCount: (json['routeCount'] as num?)?.toInt() ?? 0,
      stopCount: (json['stopCount'] as num?)?.toInt() ?? 0,
      modes: strings(json['modes']),
      coverage: strings(json['coverage']),
      lastUpdated: DateTime.tryParse(json['lastUpdated']?.toString() ?? ''),
    );
  }
}
