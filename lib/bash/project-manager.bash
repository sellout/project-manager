# This file contains a number of utilities for use by the project-manager tool and
# the generated Project Manager activation scripts. No guarantee is made about
# backwards or forward compatibility.

# Sets up colors suitable for the `errorEcho`, `warnEcho`, and `noteEcho`
# functions.
#
# The check for terminal output and color support is heavily inspired by
# https://unix.stackexchange.com/a/10065.
#
# The setup respects the `NO_COLOR` environment variable.
function setupColors() {
  normalColor=""
  errorColor=""
  warnColor=""
  noteColor=""

  # Enable colors for terminals, and allow opting out.
  if [[ ! -v NO_COLOR && -t 1 ]]; then
    # See if it supports colors.
    local ncolors
    ncolors=$(tput colors 2> /dev/null || echo 0)

    if [[ -n $ncolors && $ncolors -ge 8 ]]; then
      normalColor="$(tput sgr0)"
      errorColor="$(tput bold)$(tput setaf 1)"
      warnColor="$(tput setaf 3)"
      noteColor="$(tput bold)$(tput setaf 6)"
    fi
  fi
}

setupColors

function errorEcho() {
  echo "${errorColor}$*${normalColor}"
}

function warnEcho() {
  echo "${warnColor}$*${normalColor}"
}

function noteEcho() {
  echo "${noteColor}$*${normalColor}"
}

function _i() {
  local msgid="$1"
  shift

  # shellcheck disable=2059
  printf "$(gettext "$msgid")\n" "$@"
}

function _ip() {
  local msgid="$1"
  local msgidPlural="$2"
  local count="$3"
  shift 3

  # shellcheck disable=2059
  printf "$(ngettext "$msgid" "$msgidPlural" "$count")\n" "$@"
}

function _iError() {
  echo -n "${errorColor}"
  _i "$@"
  echo -n "${normalColor}"
}

function _iWarn() {
  echo -n "${warnColor}"
  _i "$@"
  echo -n "${normalColor}"
}

function _iNote() {
  echo -n "${noteColor}"
  _i "$@"
  echo -n "${normalColor}"
}

## Project Manager logic

function pm_listPackagesBySuffix() {
  # We attempt to use `--json` first (added in Nix 2.17). Otherwise
  # attempt to parse the legacy output format.
  {
    nix profile list --profile "$1" --json 2>/dev/null \
      | jq --raw-output --arg name "$2" '.elements[].storePaths[] | select(endswith($name))'
  } || {
    nix profile list --profile $1 \
      | { grep "$2\$" || test $? = 1; } \
      | cut -d ' ' -f 4
  }
}

function pm_removePackagesBySuffix() {
  pm_listPackagesBySuffix "$1" "$2" \
    | xargs $VERBOSE_ARG $DRY_RUN_CMD nix profile remove $VERBOSE_ARG --profile "$1"
}

function setNixProfileCommands() {
  LIST_OUTPATH_CMD="nix profile list"
  REMOVE_CMD="pm_removePackagesBySuffix"
}

function setVerboseAndDryRun() {
  if [[ -v VERBOSE ]]; then
    export VERBOSE_ARG="--verbose"
  else
    export VERBOSE_ARG=""
  fi

  if [[ -v DRY_RUN ]]; then
    export DRY_RUN_CMD=echo
  else
    export DRY_RUN_CMD=""
  fi
}

function setWorkDir() {
  if [[ ! -v WORK_DIR ]]; then
    WORK_DIR="$(mktemp --tmpdir -d project-manager-build.XXXXXXXXXX)"
    # shellcheck disable=2064
    trap "rm -r '$WORK_DIR'" EXIT
  fi
}

# Checks whether the 'flakes' and 'nix-command' Nix options are enabled.
function hasFlakeSupport() {
  type -p nix > /dev/null \
    && nix show-config 2> /dev/null \
    | grep experimental-features \
      | grep flakes \
      | grep -q nix-command
}

