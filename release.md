# Aira — Release Process

This document describes how Aira is released for direct distribution outside the Mac App Store.

## Summary

Aira has two distribution paths for the same app version:

- Humans download a notarized `.dmg`
- Installed copies of Aira update through Sparkle using a signed `.zip`

These two artifacts serve different purposes:

- The `.dmg` is the manual installer published for people visiting the release page
- The `.zip` is the machine-consumable update payload referenced by Sparkle's `appcast.xml`

The release assets may live in a separate GitHub repository from the main app source repository. Sparkle does not require the feed or the downloadable update artifact to be hosted in the same repo as the app source.

## Repositories

The release flow assumes:

- The main app source lives in the `Aira` repository
- Public release artifacts are published to a separate release repository
- Releases are cut from immutable git tags created from commits already merged into `main`

The release workflow is triggered by pushing a version tag such as `v1.0.0-beta.1`. It does not run on feature branches or on every push to `main`.

## Release Artifacts

Each released app version should produce:

1. A notarized `Aira-<version>.dmg`
2. A signed Sparkle update archive, typically `Aira-<version>.zip`
3. An updated `appcast.xml`
4. Optional release notes URL for Sparkle

Recommended division of responsibility:

- `Aira.dmg`: manual installation for humans
- `Aira.zip`: automatic updates for existing installed copies
- `appcast.xml`: update feed consumed by Sparkle

## Why DMG For Humans And ZIP For Sparkle

Humans should use the DMG because it provides the normal drag-to-Applications installation flow.

Sparkle should use the ZIP because:

- it is the standard, simpler update payload for Sparkle
- it is better suited for in-place automatic update installation
- it avoids treating the update flow like a manual installer mount/open process

Do not point Sparkle at the GitHub Releases HTML page and do not use the DMG as the primary Sparkle payload unless there is a very specific reason to do so.

## Sparkle Basics

Sparkle needs:

- a feed URL: `SUFeedURL`
- an EdDSA public key embedded in the app: `SUPublicEDKey`
- a signed update archive for each version

At runtime:

1. Aira launches
2. Sparkle fetches `appcast.xml` from `SUFeedURL`
3. Sparkle compares the latest version in the appcast with the installed app version
4. If a newer version exists, Sparkle verifies the update signature
5. Sparkle prompts the user
6. If accepted, Sparkle downloads the ZIP and installs the update

## What An Appcast Is

The appcast is an XML feed that tells Sparkle which version is current and where to download it.

Think of it as the machine-readable release index for Aira.

The appcast should contain, for each release:

- version number
- short version string
- ZIP download URL
- file length
- Sparkle EdDSA signature
- optional release notes URL
- publication date

The appcast can be hosted:

- in the release repo
- on GitHub Pages
- on a website/CDN controlled by Aira

The appcast does not need to be in the main source repo.

## Recommended Hosting Model

Recommended setup:

- Main source repo:
  - app code
  - CI workflow definitions
- Release repo:
  - notarized DMGs
  - Sparkle ZIP archives
  - `appcast.xml`
  - release notes or release metadata if desired

Example model:

- human release page points to the DMG in the release repo
- `appcast.xml` also lives in or is generated from the release repo
- `appcast.xml` points to the ZIP in the release repo

## Signing Keys

Sparkle update signing is separate from Apple code signing and notarization.

You need a Sparkle EdDSA keypair:

- private key: used only in release automation to sign update archives
- public key: embedded in the app as `SUPublicEDKey`

Rules:

- never commit the private key to the repo
- keep the private key only in CI secrets or a secure local release environment
- the public key is safe to ship in the app

Recommended release secrets:

- `SPARKLE_PRIVATE_ED_KEY`
- `SPARKLE_PUBLIC_ED_KEY`
- `SPARKLE_FEED_URL`

## Versioning

Each release must update:

- `MARKETING_VERSION`
- `CURRENT_PROJECT_VERSION`

Sparkle compares versions using the appcast metadata and the app bundle version information. Keep both values accurate and monotonic.

## Full Updates vs Delta Updates

Use full updates first.

Reasons:

- simpler pipeline
- fewer failure modes
- easier debugging
- appropriate for Aira's current release maturity

This means every Sparkle update downloads the full ZIP for the new app version.

