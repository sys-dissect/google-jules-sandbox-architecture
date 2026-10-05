1. Inspect scripts: cat /opt/environment_summary.sh
```
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
```

2. Image directory census: find /opt/jules /opt/google -maxdepth 3 -ls
```
      355      0 drwxr-xr-x   4 root     root           45 Mar  2  2026 /opt/jules
      356      0 drwxr-xr-x   6 root     root           68 Mar  2  2026 /opt/jules/pipx
      357      0 drwxr-xr-x   3 root     root           35 Mar  2  2026 /opt/jules/pipx/.cache
   188870      1 -rw-r--r--   1 root     root          186 Mar  2  2026 /opt/jules/pipx/.cache/CACHEDIR.TAG
      358      0 drwxr-xr-x   3 root     root           50 Mar  2  2026 /opt/jules/pipx/logs
   188871      6 -rw-r--r--   1 root     root         5223 Mar  2  2026 /opt/jules/pipx/logs/cmd_2026-03-02_16.40.03.log
      359      0 drwxr-xr-x   7 root     root           95 Mar  2  2026 /opt/jules/pipx/shared
      360      0 drwxr-xr-x  12 root     root          177 Mar  2  2026 /opt/jules/pipx/shared/bin
      361      0 drwxr-xr-x   3 root     root           33 Mar  2  2026 /opt/jules/pipx/shared/include
      362      0 drwxr-xr-x   3 root     root           33 Mar  2  2026 /opt/jules/pipx/shared/lib
   189893      0 lrwxrwxrwx   1 root     root            3 Mar  2  2026 /opt/jules/pipx/shared/lib64 -> lib
   189894      1 -rw-r--r--   1 root     root          169 Mar  2  2026 /opt/jules/pipx/shared/pyvenv.cfg
      363      0 drwxr-xr-x   3 root     root           33 Mar  2  2026 /opt/jules/pipx/venvs
      364      0 drwxr-xr-x   8 root     root          109 Mar  2  2026 /opt/jules/pipx/venvs/playwright
      365      0 drwxr-xr-x   4 root     root           37 Mar  2  2026 /opt/jules/playwright
      366      0 drwxr-xr-x   4 root     root           47 Mar  2  2026 /opt/jules/playwright/bin
   191392      1 -rwxr-xr-x   1 root     root           98 Mar  2  2026 /opt/jules/playwright/bin/playwright
   191393      1 -rwxr-xr-x   1 root     root           94 Mar  2  2026 /opt/jules/playwright/bin/python
      367      0 drwxr-xr-x   2 root     root            3 Mar  2  2026 /opt/jules/playwright/man
      368      0 drwxr-xr-x   3 root     root           29 Mar  2  2026 /opt/google
      369      0 drwxr-xr-x  37 root     root          888 Mar  2  2026 /opt/google/chrome
   188834      1 -rw-r--r--   1 root     root            7 Feb 20  2026 /opt/google/chrome/CHROME_VERSION_EXTRA
      370      0 drwxr-xr-x   4 root     root           61 Mar  2  2026 /opt/google/chrome/MEIPreload
   188603      1 -rw-r--r--   1 root     root          238 Feb 20  2026 /opt/google/chrome/MEIPreload/manifest.json
   188604      9 -rw-r--r--   1 root     root         8254 Feb 20  2026 /opt/google/chrome/MEIPreload/preloaded_data.pb
      371      0 drwxr-xr-x   4 root     root           76 Mar  2  2026 /opt/google/chrome/PrivacySandboxAttestationsPreloaded
   188605      1 -rw-r--r--   1 root     root          122 Feb 20  2026 /opt/google/chrome/PrivacySandboxAttestationsPreloaded/manifest.json
   188606      8 -rw-r--r--   1 root     root         7624 Feb 20  2026 /opt/google/chrome/PrivacySandboxAttestationsPreloaded/privacy-sandbox-attestations.dat
      372      0 drwxr-xr-x   5 root     root           77 Mar  2  2026 /opt/google/chrome/WidevineCdm
   188609      1 -rw-r--r--   1 root     root          473 Feb 20  2026 /opt/google/chrome/WidevineCdm/LICENSE
      373      0 drwxr-xr-x   3 root     root           32 Mar  2  2026 /opt/google/chrome/WidevineCdm/_platform_specific
   188611      1 -rw-r--r--   1 root     root          838 Feb 20  2026 /opt/google/chrome/WidevineCdm/manifest.json
   188838 261604 -rwxr-xr-x   1 root     root     268012760 Feb 20  2026 /opt/google/chrome/chrome
   188839   6141 -rwxr-xr-x   1 root     root       6287728 Feb 20  2026 /opt/google/chrome/chrome-management-service
   188840     15 -rwsr-xr-x   1 root     root         15248 Feb 20  2026 /opt/google/chrome/chrome-sandbox
   188841    938 -rw-r--r--   1 root     root        960103 Feb 20  2026 /opt/google/chrome/chrome_100_percent.pak
   188842   1786 -rw-r--r--   1 root     root       1828162 Feb 20  2026 /opt/google/chrome/chrome_200_percent.pak
   188843   1902 -rwxr-xr-x   1 root     root       1947192 Feb 20  2026 /opt/google/chrome/chrome_crashpad_handler
      374      0 drwxr-xr-x   3 root     root            36 Mar  2  2026 /opt/google/chrome/cron
   188612     16 -rwxr-xr-x   1 root     root         15532 Feb 20  2026 /opt/google/chrome/cron/google-chrome
   188845      1 -rw-r--r--   1 root     root           482 Feb 20  2026 /opt/google/chrome/default-app-block
      375      0 drwxr-xr-x   3 root     root            47 Mar  2  2026 /opt/google/chrome/default_apps
   188613      1 -rw-r--r--   1 root     root           291 Feb 20  2026 /opt/google/chrome/default_apps/external_extensions.json
   188847      2 -rwxr-xr-x   1 root     root          1585 Feb 20  2026 /opt/google/chrome/google-chrome
   188848  10569 -rw-r--r--   1 root     root      10822192 Feb 20  2026 /opt/google/chrome/icudtl.dat
   188849    238 -rw-r--r--   1 root     root        243696 Feb 20  2026 /opt/google/chrome/libEGL.so
   188850   6360 -rw-r--r--   1 root     root       6512496 Feb 20  2026 /opt/google/chrome/libGLESv2.so
   188851  19732 -rw-r--r--   1 root     root      20205552 Feb 20  2026 /opt/google/chrome/liboptimization_guide_internal.so
   188852     26 -rw-r--r--   1 root     root         26528 Feb 20  2026 /opt/google/chrome/libqt5_shim.so
   188853     29 -rw-r--r--   1 root     root         28720 Feb 20  2026 /opt/google/chrome/libqt6_shim.so
   188854   4260 -rw-r--r--   1 root     root       4361936 Feb 20  2026 /opt/google/chrome/libvk_swiftshader.so
   188855    616 -rw-r--r--   1 root     root        630040 Feb 20  2026 /opt/google/chrome/libvulkan.so.1
      376      0 drwxr-xr-x 222 root     root          4641 Mar  2  2026 /opt/google/chrome/locales
   188614    614 -rw-r--r--   1 root     root        628077 Feb 20  2026 /opt/google/chrome/locales/af.pak
   188615      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/af_FEMININE.pak
   188616      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/af_MASCULINE.pak
   188617      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/af_NEUTER.pak
   188618    995 -rw-r--r--   1 root     root       1018684 Feb 20  2026 /opt/google/chrome/locales/am.pak
   188619      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/am_FEMININE.pak
   188620      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/am_MASCULINE.pak
   188621      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/am_NEUTER.pak
   188622   1104 -rw-r--r--   1 root     root       1129580 Feb 20  2026 /opt/google/chrome/locales/ar.pak
   188623      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ar_FEMININE.pak
   188624      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ar_MASCULINE.pak
   188625      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ar_NEUTER.pak
   188626   1134 -rw-r--r--   1 root     root       1160893 Feb 20  2026 /opt/google/chrome/locales/bg.pak
   188627      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/bg_FEMININE.pak
   188628      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/bg_MASCULINE.pak
   188629      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/bg_NEUTER.pak
   188630   1461 -rw-r--r--   1 root     root       1495711 Feb 20  2026 /opt/google/chrome/locales/bn.pak
   188631      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/bn_FEMININE.pak
   188632      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/bn_MASCULINE.pak
   188633      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/bn_NEUTER.pak
   188634    699 -rw-r--r--   1 root     root        715425 Feb 20  2026 /opt/google/chrome/locales/ca.pak
   188635      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ca_FEMININE.pak
   188636      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ca_MASCULINE.pak
   188637      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ca_NEUTER.pak
   188638    714 -rw-r--r--   1 root     root        730806 Feb 20  2026 /opt/google/chrome/locales/cs.pak
   188639      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/cs_FEMININE.pak
   188640      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/cs_MASCULINE.pak
   188641      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/cs_NEUTER.pak
   188642    650 -rw-r--r--   1 root     root        665068 Feb 20  2026 /opt/google/chrome/locales/da.pak
   188643      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/da_FEMININE.pak
   188644      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/da_MASCULINE.pak
   188645      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/da_NEUTER.pak
   188646    700 -rw-r--r--   1 root     root        716491 Feb 20  2026 /opt/google/chrome/locales/de.pak
   188647      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/de_FEMININE.pak
   188648      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/de_MASCULINE.pak
   188649      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/de_NEUTER.pak
   188650   1247 -rw-r--r--   1 root     root       1276378 Feb 20  2026 /opt/google/chrome/locales/el.pak
   188651      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/el_FEMININE.pak
   188652      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/el_MASCULINE.pak
   188653      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/el_NEUTER.pak
   188654    560 -rw-r--r--   1 root     root        572959 Feb 20  2026 /opt/google/chrome/locales/en-GB.pak
   188655      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/en-GB_FEMININE.pak
   188656      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/en-GB_MASCULINE.pak
   188657      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/en-GB_NEUTER.pak
   188658    566 -rw-r--r--   1 root     root        579522 Feb 20  2026 /opt/google/chrome/locales/en-US.pak
   188659      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/en-US_FEMININE.pak
   188660      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/en-US_MASCULINE.pak
   188661      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/en-US_NEUTER.pak
   188662    685 -rw-r--r--   1 root     root        700595 Feb 20  2026 /opt/google/chrome/locales/es-419.pak
   188663      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/es-419_FEMININE.pak
   188664      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/es-419_MASCULINE.pak
   188665      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/es-419_NEUTER.pak
   188666    680 -rw-r--r--   1 root     root        696027 Feb 20  2026 /opt/google/chrome/locales/es.pak
   188667      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/es_FEMININE.pak
   188668      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/es_MASCULINE.pak
   188669      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/es_NEUTER.pak
   188670    624 -rw-r--r--   1 root     root        638546 Feb 20  2026 /opt/google/chrome/locales/et.pak
   188671      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/et_FEMININE.pak
   188672      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/et_MASCULINE.pak
   188673      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/et_NEUTER.pak
   188674   1026 -rw-r--r--   1 root     root       1049843 Feb 20  2026 /opt/google/chrome/locales/fa.pak
   188675      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/fa_FEMININE.pak
   188676      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/fa_MASCULINE.pak
   188677      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/fa_NEUTER.pak
   188678    632 -rw-r--r--   1 root     root        646358 Feb 20  2026 /opt/google/chrome/locales/fi.pak
   188679      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/fi_FEMININE.pak
   188680      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/fi_MASCULINE.pak
   188681      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/fi_NEUTER.pak
   188682    718 -rw-r--r--   1 root     root        734215 Feb 20  2026 /opt/google/chrome/locales/fil.pak
   188683      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/fil_FEMININE.pak
   188684      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/fil_MASCULINE.pak
   188685      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/fil_NEUTER.pak
   188686    742 -rw-r--r--   1 root     root        759145 Feb 20  2026 /opt/google/chrome/locales/fr.pak
   188687      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/fr_FEMININE.pak
   188688      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/fr_MASCULINE.pak
   188689      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/fr_NEUTER.pak
   188690   1447 -rw-r--r--   1 root     root       1481146 Feb 20  2026 /opt/google/chrome/locales/gu.pak
   188691      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/gu_FEMININE.pak
   188692      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/gu_MASCULINE.pak
   188693      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/gu_NEUTER.pak
   188694    901 -rw-r--r--   1 root     root        921697 Feb 20  2026 /opt/google/chrome/locales/he.pak
   188695      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/he_FEMININE.pak
   188696      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/he_MASCULINE.pak
   188697      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/he_NEUTER.pak
   188698   1543 -rw-r--r--   1 root     root       1579199 Feb 20  2026 /opt/google/chrome/locales/hi.pak
   188699      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/hi_FEMININE.pak
   188700      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/hi_MASCULINE.pak
   188701      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/hi_NEUTER.pak
   188702    692 -rw-r--r--   1 root     root        708279 Feb 20  2026 /opt/google/chrome/locales/hr.pak
   188703      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/hr_FEMININE.pak
   188704      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/hr_MASCULINE.pak
   188705      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/hr_NEUTER.pak
   188706    741 -rw-r--r--   1 root     root        758444 Feb 20  2026 /opt/google/chrome/locales/hu.pak
   188707      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/hu_FEMININE.pak
   188708      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/hu_MASCULINE.pak
   188709      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/hu_NEUTER.pak
   188710    613 -rw-r--r--   1 root     root        626953 Feb 20  2026 /opt/google/chrome/locales/id.pak
   188711      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/id_FEMININE.pak
   188712      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/id_MASCULINE.pak
   188713      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/id_NEUTER.pak
   188714    677 -rw-r--r--   1 root     root        693116 Feb 20  2026 /opt/google/chrome/locales/it.pak
   188715      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/it_FEMININE.pak
   188716      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/it_MASCULINE.pak
   188717      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/it_NEUTER.pak
   188718    820 -rw-r--r--   1 root     root        838684 Feb 20  2026 /opt/google/chrome/locales/ja.pak
   188719      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ja_FEMININE.pak
   188720      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ja_MASCULINE.pak
   188721      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ja_NEUTER.pak
   188722   1649 -rw-r--r--   1 root     root       1687560 Feb 20  2026 /opt/google/chrome/locales/kn.pak
   188723      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/kn_FEMININE.pak
   188724      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/kn_MASCULINE.pak
   188725      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/kn_NEUTER.pak
   188726    693 -rw-r--r--   1 root     root        709482 Feb 20  2026 /opt/google/chrome/locales/ko.pak
   188727      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ko_FEMININE.pak
   188728      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ko_MASCULINE.pak
   188729      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ko_NEUTER.pak
   188730    752 -rw-r--r--   1 root     root        769633 Feb 20  2026 /opt/google/chrome/locales/lt.pak
   188731      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/lt_FEMININE.pak
   188732      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/lt_MASCULINE.pak
   188733      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/lt_NEUTER.pak
   188734    749 -rw-r--r--   1 root     root        766623 Feb 20  2026 /opt/google/chrome/locales/lv.pak
   188735      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/lv_FEMININE.pak
   188736      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/lv_MASCULINE.pak
   188737      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/lv_NEUTER.pak
   188738   1704 -rw-r--r--   1 root     root       1743970 Feb 20  2026 /opt/google/chrome/locales/ml.pak
   188739      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ml_FEMININE.pak
   188740      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ml_MASCULINE.pak
   188741      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ml_NEUTER.pak
   188742   1414 -rw-r--r--   1 root     root       1447650 Feb 20  2026 /opt/google/chrome/locales/mr.pak
   188743      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/mr_FEMININE.pak
   188744      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/mr_MASCULINE.pak
   188745      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/mr_NEUTER.pak
   188746    644 -rw-r--r--   1 root     root        658630 Feb 20  2026 /opt/google/chrome/locales/ms.pak
   188747      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ms_FEMININE.pak
   188748      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ms_MASCULINE.pak
   188749      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ms_NEUTER.pak
   188750    618 -rw-r--r--   1 root     root        632542 Feb 20  2026 /opt/google/chrome/locales/nb.pak
   188751      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/nb_FEMININE.pak
   188752      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/nb_MASCULINE.pak
   188753      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/nb_NEUTER.pak
   188754    644 -rw-r--r--   1 root     root        658645 Feb 20  2026 /opt/google/chrome/locales/nl.pak
   188755      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/nl_FEMININE.pak
   188756      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/nl_MASCULINE.pak
   188757      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/nl_NEUTER.pak
   188758    718 -rw-r--r--   1 root     root        734637 Feb 20  2026 /opt/google/chrome/locales/pl.pak
   188759      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/pl_FEMININE.pak
   188760      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/pl_MASCULINE.pak
   188761      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/pl_NEUTER.pak
   188762    672 -rw-r--r--   1 root     root        687410 Feb 20  2026 /opt/google/chrome/locales/pt-BR.pak
   188763      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/pt-BR_FEMININE.pak
   188764      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/pt-BR_MASCULINE.pak
   188765      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/pt-BR_NEUTER.pak
   188766    676 -rw-r--r--   1 root     root        692036 Feb 20  2026 /opt/google/chrome/locales/pt-PT.pak
   188767      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/pt-PT_FEMININE.pak
   188768      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/pt-PT_MASCULINE.pak
   188769      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/pt-PT_NEUTER.pak
   188770    702 -rw-r--r--   1 root     root        718291 Feb 20  2026 /opt/google/chrome/locales/ro.pak
   188771      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ro_FEMININE.pak
   188772      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ro_MASCULINE.pak
   188773      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ro_NEUTER.pak
   188774   1161 -rw-r--r--   1 root     root       1188112 Feb 20  2026 /opt/google/chrome/locales/ru.pak
   188775      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ru_FEMININE.pak
   188776      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ru_MASCULINE.pak
   188777      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ru_NEUTER.pak
   188778    725 -rw-r--r--   1 root     root        741792 Feb 20  2026 /opt/google/chrome/locales/sk.pak
   188779      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/sk_FEMININE.pak
   188780      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/sk_MASCULINE.pak
   188781      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/sk_NEUTER.pak
   188782    698 -rw-r--r--   1 root     root        714244 Feb 20  2026 /opt/google/chrome/locales/sl.pak
   188783      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/sl_FEMININE.pak
   188784      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/sl_MASCULINE.pak
   188785      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/sl_NEUTER.pak
   188786   1072 -rw-r--r--   1 root     root       1097021 Feb 20  2026 /opt/google/chrome/locales/sr.pak
   188787      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/sr_FEMININE.pak
   188788      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/sr_MASCULINE.pak
   188789      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/sr_NEUTER.pak
   188790    625 -rw-r--r--   1 root     root        639419 Feb 20  2026 /opt/google/chrome/locales/sv.pak
   188791      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/sv_FEMININE.pak
   188792      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/sv_MASCULINE.pak
   188793      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/sv_NEUTER.pak
   188794    661 -rw-r--r--   1 root     root        676047 Feb 20  2026 /opt/google/chrome/locales/sw.pak
   188795      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/sw_FEMININE.pak
   188796      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/sw_MASCULINE.pak
   188797      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/sw_NEUTER.pak
   188798   1703 -rw-r--r--   1 root     root       1743052 Feb 20  2026 /opt/google/chrome/locales/ta.pak
   188799      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ta_FEMININE.pak
   188800      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ta_MASCULINE.pak
   188801      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ta_NEUTER.pak
   188802   1567 -rw-r--r--   1 root     root       1604447 Feb 20  2026 /opt/google/chrome/locales/te.pak
   188803      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/te_FEMININE.pak
   188804      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/te_MASCULINE.pak
   188805      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/te_NEUTER.pak
   188806   1318 -rw-r--r--   1 root     root       1348859 Feb 20  2026 /opt/google/chrome/locales/th.pak
   188807      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/th_FEMININE.pak
   188808      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/th_MASCULINE.pak
   188809      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/th_NEUTER.pak
   188810    673 -rw-r--r--   1 root     root        688201 Feb 20  2026 /opt/google/chrome/locales/tr.pak
   188811      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/tr_FEMININE.pak
   188812      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/tr_MASCULINE.pak
   188813      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/tr_NEUTER.pak
   188814   1168 -rw-r--r--   1 root     root       1195042 Feb 20  2026 /opt/google/chrome/locales/uk.pak
   188815      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/uk_FEMININE.pak
   188816      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/uk_MASCULINE.pak
   188817      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/uk_NEUTER.pak
   188818   1007 -rw-r--r--   1 root     root       1030740 Feb 20  2026 /opt/google/chrome/locales/ur.pak
   188819      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ur_FEMININE.pak
   188820      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ur_MASCULINE.pak
   188821      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/ur_NEUTER.pak
   188822    801 -rw-r--r--   1 root     root        819380 Feb 20  2026 /opt/google/chrome/locales/vi.pak
   188823      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/vi_FEMININE.pak
   188824      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/vi_MASCULINE.pak
   188825      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/vi_NEUTER.pak
   188826    574 -rw-r--r--   1 root     root        587350 Feb 20  2026 /opt/google/chrome/locales/zh-CN.pak
   188827      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/zh-CN_FEMININE.pak
   188828      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/zh-CN_MASCULINE.pak
   188829      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/zh-CN_NEUTER.pak
   188830    569 -rw-r--r--   1 root     root        581746 Feb 20  2026 /opt/google/chrome/locales/zh-TW.pak
   188831      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/zh-TW_FEMININE.pak
   188832      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/zh-TW_MASCULINE.pak
   188833      1 -rw-r--r--   1 root     root            18 Feb 20  2026 /opt/google/chrome/locales/zh-TW_NEUTER.pak
   188857     11 -rw-r--r--   1 root     root         10577 Feb 20  2026 /opt/google/chrome/product_logo_128.png
   188858      1 -rw-r--r--   1 root     root           787 Feb 20  2026 /opt/google/chrome/product_logo_16.png
   188859      2 -rw-r--r--   1 root     root          1281 Feb 20  2026 /opt/google/chrome/product_logo_24.png
   188860     38 -rw-r--r--   1 root     root         38037 Feb 20  2026 /opt/google/chrome/product_logo_256.png
   188861      2 -rw-r--r--   1 root     root          1810 Feb 20  2026 /opt/google/chrome/product_logo_32.png
   188862      4 -rw-r--r--   1 root     root          3095 Feb 20  2026 /opt/google/chrome/product_logo_48.png
   188863      5 -rw-r--r--   1 root     root          4557 Feb 20  2026 /opt/google/chrome/product_logo_64.png
   188864  13155 -rw-r--r--   1 root     root      13470180 Feb 20  2026 /opt/google/chrome/resources.pak
   188865    698 -rw-r--r--   1 root     root        714384 Feb 20  2026 /opt/google/chrome/v8_context_snapshot.bin
   188866      1 -rw-r--r--   1 root     root           107 Feb 20  2026 /opt/google/chrome/vk_swiftshader_icd.json
   188867     37 -rwxr-xr-x   1 root     root         37394 Feb 20  2026 /opt/google/chrome/xdg-mime
   188868     33 -rwxr-xr-x   1 root     root         33273 Feb 20  2026 /opt/google/chrome/xdg-settings
```

