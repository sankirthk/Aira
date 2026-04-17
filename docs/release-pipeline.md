# Aira Frontend — Beta Release Pipeline

## Purpose

This document defines the zero-cost public beta release pipeline for Aira under the chosen `Option A` topology:
- private app source repository
- public website repository
- public distribution repository

The goal is to keep the app source private while making the beta website and the downloadable DMG public and automatically updated.

## Repository Roles

### Private App Repository

Owns:
- Swift source code
- tests
- signing configuration
- notarization workflow
- DMG build scripts
- release orchestration

### Public Distribution Repository

Owns:
- GitHub Releases entries
- public DMG assets
- auto-generated public release notes
- public release history

### Public Website Repository

Owns:
- static marketing site
- release metadata consumed by the homepage
- screenshots and frontend assets
- GitHub Pages deployment

## Release Flow

```
Tag in Private App Repository
        |
        v
Run tests on macOS
        |
        v
Archive + sign app
        |
        v
Build DMG
        |
        v
Notarize + staple
        |
        v
Verify artifact
        |
        +----> Create/update release in Public Distribution Repository
        |           |
        |           +--> Upload DMG asset
        |           +--> Publish generated release notes
        |
        +----> Update release metadata in Public Website Repository
                    |
                    +--> Trigger GitHub Pages deploy
```

## Trigger Strategy

### Validation Workflow

Trigger:
- pull requests
- pushes to main branches relevant to release prep

Steps:
1. build the app
2. run unit tests
3. run integration tests that are stable in CI
4. fail before signing or publishing if any required checks fail

### Release Workflow

Trigger:
- annotated git tag such as `v0.9.0-beta.1`

Steps:
1. check out the tagged commit in the Private App Repository
2. run the same required tests as validation
3. archive the app
4. inject `SPARKLE_FEED_URL` and `SPARKLE_PUBLIC_ED_KEY` into the direct-distribution build
5. sign with Developer ID
6. create the DMG
7. create the Sparkle ZIP from the signed app
8. sign the ZIP and feed with the Sparkle EdDSA private key
9. notarize with `xcrun notarytool`
10. staple the notarization ticket
11. verify signature and Gatekeeper acceptance
12. create or update a GitHub Release in the Public Distribution Repository
13. upload the DMG and ZIP assets to that public release
14. update `appcast.xml` in the Public Distribution Repository
15. generate and publish release notes for the same release
16. update website release metadata in the Public Website Repository
17. trigger the static site deploy to GitHub Pages

## Required Secrets

Stored in the Private App Repository actions environment:
- Apple signing certificate material
- Apple notarization credentials
- `AIRA_RELEASE_APP_ID`
- `AIRA_RELEASE_APP_PRIVATE_KEY`
- `SPARKLE_PRIVATE_ED_KEY`
- `SPARKLE_PUBLIC_ED_KEY`
- `SPARKLE_FEED_URL`

The Public Website Repository and Public Distribution Repository should not need access back into the private source repository.

Recommended beta model:
- use one GitHub App installed on `sankirthk/aira-releases` and `sankirthk/aira-site`
- mint installation access tokens during the workflow for cross-repo publish steps
- do not rely on `GITHUB_TOKEN` for cross-repo writes

## Public Distribution Release Contract

Each public beta release should publish:
- version tag
- beta label if applicable
- release date
- notarization status
- DMG asset
- Sparkle ZIP asset
- current `appcast.xml`
- generated release notes

Recommended asset naming:
- `Aira-<version>.dmg`
- `Aira-<version>.zip`

Recommended release URL shape:
- `https://github.com/<org-or-user>/<distribution-repo>/releases/tag/<tag>`

## Website Metadata Contract

The Public Website Repository should contain one canonical release metadata file with:
- version
- release date
- dmg URL
- release notes URL
- notarized boolean
- short summary bullets

This file should be generated or updated by the release workflow rather than edited manually on every release.

## Release Notes Strategy

Use GitHub generated release notes in the Public Distribution Repository.

Recommended supporting setup:
- label pull requests with categories such as `feature`, `fix`, `polish`, and `internal`
- configure `.github/release.yml` in the Public Distribution Repository to group categories and exclude internal-only noise when appropriate

The website should show a short release summary and link to the full public GitHub release notes.

## Stability Gates

The pipeline must not publish a new public beta if any of these fail:
- required tests
- archive build
- code signing
- DMG creation
- notarization
- artifact verification

Recommended manual smoke checks before broad beta sharing:
- fresh DMG install
- first launch
- microphone permission prompt
- Voice-Sync starts
- notch overlay appears on supported hardware
- app exits cleanly

## Failure Handling

- If tests fail, stop before signing.
- If notarization fails, do not publish the release.
- If release publication succeeds but website metadata update fails, keep the public release live and alert for a follow-up website fix.
- If website deployment succeeds but the public release asset is missing, roll back website metadata to the previous release.

## Metrics

Free beta metrics should rely on public GitHub release asset download counts in the Public Distribution Repository.

Interpretation rule:
- `download_count` measures downloads of the asset, not unique people

No paid hosting or paid analytics product is required for the initial beta pipeline.
