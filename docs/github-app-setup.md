# Aira Frontend — GitHub App Setup

## Purpose

This document is the operator checklist for setting up the GitHub App used by the beta release workflow. It separates the one-time GitHub UI actions you must do manually from the workflow behavior that will be automated later.

## Repositories In Scope

- Private app repository: `sankirthk/Aira`
- Public website repository: `sankirthk/aira-site`
- Public distribution repository: `sankirthk/aira-releases`

## Recommended App Identity

- App name: `aira-release-bot`
- Owner: `sankirthk`
- Visibility: `Only on this account`

The app only needs to operate across repositories you own, so there is no need to make it publicly installable.

## Required Repository Permissions

Grant only:
- `Contents`: `Read and write`
- `Metadata`: `Read`

No organization permissions are required for the beta workflow described in the current docs.

## Install Targets

Install the app on only these repositories:
- `sankirthk/aira-site`
- `sankirthk/aira-releases`

Do not install it on unrelated repositories.

## Manual Actions For You

These are the actions you need to do in GitHub:

1. Register the GitHub App.
2. Set the app name to `aira-release-bot`.
3. Set repository permissions to:
   - `Contents: Read and write`
   - `Metadata: Read`
4. Generate a private key for the app and download the `.pem` file.
5. Install the app on your personal account `sankirthk`.
6. During installation, choose `Only select repositories`.
7. Select only:
   - `aira-site`
   - `aira-releases`
8. Copy the GitHub App ID.
9. In `sankirthk/Aira`, add these GitHub Actions secrets:
   - `AIRA_RELEASE_APP_ID`
   - `AIRA_RELEASE_APP_PRIVATE_KEY`
10. Paste the numeric app ID into `AIRA_RELEASE_APP_ID`.
11. Paste the full PEM private key contents into `AIRA_RELEASE_APP_PRIVATE_KEY`.

## Suggested GitHub UI Path

Based on GitHub’s current docs:
1. Open GitHub.
2. Go to `Settings`.
3. Open `Developer settings`.
4. Open `GitHub Apps`.
5. Click `New GitHub App`.
6. Fill in the app name and permission settings.
7. Create the app.
8. Generate a private key.
9. Click `Install App`.
10. Install it on `sankirthk` with access to only `aira-site` and `aira-releases`.

## Secrets Setup In `sankirthk/Aira`

Repository-level Actions secrets are sufficient for beta.

Add:
- `AIRA_RELEASE_APP_ID`
- `AIRA_RELEASE_APP_PRIVATE_KEY`

Optional later hardening:
- move them to an environment such as `release`
- restrict the release workflow to that environment

## What I Can Do Later

Once the secrets exist, the workflow can automate:
- minting installation access tokens from the GitHub App
- creating or updating releases in `sankirthk/aira-releases`
- uploading DMG assets
- generating release notes
- updating `src/content/release.ts` in `sankirthk/aira-site`

## What Still Requires You

I cannot complete these GitHub-account actions from this workspace:
- registering the app under your account
- generating the app private key
- installing the app on the selected repositories
- entering the app ID and private key into GitHub Actions secrets

## Completion Check

Setup is complete when all of these are true:
- the GitHub App exists under `sankirthk`
- it is installed only on `aira-site` and `aira-releases`
- `AIRA_RELEASE_APP_ID` exists in `sankirthk/Aira`
- `AIRA_RELEASE_APP_PRIVATE_KEY` exists in `sankirthk/Aira`

## Sources

- Registering a GitHub App: https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app
- Installing your own GitHub App: https://docs.github.com/apps/installing-github-apps
- Using secrets in GitHub Actions: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets?tool=cli
