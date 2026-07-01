/// Design tokens — the single source of spacing/sizing constants so screens
/// don't sprinkle magic numbers. Use these instead of literal paddings.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 40;

  /// Minimum height for primary buttons / tap targets (accessibility:
  /// comfortably above the 48dp guideline for large-event, low-dexterity use).
  static const double minTapTarget = 56;

  /// Max content width on wide screens (tablet/web) so layouts don't sprawl.
  static const double maxContentWidth = 480;
}
