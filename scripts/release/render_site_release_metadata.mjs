#!/usr/bin/env node

import fs from "node:fs";

function getArg(flag) {
  const index = process.argv.indexOf(flag);
  if (index === -1 || index + 1 >= process.argv.length) {
    throw new Error(`missing required argument ${flag}`);
  }

  return process.argv[index + 1];
}

function jsonString(value) {
  return JSON.stringify(value);
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function extractSection(markdown, heading) {
  const lines = markdown.split("\n");
  const headingLine = `## ${heading}`;
  const startIndex = lines.findIndex((line) => line.trim() === headingLine);

  if (startIndex === -1) {
    throw new Error(`missing section "## ${heading}" in release notes`);
  }

  const sectionLines = [];

  for (let index = startIndex + 1; index < lines.length; index += 1) {
    const line = lines[index];
    if (line.startsWith("## ")) {
      break;
    }
    sectionLines.push(line);
  }

  return sectionLines.join("\n").trim();
}

function extractBullets(sectionText) {
  return sectionText
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.startsWith("- "))
    .map((line) => line.slice(2).trim())
    .filter(Boolean);
}

function renderSummaryItems(items) {
  if (items.length === 0) {
    throw new Error("release notes must include at least one bullet in ## Highlights");
  }

  return `[\n${items.map((item) => `    ${jsonString(item)}`).join(",\n")}\n  ]`;
}

function parseChangeBullet(bullet) {
  const match = bullet.match(/^(added|changed|fixed|removed):\s+(.+)$/i);
  if (!match) {
    throw new Error(
      `invalid Site Changelog bullet "${bullet}". Expected "- added: ...", "- changed: ...", "- fixed: ...", or "- removed: ..."`
    );
  }

  return {
    type: match[1].toLowerCase(),
    description: match[2].trim(),
  };
}

function renderEntry(version, releaseDate, tagKind, changes) {
  const renderedChanges = changes
    .map(
      (change) =>
        `    {\n      type: ${jsonString(change.type)},\n      description: ${jsonString(change.description)},\n    }`
    )
    .join(",\n");

  return `export const changelog = [\n  {\n    version: ${jsonString(version)},\n    date: ${jsonString(releaseDate)},\n    tag: ${jsonString(
    tagKind
  )},\n    changes: [\n${renderedChanges}\n    ],\n  },`;
}

function splitEntries(entriesBody) {
  const entries = [];
  let current = "";
  let braceDepth = 0;
  let bracketDepth = 0;
  let started = false;

  for (const char of entriesBody) {
    if (!started) {
      if (char === "{") {
        started = true;
        braceDepth = 1;
        current = "{";
      }
      continue;
    }

    current += char;

    if (char === "{") {
      braceDepth += 1;
    } else if (char === "}") {
      braceDepth -= 1;
    } else if (char === "[") {
      bracketDepth += 1;
    } else if (char === "]") {
      bracketDepth -= 1;
    }

    if (started && braceDepth === 0 && bracketDepth === 0) {
      entries.push(current.trim().replace(/,$/, ""));
      current = "";
      started = false;
    }
  }

  return entries.filter(Boolean);
}

const templatePath = getArg("--template");
const notesPath = getArg("--notes");
const existingPath = getArg("--existing");
const outputPath = getArg("--output");
const tag = getArg("--tag");
const releaseDate = getArg("--release-date");
const dmgUrl = getArg("--dmg-url");
const releaseNotesUrl = getArg("--release-notes-url");

const version = tag.replace(/^v/, "");
const tagKind = tag.includes("-beta.") ? "beta" : "release";
const releaseLabel = tagKind === "beta" ? "Public Beta" : "Official Launch";

const template = fs.readFileSync(templatePath, "utf8");
const notes = fs.readFileSync(notesPath, "utf8");
const existing = fs.readFileSync(existingPath, "utf8");

const summaryItems = extractBullets(extractSection(notes, "Highlights"));
const changes = extractBullets(extractSection(notes, "Site Changelog")).map(
  parseChangeBullet
);

const latestReleaseBlock = template
  .replaceAll("__VERSION__", version)
  .replaceAll("__TAG__", tag)
  .replaceAll("__RELEASE_DATE__", releaseDate)
  .replaceAll("__RELEASE_LABEL__", releaseLabel)
  .replaceAll("__DMG_URL__", dmgUrl)
  .replaceAll("__RELEASE_NOTES_URL__", releaseNotesUrl)
  .replace("__SUMMARY_ITEMS__", renderSummaryItems(summaryItems));

const changelogMatch = existing.match(
  /export const changelog(?:\s*:\s*[^=]+)?\s*=\s*\[([\s\S]*?)\];([\s\S]*)$/
);

const existingEntries = changelogMatch
  ? tagKind === "release"
    ? []
    : splitEntries(changelogMatch[1]).filter(
        (entry) => !entry.includes(`version: ${jsonString(version)}`)
      )
  : [];
const trailingContent = changelogMatch ? changelogMatch[2] : "\n";

let output = `${latestReleaseBlock}\n\n${renderEntry(version, releaseDate, tagKind, changes)}\n`;

if (existingEntries.length > 0) {
  output += `${existingEntries.map((entry) => `  ${entry},`).join("\n")}\n`;
}

output += `];${trailingContent}`;

fs.writeFileSync(outputPath, output);
