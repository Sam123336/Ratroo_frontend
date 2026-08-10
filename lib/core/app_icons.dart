import 'package:phosphor_flutter/phosphor_flutter.dart';

/// The app's entire icon vocabulary, in one place, at one weight.
///
/// Before this, the app drew from Material's set, which ships filled and
/// outlined drawings of the same idea under near-identical names. We had
/// eleven pairs mixed across screens — `home` beside `map_outlined`,
/// `bookmark` and `bookmark_border` and `bookmark_outline` all at once — so
/// icon rows read as an assortment rather than a set.
///
/// Phosphor draws every glyph at a single stroke weight. Regular is the app
/// default; [fill] is used deliberately and only to mark selection, which is
/// the one place a weight change carries meaning rather than noise.
class AppIcons {
  const AppIcons._();

  // Modes. The vocabulary a rider actually navigates by.
  static const bus = PhosphorIconsRegular.bus;
  static const rail = PhosphorIconsRegular.train;
  static const ferry = PhosphorIconsRegular.boat;
  static const tram = PhosphorIconsRegular.tram;
  static const metro = PhosphorIconsRegular.subway;
  static const walk = PhosphorIconsRegular.personSimpleWalk;

  // Places and position.
  static const place = PhosphorIconsRegular.mapPin;
  static const map = PhosphorIconsRegular.mapTrifold;
  static const myLocation = PhosphorIconsRegular.crosshair;
  static const nearMe = PhosphorIconsRegular.navigationArrow;
  static const route = PhosphorIconsRegular.signpost;
  static const alternatives = PhosphorIconsRegular.path;
  static const explore = PhosphorIconsRegular.compass;

  // Chrome and actions.
  static const home = PhosphorIconsRegular.house;
  static const search = PhosphorIconsRegular.magnifyingGlass;
  static const chevron = PhosphorIconsRegular.caretRight;
  static const back = PhosphorIconsRegular.arrowLeft;
  static const forward = PhosphorIconsRegular.arrowRight;
  static const up = PhosphorIconsRegular.arrowUp;
  static const close = PhosphorIconsRegular.x;
  static const clear = PhosphorIconsRegular.xCircle;
  static const refresh = PhosphorIconsRegular.arrowClockwise;
  static const externalLink = PhosphorIconsRegular.arrowSquareOut;
  static const add = PhosphorIconsRegular.plus;
  static const remove = PhosphorIconsRegular.minus;
  static const list = PhosphorIconsRegular.listBullets;
  static const time = PhosphorIconsRegular.clock;
  static const operator_ = PhosphorIconsRegular.buildings;
  static const verified = PhosphorIconsRegular.sealCheck;
  static const assistant = PhosphorIconsRegular.sparkle;
  static const bookmark = PhosphorIconsRegular.bookmarkSimple;

  // Account.
  static const user = PhosphorIconsRegular.user;
  static const signOut = PhosphorIconsRegular.signOut;
  static const showPassword = PhosphorIconsRegular.eye;
  static const hidePassword = PhosphorIconsRegular.eyeSlash;

  // Nothing-to-show states. Each says which kind of nothing it is, because
  // "offline" and "no results" need different actions from the rider.
  static const error = PhosphorIconsRegular.warningCircle;
  static const offline = PhosphorIconsRegular.wifiSlash;
  static const noResults = PhosphorIconsRegular.magnifyingGlassMinus;
  static const locationOff = PhosphorIconsRegular.mapPinLine;
  static const noRoute = PhosphorIconsRegular.signpost;

  /// Filled glyphs, used in two places and no others:
  ///
  /// 1. Selected states — a filled glyph beside outlined ones reads as "this
  ///    one is on".
  /// 2. Icons sitting on a solid or tinted plate, where a thin outline at
  ///    20px looks weightless and unfinished rather than light.
  ///
  /// Anywhere else a fill just reads as a mistake.
  static const homeSelected = PhosphorIconsFill.house;
  static const searchSelected = PhosphorIconsFill.magnifyingGlass;
  static const nearMeSelected = PhosphorIconsFill.navigationArrow;
  static const alternativesSelected = PhosphorIconsFill.path;
  static const bookmarkSelected = PhosphorIconsFill.bookmarkSimple;
  static const userSelected = PhosphorIconsFill.user;

  // On-plate variants for the home screen's primary actions.
  static const planSolid = PhosphorIconsFill.path;
  static const exploreSolid = PhosphorIconsFill.compass;
  static const nearMeSolid = PhosphorIconsFill.navigationArrow;
  static const assistantSolid = PhosphorIconsFill.sparkle;
}
