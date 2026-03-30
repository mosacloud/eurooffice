#!/usr/bin/env bash
# strip-license-clauses.sh
# Usage: ./strip-license-clauses.sh [target_dir] [repo]
#
# Removes the Section 7(b) logo/trademark clause and the contact address
# block from license headers, using exact literal string replacement.
#
# Handles four comment styles:
#   1. " * " prefix (most C-style comments)
#   2. "* "  prefix (no leading space, a few files)
#   3. " "   prefix (HTML comments)
#   4. "// * " prefix (commented-out block comments, rare)
#
# And two address variants:
#   - 20A-6  Ernesta Birznieka-Upish
#   - 20A-12 Ernesta Birznieka-Upisha
#
# Pass repo name as second argument to apply repo-specific excludes.
# When repo is "DocumentServer", submodule directories (web-apps, sdkjs, core, server)
# are excluded so you can run them individually.
#
# How it works:
#   1. Uses grep to quickly find only files that contain the target text
#   2. Filters out excluded paths (deploy, 3dParty, etc.)
#   3. Feeds those files to perl, which does all 9 literal replacements in one pass
#   4. Checks afterwards that no files were missed — exits with error if any remain
#
# The perl replacements use \Q...\E which means "treat this as a literal string,
# not a regex". The \n between \Q...\E blocks matches actual newlines.

# Exit on any error. pipefail means a failure in any part of a pipe is caught.
set -euo pipefail

# First arg is the directory to process (defaults to current directory).
# Second arg is an optional repo name for exclude rules.
TARGET="${1:-.}"
REPO="${2:-}"

if [[ ! -d "$TARGET" ]]; then
    echo "Error: '$TARGET' is not a directory"
    exit 1
fi

# -------------------------------------------------------------------
# Paths to skip. These are matched as substrings against file paths.
# -------------------------------------------------------------------
EXCLUDES=(
    '*/.git/*'
    '*/Common/3dParty/*'
    '*/core-fonts/*'
    '*/deploy/*'              # built/bundled output, not source
)

# When run from the DocumentServer umbrella repo, skip the submodule directories
# so each can be processed individually with its own commit.
if [[ "$REPO" == "DocumentServer" ]]; then
    EXCLUDES+=(
        '*/web-apps/*'
        '*/sdkjs/*'
        '*/core/*'
        '*/server/*'
    )
fi

# -------------------------------------------------------------------
# File extensions to search. Used in two forms:
#   INCLUDE_ARGS  -> for grep (--include=*.js)
#   EXCLUDE_GREP_ARGS -> for filtering out excluded paths via grep -v
# -------------------------------------------------------------------
INCLUDE_ARGS=()
for ext in js ts cpp c h py css less html htm json sh mjs jsx tsx; do
    INCLUDE_ARGS+=("--include=*.${ext}")
done

# Convert glob-style excludes to simple grep -v patterns.
# e.g. "*/.git/*" becomes "/.git/" which grep -v can match against file paths.
EXCLUDE_GREP_ARGS=()
for ex in "${EXCLUDES[@]}"; do
    pattern="${ex#\*}"    # strip leading *
    pattern="${pattern%\*}"  # strip trailing *
    EXCLUDE_GREP_ARGS+=(-e "$pattern")
done

echo "Stripping license clauses under: $TARGET"
[[ -n "$REPO" ]] && echo "Repo mode: $REPO"

# -------------------------------------------------------------------
# Step 1: Find candidate files
# Rather than running perl on every file, we first use grep to find
# only files that actually contain the text we want to remove.
# This is much faster on large repos.
# -------------------------------------------------------------------
CANDIDATES=$(mktemp)
trap 'rm -f "$CANDIDATES"' EXIT    # clean up temp file on exit

# Find files containing either the address or the logo clause.
# "|| true" prevents grep's non-zero exit (when no matches) from killing the script.
# The result is a null-separated list of file paths written to $CANDIDATES.
{ grep -rl "${INCLUDE_ARGS[@]}" \
    -e 'You can contact Ascensio System SIA' \
    -e 'Pursuant to Section 7(b)' \
    "$TARGET" 2>/dev/null || true; } \
    | { grep -v "${EXCLUDE_GREP_ARGS[@]}" || true; } \
    | tr '\n' '\0' > "$CANDIDATES"

# Count how many files we found (convert null-separated back to lines to count).
count_before=$(tr '\0' '\n' < "$CANDIDATES" | sed '/^$/d' | wc -l | tr -d ' ')
echo "Files to process: $count_before"

if [[ "$count_before" -eq 0 ]]; then
    echo "No matching files found. Nothing to do."
    echo "Done."
    exit 0
fi