Delta updates are deferred until the release pipeline is stable.

## Release Pipeline

The intended end-to-end release flow is:

1. Feature work lands on `main`
2. The release version/build is bumped in the app project
3. A release tag such as `v1.0.0-beta.1` is created from a `main` commit and pushed
4. CI checks out that exact tagged commit and verifies it is reachable from `main`
5. CI archives, signs, and notarizes the app
6. CI creates the human-facing DMG
7. CI creates the Sparkle ZIP from the signed app
8. CI signs the ZIP and generates or updates `appcast.xml`
9. CI publishes both DMG and ZIP to the release repo
10. CI commits the latest `appcast.xml` to the release repo's default branch for the stable feed URL
11. Installed Aira copies detect the new appcast entry and offer the update

## Current State

Already in place:

- the app bundle is wired to read `SUFeedURL` and `SUPublicEDKey`
- the app-side updater fails closed when those values are absent
- the release workflow can already build and notarize the DMG path

Still needed for complete Sparkle releases:

- build a ZIP artifact for Sparkle
- sign the ZIP and feed with the Sparkle private key
- publish the ZIP to the release repo
- generate/update `appcast.xml`
- provide a stable public URL for the appcast
- inject `SPARKLE_FEED_URL` in the release build settings
- inject `SPARKLE_PUBLIC_ED_KEY` in the release build settings

## CI Responsibilities

The release CI should do the following for each shipping build:

- build the app
- sign the app with Apple signing identity
- notarize the app
- staple notarization if needed for the distributed artifact path
- create `Aira.dmg`
- create `Aira.zip`
- sign `Aira.zip` with Sparkle EdDSA private key
- upload the DMG to the release repo
- upload the ZIP to the release repo
- update `appcast.xml`

The release CI should fail the release if any of these fail:

- archive/build
- notarization
- ZIP signing
- appcast generation
- artifact upload

## App Build Configuration

The app currently expects:

- `SUFeedURL`
- `SUPublicEDKey`

These are supplied through the app bundle configuration and build settings.

If either value is missing, the app should fail closed:

- Sparkle does not start
- update checks remain disabled

This is intentional and prevents a partially configured updater from shipping broken behavior.

## Human Install Flow

For someone installing fresh:

1. Visit the release page
2. Download `Aira.dmg`
3. Open the DMG
4. Drag `Aira.app` into Applications
5. Launch Aira

## In-App Update Flow

For an existing installed user:

1. Aira launches
2. Sparkle checks the appcast
3. A newer version is found
4. Aira presents an update prompt
5. If the user chooses `Update Now`, Sparkle downloads the ZIP
6. Sparkle verifies the signature
7. Sparkle installs the new version in place

## Custom Update Prompt

The desired product behavior is a small Aira-branded update popup with:

- `Update Now`
- `Cancel`

This is separate from the artifact/release pipeline.

The release pipeline provides the update metadata and signed ZIP. The app-side Sparkle integration is responsible for:

- detecting the update
- presenting the custom mini popup
- starting the Sparkle install flow after `Update Now`

`design.md` should be updated if the custom popup becomes a required UI surface for v1 behavior.

## Appcast Ownership And URL

`SUFeedURL` must point to the hosted `appcast.xml`, not to:

- the main source repo
- the GitHub Releases HTML page
- the DMG URL

Example shape only:

```text
https://example.com/aira/appcast.xml
```

Inside that appcast, the ZIP enclosure URL may point to a different release repo, for example:

```text
https://github.com/<org-or-user>/<release-repo>/releases/download/v1.2.3/Aira.zip
```

That separation is valid.

## Practical Recommendation

Use this release model:

- DMG for manual downloads
- ZIP for Sparkle
- appcast in the release repo or on a stable Aira-controlled URL
- full updates only
- no delta updates yet

## Release Checklist

Before considering the updater production-ready, verify:

- Sparkle public key is embedded correctly
- Sparkle private key is only in CI secrets
- appcast URL is stable and publicly reachable
- appcast points to ZIP, not DMG
- ZIP signature verifies correctly
- DMG remains available for manual install
- app version numbers are incremented correctly
- update prompt appears when a newer version exists
- update install succeeds from an already-installed app
- manual install still works from the DMG
