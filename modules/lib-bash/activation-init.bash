function setupVars() {
  declare -r stateHome="${XDG_STATE_HOME:-$HOME/.local/state}"
  declare -r userNixStateDir="$stateHome/nix"
  declare -r pmGcrootsDir="$stateHome/project-manager/gcroots"

  declare -r globalNixStateDir="${NIX_STATE_DIR:-/nix/var/nix}"
  declare -r globalProfilesDir="$globalNixStateDir/profiles/per-user"

  # If the user Nix profiles path exists, then place the PM profile there.
  # Otherwise, if the global Nix per-user state directory exists then use
  # that. If neither exists, then we give up.
  #
  # shellcheck disable=2174
  if [[ -d $userNixStateDir/profiles ]]; then
    declare -r profilesDir="$userNixStateDir/profiles"
  elif [[ -v USER && -d $globalProfilesDir/$USER ]]; then
    declare -r profilesDir="$globalProfilesDir/$USER"
  else
    _iError 'Could not find suitable profile directory, tried %s and %s' \
      "$userNixStateDir/profiles" "$globalProfilesDir" >&2
    exit 1
  fi

  mkdir -p "$profilesDir/project-manager"
  declare -gr genProfilePath="$profilesDir/project-manager/@PROJECT_NAME@"
  declare -gr newGenPath="@GENERATION_DIR@"
  declare -gr newGenGcPath="$pmGcrootsDir/current-project"

  declare greatestGenNum
  greatestGenNum=$(
    nix-env --list-generations --profile "$genProfilePath" \
      | tail -1 \
      | sed -E 's/ *([[:digit:]]+) .*/\1/'
  )

  if [[ -n $greatestGenNum ]]; then
    declare -gr oldGenNum=$greatestGenNum
    declare -gr newGenNum=$((oldGenNum + 1))
  else
    declare -gr newGenNum=1
  fi

  if [[ -e $genProfilePath ]]; then
    declare -g oldGenPath
    oldGenPath="$(readlink -e "$genProfilePath")"
  fi

  $VERBOSE_RUN _i "Sanity checking oldGenNum and oldGenPath"
  if [[ -v oldGenNum && ! -v oldGenPath ||
    ! -v oldGenNum && -v oldGenPath ]]; then
    _i $'The previous generation number and path are in conflict! These\nmust be either both empty or both set but are now set to\n\n    \'%s\' and \'%s\'\n\nIf you don\'t mind losing previous profile generations then\nthe easiest solution is probably to run\n\n   rm %s/project-manager*\n   rm %s/current-project\n\nand trying project-manager switch again. Good luck!' \
      "${oldGenNum-}" "${oldGenPath-}" \
      "$profilesDir" "$pmGcrootsDir"
    exit 1
  fi
}

function checkProjectDirectory() {
  local expectedProject="$1"

  if ! [[ $PROJECT_ROOT -ef $expectedProject ]]; then
    _iError 'Error: PROJECT_ROOT is set to "%s" but we expect "%s"' "$PROJECT_ROOT" "$expectedProject"
    exit 1
  fi
}

if [[ -v VERBOSE ]]; then
  export VERBOSE_ECHO=echo
  export VERBOSE_ARG="--verbose"
  export VERBOSE_RUN=""
else
  export VERBOSE_ECHO=true
  export VERBOSE_ARG=""
  export VERBOSE_RUN=true
fi

_i "Starting Project Manager activation"

# Verify that we can connect to the Nix store and/or daemon. This will
# also create the necessary directories in profiles and gcroots.
$VERBOSE_RUN _i "Sanity checking Nix"
nix-build --expr '{}' --no-out-link

# Also make sure that the Nix profiles path is created.
nix-env -q > /dev/null 2>&1 || true

setupVars

if [[ -v DRY_RUN ]]; then
  _i "This is a dry run"
  export DRY_RUN_CMD=echo
  export DRY_RUN_NULL=/dev/stdout
else
  $VERBOSE_RUN _i "This is a live run"
  export DRY_RUN_CMD=""
  export DRY_RUN_NULL=/dev/null
fi

if [[ -v VERBOSE ]]; then
  _i 'Using Nix version: %s' "$(nix-env --version)"
fi

$VERBOSE_RUN _i "Activation variables:"
if [[ -v oldGenNum ]]; then
  $VERBOSE_ECHO "  oldGenNum=$oldGenNum"
  $VERBOSE_ECHO "  oldGenPath=$oldGenPath"
else
  $VERBOSE_ECHO "  oldGenNum undefined (first run?)"
  $VERBOSE_ECHO "  oldGenPath undefined (first run?)"
fi
$VERBOSE_ECHO "  newGenPath=$newGenPath"
$VERBOSE_ECHO "  newGenNum=$newGenNum"
$VERBOSE_ECHO "  genProfilePath=$genProfilePath"
$VERBOSE_ECHO "  newGenGcPath=$newGenGcPath"
