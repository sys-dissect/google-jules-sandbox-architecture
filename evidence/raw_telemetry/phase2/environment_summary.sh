#!/usr/bin/env bash
#
# A diagnostic script to check the versions of installed development tools
# without altering the current shell environment. It reports what is
# currently active and will print "not found" if a tool isn't
# available in the current PATH.
#

# --- Helper Functions ---

# Prints a styled header.
print_header() {
  echo ""
  echo "--------- $1 ---------"
}

# Checks for a command and prints its version if found.
# Arguments:
#   $1: The command name to check (e.g., "python3").
#   $2: The arguments to get the version (e.g., "--version").
#   $3: The optional string to grep for in the version output.
check_command() {
  COMMAND="$1"
  VERSION_FLAG="$2"
  GREP="${3-""}"
  if command -v "$COMMAND" &> /dev/null; then
    echo -n "✅  $1: "
    if [ -z "$GREP" ]; then
      "$COMMAND" $VERSION_FLAG | head -n 10
    else
      "$COMMAND" $VERSION_FLAG | grep "$GREP" | head -n 10
    fi

  else
    echo "❌  $1: not found"
  fi
}

# --- Environment Checks ---

echo "-------------------------------------"
echo "Environment check starting..."

print_header "Python"
check_command python3 --version
check_command python --version
check_command pip --version
check_command pipx --version
check_command poetry --version
check_command uv --version
check_command black --version
check_command mypy --version
check_command pytest --version
check_command ruff --version
if command -v pyenv &> /dev/null; then
  echo "✅  pyenv: available"
  pyenv versions
else
  echo "❌  pyenv: not found"
fi

print_header "NodeJS"
check_command node --version
if [ -s "$NVM_DIR/nvm.sh" ] && nvm ls --no-alias; then
  echo "✅  nvm: available"
else
  echo "❌  nvm: not found"
fi
check_command npm --version
check_command yarn --version
check_command pnpm --version
check_command eslint --version
check_command prettier --version
check_command chromedriver --version

print_header "Java"
check_command java -version 2>&1
check_command mvn --version
check_command gradle --version Gradle

print_header "Go"
check_command go version

print_header "Rust"
check_command rustc --version
check_command cargo --version

print_header "Bun"
check_command bun --version

print_header "C/C++ Compilers"
check_command clang --version
check_command gcc --version
check_command cmake --version
check_command ninja --version
check_command conan --version

print_header "Android"
check_command sdkmanager --list_installed

print_header "Flutter"
check_command flutter --version

print_header "PHP"
check_command php -v
check_command composer --version

print_header "Ruby"
check_command ruby --version
check_command gem -v
check_command bundle -v

print_header ".NET"
check_command dotnet --list-sdks

print_header "Docker"
check_command docker --version
check_command docker "compose version"

print_header "PlayWright"
check_command playwright --version

print_header "Other Utilities"
check_command awk -V
check_command curl --version
check_command git --version
check_command grep --version
check_command gzip --version
check_command jq --version
check_command make --version
check_command rg --version
check_command sed --version
check_command tar --version
check_command tmux -V
check_command yq --version



echo ""
echo "-------------------------------------"
echo "Environment check complete."
