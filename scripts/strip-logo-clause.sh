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

PATTERN="Pursuant to Section 7(b)"
COMMIT_AUTHOR="Euro-Office Robot <eo-robot@users.noreply.github.com>"
BRANCH_NAME="chore/strip-logo-clause-$(date +%Y%m%d)"

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
    if [ -e "$PROJECT_ROOT/$CURRENT_DIR/.git" ]; then
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

# Create branch, fetch, and merge main for each repo
echo "Preparing branches..."
for dir in "${DIRS[@]}"; do
    REPO="$PROJECT_ROOT/$dir"
    if [ ! -e "$REPO/.git" ]; then
        continue
    fi

    DEFAULT_BRANCH=$(git -C "$REPO" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
    if [ -z "$DEFAULT_BRANCH" ]; then
        DEFAULT_BRANCH="main"
    fi

    echo "  $dir: fetching and creating branch $BRANCH_NAME..."
    git -C "$REPO" fetch origin
    git -C "$REPO" checkout "$DEFAULT_BRANCH"
    git -C "$REPO" pull origin "$DEFAULT_BRANCH"
    git -C "$REPO" checkout -b "$BRANCH_NAME"
done
echo ""

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
    echo "No files to strip. Cleaning up branches..."
    for dir in "${DIRS[@]}"; do
        REPO="$PROJECT_ROOT/$dir"
        if [ ! -e "$REPO/.git" ]; then
            continue
        fi
        DEFAULT_BRANCH=$(git -C "$REPO" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
        if [ -z "$DEFAULT_BRANCH" ]; then
            DEFAULT_BRANCH="main"
        fi
        git -C "$REPO" checkout "$DEFAULT_BRANCH"
        git -C "$REPO" branch -d "$BRANCH_NAME" 2>/dev/null
    done
    exit 0
fi

echo "  Total: $TOTAL files"
echo ""

# Show commit message preview
echo "Commit message preview:"
for dir in "${DIRS[@]}"; do
    if [ -e "$PROJECT_ROOT/$dir/.git" ]; then
        echo "---"
        sed "s/%DIR%/$dir/g" "$TEMPLATE"
    fi
done
echo "---"
echo ""
echo "Branch: $BRANCH_NAME"
echo "Commit author: $COMMIT_AUTHOR"
echo ""
printf "Proceed? Strip and commit [y] / Cancel [n]: "
read -r choice

case "$choice" in
    y|Y) ;;
    *)
        echo "Cancelled. Cleaning up branches..."
        for dir in "${DIRS[@]}"; do
            REPO="$PROJECT_ROOT/$dir"
            if [ ! -e "$REPO/.git" ]; then
                continue
            fi
            DEFAULT_BRANCH=$(git -C "$REPO" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
            if [ -z "$DEFAULT_BRANCH" ]; then
                DEFAULT_BRANCH="main"
            fi
            git -C "$REPO" checkout "$DEFAULT_BRANCH"
            git -C "$REPO" branch -d "$BRANCH_NAME" 2>/dev/null
        done
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
COMMITTED_DIRS=()
for dir in "${DIRS[@]}"; do
    REPO="$PROJECT_ROOT/$dir"
    if [ ! -e "$REPO/.git" ]; then
        continue
    fi
    if git -C "$REPO" diff --quiet 2>/dev/null; then
        continue
    fi
    COMMIT_MSG=$(sed "s/%DIR%/$dir/g" "$TEMPLATE")
    git -C "$REPO" add -u
    COMMITTER_EMAIL="${COMMIT_AUTHOR#*<}"
    GIT_COMMITTER_NAME="${COMMIT_AUTHOR%% <*}" GIT_COMMITTER_EMAIL="${COMMITTER_EMAIL%>}" git -C "$REPO" commit -m "$COMMIT_MSG" --author="$COMMIT_AUTHOR"
    COMMITTED_DIRS+=("$dir")
    echo "Committed in $dir."
done

if [ ${#COMMITTED_DIRS[@]} -eq 0 ]; then
    exit 0
fi

# Optionally create PRs and merge via the bot account
echo ""
printf "Create pull requests and merge? [y/n]: "
read -r pr_choice

case "$pr_choice" in
    y|Y) ;;
    *)
        echo "Skipping PR creation."
        exit 0
        ;;
esac

if [ -z "$EO_ROBOT_TOKEN" ]; then
    printf "EO_ROBOT_TOKEN not set. Enter token (or leave blank to skip): "
    read -rs token_input
    echo ""
    if [ -z "$token_input" ]; then
        echo "No token provided. Skipping PR creation."
        exit 0
    fi
    EO_ROBOT_TOKEN="$token_input"
fi

PR_TITLE="chore(license): Remove non-obligatory Section 7 additions"

for dir in "${COMMITTED_DIRS[@]}"; do
    REPO="$PROJECT_ROOT/$dir"
    REMOTE_URL=$(git -C "$REPO" remote get-url origin)
    # Extract owner/repo from SSH or HTTPS URL
    REPO_SLUG=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]||; s|\.git$||')
    DEFAULT_BRANCH=$(git -C "$REPO" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
    if [ -z "$DEFAULT_BRANCH" ]; then
        DEFAULT_BRANCH="main"
    fi

    echo ""
    echo "Creating PR for $dir ($REPO_SLUG)..."

    git -C "$REPO" push origin "$BRANCH_NAME"

    PR_URL=$(GH_TOKEN="$EO_ROBOT_TOKEN" gh pr create \
        --repo "$REPO_SLUG" \
        --base "$DEFAULT_BRANCH" \
        --head "$BRANCH_NAME" \
        --title "$PR_TITLE" \
        --body "Automated removal of unenforceable Section 7(b) trademark clause. See commit message for legal rationale." \
        2>&1)

    if [ $? -eq 0 ]; then
        echo "  PR created: $PR_URL"
        GH_TOKEN="$EO_ROBOT_TOKEN" gh pr merge "$PR_URL" --merge --delete-branch
        echo "  Merged and branch deleted."
        git -C "$REPO" checkout "$DEFAULT_BRANCH"
        git -C "$REPO" pull origin "$DEFAULT_BRANCH"
    else
        echo "  Failed to create PR: $PR_URL"
    fi
done
