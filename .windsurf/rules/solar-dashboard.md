---
trigger: always_on
description: Core standards for the Solar Dashboard project
---

# Solar Dashboard Project Rules

## Phase 1 Constraints (Current)
- QML-first development with mock data on Windows.
- Do NOT add Linux-specific headers or SocketCAN code yet.
- Keep the app runnable on Windows at all times.

## QML & Qt Conventions
- Use PascalCase file names for reusable components (e.g., `TempReadout.qml`).
- Prefer separate QML files for reusable UI elements over inline components.
- Keep UI logic (layout/visuals) separate from data logic.
- Avoid breaking QML runtime (no unresolved components).

## UI/UX Quality Bar
- High-contrast theme (black background, green text, red/amber warnings).
- Safety-critical readability: large numeric values, clear alerts.

## Documentation Cadence
- After major UI or architecture changes, update:
  - `docs/ui-layout.md`
  - `docs/implementation.md`
  - `docs/implementation-tldr.md`