#! /bin/bash -e
function banner() {
  local message="$1"
  local border

  border=$(printf '%*s' ${#message} '' | tr ' ' '=')

  printf '\n%s\n%s\n%s\n\n' "$border" "$message" "$border" 
}

banner "Ubuntu"
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

if command -v brew > /dev/null; then 
  banner "Homebrew"
  brew update && brew upgrade -y
fi

if command -v agent > /dev/null; then
  banner "Cursor agent"
  agent update
fi

if command -v glci > /dev/null; then
  banner "GitLab Runner"
  curl -fsSL https://gitlab.com/gitlab-org/ci-cd/runner-tools/glci/-/raw/main/install.sh | bash
fi


