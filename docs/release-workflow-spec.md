# Aira Frontend — Release Workflow Spec

## Purpose

This document defines the exact GitHub Actions workflow contract for beta releases. It describes what the private app repository workflow must do, what the public website repository should do on content updates, and which steps still require human verification.

## Repositories

- Private app repository: `sankirthk/Aira`
- Public distribution repository: `sankirthk/aira-releases`
- Public website repository: `sankirthk/aira-site`

## Workflow Overview

Use two workflows:

### 1. Private Release Workflow

Repository:
- `sankirthk/Aira`

Purpose:
- build and validate the app
- produce the notarized DMG and signed Sparkle ZIP
- publish the public release
- publish the Sparkle appcast
- update website metadata

### 2. Website Deploy Workflow

Repository:
- `sankirthk/aira-site`

Purpose:
- build and deploy GitHub Pages when content on `main` changes

This keeps release authority in the private repository while keeping the public website deployment simple.

## Private Release Workflow Contract

Recommended workflow file:
- `.github/workflows/release.yml`

Recommended trigger:
- push of matching annotated tag such as `v*.*.*-beta.*` or `v*.*.*`

Optional secondary trigger:
- `workflow_dispatch` for manual dry runs

## Release Workflow Jobs

### Job 1: Validate

Runs on:
- `macos-latest`

Responsibilities:
1. check out the tagged commit
2. verify the tagged commit is reachable from `main`
3. verify the matching release notes file exists
4. restore any required caches
5. build the direct-distribution app
6. run direct-distribution unit tests
7. run CI-stable integration tests
8. build the App Store variant
9. fail the workflow if any required validation step fails

This job produces no public side effects.

### Job 2: Package And Notarize

Runs on:
- `macos-latest`

Needs:
- `validate`

Responsibilities:
1. import signing certificate material
2. derive `MARKETING_VERSION` from the pushed tag base version
3. derive the next `CURRENT_PROJECT_VERSION` from the highest published Sparkle build across the stable and beta feeds
4. select `appcast.xml` or `appcast-beta.xml` based on whether the release tag is stable or beta
5. inject the selected `SUFeedURL` and `SUPublicEDKey` into the release build
6. archive the app
7. sign the app
8. build the DMG
9. build the Sparkle ZIP from the signed app
10. sign the ZIP and feed with the Sparkle EdDSA private key
11. notarize with Apple
12. staple the notarization ticket
13. verify the artifact with Gatekeeper-oriented checks
14. emit release metadata needed by downstream jobs

Outputs required:
- `version`
- `tag`
- `release_date`
- `dmg_path`
- `dmg_name`
- `zip_path`
- `zip_name`
- `appcast_path`
- `notarized=true`

### Job 3: Mint GitHub App Tokens

Runs on:
- any GitHub-hosted runner

Needs:
- `package-and-notarize`

Responsibilities:
1. authenticate using `AIRA_RELEASE_APP_ID`
2. authenticate using `AIRA_RELEASE_APP_PRIVATE_KEY`
3. mint an installation token for `sankirthk/aira-releases`
4. mint an installation token for `sankirthk/aira-site`

Outputs required:
- `releases_repo_token`
- `site_repo_token`

### Job 4: Publish Public Release

Runs on:
- `ubuntu-latest` or `macos-latest`

Needs:
- `package-and-notarize`
- `mint-github-app-tokens`

Responsibilities:
1. create or update the GitHub Release in `sankirthk/aira-releases`
2. use tag `v<version>`
3. set title `Aira <version>`
4. mark it as prerelease while beta is active
5. generate release notes automatically
6. upload the notarized DMG asset
7. upload the Sparkle ZIP asset
8. verify the asset URLs are available

Public release record must include:
- tag
- title
- generated release notes
- DMG asset
- ZIP asset

### Job 5: Publish Sparkle Appcast

Runs on:
- `ubuntu-latest`

Needs:
- `package-and-notarize`
- `mint-github-app-tokens`
- `publish-public-release`

Responsibilities:
1. check out `sankirthk/aira-releases`
2. copy the generated channel-specific Sparkle appcast into the repository default branch
3. commit the updated feed if content changed
4. push to `main`
5. preserve the stable public feed URL referenced by stable builds and the beta feed URL referenced by beta builds

### Job 6: Update Website Metadata

Runs on:
- `ubuntu-latest`

Needs:
- `publish-public-release`
- `publish-sparkle-appcast`
- `mint-github-app-tokens`

Responsibilities:
1. check out `sankirthk/aira-site`
2. update `src/content/release.ts`
3. write:
   - version
   - tag
   - release date
   - beta label
   - notarized boolean
   - DMG URL
   - release notes URL
   - distribution repo slug
   - short summary bullets
4. commit the file if content changed
5. push to `main`

Recommended commit message:
- `Update release metadata for <tag>`

### Job 7: Post-Publish Summary

Runs on:
- any GitHub-hosted runner

Needs:
- `update-website-metadata`

Responsibilities:
1. print the public release URL
2. print the DMG asset URL
3. print the ZIP asset URL
4. print the Sparkle appcast URL
5. print the public site URL
6. print any manual smoke checks still required

## Website Deploy Workflow Contract

Recommended workflow file:
- `.github/workflows/ci.yml`

Repository:
- `sankirthk/aira-site`

Recommended trigger:
- push to `main`
- optional `workflow_dispatch`

Responsibilities:
1. check out the repository
2. install dependencies
3. build the static site
4. upload the Pages artifact
5. deploy to GitHub Pages

This workflow does not need access to the private app repository.

## Failure Rules

- If validation fails, stop immediately.
- If notarization fails, do not create a public release.
- If ZIP signing or appcast generation fails, do not create a public release.
- If public release creation fails, do not update the appcast or website metadata.
- If appcast publication fails, keep the public release live and surface the failure clearly in workflow output.
- If website metadata update fails, keep the public release live and surface the failure clearly in workflow output.
- If the website deploy later fails, the release remains valid; fix the site separately.

## Human Actions Still Required

These are not replaced by CI:
- confirm the app launches from the DMG on a clean machine
- confirm microphone permission prompt behavior
- confirm Voice-Sync starts correctly
- confirm notch overlay behavior on supported hardware
- confirm installed copies can discover the new appcast entry and offer the update
- confirm the published site shows the same version as the public release

## Required Secrets In `sankirthk/Aira`

- `AIRA_RELEASE_APP_ID`
- `AIRA_RELEASE_APP_PRIVATE_KEY`
- `APPLE_SIGNING_CERT_BASE64`
- `APPLE_SIGNING_CERT_PASSWORD`
- `APPLE_TEAM_ID`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `SPARKLE_PRIVATE_ED_KEY`
- `SPARKLE_PUBLIC_ED_KEY`
- `SPARKLE_FEED_URL`

## What You Need To Do

At this point, your manual GitHub setup work is done for the GitHub App itself.

Remaining operator actions before implementation:
1. confirm the exact file path for website release metadata once `aira-site` is scaffolded
2. decide whether public releases should always be marked prerelease during beta

## Next Implementation Target

The next coding task should be:
- create the actual `release.yml` workflow in `sankirthk/Aira`

After that:
- scaffold `aira-site`
- add `deploy-pages.yml`
- translate the existing React mockup from `frontend/Mockup` into the production site structure
- wire `src/content/release.ts`
