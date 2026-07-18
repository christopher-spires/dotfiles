#! /bin/bash -e
set -x

###############################################################################
# support functions
###############################################################################

###############################################################################
function symlinkIfNotExist {
	local from="$1"
	local to="$2"
	if [[ ! -h $2 ]]; then
	  ln -s "$from" "$to"
	fi
}

###############################################################################
function prependPathIfNotPresent {
  [[ "$IS_CYGWIN" == true ]] || return
	NEWPATH=$1
	CURRENT_PATH=$(regtool get '\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\Path')
	if ! environmentPathHas "${NEWPATH}"; then 
		>&2 echo "prepending ${NEWPATH} to ${CURRENT_PATH}"
		/proc/cygdrive/c/Windows/System32/setx.exe Path "${NEWPATH};$CURRENT_PATH" /M
	fi
}

###############################################################################
function environmentPathHas {
	SEARCHPATH="$1"
	CURRENT_PATH=$(regtool get '\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\Path')
	[[ $CURRENT_PATH == *"${SEARCHPATH}"* ]]
}

###############################################################################
# installations
###############################################################################

###############################################################################
function install_maven() {
	# MAVEN_VERSION=3.9.16
  # no release candidates, alpha, beta, or milestone versions
  MAVEN_VERSION=$(curl https://repo1.maven.org/maven2/org/apache/maven/maven/maven-metadata.xml | grep -oE '>[0-9]+\.[0-9]+\.[0-9]+<' | cut -d '>' -f 2 | cut -d '<' -f 1 | sort -V | tail -1)
  MAVEN_URL="https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.zip"

	MAVEN_DIR=${OPT_DIR}/maven
	MAVEN_REPO_DIR=${MAVEN_DIR}/repository
	MAVEN_INSTALL="apache-maven-${MAVEN_VERSION}"
	MAVEN_ZIP_FILE=${TEMP_DIR}/${MAVEN_INSTALL}-bin.zip
	MAVEN_JANSI_PATH="lib/jansi-native/Windows/x86_64/jansi.dll"
	
	mkdir -p "${MAVEN_REPO_DIR}"
	
	if [ ! -e "${MAVEN_DIR}/${MAVEN_INSTALL}" ]; then
	  if [ ! -e "${MAVEN_ZIP_FILE}" ]; then
		  wget "$MAVEN_URL" -O "${MAVEN_ZIP_FILE}"
		fi
	  if [ -e "${MAVEN_ZIP_FILE}" ]; then
		  unzip "${MAVEN_ZIP_FILE}" -d "${MAVEN_DIR}"
		  chmod a+x "${MAVEN_DIR}/${MAVEN_INSTALL}/${MAVEN_JANSI_PATH}"
		else
		  >&2 echo "Maven zip file (${MAVEN_ZIP_FILE}) doesn't exist"
			return 2
		fi
	fi

	symlinkIfNotExist "${MAVEN_INSTALL}" "${MAVEN_DIR}/maven"
	# symlinkIfNotExist  $HOME/.m2 "${USER_PATH}/.m2"
	export MAVEN_HOME=${MAVEN_DIR}/maven

  local MAVEN_USER_DIR="${HOME}/.m2"
  source="${SCRIPT_DIR}/toolchains.xml"
  destination="${MAVEN_USER_DIR}/toolchains.xml"
  [[ "$IS_WSL2" == true ]] && [[ ! -e "$destination" ]] && mkdir -p "$MAVEN_USER_DIR" && cp "$source" "$destination"  
  [[ "$IS_WSL2" == true ]] && return
	
  [[ "$IS_CYGWIN" == true ]] && setx MAVEN_HOME "$(cygpath -w "${MAVEN_HOME}")" /M
	[[ "$IS_CYGWIN" == true ]] && prependPathIfNotPresent "%MAVEN_HOME%\bin"
}

###############################################################################
function install_gradle() {
  local GRADLE_JSON GRADLE_VERSION GRADLE_URL GRADLE_DIR GRADLE_INSTALL GRADLE_ZIP_FILE
  # curl -s https://services.gradle.org/versions/current
  # curl -s https://services.gradle.org/versions/all | jq -r '[.[] | select(.version | startswith("8.")) | select(.final == true)] | max_by(.version | split(".") | map(tonumber)) '
  GRADLE_JSON=$(curl -s https://services.gradle.org/versions/current)
  GRADLE_VERSION=$(jq -r '.version' <<< "$GRADLE_JSON")
  GRADLE_URL=$(jq -r '.downloadUrl' <<< "$GRADLE_JSON")

  GRADLE_DIR=${OPT_DIR}/gradle
  GRADLE_INSTALL=gradle-${GRADLE_VERSION}
  GRADLE_ZIP_FILE=${TEMP_DIR}/${GRADLE_INSTALL}-bin.zip
  mkdir -p "${GRADLE_DIR}"

  if [ ! -e "${GRADLE_DIR}/${GRADLE_INSTALL}" ]; then
	  if [ ! -e "${GRADLE_ZIP_FILE}" ]; then
		  wget "$GRADLE_URL" -O "${GRADLE_ZIP_FILE}"
		fi
	  if [ -e "${GRADLE_ZIP_FILE}" ]; then
		  unzip "${GRADLE_ZIP_FILE}" -d "${GRADLE_DIR}"
		else
		  >&2 echo "Gradle zip file (${GRADLE_ZIP_FILE}) doesn't exist"
		  return 2
		fi
	fi
  export GRADLE_HOME=${GRADLE_DIR}/gradle
  symlinkIfNotExist "${GRADLE_INSTALL}" "${GRADLE_HOME}"

  [[ "$IS_WSL2" == true ]] && return

  [[ "$IS_CYGWIN" == true ]] && setx GRADLE_HOME "$(cygpath -w "${GRADLE_HOME}")" /M
  [[ "$IS_CYGWIN" == true ]] && prependPathIfNotPresent "%GRADLE_HOME%\bin"
}

###############################################################################
function install_java_temurin {
  [ -n "$JAVA_TOOL_OPTIONS" ] && [ -x "$PWSH" ] && "$PWSH" -Command '[Environment]::SetEnvironmentVariable("JAVA_TOOL_OPTIONS",[NullString]::Value,"Machine")'

  [[ "$IS_WSL2" == true ]] || return
  # https://adoptium.net/installation/linux/
  apt install -y wget apt-transport-https gpg
  wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null
  # shellcheck source=/etc/os-release
  source /etc/os-release
  echo "deb https://packages.adoptium.net/artifactory/deb $VERSION_CODENAME main" | tee /etc/apt/sources.list.d/adoptium.list
  apt update -y # update if you haven't already
  apt install -y temurin-8-jdk temurin-17-jdk temurin-21-jdk temurin-25-jdk
}

###############################################################################
function install_java_openjdk {
  apt update -y # update if you haven't already
  apt install -y openjdk-8-jdk openjdk-17-jdk openjdk-21-jdk openjdk-25-jdk
}

###############################################################################
function defender_configuration() {
  [ -x "$PWSH" ] || return 1
  local CURRENT_EXCLUSIONS EXCLUSIONS MISSING_EXCLUSIONS WUP
  # CURRENT_EXCLUSIONS=( "$(regtool list '\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths')" )
  CURRENT_EXCLUSIONS=( "$PWSH" "Get-MpPreference | Select-Object -ExpandProperty ExclusionPath" )
  echo "CURRENT_EXCLUSIONS " "${CURRENT_EXCLUSIONS[@]}"
  WUP=$(wslpath -w "$USER_PATH")
  EXCLUSIONS=( "$WUP"'\AppData\Local\JetBrains\IntelliJIdea2026.2' "$WUP"'\.gradle' "$WUP"'\AppData\Local\Programs\IntelliJ IDEA Ultimate' 'C:\cygwin64\bin' 'C:\Program Files\Windows Defender' )
  for EXCLUSION in "${EXCLUSIONS[@]}"; do
	# shellcheck disable=SC2076
	if [[ ! " ${CURRENT_EXCLUSIONS[*]} " =~ " ${EXCLUSION} " ]]; then
	  MISSING_EXCLUSIONS+=("$EXCLUSION")
	fi
  done
  echo "MISSING_EXCLUSIONS " "${MISSING_EXCLUSIONS[@]}"
  for EXCLUSION in "${MISSING_EXCLUSIONS[@]}"; do
    [ -x "$PWSH" ] && "$PWSH" -Command Add-MpPreference -ExclusionPath "'$EXCLUSION'"
  done
  
}

###############################################################################
function install_git() {
  add-apt-repository ppa:git-core/ppa -y
  apt update -y 
  apt install -y git
}

###############################################################################
function install_firacode() {
# https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/FiraCode.zip
  echo "Installing FiraCode font"
}

###############################################################################
function install_pwsh() {
  # https://learn.microsoft.com/en-us/powershell/scripting/install/install-ubuntu
  ###################################
  # Prerequisites

  # Update the list of packages
  sudo apt-get update

  # Install pre-requisite packages.
  sudo apt-get install -y wget apt-transport-https software-properties-common

  # Get the version of Ubuntu
  # shellcheck source=/etc/os-release
  source /etc/os-release

  local DEB_FILE=${TEMP_DIR}/packages-microsoft-prod.deb

  # Download the Microsoft repository keys
  wget -q "https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb" -O "$DEB_FILE"

  # Register the Microsoft repository keys
  sudo dpkg -i "${DEB_FILE}"

  # Delete the Microsoft repository keys file
  rm "${DEB_FILE}"

  # Update the list of packages after we added packages.microsoft.com
  sudo apt-get update

  ###################################
  # Install PowerShell
  sudo apt-get install -y powershell

  # Start PowerShell
  # pwsh --version
}

###############################################################################
function install_homebrew() {
  [[ -x "$BREW" || -x "brew" ]] && { echo "Homebrew installed. Use 'brew update'."; return 1; }
  sudo -u "$USER" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

###############################################################################
function brew_install() {
  local PACKAGE_NAME="$1"
  local COMMAND_NAME="${2:-$1}"
  local COMMAND_PATH="/home/linuxbrew/.linuxbrew/bin/${COMMAND_NAME}"
  [[ -x "$COMMAND_PATH" || -x "$COMMAND_NAME" ]] && { echo "${PACKAGE_NAME} already installed. Use 'brew update && brew upgrade' to update"; return; };
  [[ -x "$BREW" ]] || { echo "Homebrew not installed. Please install Homebrew first."; return 1; }
  sudo -u "$USER" "$BREW" install "$PACKAGE_NAME"
}

###############################################################################
function install_chezmoi() {
  # sudo sh -c "$(curl -fsLS https://get.chezmoi.io)"
  local CHEZMOI
  CHEZMOI="/home/linuxbrew/.linuxbrew/bin/chezmoi"
  brew_install "chezmoi"
  "$CHEZMOI" init --apply christopher-spires
}

###############################################################################
function install_podman() {
  brew_install "podman"
  brew_install "podman-compose"
  # Error: command required for rootless mode with multiple IDs: exec: "newuidmap": executable file not found in $PATH
  sudo apt update && sudo apt install -y uidmap
}

###############################################################################
function install_delta() {
  # local DEB_FILE=git-delta_0.18.2_amd64.deb
  # local DOWNLOAD_FILE=$TEMP_DIR/$DEB_FILE
  # wget https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_amd64.deb -O "$DOWNLOAD_FILE"
  # sudo dpkg -i "$DOWNLOAD_FILE"
  brew_install "git-delta" "delta"
}

###############################################################################
function install_glab() {
  brew_install "glab"
}

###############################################################################
function install_copilot() {
  brew_install "copilot-cli" "copilot"
}

###############################################################################
function install_cursor() {
  local arch
  apt install -y wget gpg
  wget -qO - https://downloads.cursor.com/keys/anysphere.asc | sudo gpg --dearmor --yes -o /usr/share/keyrings/anysphere.gpg
  gpg --quiet --show-keys --with-fingerprint /usr/share/keyrings/anysphere.gpg
  # shellcheck source=/etc/os-release
  # source /etc/os-release
  # echo "deb https://downloads.cursor.com/aptrepo $VERSION_CODENAME main" | tee /etc/apt/sources.list.d/adoptium.list
  arch="$(dpkg --print-architecture)"
  printf '%s\n' \
    'Types: deb' \
    'URIs: https://downloads.cursor.com/aptrepo' \
    'Suites: stable' \
    'Components: main' \
    "Architectures: ${arch}" \
    'Signed-By: /usr/share/keyrings/anysphere.gpg' | sudo tee /etc/apt/sources.list.d/cursor.sources > /dev/null  
  printf 'cursor cursor/add-cursor-repo boolean false\n' | sudo debconf-set-selections
  apt update -y
  apt-cache policy cursor
  apt install -y cursor  
}

###############################################################################
function install_yq() {
  brew_install "yq"
}

###############################################################################
function install_starship {
    # curl -sS https://starship.rs/install.sh | sh
    brew_install "starship"
}

###############################################################################
function install_node {
    # curl -sS https://starship.rs/install.sh | sh
    brew_install "node"
}

###############################################################################
function setup_wsl2() {
  [[ "$IS_WSL2" == true ]] || return
  
  setup_sudo
  
  update_wsl_conf

  protect_ssh_dir
  
  local HUSH_LOGIN=$HOME/.hushlogin
  [[ ! -e $HUSH_LOGIN ]] && touch "$HUSH_LOGIN"
  
  sudo apt update -y
  sudo apt upgrade -y
  sudo apt install -y \
      zip \
      unzip \
      jq \
      iselect \
      dos2unix \
      moreutils \
      apt-transport-https \
      ca-certificates \
      crudini
}

###############################################################################
function setup_sudo() {
    [[ "$IS_WSL2" == true ]] || return
    
    local SUDO_FILE=/etc/sudoers.d/$USER
    [[ -e $SUDO_FILE ]] && warn "$SUDO_FILE exists. No changes will be made to SUDO." && return
    echo "$USER ALL=(ALL) NOPASSWD:ALL" | EDITOR='tee' visudo -f "$SUDO_FILE"
}

###############################################################################
function update_wsl_conf() {
  [[ "$IS_WSL2" == true ]] || return
  local WSL_CONF=/etc/wsl.conf
  local root default_root="/mnt" new_root="/"
  root=$(crudini --get "$WSL_CONF" automount root 2> /dev/null || echo "$default_root")
  if [[ "$root" != "$new_root" ]]; then
    sudo crudini --ini-options=nospace --set "$WSL_CONF" automount root "$new_root"
  fi
}

###############################################################################
function protect_ssh_dir() {
  local SSH_DIR="$HOME/.ssh"
  mkdir -p "$SSH_DIR"
	chmod 700 "$SSH_DIR"
	mapfile -t private_keys< <(find "$SSH_DIR" -name 'id_*')
	for private_key in "${private_keys[@]}"; do
    chmod 700 "$private_key"
	done
}

###############################################################################
function setup_power() {
  powercfg.exe
}

###############################################################################
function source_file() {
  local file="$1"
  if [ -f "$file" ]; then
    # shellcheck source=/dev/null
    source "$file"
  fi
}

###############################################################################
function warn {
  >&2 echo "$@"
}

###############################################################################
function show_install_menu() {
  local selections
  local token
  local gitVersion pwshVersion deltaVersion mavenVersion gradleVersion starshipVersion javaVersion brewVersion podmanVersion copilotVersion glabVersion yqVersion npmVersion nodeVersion batVersion cursorVersion
  gitVersion=$(git --version 2>/dev/null || echo "not installed")
  pwshVersion=$(pwsh --version 2>/dev/null || echo "not installed")
  deltaVersion=$(delta --version 2>/dev/null || echo "not installed")
  batVersion=$(bat --version 2>/dev/null || echo "not installed")
  mavenVersion=$(mvn -version 2>/dev/null | head -n 1 || echo "not installed")
  gradleVersion=$(gradle --version 2>/dev/null | grep "Gradle" || echo "not installed")
  javaVersion=$(java -version 2>&1 | head -n 1 || echo "not installed")
  # chezmoiVersion=$(chezmoi --version 2>/dev/null || echo "not installed")
  brewVersion=$(brew --version 2>/dev/null | head -n 1 || echo "not installed")
  podmanVersion=$(podman --version 2>/dev/null || echo "not installed")
  starshipVersion=$(starship --version 2>/dev/null | head -n 1 || echo "not installed")
  copilotVersion=$(copilot --version 2>/dev/null | head -n 1 || echo "not installed")
  glabVersion=$(glab --version 2>/dev/null | head -n 1 || echo "not installed")
  yqVersion=$(yq --version 2>/dev/null || echo "not installed")
  npmVersion=$(npm --version 2>/dev/null || echo "not installed")
  nodeVersion=$(node --version 2>/dev/null || echo "not installed")
  cursorVersion=$(cursor --version 2>/dev/null || echo "not installed")

  declare -A install_options=(
    ["install_pwsh"]="PowerShell ($pwshVersion)"
    ["install_delta"]="Delta ($deltaVersion)"
    ["install_bat"]="Bat ($batVersion)"
    ["install_maven"]="Maven ($mavenVersion)"
    ["install_gradle"]="Gradle ($gradleVersion)"
    ["install_java_temurin"]="Java (Temurin 8/17/21/25) ($javaVersion)"
    ["install_java_openjdk"]="Java (OpenJdk 8/17/21/25) ($javaVersion)"
    ["install_git"]="Git ($gitVersion)"
    ["install_starship"]="Starship ($starshipVersion)"
    ["install_homebrew"]="Homebrew ($brewVersion)"
    ["install_podman"]="Podman ($podmanVersion)"
    ["install_copilot"]="GitHub Copilot CLI ($copilotVersion)"
    ["install_glab"]="GitLab CLI ($glabVersion)"  
    ["install_yq"]="yq ($yqVersion)"
    ["install_node"]="Node.js (Node=$nodeVersion npm=$npmVersion)"
    ["install_cursor"]="Cursor ($cursorVersion)"
   # ["install_chezmoi"]="Chezmoi ($chezmoiVersion)"

  )
  local options=()
  for key in "${!install_options[@]}"; do
    options+=("$key" "${install_options[$key]}" "OFF")
  done
  if ! command -v whiptail >/dev/null 2>&1; then
    return 9;
  fi 
  mapfile -t selections < <(whiptail \
    --separate-output --notags --title "Setup" \
    --checklist "Select install options (SPACE to toggle, ENTER to run):" \
    20 90 12 \
    "${options[@]}" \
    3>&1 1>&2 2>&3)
  local rc=$?
  [[ $rc -ne 0 ]] && echo "No install options selected. Exiting." && return 0

  for token in "${selections[@]}"; do
    $token || { local error_code=$?; warn "Installation failed for option: $token ($error_code) "; return $error_code; }  
  done  
}

###############################################################################
# main
###############################################################################
if ! sudo -v; then
  error "Superuser not granted, aborting installation"
  exit 1
fi

WSL_OSTYPE=linux-gnu
CYGWIN_OSTYPE=cygwin
if [[ "$OSTYPE" == "$CYGWIN_OSTYPE" ]]; then
  # echo "Running in Cygwin"
  export IS_CYGWIN=true
  # source_file "${HOME}/.bashrc_cygwin"
# elif grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null && [ -n "$WSL_INTEROP" ]; then
elif [[ "$OSTYPE" == "$WSL_OSTYPE" ]]; then
  # echo "Running in WSL2"
  export IS_WSL2=true
  # source_file "${HOME}/.bashrc_wsl2"
else
  echo "Running unknown environment"
fi

TEMP_DIR=$(mktemp -d)
# mkdir -p "$TEMP_DIR"
SCRIPT_DIR=$(dirname "$0")
CYGWIN_OPTIONS=winsymlinks:nativestrict
[[ "$IS_CYGWIN" == true ]] && C_DRIVE=/proc/cygdrive/c
if [[ "$IS_WSL2" == true ]]; then
  [[ -e /mnt/c ]] && C_DRIVE=/mnt/c
  [[ -e /c ]] && C_DRIVE=/c
fi

USER=${SUDO_USER:-$USER}
HOME=/home/$USER

USER_PATH="${C_DRIVE}/Users/${USER}"
PWSH="${C_DRIVE}/Program Files/PowerShell/7/pwsh.exe"
BREW=/home/linuxbrew/.linuxbrew/bin/brew

if [ -n "$OneDrive" ]; then
  [[ "$IS_CYGWIN" == true ]] && ONEDRIVE_PATH=$(cygpath --proc-cygdrive -u "$OneDrive")
  [[ "$IS_WSL2" == true ]]   && ONEDRIVE_PATH=$(wslpath -u "$OneDrive")
else
  my_paths=( "$USER_PATH/OneDrive?*" ) # enterprise OneDrive path may have a suffix like " - CompanyName"
  if [ ${#my_paths[@]} -eq 1 ]; then
    >&2 echo "Enterprise OneDrive path not found. Using default OneDrive path."
    my_paths=( "$USER_PATH/OneDrive" )
  fi
  ONEDRIVE_PATH=${my_paths[0]}
  >&2 echo "Using OneDrive path: $ONEDRIVE_PATH"
  if [ ! -e "$ONEDRIVE_PATH" ]; then
    >&2 echo "OneDrive path not found: $ONEDRIVE_PATH"
  fi
fi

setup_wsl2

[[ "$IS_CYGWIN" == true ]] && [ "$CYGWIN" != "$CYGWIN_OPTIONS" ] && /proc/cygdrive/c/Windows/System32/setx.exe CYGWIN "$CYGWIN_OPTIONS" /M

[[ "$IS_CYGWIN" == true ]] && OPT_DIR=/proc/cygdrive/c/opt
[[ "$IS_WSL2" == true ]] && OPT_DIR=/opt

if [[ "$IS_CYGWIN" == true ]]; then
  if ! ls /c/ &> /dev/null; then
    mount -c / --options posix=0
    mount -m > "/etc/fstab.d/${USER}"
  fi
fi

if ! shopt direxpand; then
  shopt -s direxpand
fi

if [ -e "$USER_PATH" ]; then
  symlinkIfNotExist "$USER_PATH" "$HOME/Users" &&
  symlinkIfNotExist "$USER_PATH/Downloads" "$HOME/Downloads"
fi
if [ -e "$ONEDRIVE_PATH" ]; then
  symlinkIfNotExist "$ONEDRIVE_PATH" "$HOME/onedrive" &&
  symlinkIfNotExist "$ONEDRIVE_PATH/Desktop" "$HOME/Desktop"
fi

[[ "$IS_CYGWIN" == true ]] && prependPathIfNotPresent "$(cygpath -w /bin)"
[[ "$IS_CYGWIN" == true ]] && defender_configuration

show_install_menu
# set

set +e
set +x

>&2 echo "exiting $0"

