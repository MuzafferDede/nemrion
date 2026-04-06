# Nemrion Rebuild

## PRD Summary

Nemrion is a premium macOS writing assistant for one job: improve the user's currently selected text anywhere on the system with as little friction as possible. The v1 product is optimized around a single "Polish" action that repairs grammar, clarifies wording, smooths tone, and restores likely intended meaning without inventing facts.

The critical user loop is:

1. Select text in any app.
2. Trigger Nemrion through the floating bubble, global hotkey, or menu bar.
3. Capture the selection.
4. Stream a rewritten result from the active AI provider.
5. Review in a compact panel.
6. Apply the rewritten text back into the source app.

### Product Principles

- Fast enough to feel ambient, not workflow-breaking.
- Reliable first on capture and replace, because that is the entire product.
- Calm around permissions and missing dependencies.
- Compact UI with keyboard-first interaction.
- Local AI first through Ollama, but cleanly extensible to remote providers.

### v1 Scope

- System selection capture using Accessibility where possible, with command simulation fallback for common apps.
- Selection replacement using accessibility insertion when supported, with paste fallback.
- One primary rewrite action: `Polish`.
- Compact rewrite panel with streaming, refinement instruction, copy, retry, and apply.
- Menu bar presence, global hotkey, and contextual floating bubble.
- Minimal premium settings and dependency guidance.

### Non-Goals

- Chat workspace
- Full document editing
- Multi-step prompt builder
- Large settings dashboard
- Legacy architecture or compatibility-preserving shortcuts

## Architecture Decisions

### App Architecture

- `SwiftUI` for product surfaces, settings, and rewrite panel.
- `AppKit` bridges where macOS system integration matters: menu bar item, floating non-activating panels, accessibility interaction, and global hotkey registration.
- `@MainActor` app container with focused service protocols and a lightweight dependency graph.
- Async/await for provider execution and selection workflows. Streaming uses `AsyncThrowingStream`.

### Core Modules

- `App`: lifecycle, dependency injection, routing between surfaces.
- `Design`: tokens, backgrounds, surface styles, typography, control styling.
- `Selection`: accessibility capture/replace, clipboard fallback, source-app session tracking.
- `Providers`: provider protocol, Ollama implementation, future remote provider adapters.
- `System`: global hotkey, status item, transient panels, animation coordination.
- `Features`: panel, settings, onboarding, dependency guidance, bubble.

### Selection Strategy

Primary path:

- Read focused element selection via Accessibility APIs.
- Retrieve selection bounds with parameterized AX attributes.
- Replace selection through `kAXSelectedTextRangeAttribute` + `kAXValueAttribute` insertion where supported.

Fallback path:

- Simulate `Cmd-C` for capture and `Cmd-V` for replacement with clipboard preservation.
- Maintain a short-lived source-app session so apply targets the same application context.

This gives a robust baseline without hard-coding app-specific automation logic in v1.

### Provider Strategy

- Provider abstraction returns streamed text chunks and final metadata.
- Ollama is the default and required local provider in v1.
- Provider registry is designed so OpenAI and Anthropic adapters can be added without panel changes.
- Prompting is action-based, not chat-based. `Polish` emits only the rewritten text.

### Permissions Strategy

- Accessibility is the primary permission.
- Nemrion owns the onboarding and status explanation before asking the user to open System Settings.
- Permission state is observable and reused across views to prevent repeated prompt loops.

## Visual Design Direction

Nemrion should feel closer to a premium modern SaaS component library than a stock macOS utility, while still behaving like a real macOS tool.

### Visual Language

- Deep neutral base with restrained blue-cyan accents.
- Layered panels with semi-translucent top surfaces and stronger opaque content cards.
- Soft shadows, clean 1px borders, disciplined gradients for depth only.
- Tight spacing scale and sharp typography hierarchy.
- Compact controls with crisp hover and pressed states.

### Surface Model

- App frame: dark graphite gradient background with subtle radial lighting.
- Floating panel: blurred glass shell with an inset card stack.
- Primary action surfaces: luminous but controlled accent treatment.
- Status and error states: semantic color accents with premium subdued backgrounds.

### Motion

- 160-220ms opacity and scale transitions for panel presentation.
- Streaming states animate via shimmer and cursor pulse, not noisy spinners everywhere.
- Bubble reveal is subtle and spatially precise.

## Implementation Plan

1. Scaffold a fresh macOS app target and test target.
2. Build the design system and window/panel hosting layer.
3. Implement provider abstractions and Ollama streaming client.
4. Implement accessibility permission monitoring and onboarding.
5. Implement selection capture/replace service with fallback clipboard workflow.
6. Add menu bar, global hotkey, and contextual bubble trigger surfaces.
7. Build the rewrite panel and settings UI.
8. Validate local build and document test scenarios across app classes.