# Attempts to set the PROJECT_MANAGER_CONFIG global variable.
#
# If no configuration file can be found then this function will print
# an error message and exit with an error code.
function setConfigFile() {
  if [[ -v PROJECT_MANAGER_CONFIG ]]; then
    if [[ -e $PROJECT_MANAGER_CONFIG ]]; then
      PROJECT_MANAGER_CONFIG="$(realpath "$PROJECT_MANAGER_CONFIG")"
    else
      _i 'No configuration file found at %s' \
        "$PROJECT_MANAGER_CONFIG" >&2
      exit 1
    fi
  elif [[ ! -v PROJECT_MANAGER_CONFIG ]]; then
    local configHome="${PROJECT_ROOT}/.config"
    local pmConfigHome="$configHome/project"
    local defaultConfFile="$pmConfigHome/default.nix"
    local configFile

    if [[ -e $defaultConfFile ]]; then
      configFile="$defaultConfFile"
    fi

    if [[ -v configFile ]]; then
      PROJECT_MANAGER_CONFIG="$(realpath "$configFile")"
    else
      _i 'No configuration file found. Please create one at %s' \
        "$defaultConfFile" >&2
      exit 1
    fi
  fi
}

# Sets some useful Project Manager related paths as global read-only variables.
function setProjectManagerPathVariables() {
  # If called twice then just exit early.
  if [[ -v PM_DATA_HOME ]]; then
    return
  fi

  declare -r stateHome="$PROJECT_ROOT/.local/state"
  declare -r userNixStateDir="$stateHome/nix"

  declare -gr PM_DATA_HOME="$PROJECT_ROOT/.local/share/project-manager"
  declare -gr PM_STATE_DIR="$stateHome/project-manager"

  mkdir -p "$userNixStateDir/profiles"
  declare -gr PM_PROFILE_DIR="$userNixStateDir/profiles"
}

function setFlakeAttribute() {
  local flake="."
  local name
  name="$(nix eval --expr 'builtins.currentSystem' --impure --raw)"
  export FLAKE_CONFIG_URI="$flake#projectConfigurations.$name"
}

function pm_init() {
  # The directory where we should place the initial configuration.
  local confDir

  # Whether we should immediate activate the configuration.
  local switch

  # Whether we should create a flake file.
  local withFlake

  if hasFlakeSupport; then
    withFlake=1
  fi

  while (($# > 0)); do
    local opt="$1"
    shift

    case $opt in
      --no-flake)
        unset withFlake
        ;;
      --switch)
        switch=1
        ;;
      -*)
        _iError "%s: unknown option '%s'" "$0" "$opt" >&2
        exit 1
        ;;
      *)
        if [[ -v confDir ]]; then
          _i "Run '%s --help' for usage help" "$0" >&2
          exit 1
        else
          confDir="$opt"
        fi
        ;;
    esac
  done

  if [[ ! -v confDir ]]; then
    confDir="${PROJECT_ROOT}/.config/project"
  fi

  if [[ ! -e $confDir ]]; then
    mkdir -p "$confDir"
  fi

  if [[ ! -d $confDir ]]; then
    _iError "%s: unknown option '%s'" "$0" "$opt" >&2
    exit 1
  fi

  local confFile="$confDir/default.nix"
  local flakeFile="${PROJECT_ROOT}/flake.nix"

  if [[ -e $confFile ]]; then
    _i 'The file %s already exists, leaving it unchanged...' "$confFile"
  else
    _i 'Creating %s...' "$confFile"

    mkdir -p "$confDir"
    cat > "$confFile" << EOF
{ config, pkgs, ... }:

{
  # This value determines the Project Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Project Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Project Manager. If you do
  # want to update the value, then make sure to first check the Project Manager
  # release notes.
  project.stateVersion = 0; # Please read the comment before changing.

  # The project.devPackages option allows you to install Nix packages into your
  # environment.
  project.devPackages = [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, \${config.project.username}!"
    # '')
  ];

  # Project Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'project.file'.
  project.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/pm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/$USER/etc/profile.d/pm-session-vars.sh
  #
  # if you don't want to manage your shell through Project Manager.
  project.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Let Project Manager install and manage itself.
  programs.project-manager.enable = true;
}
EOF
  fi

  if [[ ! -v withFlake ]]; then
    PROJECT_MANAGER_CONFIG="$confFile"
  else
    if [[ -e $flakeFile ]]; then
      _i 'The file %s already exists, leaving it unchanged...' "$flakeFile"
    else
      _i 'Creating %s...' "$flakeFile"

      local nixSystem
      nixSystem=$(nix eval --expr builtins.currentSystem --raw --impure)

      mkdir -p "$confDir"
      cat > "$flakeFile" << EOF
{
  description = "Project Manager configuration for $(basename "$PWD")";

  inputs = {
    # Specify the source of Project Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    project-manager = {
      url = "github:nix-community/project-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, project-manager, ... }:
    let
      system = "$nixSystem";
      pkgs = nixpkgs.legacyPackages.\${system};
    in {
      projectConfigurations.\${system} = project-manager.lib.projectManagerConfiguration {
        inherit pkgs;

        # Specify your project configuration modules here, for example,
        # the path to your project.nix.
        modules = [ ./project.nix ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to project.nix
      };
    };
}
EOF
    fi
  fi

  if [[ -v switch ]]; then
    echo
    _i "Creating initial Project Manager generation..."
    echo

    if pm_switch; then
      # translators: The "%s" specifier will be replaced by a file path.
      _i $'All done! The project-manager tool should now be installed and you can edit\n\n    %s\n\nto configure Project Manager. Run \'man project-configuration.nix\' to\nsee all available options.' \
        "$confFile"
      exit 0
    else
      # translators: The "%s" specifier will be replaced by a URL.
      _i $'Uh oh, the installation failed! Please create an issue at\n\n    %s\n\nif the error seems to be the fault of Project Manager.' \
        "https://github.com/nix-community/project-manager/issues"
      exit 1
    fi
  fi
}

function pm_buildFlake() {
  local extraArgs=("$@")

  if [[ -v VERBOSE ]]; then
    extraArgs=("${extraArgs[@]}" "--verbose")
  fi

  nix build \
    "${extraArgs[@]}" \
    "${PASSTHROUGH_OPTS[@]}"
}

# Presents news to the user as specified by the `news.display` option.
function presentNews() {
  local newsNixFile="$WORK_DIR/news.nix"
  pm_buildNews "$newsNixFile"

  local newsDisplay
  newsDisplay="$(nix-instantiate --eval --expr "(import ${newsNixFile}).meta.display" | xargs)"

  local newsNumUnread
  newsNumUnread="$(nix-instantiate --eval --expr "(import ${newsNixFile}).meta.numUnread" | xargs)"

  # shellcheck disable=2154
  if [[ $newsNumUnread -eq 0 ]]; then
    return
  elif [[ $newsDisplay == "silent" ]]; then
    return
  elif [[ $newsDisplay == "notify" ]]; then
    local cmd msg
    cmd="$(basename "$0")"
    msg="$(_ip \
      $'There is %d unread and relevant news item.\nRead it by running the command "%s news".' \
      $'There are %d unread and relevant news items.\nRead them by running the command "%s news".' \
      "$newsNumUnread" "$newsNumUnread" "$cmd")"

    # Not actually an error but here stdout is reserved for
    # nix-build output.
    echo $'\n'"$msg"$'\n' >&2

    if [[ -v DISPLAY ]] && type -P notify-send > /dev/null; then
      notify-send "Project Manager" "$msg" > /dev/null 2>&1 || true
    fi
  elif [[ $newsDisplay == "show" ]]; then
    pm_showNews --unread
  else
    _i 'Unknown "news.display" setting "%s".' "$newsDisplay" >&2
  fi
}

function pm_edit() {
  if [[ ! -v EDITOR || -z $EDITOR ]]; then
    # shellcheck disable=2016
    _i 'Please set the $EDITOR environment variable' >&2
    return 1
  fi

  setConfigFile

  # Don't quote $EDITOR in order to support values including options, e.g.,
  # "code --wait".
  #
  # shellcheck disable=2086
  exec $EDITOR "$PROJECT_MANAGER_CONFIG"
}

function pm_build() {
  if [[ ! -w . ]]; then
    _i 'Cannot run build in read-only directory' >&2
    return 1
  fi

  setWorkDir

  setFlakeAttribute
  pm_buildFlake \
    "$FLAKE_CONFIG_URI.packages.activation" \
    ${DRY_RUN+--dry-run} \
    ${NO_OUT_LINK+--no-link} \
    ${PRINT_BUILD_LOGS+--print-build-logs} \
    || return

  # presentNews
}

function pm_switch() {
  setFlakeAttribute
  nix run \
    "$FLAKE_CONFIG_URI.packages.activation" \
    ${PRINT_BUILD_LOGS+--print-build-logs} \
    ${VERBOSE+--verbose} \
    "${PASSTHROUGH_OPTS[@]}" \
    || return

  # presentNews
}

function pm_listGenerations() {
  setProjectManagerPathVariables

  # Whether to colorize the generations output.
  local color="never"
  if [[ ! -v NO_COLOR && -t 1 ]]; then
    color="always"
  fi

  pushd "$PM_PROFILE_DIR" > /dev/null || exit
  # shellcheck disable=2012
  ls --color=$color -gG --time-style=long-iso --sort time project-manager-*-link \
    | cut -d' ' -f 4- \
    | sed -E 's/project-manager-([[:digit:]]*)-link/: id \1/'
  popd > /dev/null || exit
}

# Removes linked generations. Takes as arguments identifiers of
# generations to remove.
function pm_removeGenerations() {
  setProjectManagerPathVariables
  setVerboseAndDryRun

  pushd "$PM_PROFILE_DIR" > /dev/null || exit

  for generationId in "$@"; do
    local linkName="project-manager-$generationId-link"

    if [[ ! -e $linkName ]]; then
      _i 'No generation with ID %s' "$generationId" >&2
    elif [[ $linkName == $(readlink project-manager) ]]; then
      _i 'Cannot remove the current generation %s' "$generationId" >&2
    else
      _i 'Removing generation %s' "$generationId"
      $DRY_RUN_CMD rm $VERBOSE_ARG "$linkName"
    fi
  done

  popd > /dev/null || exit
}

function pm_expireGenerations() {
  setProjectManagerPathVariables

  local generations
  generations="$(
    find "$PM_PROFILE_DIR" -name 'project-manager-*-link' -not -newermt "$1" \
      | sed 's/^.*-\([0-9]*\)-link$/\1/'
  )"

  if [[ -n $generations ]]; then
    # shellcheck disable=2086
    pm_removeGenerations $generations
  elif [[ -v VERBOSE ]]; then
    _i "No generations to expire"
  fi
}

