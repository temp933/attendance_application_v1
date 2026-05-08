import 'package:flutter/material.dart';

class Responsive {
  final double width;
  final double height;

  const Responsive._(this.width, this.height);

  factory Responsive.of(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Responsive._(size.width, size.height);
  }

  // ── Breakpoints ──────────────────────────────────────────────────────────
  bool get isMobile => width < 600;
  bool get isTablet => width >= 600 && width < 900;
  bool get isDesktop => width >= 900;

  // ── Horizontal content padding ───────────────────────────────────────────
  double get hPad {
    if (isDesktop) return width * 0.15;
    if (isTablet) return 32.0;
    return 16.0;
  }

  // ── Max content width (centered on large screens) ────────────────────────
  double get contentMaxWidth {
    if (isDesktop) return 860.0;
    if (isTablet) return width - 64;
    return width - 32;
  }

  // ── Card grid cross-axis count ────────────────────────────────────────────
  int get summaryCardCols {
    if (isDesktop) return 4;
    if (isTablet) return 4;
    return 2;
  }

  // ── Avatar / initials size ────────────────────────────────────────────────
  double get avatarSize {
    if (isDesktop) return 88.0;
    if (isTablet) return 80.0;
    return 72.0;
  }

  double get heroNameSize {
    if (isDesktop) return 24.0;
    if (isTablet) return 22.0;
    return 20.0;
  }

  // ── Info row label width ──────────────────────────────────────────────────
  double get infoLabelWidth {
    if (isDesktop) return 200.0;
    if (isTablet) return 180.0;
    return 148.0;
  }

  // ── Section card columns (profile detail sections) ───────────────────────
  // On desktop/tablet show sections side-by-side in a 2-col grid
  bool get useTwoColSections => isDesktop || isTablet;

  // ── Font sizes ────────────────────────────────────────────────────────────
  double get sectionTitleSize => isDesktop ? 15.0 : 14.0;
  double get bodyTextSize => isDesktop ? 14.0 : 13.0;
  double get labelTextSize => isDesktop ? 13.0 : 12.5;
  double get chipTextSize => isDesktop ? 12.0 : 11.0;
  double get miniTextSize => isDesktop ? 12.0 : 11.0;

  // ── Card border radius ────────────────────────────────────────────────────
  double get cardRadius => isDesktop ? 20.0 : 16.0;

  // ── AppBar expanded height ────────────────────────────────────────────────
  // Extra height ensures the subtitle text clears the status bar + back button row.
  double get appBarHeight {
    if (isDesktop) return 140.0;
    if (isTablet) return 130.0;
    return 120.0;
  }
}