# -------------------------------------------------------------------
# Step 2: Run replacements
# Perl reads each file entirely into memory (-0777), applies all 9
# literal replacements, and writes it back (-pi = edit in place).
#
# xargs reads the null-separated file list from $CANDIDATES and
# passes them to perl in batches of 200.
#
# -r (--no-run-if-empty): on GNU/Linux, prevents xargs from running
# perl with no arguments if the list is empty. macOS ignores -r
# (it's the default behaviour there).
#
# Inside each s/...//g replacement:
#   \Q...\E = literal string (no regex, so parentheses etc. are safe)
#   \n      = newline (between \Q\E blocks, this matches actual newlines)
#
# Some files use Windows line endings (CRLF). We temporarily strip \r
# before matching, then restore it afterwards if the file had it.
# -------------------------------------------------------------------
xargs -0 -r -n 200 perl -pi -0777 -e '
    # Detect and strip \r so our \n-based patterns match CRLF files too.
    my $had_cr = (s/\r\n/\n/g) ? 1 : 0;

    # Style 1: " * " prefix — address variant A (20A-6)
    s/\Q * You can contact Ascensio System SIA at 20A-6 Ernesta Birznieka-Upish\E\n\Q * street, Riga, Latvia, EU, LV-1050.\E\n\Q *\E\n//g;

    # Style 1: " * " prefix — address variant B (20A-12)
    s/\Q * You can contact Ascensio System SIA at 20A-12 Ernesta Birznieka-Upisha\E\n\Q * street, Riga, Latvia, EU, LV-1050.\E\n\Q *\E\n//g;

    # Style 1: " * " prefix — logo/trademark
    s/\Q * Pursuant to Section 7(b) of the License you must retain the original Product\E\n\Q * logo when distributing the program. Pursuant to Section 7(e) we decline to\E\n\Q * grant you any rights under trademark law for use of our trademarks.\E\n\Q *\E\n//g;

    # Style 2: "* " prefix (no leading space) — address variant A
    s/\Q* You can contact Ascensio System SIA at 20A-6 Ernesta Birznieka-Upish\E\n\Q* street, Riga, Latvia, EU, LV-1050.\E\n\Q*\E\n//g;

    # Style 2: "* " prefix — address variant B
    s/\Q* You can contact Ascensio System SIA at 20A-12 Ernesta Birznieka-Upisha\E\n\Q* street, Riga, Latvia, EU, LV-1050.\E\n\Q*\E\n//g;

    # Style 2: "* " prefix — logo/trademark
    s/\Q* Pursuant to Section 7(b) of the License you must retain the original Product\E\n\Q* logo when distributing the program. Pursuant to Section 7(e) we decline to\E\n\Q* grant you any rights under trademark law for use of our trademarks.\E\n\Q*\E\n//g;

    # Style 3: HTML " " prefix — address variant A
    # In HTML comments, blank separator lines are " " (single space), not "* "
    s/\Q You can contact Ascensio System SIA at 20A-6 Ernesta Birznieka-Upish\E\n\Q street, Riga, Latvia, EU, LV-1050.\E\n\Q \E\n//g;

    # Style 3: HTML " " prefix — address variant B
    s/\Q You can contact Ascensio System SIA at 20A-12 Ernesta Birznieka-Upisha\E\n\Q street, Riga, Latvia, EU, LV-1050.\E\n\Q \E\n//g;

    # Style 3: HTML " " prefix — logo/trademark
    s/\Q Pursuant to Section 7(b) of the License you must retain the original Product\E\n\Q logo when distributing the program. Pursuant to Section 7(e) we decline to\E\n\Q grant you any rights under trademark law for use of our trademarks.\E\n\Q \E\n//g;

    # Style 4: "// * " prefix — commented-out block comments (rare, 2 files)
    # Uses {} delimiters instead of // to avoid clash with the // in the pattern.
    s{\Q// * You can contact Ascensio System SIA at 20A-6 Ernesta Birznieka-Upish\E\n\Q// * street, Riga, Latvia, EU, LV-1050.\E\n\Q// *\E\n}{}g;
    s{\Q// * You can contact Ascensio System SIA at 20A-12 Ernesta Birznieka-Upisha\E\n\Q// * street, Riga, Latvia, EU, LV-1050.\E\n\Q// *\E\n}{}g;
    s{\Q// * Pursuant to Section 7(b) of the License you must retain the original Product\E\n\Q// * logo when distributing the program. Pursuant to Section 7(e) we decline to\E\n\Q// * grant you any rights under trademark law for use of our trademarks.\E\n\Q// *\E\n}{}g;

    # Restore \r\n if the file originally had Windows line endings.
    s/\n/\r\n/g if $had_cr;
' < "$CANDIDATES"

# -------------------------------------------------------------------
# Step 3: Verify
# Re-scan to check nothing was missed. If any files still contain
# the Section 7(b) text, list them and exit with an error so the
# GitHub Action fails rather than silently committing partial work.
# -------------------------------------------------------------------
count_after=$({ grep -rl "${INCLUDE_ARGS[@]}" -e 'Pursuant to Section 7(b)' "$TARGET" 2>/dev/null || true; } \
    | { grep -v "${EXCLUDE_GREP_ARGS[@]}" || true; } \
    | wc -l | tr -d ' ')
echo "Files with Section 7(b) after:  $count_after"

if [[ "$count_after" -gt 0 ]]; then
    echo ""
    echo "ERROR: $count_after file(s) still contain Section 7(b) clause (list limited to 100):"
    { grep -rl "${INCLUDE_ARGS[@]}" -e 'Pursuant to Section 7(b)' "$TARGET" 2>/dev/null || true; } \
        | { grep -v "${EXCLUDE_GREP_ARGS[@]}" || true; } \
        | head -100
    exit 1
fi

echo "Done."
