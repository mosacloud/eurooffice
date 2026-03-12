#!/bin/bash
# Strip AGPL Section 7(b) trademark clause from all source files.
#
# Per FSF guidance, downstream recipients may remove Section 7(b) additional
# requirements that mandate retaining the original product logo.
# See: https://www.fsf.org/news/fsf-submits-amicus-brief-in-neo4j-v-suhy
#
# Removes these three lines from license headers:
#   * Pursuant to Section 7(b) of the License you must retain the original Product
#   * logo when distributing the program. Pursuant to Section 7(e) we decline to
#   * grant you any rights under trademark law for use of our trademarks.
#
# Skips: node_modules/, vendor/
# File types: js, less, css, html, htm, py, sh, json, ts, cpp, h, c
#
# Usage:
#   Strip current repo (run from within a project directory):
#     ./fork/scripts/strip-logo-clause.sh
#
#   Strip a specific project:
#     ./fork/scripts/strip-logo-clause.sh web-apps
#     ./fork/scripts/strip-logo-clause.sh sdkjs
#     ./fork/scripts/strip-logo-clause.sh core
#     ./fork/scripts/strip-logo-clause.sh server
#
#   Strip all projects:
#     ./fork/scripts/strip-logo-clause.sh --all
#
#   From inside the Docker container (via Makefile):
#     make strip-logo-clause            (current repo)
#     make strip-logo-clause DIR=web-apps
#     make strip-logo-clause DIR=--all
#
#   Run after upstream merges to remove any re-introduced clauses.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PATTERN="Pursuant to Section 7(b)"

# macOS: avoid "illegal byte sequence" errors on files with non-UTF8 bytes
export LC_ALL=C

# macOS sed requires 'sed -i ""', GNU/Linux sed requires 'sed -i'
if [[ "$OSTYPE" == "darwin"* ]]; then
    SED_INPLACE=(sed -i '')
else
    SED_INPLACE=(sed -i)
fi

ALL_DIRS=(web-apps sdkjs core server fork)

if [ "$1" == "--all" ]; then
    DIRS=("${ALL_DIRS[@]}")
elif [ -n "$1" ]; then
    TARGET="$PROJECT_ROOT/$1"
    if [ ! -d "$TARGET" ]; then
        echo "Error: directory not found: $TARGET"
        exit 1
    fi
    DIRS=("$1")
else
    # Default to the repo matching the current working directory
    CWD="$(pwd)"
    CURRENT_DIR="${CWD#$PROJECT_ROOT/}"
    CURRENT_DIR="${CURRENT_DIR%%/*}"
    if [ -d "$PROJECT_ROOT/$CURRENT_DIR/.git" ]; then
        DIRS=("$CURRENT_DIR")
    else
        echo "Error: could not detect repo from current directory."
        echo "Run from within a project directory, or specify one:"
        echo "  $0 web-apps"
        echo "  $0 --all"
        exit 1
    fi
fi

# Commit template is required — this is a legal operation
TEMPLATE="$SCRIPT_DIR/strip-logo-clause-commit.txt"
if [ ! -f "$TEMPLATE" ]; then
    echo "Error: commit template not found at $TEMPLATE"
    echo "The commit template is required to document the legal basis for this change."
    exit 1
fi

# Spinner for progress feedback
spin() {
    local pid=$1
    local msg=$2
    local chars='|/-\'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  %s %s" "$msg" "${chars:$i:1}"
        i=$(( (i + 1) % ${#chars} ))
        sleep 0.1
    done
    printf "\r                                                \r"
}

DIR_LABEL="${DIRS[*]}"
echo "Finding files in ${DIR_LABEL} containing AGPL Section 7(b) trademark clause..."

# Count occurrences per project before stripping
TOTAL=0
TMPFILE=$(mktemp)
for dir in "${DIRS[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        (find "$PROJECT_ROOT/$dir" -type f \( -name "*.js" -o -name "*.less" -o -name "*.css" \
            -o -name "*.html" -o -name "*.htm" -o -name "*.py" -o -name "*.sh" \
            -o -name "*.json" -o -name "*.ts" -o -name "*.cpp" -o -name "*.h" \
            -o -name "*.c" \) \
            ! -path "*/node_modules/*" ! -path "*/vendor/*" \
            -exec grep -l "$PATTERN" {} + 2>/dev/null | wc -l | tr -d ' ' > "$TMPFILE") &
        spin $! "Scanning $dir..."
        wait $!
        count=$(cat "$TMPFILE")
        if [ "$count" -gt 0 ]; then
            echo "  $dir: $count files"
            TOTAL=$((TOTAL + count))
        fi
    fi
done
rm -f "$TMPFILE"

if [ "$TOTAL" -eq 0 ]; then
    echo "No files to strip."
    exit 0
fi

echo "  Total: $TOTAL files"
echo ""

# Show commit message preview
echo "Commit message preview:"
for dir in "${DIRS[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir/.git" ]; then
        echo "---"
        sed "s/%DIR%/$dir/g" "$TEMPLATE"
    fi
done
echo "---"
echo ""
printf "Proceed? Strip and commit [y] / Cancel [n]: "
read -r choice

case "$choice" in
    y|Y) ;;
    *)
        echo "Cancelled."
        exit 0
        ;;
esac

# Strip the clause
for dir in "${DIRS[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        find "$PROJECT_ROOT/$dir" -type f \( -name "*.js" -o -name "*.less" -o -name "*.css" \
            -o -name "*.html" -o -name "*.htm" -o -name "*.py" -o -name "*.sh" \
            -o -name "*.json" -o -name "*.ts" -o -name "*.cpp" -o -name "*.h" \
            -o -name "*.c" \) \
            ! -path "*/node_modules/*" ! -path "*/vendor/*" \
            -exec "${SED_INPLACE[@]}" '/Pursuant to Section 7(b)/,/grant you any rights under trademark law/{N;d;}' {} + &
        spin $! "Stripping $dir..."
        wait $!
    fi
done

echo "Done. Stripped $TOTAL files."

# Commit
for dir in "${DIRS[@]}"; do
    REPO="$PROJECT_ROOT/$dir"
    if [ ! -d "$REPO/.git" ]; then
        continue
    fi
    if git -C "$REPO" diff --quiet 2>/dev/null; then
        continue
    fi
    COMMIT_MSG=$(sed "s/%DIR%/$dir/g" "$TEMPLATE")
    git -C "$REPO" add -A
    git -C "$REPO" commit -m "$COMMIT_MSG"
    echo "Committed in $dir."
done
