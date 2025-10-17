#!/bin/bash
# find_scan_noreadme.sh
# Scans for git repos without README.md, detects tech stacks,
# and generates README.md files interactively using your original generator logic.

set -euo pipefail

echo "[BOT] Scanning for git repos without README.md..." | lolcat
echo "---------------------------------------------"

missing_repos=()

# ---- SCAN PHASE ----
while IFS= read -r repo; do
    repo_dir=$(dirname "$repo")
    if [ ! -f "$repo_dir/README.md" ]; then
        echo "⚠️  Repo without README: $repo_dir"
        missing_repos+=("$repo_dir")
    fi
done < <(find "$HOME" -type d -name ".git")

echo "---------------------------------------------"
echo "[BOT] Scan completed." | lolcat
echo

if [ ${#missing_repos[@]} -eq 0 ]; then
    termux-notification \
        --title "Git Bot Alert" \
        --content "All repos have README.md ✅"
    echo "✅ All repositories have README.md files."
    exit 0
fi

# ---- LIST & SELECTION ----
echo "The following repositories are missing README.md:"
index=1
for repo in "${missing_repos[@]}"; do
    echo "[$index] $repo"
    ((index++))
done
echo
read -p "Enter the numbers of repos to generate README for (e.g., 1 3 5 or 'all'): " choice

selected_repos=()
if [[ "$choice" == "all" ]]; then
    selected_repos=("${missing_repos[@]}")
else
    for num in $choice; do
        ((num--))
        selected_repos+=("${missing_repos[$num]}")
    done
fi

# ---- TECH STACK DETECTION FUNCTION ----
detect_tech_stack() {
    local path="$1"
    local tech=()

    [[ -f "$path/package.json" || $(find "$path" -name "*.js" -print -quit) ]] && tech+=("[Node.js][JavaScript]")
    [[ -f "$path/requirements.txt" || $(find "$path" -name "*.py" -print -quit) ]] && tech+=("[Python]")
    [[ -f "$path/index.html" || $(find "$path" -name "*.css" -o -name "*.js" -print -quit) ]] && tech+=("[HTML][CSS][JavaScript]")
    [[ -f "$path/composer.json" || $(find "$path" -name "*.php" -print -quit) ]] && tech+=("[PHP]")
    [[ $(find "$path" -name "*.java" -print -quit) || -f "$path/pom.xml" || -f "$path/build.gradle" ]] && tech+=("[Java]")
    [[ $(find "$path" -name "*.c" -o -name "*.h" -print -quit) ]] && tech+=("[C]")
    [[ $(find "$path" -name "*.cpp" -o -name "*.hpp" -print -quit) ]] && tech+=("[C++]")
    [[ -f "$path/main.go" ]] && tech+=("[Go]")
    [[ -f "$path/Cargo.toml" ]] && tech+=("[Rust]")
    [[ -f "$path/Dockerfile" ]] && tech+=("[Docker]")
    [[ -f "$path/Gemfile" ]] && tech+=("[Ruby]")
    [[ -f "$path/AndroidManifest.xml" ]] && tech+=("[Android]")
    [[ $(find "$path" -name "*.ipynb" -print -quit) ]] && tech+=("[Jupyter Notebook]")

    if [ ${#tech[@]} -eq 0 ]; then
        echo "[Unknown]"
    else
        echo "${tech[@]}"
    fi
}

# ---- README GENERATOR FUNCTION (your original code + GitHub auto-detect) ----
# ---- README GENERATOR FUNCTION ----
generate_readme() {
  # ---- User Input ----
  read -p "Project Name: " TITLE
  read -p "One-line Description: " DESC

  # ---- Detect GitHub URL automatically ----
  if [ -f ".git/config" ]; then
    AUTO_REPOURL=$(git config --get remote.origin.url | sed -E 's#(git@|https://)github.com[:/](.*)#https://github.com/\2#' | sed 's/.git$//')
  else
    AUTO_REPOURL=""
  fi
  read -p "GitHub Repo URL (default: $AUTO_REPOURL): " REPOURL
  REPOURL=${REPOURL:-$AUTO_REPOURL}

  read -p "Features (comma separated): " FEATURES
  read -p "Tech Stack (comma separated): " TECH
  read -p "Preview image filename (leave blank if none): " PREVIEW
  read -p "Local server command (default: python -m http.server 5500): " SERVERCMD
  SERVERCMD=${SERVERCMD:-python -m http.server 5500}

  # ---- Generate ASCII Banner ----
  if command -v figlet >/dev/null 2>&1; then
    BANNER=$(figlet -f slant "$TITLE" 2>/dev/null || echo "$TITLE")
  else
    BANNER="$TITLE"
  fi

  # ---- Generate README safely ----
  cat <<EOF > README.md
\`\`\`
$BANNER
\`\`\`

$DESC

---

## Badges
[![License](https://img.shields.io/badge/license-MIT-blue.svg)]($REPOURL)
[![GitHub stars](https://img.shields.io/github/stars/${REPOURL#https://github.com/}?style=flat)]($REPOURL)
[![Language](https://img.shields.io/github/languages/top/${REPOURL#https://github.com/}?style=flat)]($REPOURL)
[![Last Commit](https://img.shields.io/github/last-commit/${REPOURL#https://github.com/}?style=flat)]($REPOURL)

---

## Features
$(echo "${FEATURES}" | sed 's/,/\n- /g' | sed 's/^/- /')

---

## Preview
$(if [ -n "$PREVIEW" ]; then echo "![Preview]($PREVIEW)"; else echo "_Add a screenshot or GIF here (e.g., screenshot.png)_"; fi)

---

## Installation & Setup

\`\`\`bash
git clone $REPOURL
cd $(basename "$REPOURL")
ls
\`\`\`

---

## Running locally

\`\`\`bash
$SERVERCMD
\`\`\`

Open your browser at http://localhost:5500 (or your chosen port)

---

## Tech Stack
$TECH

---

## Contributing
1. Fork the repo
2. Create a branch (\`git checkout -b feature/my-feature\`)
3. Commit your changes (\`git commit -m "Add feature"\`)
4. Push and open a Pull Request

---

## License
This project is released under the **MIT License**. See [LICENSE](LICENSE) for details.

---

## Terminal Neo-style Banner
\`\`\`bash
figlet "$TITLE" | lolcat
\`\`\`
EOF

  echo "✅ README.md generated successfully!"
}

# ---- PROCESS EACH SELECTED REPO ----
generated_count=0
for repo in "${selected_repos[@]}"; do
    echo
    echo "---------------------------------------------"
    echo "[BOT] Processing: $repo" | lolcat
    cd "$repo"

    detected_stack=$(detect_tech_stack "$repo")
    echo "Detected Tech Stack: $detected_stack"
    echo

    read -p "Proceed to generate README.md for this repo? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        generate_readme
        ((generated_count++))
    else
        echo "⏭️  Skipping $repo"
    fi
    cd - >/dev/null
done

# ---- SAFE NOTIFICATION ----
if command -v termux-notification >/dev/null 2>&1; then
  if [ "$generated_count" -gt 0 ]; then
      termux-notification \
          --title "Git Bot Complete" \
          --content "$generated_count README.md files generated ✅" \
          --priority high
  else
      termux-notification \
          --title "Git Bot Complete" \
          --content "No READMEs generated."
  fi
fi

echo "---------------------------------------------"
echo "[BOT] Operation finished. $generated_count README.md file(s) generated." | lolcat