function pm_listPackages() {
  setNixProfileCommands
  local outPath
  outPath="$($LIST_OUTPATH_CMD | grep -o '/.*project-manager-path$')"
  if [[ -n $outPath ]]; then
    nix-store -q --references "$outPath" | sed 's/[^-]*-//'
  else
    _i 'No project-manager packages seem to be installed.' >&2
  fi
}

function newsReadIdsFile() {
  local dataDir="${XDG_DATA_HOME:-$HOME/.local/share}/project-manager"
  local path="$dataDir/news-read-ids"

  # If the path doesn't exist then we should create it, otherwise
  # Nix will error out when we attempt to use builtins.readFile.
  if [[ ! -f $path ]]; then
    mkdir -p "$dataDir"
    touch "$path"
  fi

  echo "$path"
}

# Builds the Project Manager news data file.
#
# Note, we suppress build output to remove unnecessary verbosity. We
# put the output in the work directory to avoid the risk of an
# unfortunately timed GC removing it.
function pm_buildNews() {
  local newsNixFile="$1"
  local newsJsonFile="$WORK_DIR/news.json"

  # TODO: Use check=false to make it more likely that the build succeeds.
  pm_buildFlake \
    "$FLAKE_CONFIG_URI.config.news.json.output" \
    --quiet \
    --out-link "$newsJsonFile" \
    || return

  local extraArgs=()

  for p in "${EXTRA_NIX_PATH[@]}"; do
    extraArgs=("${extraArgs[@]}" "-I" "$p")
  done

  local readIdsFile
  readIdsFile=$(newsReadIdsFile)

  # nix-instantiate \
  #     --no-build-output --strict \
  #     --eval '<project-manager/project-manager/build-news.nix>' \
  #     --arg newsJsonFile "$newsJsonFile" \
  #     --arg newsReadIdsFile "$readIdsFile" \
  #     "${extraArgs[@]}" \
  #     > "$newsNixFile"
}

