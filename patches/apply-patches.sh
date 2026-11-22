#!/bin/bash
#
# Apply the zorn source patches to the ROM tree.
# Patches live in patches/<project path>/NNNN-*.patch, e.g.
#   patches/packages/apps/Settings/0001-foo.patch -> packages/apps/Settings
#
# Run after every `repo sync`, from anywhere:
#   device/xiaomi/zorn/patches/apply-patches.sh
#
# Patches already in a project are skipped, so running it twice is safe.

set -u

PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROM_ROOT="$(cd "$PATCH_DIR/../../../.." && pwd)"

failed=0

while IFS= read -r project_dir; do
    project="${project_dir#"$PATCH_DIR"/}"
    target="$ROM_ROOT/$project"

    if [ ! -d "$target/.git" ] && ! git -C "$target" rev-parse --git-dir >/dev/null 2>&1; then
        echo "!! $project: not a git project, skipping"
        failed=1
        continue
    fi

    for patch in "$project_dir"/*.patch; do
        name="$(basename "$patch")"
        if git -C "$target" apply --reverse --check "$patch" >/dev/null 2>&1; then
            echo "-- $project: $name already applied"
            continue
        fi
        if git -C "$target" am -3 --keep-cr "$patch" >/dev/null 2>&1; then
            echo "OK $project: $name"
        else
            git -C "$target" am --abort >/dev/null 2>&1
            echo "!! $project: $name FAILED (resolve manually with: cd $project && git am -3 $patch)"
            failed=1
        fi
    done
done < <(find "$PATCH_DIR" -name '*.patch' -printf '%h\n' | sort -u)

exit $failed
