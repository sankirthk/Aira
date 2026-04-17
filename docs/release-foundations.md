# Aira Frontend — Release Foundations

## Purpose

This document turns the Phase 2 release-foundation work into concrete decisions for the beta. It defines the recommended repository layout, naming conventions, release identifiers, website metadata contract, and cross-repo credential boundaries for the zero-cost public beta setup.

Resolved public repositories:
- Public Website Repository: `https://github.com/sankirthk/aira-site.git`
- Public Distribution Repository: `https://github.com/sankirthk/aira-releases.git`
Resolved private repository:
- Private App Repository: `https://github.com/sankirthk/Aira.git`

## Recommended Repository Set

Use three repositories:

### 1. Private App Repository

Resolved repository:
- `sankirthk/Aira`

Purpose:
- private Swift source
- app tests
- signing and notarization workflow
- DMG build scripts
- release orchestration

Visibility:
- private

Default branch:
- `main`

### 2. Public Website Repository

Recommended name:
- `aira-site`

Purpose:
- static marketing site
- GitHub Pages deployment
- release metadata file consumed by the homepage
- screenshots and website assets

Visibility:
- public

Default branch:
- `main`

Recommended published URL:
- `https://sankirthk.github.io/aira-site/`

If a custom domain is added later, it should point here without changing the artifact host.

### 3. Public Distribution Repository

Recommended name:
- `aira-releases`

Purpose:
- public GitHub Releases entries
- DMG assets
- public release notes
- public issue tracker if you want the closed-source public community surface here instead of the site repo

Visibility:
- public

Default branch:
- `main`

Recommended release base URL:
- `https://github.com/sankirthk/aira-releases/releases`

## Branch And Ownership Rules

- The Private App Repository remains the only source of truth for shipping app code.
- The Public Website Repository must not contain app source code copied from the private repository.
- The Public Distribution Repository must not contain app source code or CI secrets.
- Public repositories should be writable only by maintainers; releases are published by automation from the private repository.

## Tag And Release Naming

### Git Tag Format

Use:
- `v<major>.<minor>.<patch>-beta.<n>`

Examples:
- `v0.9.0-beta.1`
- `v0.9.0-beta.2`
- `v0.10.0-beta.1`

Rules:
- Tags are created in the Private App Repository.
- The same tag name is used for the public release in the Public Distribution Repository.
- Do not reuse tags for rebuilt artifacts.

### DMG Asset Name

Use:
- `Aira-<version>.dmg`

Examples:
- `Aira-0.9.0-beta.1.dmg`
- `Aira-0.9.0-beta.2.dmg`

### Public Release Title

Use:
- `Aira <version>`

Examples:
- `Aira 0.9.0-beta.1`
- `Aira 0.9.0-beta.2`

## Website Metadata Contract

The Public Website Repository should keep one canonical metadata file for the latest beta release.

Recommended path:
- `src/content/release.ts`

Recommended shape:

```ts
export type ReleaseMetadata = {
  version: string;
  tag: string;
  releaseDate: string;
  betaLabel: string;
  notarized: boolean;
  dmgUrl: string;
  releaseNotesUrl: string;
  distributionRepo: string;
  summary: string[];
};
```

Example:

```ts
export const latestRelease = {
  version: "0.9.0-beta.1",
  tag: "v0.9.0-beta.1",
  releaseDate: "2026-04-14",
  betaLabel: "Public Beta",
  notarized: true,
  dmgUrl: "https://github.com/sankirthk/aira-releases/releases/download/v0.9.0-beta.1/Aira-0.9.0-beta.1.dmg",
  releaseNotesUrl: "https://github.com/sankirthk/aira-releases/releases/tag/v0.9.0-beta.1",
  distributionRepo: "sankirthk/aira-releases",
  summary: [
    "Voice-Sync follows your script with on-device speech recognition.",
    "Notch and pill overlays stay hidden from screen sharing.",
    "Built-in script editing and local-first storage are included in the beta."
  ]
} satisfies ReleaseMetadata;
```

Rules:
- `version`, `tag`, `dmgUrl`, and `releaseNotesUrl` must all refer to the same release.
- `releaseDate` is the public release publish date, not the build timestamp.
- `summary` is a website-friendly short list, not a replacement for full release notes.

## Release Notes Contract

The Public Distribution Repository release entry should be the canonical full changelog for each beta.

Rules:
- use GitHub generated release notes
- keep PR labels clean enough for public notes
- exclude internal-only noise where possible through release-note configuration

The website links to the public release page rather than duplicating the full markdown notes.

## Secret And Credential Boundaries

Store secrets only in the Private App Repository CI environment.

Recommended beta auth model:
- use **one GitHub App** for cross-repo release automation
- install it only on `sankirthk/aira-releases` and `sankirthk/aira-site`
- generate installation access tokens inside the `sankirthk/Aira` release workflow
- do not rely on the workflow `GITHUB_TOKEN` for cross-repo writes because it is scoped to the repository that contains the workflow

Why this model:
- better long-term security posture than PATs
- short-lived installation tokens instead of long-lived user tokens
- cleaner audit trail for release automation
- easier multi-repo automation without tying release authority to one personal token

Required secret groups:
- Apple signing certificate material
- Apple notarization credentials
- GitHub App identifier
- GitHub App private key

Recommended secret names in `sankirthk/Aira`:
- `APPLE_SIGNING_CERT_BASE64`
- `APPLE_SIGNING_CERT_PASSWORD`
- `APPLE_TEAM_ID`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `AIRA_RELEASE_APP_ID`
- `AIRA_RELEASE_APP_PRIVATE_KEY`

### GitHub App Scope

Recommended app name:
- `aira-release-bot`

Install on:
- `sankirthk/aira-releases`
- `sankirthk/aira-site`

Do not install on:
- unrelated repositories

Minimum repository permissions:
- `Contents`: `Read and write`
- `Metadata`: `Read`

Used for:
- create or update GitHub Releases in `sankirthk/aira-releases`
- upload release assets in `sankirthk/aira-releases`
- generate release notes in `sankirthk/aira-releases`
- update `src/content/release.ts` in `sankirthk/aira-site`
- commit and push website metadata changes to `sankirthk/aira-site`

Rules:
- no credentials are stored in either public repository
- no credential values are committed into the website metadata file
- public repositories should not need read access to the private app source
- the GitHub App should be installed only on the two public repositories that the release workflow needs to modify
- store the app ID and private key only in `sankirthk/Aira` GitHub Actions secrets or environment secrets

### Future Adjustment

If later you want stricter separation, split the single GitHub App into:
- one app installed only on `sankirthk/aira-releases`
- one app installed only on `sankirthk/aira-site`

For beta, a single GitHub App installed on both public repositories is the best balance of simplicity and security.

## Minimum Automation Boundary

The private release workflow is responsible for:
1. running required tests
2. building the archive
3. signing
4. creating the DMG
5. notarizing and stapling
6. verifying the artifact
7. publishing the release in `aira-releases`
8. updating `src/content/release.ts` in `aira-site`

This keeps release authority in one place and prevents the public repositories from owning sensitive build steps.

## Deferred Decisions

These can wait until implementation without blocking the foundations:
- whether the public community issue tracker lives in `aira-site` or `aira-releases`
- whether a custom domain is added during beta
- whether lightweight website analytics are added later

Resolved implementation choice:
- the public website uses `Vite + React + TypeScript`