3. Process hierarchy: pstree -apnh (or ps auxf if pstree unavailable)
```
[1msystemd,1[0m
  |-systemd-journal,439
  |-systemd-udevd,790
  |-dbus-daemon,833 --system --address=systemd: --nofork --nopidfile --systemd-activation --syslog-only
  |-systemd-logind,841
  |-agetty,844 -o -p -- \\u --noclear - linux
  |-agetty,845 -o -p -- \\u --keep-baud 115200,57600,38400,9600 - vt220
  |-containerd,872
  |   |-{containerd},879
  |   |-{containerd},880
  |   |-{containerd},881
  |   |-{containerd},882
  |   |-{containerd},883
  |   |-{containerd},884
  |   |-{containerd},909
  |   `-{containerd},912
  |-sshd,874
  |   |-sshd,877
  |   |   `-sshd,907
  |   `-sshd,918
  |       `-sshd,929
  |           `-bash,6351 -c...
  |               |-inotifywait,6356 -e create,moved_to --include /stamp$ /run/devbox-session/default
  |               `-bash,6357 -c...
  |                   `-tail,6361 --pid 2349 -f /dev/null
  |-socat,876 -d VSOCK-LISTEN:22,fork TCP4:127.0.0.1:22
  |-systemd,887 --user
  |   `-(sd-pam),888
  |-dockerd,911 -H fd:// --containerd=/run/containerd/containerd.sock
  |   |-{dockerd},944
  |   |-{dockerd},945
  |   |-{dockerd},946
  |   |-{dockerd},947
  |   |-{dockerd},954
  |   |-{dockerd},1251
  |   |-{dockerd},1265
  |   |-{dockerd},1277
  |   `-{dockerd},1443
  `-[1mtmux: server,2348[0m new-session -d -s default -c /app -e JULES_SESSION_ID=13437284186659263797 -e GIT_TERMINAL_PROMPT=0
      `-[1mbash,2349[0m
          `-[1mbash,6373[0m run_checks.sh
              `-[1mpstree,6376[0m -apnh
```

4. VSOCK service definition: cat /etc/systemd/system/devbox-ssh-over-vsock.service (or systemctl cat devbox-ssh-over-vsock.service)
```
# Forwards VSOCK:22 to localhost:22
#
# For systemd > 256 there is also a systemd-ssh-generator(8) that can configure
# sshd over vsock. We use a somewhat old ubuntu for guest that has systemd 255.
# So the approach here is slightly more portable. Revisit this in a few years.
#
# c.f. https://libvirt.org/ssh-proxy.html#guest-os-requirements
[Unit]
After=sshd.service

[Service]
Type=simple
ExecStart=/usr/bin/socat -d VSOCK-LISTEN:22,fork TCP4:127.0.0.1:22
Restart=always

[Install]
WantedBy=multi-user.target

```

5. User profile: ls -la /home/jules; ls -la /home/jules/.config 2>/dev/null || true
```
total 26
drwxr-x---  1 jules jules 4096 Oct  5 18:29 .
drwxr-xr-x  1 root  root  4096 Mar  4  2026 ..
drwxr-xr-x  3 jules jules   28 Mar  6  2026 .android
-rw-r--r--  1 jules jules  220 Mar 31  2024 .bash_logout
-rw-r--r--  1 jules jules 3792 Mar  6  2026 .bashrc
drwxr-xr-x  1 jules jules 4096 Mar  6  2026 .cache
drwxr-xr-x  4 jules jules   37 Mar  6  2026 .cargo
drwxr-xr-x  7 jules jules  109 Mar  6  2026 .conan2
drwxr-xr-x  4 jules jules   40 Mar  6  2026 .config
-rw-rw-r--  1 jules jules  135 Oct  5 18:29 .gitconfig
drwxr-xr-x  4 jules jules   50 Mar  6  2026 .gradle
drwxr-xr-x  5 jules jules   52 Mar  6  2026 .local
drwxr-xr-x  5 jules jules   81 Mar  6  2026 .npm
drwxr-xr-x 32 jules jules  571 Mar  6  2026 .nvm
-rw-r--r--  1 jules jules 1522 Mar  6  2026 .profile
drwxr-xr-x  1 jules jules 4096 Mar  6  2026 .pyenv
drwxr-xr-x  7 jules jules  103 Mar  6  2026 .rustup
drwx------  3 jules jules   38 Mar  4  2026 .ssh
-rw-r--r--  1 jules jules    0 Mar  4  2026 .sudo_as_admin_successful
total 4
drwxr-xr-x 4 jules jules   40 Mar  6  2026 .
drwxr-x--- 1 jules jules 4096 Oct  5 18:29 ..
drwxr-xr-x 3 jules jules   33 Mar  6  2026 flutter
drwxr-xr-x 3 jules jules   32 Mar  6  2026 go
```
