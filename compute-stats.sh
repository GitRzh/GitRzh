#!/usr/bin/env bash
set -euo pipefail

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

cd -
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
<svg width="900" height="150" viewBox="0 0 900 150" xmlns="http://www.w3.org/2000/svg">
  <style>
    .bg { fill: #0d0d0d; }
    .box { fill: #0d0d0d; stroke: #2a2a2a; stroke-width: 1; rx: 6; }
    .value { font-family: 'JetBrains Mono', monospace; font-size: 32px; fill: #aaaaaa; font-weight: bold; text-anchor: middle; }
    .label { font-family: 'JetBrains Mono', monospace; font-size: 13px; fill: #888888; text-anchor: middle; letter-spacing: 1px; }
  </style>
  <rect class="bg" width="900" height="150"/>

  <rect class="box" x="10" y="10" width="280" height="130"/>
  <text class="value" x="150" y="70">+${TOTAL_ADD}</text>
  <text class="label" x="150" y="100">LINES ADDED</text>

  <rect class="box" x="310" y="10" width="280" height="130"/>
  <text class="value" x="450" y="70">-${TOTAL_DEL}</text>
  <text class="label" x="450" y="100">LINES DELETED</text>

  <rect class="box" x="610" y="10" width="280" height="130"/>
  <text class="value" x="750" y="70">${TOTAL_COMMITS}</text>
  <text class="label" x="750" y="100">TOTAL COMMITS</text>
</svg>
EOF

echo "Done: +${TOTAL_ADD} / -${TOTAL_DEL} / ${TOTAL_COMMITS} commits"
