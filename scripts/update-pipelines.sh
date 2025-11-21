#!/bin/bash
set -e

git clone --depth 1 https://github.com/wolfi-dev/os.git wolfi-os
cd wolfi-os
git filter-repo --path pipelines --path-rename pipelines/:
git checkout main

cd ../
rm -rf ./pipelines
mkdir ./pipelines
cp -r wolfi-os/* ./pipelines/

git add pipelines
if git diff --cached --quiet; then
    echo "No changes in pipelines. Nothing to commit."
else
    git commit -S -m "Update pipelines from wolfi-dev/os repository"
    git push origin main
    echo "Pipelines updated successfully."
fi

rm -rf wolfi-os
