import '../models/place.dart';

// Number and time formatting shared by the screens that display counts.
//
// Lives here because the home screen and the mode list each grew their own
// copy, and two copies of a formatter is how "11,788 stops" and "11788 stops"
// end up on the same page.

/// 11788 -> 11,788, so a five-figure count can be read at a glance.
///
/// Indian digit grouping (11,788 vs 1,17,88) is deliberately not used: the
/// counts sit beside English labels and Latin numerals throughout.
String groupedNumber(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer(negative ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Freshness in the coarsest unit that is still true.
///
/// "2 hours ago" is a promise about the data. Rounding it up to "today" would
/// hide a stale feed, which is the one thing a freshness label exists to
/// prevent.
String timeAgo(DateTime when, {DateTime? now}) {
  final delta = (now ?? DateTime.now()).difference(when);

  // A clock skew between device and server must not produce "in 3 minutes".
  if (delta.isNegative || delta.inMinutes < 1) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
  if (delta.inHours < 24) {
    return '${delta.inHours} ${delta.inHours == 1 ? 'hour' : 'hours'} ago';
  }
  if (delta.inDays == 1) return 'yesterday';
  if (delta.inDays < 30) return '${delta.inDays} days ago';

  final months = delta.inDays ~/ 30;
  return '$months ${months == 1 ? 'month' : 'months'} ago';
}

/// "KOLKATA" -> "Kolkata", "bb ganguly xing" -> "BB Ganguly Xing".
///
/// Stop names arrive from operator sites in whatever case the operator typed
/// them, and a list mixing "KOLKATA" with "Kolkata" looks like a broken export
/// rather than a transit network. Short all-caps tokens are left alone, since
/// they are nearly always initialisms — BB Ganguly, C.R. Avenue, ESI Hospital.
String titleCaseName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;

  return trimmed
      .split(RegExp(r'(\s+)'))
      .map((word) {
        if (word.trim().isEmpty) return word;
        // A dotted initialism, whatever its length: "C.R.", "B.B.D.".
        //
        // The length rule below alone was not enough — this comment has always
        // claimed "C.R. Avenue" was handled, but "C.R." is four characters, so
        // it fell through and the app rendered "C.r. Avenue". Only visible
        // once every screen started title-casing; before that, Nearby showed
        // the raw "C.R. AVENUE" and hid the bug.
        if (RegExp(r'^([A-Za-z]\.)+$').hasMatch(word)) return word;
        // Keep short *dotless* initialisms — "BB", "ESI". A short token with a
        // dot is an abbreviation, not an initialism, so "ST." title-cases to
        // "St." rather than staying shouted.
        if (word.length <= 3 &&
            !word.contains('.') &&
            word == word.toUpperCase()) {
          return word;
        }
        if (word != word.toUpperCase()) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
      .join(' ');
}

/// Distance a rider can act on: metres up close, kilometres beyond that.
String distanceLabel(double metres) {
  if (metres < 1000) return '${(metres / 10).round() * 10} m';
  if (metres < 10000) return '${(metres / 1000).toStringAsFixed(1)} km';
  return '${(metres / 1000).round()} km';
}

/// Collapses stop records that are the same physical place into one row.
///
/// The nearby list showed "KOLKATA", "Kolkata" and "Kolkata" as three cards —
/// separate operator imports of one bus stand, identical to a rider and
/// impossible to choose between.
///
/// Merges rather than drops. Those three cards carried *different* services
/// between them; keeping only the first would have hidden the rest, which is
/// worse than the duplication it fixes. The nearest record supplies the
/// identity and distance, and the others contribute their routes.
///
/// Only merged when the names match *and* the two sit within [withinMetres] of
/// each other. Two genuinely different stops that share a name — common, since
/// operators name stops after the locality — stay separate.
List<Place> mergeSamePlace(List<Place> places, {double withinMetres = 150}) {
  final kept = <Place>[];

  for (final place in places) {
    final key = _nameKey(place.canonicalName);
    final index = kept.indexWhere((other) {
      if (_nameKey(other.canonicalName) != key) return false;
      final a = place.distanceMetres;
      final b = other.distanceMetres;
      // Without distances we cannot tell a duplicate from a namesake, so we
      // keep both rather than guess.
      if (a == null || b == null) return false;
      return (a - b).abs() <= withinMetres;
    });

    if (index < 0) {
      kept.add(place);
    } else {
      kept[index] = _absorb(kept[index], place);
    }
  }

  return kept;
}

/// [keep] wins on identity — the list arrives sorted by distance, so it is the
/// nearest record and the one the card opens.
Place _absorb(Place keep, Place extra) {
  final routes = [...keep.routes];
  final routeIds = routes.map((route) => route.id).toSet();
  for (final route in extra.routes) {
    if (routeIds.add(route.id)) routes.add(route);
  }

  final departures = [...keep.departures, ...extra.departures];

  return Place(
    id: keep.id,
    canonicalName: keep.canonicalName,
    type: keep.type ?? extra.type,
    lat: keep.lat ?? extra.lat,
    lon: keep.lon ?? extra.lon,
    routes: routes,
    departures: departures,
    sources: [...keep.sources, ...extra.sources],
    sourceUrl: keep.sourceUrl ?? extra.sourceUrl,
    distanceMetres: keep.distanceMetres,
    city: keep.city ?? extra.city,
    district: keep.district ?? extra.district,
    state: keep.state ?? extra.state,
  );
}

String _nameKey(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
