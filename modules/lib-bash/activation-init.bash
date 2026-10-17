function setupVars() {
  declare -r stateHome="$PROJECT_ROOT/.local/state"
  declare -r userNixStateDir="$stateHome/nix"
  declare -r pmGcrootsDir="$stateHome/project-manager/gcroots"

  mkdir -p "$userNixStateDir/profiles"
  declare -r profilesDir="$userNixStateDir/profiles"

  declare -gr genProfilePath="$profilesDir/project-manager"
  declare -gr newGenPath="@GENERATION_DIR@"
  declare -gr newGenGcPath="$pmGcrootsDir/current-project"

  if [[ -e $genProfilePath ]]; then
    declare -g oldGenNum oldGenPath
    oldGenNum="$(pm_generationNumber "$genProfilePath")"
    oldGenPath="$(readlink -e "$genProfilePath")"
  elif [[ -L $genProfilePath ]]; then
    _iWarn "The profile at ‘%s’ points at a generation that no longer exists, so there is no previous generation to compare against." "$genProfilePath"
  fi
}

function checkProjectDirectory() {
  local expectedProject
  expectedProject=$(readlink --canonicalize-missing "$1")

  if ! [[ $PROJECT_ROOT -ef $expectedProject ]]; then
    _iError 'Error: PROJECT_ROOT is set to "%s" but we expect "%s"' "$PROJECT_ROOT" "$expectedProject"
    exit 1
  fi
}

pm_setVerboseAndDryRun

_i "Starting Project Manager activation"

# Verify that we can connect to the Nix store and/or daemon. This will
# also create the necessary directories in profiles and gcroots.
"${VERBOSE_RUN[@]}" _i "Validating Nix installation"
nix-build --expr '{}' --no-out-link --quiet

setupVars

if [[ -v VERBOSE ]]; then
  _i 'Using Nix version: %s' "$(nix --version)"
fi

"${VERBOSE_RUN[@]}" _i "Activation variables:"
if [[ -v oldGenNum ]]; then
  "${VERBOSE_ECHO}" "  oldGenNum=$oldGenNum"
  "${VERBOSE_ECHO}" "  oldGenPath=$oldGenPath"
else
  "${VERBOSE_ECHO}" "  oldGenNum undefined (first run?)"
  "${VERBOSE_ECHO}" "  oldGenPath undefined (first run?)"
fi
"${VERBOSE_ECHO}" "  newGenPath=$newGenPath"
"${VERBOSE_ECHO}" "  genProfilePath=$genProfilePath"
"${VERBOSE_ECHO}" "  newGenGcPath=$newGenGcPath"
