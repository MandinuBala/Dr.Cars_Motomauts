# Motornauts Mobile Theme Guide

This is the compact source of truth for Motornauts Flutter styling on iOS and Android. Keep the palette stable, implement through shared `ThemeData`/`ColorScheme` choices, and avoid platform-specific color drift.

## Core Rules

- Support light and dark themes from `MaterialApp.theme` and `MaterialApp.darkTheme`.
- Use the same colors on iOS and Android; only native spacing, safe areas, and system gestures may vary.
- Keep customer workflows operational and readable: compact headings, clear hierarchy, predictable forms, and no promotional hero treatment inside the app.
- Use `SafeArea`, scrollable content, and responsive constraints so screens work on small phones, large phones, tablets, and both orientations.
- Minimum touch target: 44px logical pixels; prefer 48px for primary buttons, fields, and navigation.
- Cards are for repeated records, dialogs, and framed tools only. Avoid nested cards and decorative panels.
- Focus, validation, loading, empty, disabled, and offline states must be explicit and accessible.

## Dark Palette

```css
--bg-page: #0b0b0c;
--bg-subtle: #111113;
--bg-surface: #171719;
--bg-elevated: #202024;
--bg-overlay: rgba(0, 0, 0, 0.75);

--text-primary: #f6f1e8;
--text-secondary: #a9a196;
--text-tertiary: #746d65;
--text-on-accent: #120b03;

--border-subtle: rgba(255, 255, 255, 0.06);
--border-default: rgba(255, 255, 255, 0.10);
--border-strong: rgba(255, 255, 255, 0.18);

--accent: #d98a21;
--accent-hover: #f0a23a;
--accent-muted: rgba(217, 138, 33, 0.16);
--accent-subtle: rgba(217, 138, 33, 0.08);
--ring-focus: #d98a21;

--accent-secondary: #6f767f;
--accent-secondary-muted: rgba(111, 118, 127, 0.12);
```

Use charcoal for the app base in dark mode. Use amber for primary action, focus, selected navigation, and active controls. Use neutral chrome as secondary emphasis, never as a competing product mode.

## Light Palette

```css
--mobile-bg: #f7f3ea;
--mobile-bg-elevated: #ffffff;
--mobile-bg-sunken: #ede6da;
--mobile-surface: #fffcf5;
--mobile-surface-muted: #ede6da;
--mobile-ink: #15120e;
--mobile-ink-soft: #5d554b;
--mobile-ink-faint: #8c8276;
--mobile-line: #ddd2c2;
--mobile-line-strong: #cbbba5;
--mobile-accent: #a65f12;
--mobile-accent-hover: #8f4e0b;
--mobile-accent-soft: rgba(166, 95, 18, 0.15);
--mobile-accent-tint: rgba(166, 95, 18, 0.08);
--mobile-accent-deep: #383b40;
--mobile-accent-deep-soft: rgba(56, 59, 64, 0.12);
--mobile-focus: #a65f12;
```

Light mode should feel clean and paper-like. Keep surfaces warm, borders visible, and amber reserved for primary actions, selected states, and focus.

## Status And Effects

```css
--status-success: #21e07a;
--status-warning: #ffb400;
--status-danger: #ff3d55;
--status-info: #5bc8ff;

--glow-accent: 0 0 0 3px rgba(217, 138, 33, 0.30);
--glow-danger: 0 0 0 3px rgba(255, 61, 85, 0.30);
--shadow-md: 0 4px 12px -2px rgba(0, 0, 0, 0.60);
--shadow-lg: 0 18px 36px -16px rgba(0, 0, 0, 0.75);
```

Status fills should use low-alpha backgrounds around `0.10` to `0.14` and borders around `0.35` to `0.45`. Do not place white text on amber or bright green accents; use dark foreground text or a surface text token with verified contrast.

## Flutter Application

- Map the palettes through `ColorScheme`, `scaffoldBackgroundColor`, `AppBarTheme`, `NavigationBarTheme`, `CardThemeData`, `InputDecorationTheme`, button themes, dialog themes, and snack bars.
- `NavigationBar` should keep labels visible, selected state obvious, and height comfortable for thumbs.
- Forms need 8px radius fields, persistent labels or clear hints, inline validation, and keyboard-safe scrolling.
- Primary buttons should be full-width when they complete a mobile flow; secondary actions should stay visually quieter.
- Dialogs and bottom sheets must respect safe areas, keyboard insets, and one-handed reach.
- Document and PDF previews may stay paper-white when that matches customer expectations.

## Accessibility

- Body text must remain readable on both palettes and under platform text scaling.
- Focus must be visible and not rely on color alone.
- Error states need text plus color or icon cues.
- Disabled controls must look inactive without becoming unreadable.
- Avoid continuous animation except for loading or live-state feedback; honor platform reduced-motion settings where animation is used.

## Implementation Discipline

- Keep new theme work centralized in Flutter theme code instead of per-screen color literals.
- Add a color only when it represents a reusable semantic role.
- Preserve platform parity: a screen should not look like a different product between iOS and Android.
- If the palette changes, update this guide and the Flutter theme implementation together.
