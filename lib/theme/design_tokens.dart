import 'package:flutter/material.dart';

/// Canonical "Wachbuch Klar" design tokens.
///
/// Mirrors the OpenDesign package (`design-system/wachbuch/tokens.css` and
/// `design-tokens.json`) and the Django web PWA (`core/static/core/app.css`).
/// One palette, two targets — web == client.
///
/// Brand and semantic values are unchanged; this revision adds the OpenDesign
/// token tiers (foreground steps, status/priority tag pairs, 4px spacing grid,
/// the 12/14/16/18/22/28/34/44 type scale and the 8/12/16 radius scale) and
/// repoints the keyboard focus ring onto OD `--accent` (#0D47A1).
class WachbuchTokens {
  WachbuchTokens._();

  // ── Priority ──────────────────────────────────────────────────────
  static const Color urgent = Color(0xFFDC2626);
  static const Color important = Color(0xFFF59E0B);
  static const Color normal = Color(0xFF2563EB);
  static const Color done = Color(0xFF16A34A);

  // ── Status dots/lines (OD --status-*) ─────────────────────────────
  static const Color statusOpen = Color(0xFF2563EB);
  static const Color statusInProgress = Color(0xFFF59E0B);
  static const Color statusDone = Color(0xFF16A34A);

  // ── Semantic state ────────────────────────────────────────────────
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF2563EB);

  // ── Surfaces / brand (OD A1-identity) ─────────────────────────────
  static const Color surfaceLight = Color(0xFFF7F9FC);
  static const Color surfaceDark = Color(0xFF0B1220);
  static const Color surfaceWarm = Color(0xFFEEF4FF);
  static const Color primary = Color(0xFF0D47A1);
  static const Color brandDeep = Color(0xFF17343D);
  static const Color brandHover = Color(0xFF082E63);
  static const Color brandAccent = Color(0xFF2563EB);

  // ── Foreground tiers (OD --fg-2 / --muted / --meta / --border-soft) ─
  static const Color fg2 = Color(0xFF2B3648);
  static const Color muted = Color(0xFF47536A);
  static const Color meta = Color(0xFF3F4B63);
  static const Color borderSoft = Color(0xFFE9EEF6);

  /// Keyboard focus ring colour — OD `--accent` (#0D47A1), ≥3:1 non-text.
  static const Color focusRing = Color(0xFF0D47A1);

  // ── Status/priority tag pairs (OD --tag-bg-* / --tag-line-*) ───────
  // Chip text always uses onSurface; the soft bg carries the tint and the
  // *-line value (≥3:1 graphical token, WCAG 1.4.11) carries dot/border.
  static const Color tagBgUrgent = Color(0xFFFEE2E2);
  static const Color tagLineUrgent = Color(0xFFB91C1C);
  static const Color tagBgImportant = Color(0xFFFEF3C7);
  static const Color tagLineImportant = Color(0xFFB45309);
  static const Color tagBgNormal = Color(0xFFDBEAFE);
  static const Color tagLineNormal = Color(0xFF1D4ED8);
  static const Color tagBgDone = Color(0xFFDCFCE7);
  static const Color tagLineDone = Color(0xFF15803D);
  static const Color tagBgBlocked = Color(0xFFEDE9FE);
  static const Color tagLineBlocked = Color(0xFF6D28D9);
  static const Color tagBgMuted = Color(0xFFE9EEF6);
  static const Color tagLineMuted = Color(0xFF47536A);

  // ── Spacing — 4px grid (OD --space-*) ─────────────────────────────
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double space2Xl = 32;

  static const double touchTarget = 48;

  // ── Type scale (OD --text-*; body baseline ≥14sp) ─────────────────
  static const double textCaption = 12;
  static const double textBody = 14;
  static const double textTitle = 16;
  static const double textLg = 18;
  static const double textHeadline = 20;
  static const double textXl = 22;
  static const double textDisplay = 28;
  static const double text2Xl = 28;
  static const double text3Xl = 34;
  static const double text4Xl = 44;

  static const double leadingBody = 1.5;
  static const double leadingTight = 1.2;

  // ── Radius (OD --radius-sm/md/lg) ─────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  static Duration animFast = const Duration(milliseconds: 150);
  static Duration animNormal = const Duration(milliseconds: 200);

  static Color priorityColor(String priority) {
    return switch (priority) {
      'urgent' || 'high' => urgent,
      'important' || 'medium' => important,
      'done' || 'low' => done,
      _ => normal,
    };
  }

  static Color statusColor(String status) {
    return switch (status) {
      'open' || 'new' => statusOpen,
      'in_progress' || 'active' => statusInProgress,
      'waiting' || 'blocked' => important,
      'done' || 'closed' => statusDone,
      _ => normal,
    };
  }

  /// Soft tag surface for a status — OD `--tag-bg-*`.
  static Color statusSoft(String status) {
    return switch (status) {
      'in_progress' || 'active' => tagBgImportant,
      'waiting' || 'blocked' => tagBgBlocked,
      'done' || 'closed' => tagBgDone,
      'open' || 'new' => tagBgNormal,
      _ => tagBgMuted,
    };
  }

  /// ≥3:1 line/dot token for a status — OD `--tag-line-*`.
  static Color statusLine(String status) {
    return switch (status) {
      'in_progress' || 'active' => tagLineImportant,
      'waiting' || 'blocked' => tagLineBlocked,
      'done' || 'closed' => tagLineDone,
      'open' || 'new' => tagLineNormal,
      _ => tagLineMuted,
    };
  }
}