function pm_showNews() {
  setWorkDir
  setFlakeAttribute

  local newsNixFile="$WORK_DIR/news.nix"
  pm_buildNews "$newsNixFile"

  local readIdsFile
  readIdsFile=$(newsReadIdsFile)

  local news

  # shellcheck disable=2154,2046
  case $1 in
    --all)
      news="$(nix-instantiate --quiet --eval --expr "(import ${newsNixFile}).news.all")"
      ;;
    --unread)
      news="$(nix-instantiate --quiet --eval --expr "(import ${newsNixFile}).news.unread")"
      ;;
    *)
      _i 'Unknown argument %s' "$1"
      return 1
      ;;
  esac

  # Prints the news without surrounding quotes.
  echo -e "${news:1:-1}" | ${PAGER:-less}

  local allIds
  allIds="$(nix-instantiate --quiet --eval --expr "(import ${newsNixFile}).meta.ids")"
  allIds="${allIds:1:-1}" # Trim surrounding quotes.

  local readIdsFileNew="$WORK_DIR/news-read-ids.new"
  {
    cat "$readIdsFile"
    echo -e "$allIds"
  } | sort | uniq > "$readIdsFileNew"

  mv -f "$readIdsFileNew" "$readIdsFile"
}

function pm_uninstall() {
  setVerboseAndDryRun
  setNixProfileCommands

  _i 'This will remove Project Manager from your system.'

  if [[ -v DRY_RUN ]]; then
    _i 'This is a dry run, nothing will actually be uninstalled.'
  fi

  local confirmation
  read -r -n 1 -p "$(_i 'Really uninstall Project Manager?') [y/n] " confirmation
  echo

  # shellcheck disable=2086
  case $confirmation in
    y | Y)
      _i "Switching to empty Project Manager configuration..."
      PROJECT_MANAGER_CONFIG="$(mktemp --tmpdir project-manager.XXXXXXXXXX)"
      echo "{ lib, ... }: {" > "$PROJECT_MANAGER_CONFIG"
      echo "  project.file = lib.mkForce {};" >> "$PROJECT_MANAGER_CONFIG"
      echo '  project.stateVersion = 0;' >> "$PROJECT_MANAGER_CONFIG"
      echo "  manual.manpages.enable = false;" >> "$PROJECT_MANAGER_CONFIG"
      echo "}" >> "$PROJECT_MANAGER_CONFIG"
      pm_switch
      if [[ -e $PM_PROFILE_DIR ]]; then
        $DRY_RUN_CMD $REMOVE_CMD "$PM_PROFILE_DIR/project-manager" project-manager-path || true
      fi

      rm "$PROJECT_MANAGER_CONFIG"

      if [[ -e $PM_DATA_HOME ]]; then
        $DRY_RUN_CMD rm $VERBOSE_ARG -r "$PM_DATA_HOME"
      fi

      if [[ -e $PM_STATE_DIR ]]; then
        $DRY_RUN_CMD rm $VERBOSE_ARG -r "$PM_STATE_DIR"
      fi

      if [[ -e $PM_PROFILE_DIR ]]; then
        $DRY_RUN_CMD rm $VERBOSE_ARG "$PM_PROFILE_DIR/project-manager"*
      fi
      ;;
    *)
      _i "Yay!"
      exit 0
      ;;
  esac

  _i "Project Manager is uninstalled but your project.nix is left untouched."
}
