## Nemrion Card Layout Guide

Use one surface system for every card-like element in the app.

### Surface types

- `shell`
  - Use for standalone floating containers such as the menu bar popover.
  - Uses the app shell gradient, one border, no nested extra glow layer.

- `section`
  - Use for major grouped content blocks such as `Workspace`, `Runtime`, or the main rewrite result block.
  - Padding: `NemrionScale.space3`
  - Background: solid raised surface
  - Border: `NemrionTheme.border`

- `tile`
  - Use for passive rows and cards inside a section.
  - Padding: `NemrionScale.space3`
  - Background: `NemrionTheme.surface`
  - Border: `NemrionTheme.border`

- `tileStrong`
  - Use when a tile needs slightly more separation but is not an active CTA.
  - Background: `NemrionTheme.surfaceStrong`

- `interactive`
  - Use for active or selected tiles.
  - Background: `NemrionTheme.surfaceInteractive`
  - Border: `NemrionTheme.borderStrong`

- `inset`
  - Use for nested reading/input wells inside a larger card.
  - Background: darker inset fill
  - Border: `NemrionTheme.border`

### Rules

- One corner radius only: `NemrionScale.radius`
- Major cards use `space3` internal padding
- Nested inset surfaces use `space2` outer gap from the parent card
- Do not stack multiple unrelated backgrounds on one card
- Prefer `section > tile > inset`, not `section > section > tile`
- Icons inside tiles use the same 32x32 badge treatment
- Selected state should change the whole tile surface, not only a small badge

### Applied targets

- Settings window cards and rows
- Rewrite panel result surface and prompt composer
- Menu bar popover shell and action rows
