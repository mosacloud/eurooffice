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
#   Strip all projects (from project root):
#     ./fork/scripts/strip-logo-clause.sh
#
#   Strip a single project:
#     ./fork/scripts/strip-logo-clause.sh web-apps
#     ./fork/scripts/strip-logo-clause.sh sdkjs
#     ./fork/scripts/strip-logo-clause.sh core
#     ./fork/scripts/strip-logo-clause.sh server
#
#   From inside the Docker container (via Makefile):
#     make strip-logo-clause
#     make strip-logo-clause DIR=web-apps
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

if [ -n "$1" ]; then
    TARGET="$PROJECT_ROOT/$1"
    if [ ! -d "$TARGET" ]; then
        echo "Error: directory not found: $TARGET"
        exit 1
    fi
    DIRS=("$1")
else
    DIRS=(web-apps sdkjs core server fork)
fi

echo "Stripping AGPL Section 7(b) trademark clause..."

# Count occurrences per project before stripping
TOTAL=0
for dir in "${DIRS[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        count=$(find "$PROJECT_ROOT/$dir" -type f \( -name "*.js" -o -name "*.less" -o -name "*.css" \
            -o -name "*.html" -o -name "*.htm" -o -name "*.py" -o -name "*.sh" \
            -o -name "*.json" -o -name "*.ts" -o -name "*.cpp" -o -name "*.h" \
            -o -name "*.c" \) \
            ! -path "*/node_modules/*" ! -path "*/vendor/*" \
            -exec grep -l "$PATTERN" {} + 2>/dev/null | wc -l | tr -d ' ')
        if [ "$count" -gt 0 ]; then
            echo "  $dir: $count files"
            TOTAL=$((TOTAL + count))
        fi
    fi
done

if [ "$TOTAL" -eq 0 ]; then
    echo "No files to strip."
    exit 0
fi

echo "  Total: $TOTAL files"

# Spinner for progress feedback
spin() {
    local pid=$1
    local chars='|/-\'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  Stripping... %s" "${chars:$i:1}"
        i=$(( (i + 1) % ${#chars} ))
        sleep 0.1
    done
    printf "\r                \r"
}

# Strip the clause
for dir in "${DIRS[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        find "$PROJECT_ROOT/$dir" -type f \( -name "*.js" -o -name "*.less" -o -name "*.css" \
            -o -name "*.html" -o -name "*.htm" -o -name "*.py" -o -name "*.sh" \
            -o -name "*.json" -o -name "*.ts" -o -name "*.cpp" -o -name "*.h" \
            -o -name "*.c" \) \
            ! -path "*/node_modules/*" ! -path "*/vendor/*" \
            -exec "${SED_INPLACE[@]}" '/Pursuant to Section 7(b)/,/grant you any rights under trademark law/{N;d;}' {} + &
        spin $!
        wait $!
    fi
done

echo "Done."
