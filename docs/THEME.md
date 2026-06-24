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
--bg-page: #000000;
--bg-subtle: #0a0a0c;
--bg-surface: #101014;
--bg-elevated: #18181d;
--bg-overlay: rgba(0, 0, 0, 0.75);

--text-primary: #f5f7fa;
--text-secondary: #a8b0bc;
--text-tertiary: #6c7480;
--text-on-accent: #001318;

--border-subtle: rgba(255, 255, 255, 0.06);
--border-default: rgba(255, 255, 255, 0.10);
--border-strong: rgba(255, 255, 255, 0.18);

--accent: #00e5ff;
--accent-hover: #33ecff;
--accent-muted: rgba(0, 229, 255, 0.12);
--accent-subtle: rgba(0, 229, 255, 0.06);
--ring-focus: #00e5ff;

--accent-secondary: #ff2d95;
--accent-secondary-muted: rgba(255, 45, 149, 0.12);
```

Use pure black for the app base in dark mode. Use cyan for primary action, focus, selected navigation, and active controls. Use magenta only as secondary emphasis, never as a competing product mode.

## Light Palette

```css
--mobile-bg: #fafaf7;
--mobile-bg-elevated: #ffffff;
--mobile-bg-sunken: #f4f3ee;
--mobile-surface: #ffffff;
--mobile-surface-muted: #f7f6f1;
--mobile-ink: #0b0e14;
--mobile-ink-soft: #4a4f58;
--mobile-ink-faint: #7a7f87;
--mobile-line: #ecece6;
--mobile-line-strong: #d8d8d0;
--mobile-accent: #ff5a1f;
--mobile-accent-hover: #e54a14;
--mobile-accent-soft: #ffe6d9;
--mobile-accent-tint: #fff3eb;
--mobile-accent-deep: #1e2a4a;
--mobile-accent-deep-soft: #e7eaf3;
--mobile-focus: #ff5a1f;
```

Light mode should feel clean and paper-like. Keep surfaces calm, borders visible, and orange reserved for primary actions, selected states, and focus.

## Status And Effects

```css
--status-success: #21e07a;
--status-warning: #ffb400;
--status-danger: #ff3d55;
--status-info: #5bc8ff;

--glow-accent: 0 0 0 3px rgba(0, 229, 255, 0.30);
--glow-danger: 0 0 0 3px rgba(255, 61, 85, 0.30);
--shadow-md: 0 4px 12px -2px rgba(0, 0, 0, 0.60);
--shadow-lg: 0 18px 36px -16px rgba(0, 0, 0, 0.75);
```

Status fills should use low-alpha backgrounds around `0.10` to `0.14` and borders around `0.35` to `0.45`. Do not place white text on cyan, amber, or bright green accents; use dark foreground text or a surface text token with verified contrast.

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
