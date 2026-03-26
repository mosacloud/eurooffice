#!/bin/bash
# Strip AGPL Section 7(b) trademark clause from all source files.
#
# Per FSF guidance, downstream recipients may remove Section 7(b) additional
# requirements that mandate retaining the original product logo.
# See: https://www.fsf.org/news/fsf-submits-amicus-brief-in-neo4j-v-suhy
#
# Removes these three lines from license headers:
# Skips: node_modules/, vendor/
# File types: js, less, css, html, htm, py, sh, json, ts, cpp, h, c
#
# Flow:
#   1. Creates a branch (chore/strip-logo-clause-YYYYMMDD) per repo
#   2. Fetches origin and merges main onto the branch
#   3. Scans for files containing the clause
#   4. Prompts for confirmation, then strips and commits
#   5. Optionally pushes, creates a PR, and merges via the eo-robot bot account
#
# Set EO_ROBOT_TOKEN to a GitHub PAT for the bot account to skip the token
# prompt. If not set, the script will prompt for it interactively.
#
# Usage:
#   Strip current repo (run from within a project directory):
#     ../scripts/strip-logo-clause.sh
#
#   Strip a specific project:
#     ./scripts/strip-logo-clause.sh web-apps
#     ./scripts/strip-logo-clause.sh sdkjs
#     ./scripts/strip-logo-clause.sh core
#     ./scripts/strip-logo-clause.sh server
#
#   Strip all projects:
#     ./scripts/strip-logo-clause.sh --all
#
#   From inside the Docker container (via Makefile):
#     make strip-logo-clause            (current repo)
#     make strip-logo-clause DIR=web-apps
#     make strip-logo-clause DIR=--all
#
#   Run after upstream merges to remove any re-introduced clauses.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

