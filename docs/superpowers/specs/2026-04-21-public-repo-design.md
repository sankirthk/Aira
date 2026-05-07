# Aira Public Repo Design

## Goal

Create a clean public GitHub repository package for Aira that does not expose private app source code, but does give users a professional public surface for discovering the app, viewing media, and filing issues.

## Scope

The public repo starter package includes:

- a detailed `README.md`
- issue templates for bugs, feature requests, and compatibility reports
- an `assets/README.md` file that defines the media contract for screenshots and video

It does not include:

- private Swift source
- build scripts
- signing secrets
- notarization workflow details

## Design

### Repository role

This repository acts as the public product surface for Aira.

It should communicate:

- what Aira is
- why it exists
- how it differs from generic teleprompters
- where to download current builds
- where users should report bugs and request features

### README strategy

The README should feel product-led rather than code-led.

It should emphasize:

- macOS teleprompter positioning
- voice-aware overlays
- collections and script management
- accessibility controls
- privacy/local-first behavior

It should also support polished screenshots and a short demo video through stable asset filenames.

### Issues strategy

Public issue intake is split into three flows:

- bug reports for defects and regressions
- feature requests for product ideas
- compatibility reports for macOS, hardware, display, notch, and permission-specific issues

This separation improves triage quality and reduces back-and-forth.

### Asset strategy

The README references stable asset paths so media can be improved later without changing README structure.

## Recommendation

Use a new public repo dedicated to Aira’s public-facing product presence rather than exposing the private app source repository.
