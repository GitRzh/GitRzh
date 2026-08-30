#!/usr/bin/env bash
set -euo pipefail

ORIGINAL_DIR=$(pwd)
USERNAME="GitRzh"
TOTAL_ADD=0
TOTAL_DEL=0
TOTAL_COMMITS=0

WORKDIR=$(mktemp -d)
cd "$WORKDIR"

# Get all owned, non-fork public repos
REPOS=$(curl -s "https://api.github.com/users/${USERNAME}/repos?per_page=100" \
  | jq -r '.[] | select(.fork == false) | .full_name')

for repo in $REPOS; do
  echo "Processing $repo..."
  if git clone --quiet "https://github.com/${repo}.git" repo_tmp 2>/dev/null; then
    cd repo_tmp

    read -r add del <<< "$(git log --pretty=tformat: --numstat 2>/dev/null \
      | awk '{add+=$1; del+=$2} END{print add+0, del+0}')"
    commits=$(git rev-list --count HEAD 2>/dev/null || echo 0)

    TOTAL_ADD=$((TOTAL_ADD + add))
    TOTAL_DEL=$((TOTAL_DEL + del))
    TOTAL_COMMITS=$((TOTAL_COMMITS + commits))

    cd "$WORKDIR"
    rm -rf repo_tmp
  else
    echo "Skipping $repo (clone failed)"
  fi
done

cd "$ORIGINAL_DIR"
mkdir -p stats-badge

cat > stats-badge/lines-added.json << EOF
{"schemaVersion":1,"label":"lines added","message":"${TOTAL_ADD}","color":"555555"}
EOF

cat > stats-badge/lines-deleted.json << EOF
{"schemaVersion":1,"label":"lines deleted","message":"${TOTAL_DEL}","color":"555555"}
EOF

cat > stats-badge/commits.json << EOF
{"schemaVersion":1,"label":"total commits","message":"${TOTAL_COMMITS}","color":"555555"}
EOF

cat > stats-badge/stats-card.svg << EOF
<svg width="800" height="200" viewBox="0 0 800 200" xmlns="http://www.w3.org/2000/svg">
  <style>
    .bg { fill: #0d0d0d; }
    .box { fill: #0d0d0d; stroke: #2a2a2a; stroke-width: 1; rx: 6; }
    .value { font-family: 'Segoe UI', Ubuntu, sans-serif; font-size: 40px; fill: #aaaaaa; font-weight: 700; text-anchor: middle; }
    .label { font-family: 'Segoe UI', Ubuntu, sans-serif; font-size: 14px; fill: #888888; text-anchor: middle; letter-spacing: 1px; }
  </style>
  <rect class="bg" width="800" height="200"/>

  <rect class="box" x="10" y="10" width="245" height="180"/>
  <text class="value" x="132" y="100">+${TOTAL_ADD}</text>
  <text class="label" x="132" y="135">Lines Added</text>

  <rect class="box" x="277" y="10" width="245" height="180"/>
  <text class="value" x="400" y="100">-${TOTAL_DEL}</text>
  <text class="label" x="400" y="135">Lines Deleted</text>

  <rect class="box" x="545" y="10" width="245" height="180"/>
  <text class="value" x="668" y="100">${TOTAL_COMMITS}</text>
  <text class="label" x="668" y="135">Total Commits</text>
</svg>
EOF

echo "Done: +${TOTAL_ADD} / -${TOTAL_DEL} / ${TOTAL_COMMITS} commits"
