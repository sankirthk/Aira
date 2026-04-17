# Release Notes Schema

Files in this directory are the single source of truth for public release content.

Each release note file must be named from the Git tag without the leading `v`.

Example:

- tag: `v1.0.0-beta.1`
- file: `docs/releases/1.0.0-beta.1.md`

The release workflow uses the whole markdown file as the GitHub Release body.

The site metadata automation also parses specific sections from the same file:

- `## Highlights`
  - required
  - use flat `- ` bullets only
  - these bullets become `latestRelease.summary` on the website
- `## Site Changelog`
  - required
  - use flat `- ` bullets only
  - every bullet must start with one of:
    - `added:`
    - `changed:`
    - `fixed:`
    - `removed:`
  - these bullets become the structured website `changelog` entry

Rules:

- Keep the section headings exactly as written above.
- Do not use nested bullets in `Highlights` or `Site Changelog`.
- Do not wrap one changelog item across multiple bullets.
- Other sections may be written freely for the GitHub Release body.

Bootstrap requirement:

- The release automation assumes `sankirthk/aira-releases` and `sankirthk/aira-site` are already initialized repositories with at least one commit and a default branch.
- A completely empty GitHub repository must be bootstrapped once before the release workflow can publish artifacts or site metadata into it.
