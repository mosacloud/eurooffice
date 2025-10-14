#!/bin/bash

SOURCE_ORG="ONLYOFFICE"
TARGET_ORG="Euro-Office"

CLONE_PATH="$(pwd)/../.."

# Check if gh cli is installed
if ! command -v gh &> /dev/null
then
    echo "gh cli could not be found, please install it first."
    exit
fi

DRY_RUN=0
LIMIT=2

write_operation() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY RUN] $*"
    else
        "$@"
    fi
}

REPO_IGNORE=()

REPO_LIST=(
    "build_tools"
    "core"
    "core-fonts"
    "desktop-sdk"
    "dictionaries"
    "Docker-DocumentServer"
    "document-server-integration"
    "document-server-package"
    "document-templates"
    "onlyoffice.github.io"
    "sdkjs"
    "sdkjs-forms"
    "server"
    "web-apps"
)
# REPO_LIST=$(gh repo list "$SOURCE_ORG" --limit "$LIMIT" --json name -q '.[].name')

for repo in "${REPO_LIST[@]}"; do
    if [[ " ${REPO_IGNORE[*]} " == *" $repo "* ]]; then
        echo "Ignoring repository $repo"
        continue
    fi

    if gh repo view "$TARGET_ORG/$repo" &> /dev/null; then
        echo "Repository $TARGET_ORG/$repo already exists. Skipping..."
    else
        echo "Creating $TARGET_ORG/$repo from $SOURCE_ORG/$repo..."
        write_operation gh repo create --private "$TARGET_ORG/$repo"
    fi

    # prefer a non-bare working clone so we can push refs normally
    REPO_PATH="$CLONE_PATH/$repo"
    if [ -d "$REPO_PATH" ]; then
        echo "Directory $REPO_PATH already exists. Updating..."
        (
            cd "$REPO_PATH" || exit
            # ensure remotes are present and up-to-date
            echo "Fetching latest changes for $REPO_PATH..."
            # prefer SSH origin; add if missing
            git remote | grep -q origin || git remote add origin "git@github.com:$SOURCE_ORG/$repo.git"
            # if origin exists but uses https, switch it to SSH
            if git remote get-url origin 2>/dev/null | grep -q "^https://github.com/"; then
                git remote set-url origin "git@github.com:$SOURCE_ORG/$repo.git"
            fi
            git fetch --all --prune
        )
    else
        echo "Cloning $SOURCE_ORG/$repo.git (working clone)..."
        git clone "git@github.com:$SOURCE_ORG/$repo.git" "$REPO_PATH"
    fi

    (
        cd "$REPO_PATH" || exit
        # ensure target remote exists
        if git remote | grep -q "target"; then
            git remote remove target
        fi
        git remote add target "git@github.com:$TARGET_ORG/$repo.git"

        # push all branches and tags to target. Use separate commands so DRY_RUN shows them clearly.
        write_operation git push --mirror target
        write_operation git push target --tags
    )
done

