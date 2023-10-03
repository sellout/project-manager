#!/usr/bin/env strict-bash

##################################################

# « project-manager » command-line completion
#
# © 2019 "Sam Boosalis" <samboosalis@gmail.com>
#
# MIT License
#

##################################################
# Contributing:

# Compatibility — Bash 3.
#
# OSX won't update Bash 3 (last updated circa 2009) to Bash 4,
# and we'd like this completion script to work on both Linux and Mac.
#
# For example, OSX Yosemite (released circa 2014) ships with Bash 3:
#
#  $ echo $BASH_VERSION
#  3.2
#
# While Ubuntu LTS 14.04 (a.k.a. Trusty, also released circa 2016)
# ships with the latest version, Bash 4 (updated circa 2016):
#
#  $ echo $BASH_VERSION
#  4.3
#

# Testing
#
# (1) Invoke « shellcheck »
#
#     * source: « https://github.com/koalaman/shellcheck »
#     * run:    « shellcheck ./share/bash-completion/completions/project-manager »
#
# (2) Interpret via Bash 3
#
#     * run:    « bash --noprofile --norc ./share/bash-completion/completions/project-manager »
#

##################################################
# Examples:

# $ project-manager <TAB>
#
# -A
# -I
# -f
# --file
# -h
# --help
# -n
# --dry-run
# -v
# --verbose
# build
# edit
# expire-generations
# generations
# help
# news
# option
# packages
# remove-generations
# switch
# uninstall

# $ project-manager e<TAB>
#
# edit
# expire-generations

# $ project-manager remove-generations 20<TAB>
#
# 200
# 201
# 202
# 203

##################################################
# Notes:

# « project-manager » Subcommands:
#
#   help
#   edit
#   option
#   build
#   switch
#   generations
#   remove-generations
#   expire-generations
#   packages
#   news
#   uninstall

# « project-manager » Options:
#
#   -f FILE
#   --file FILE
#   -A ATTRIBUTE
#   -I PATH
#   -v
#   --verbose
#   -n
#   --dry-run
#   -h
#   --help

# $ project-manager
#
# Usage: /project/sboo/.nix-profile/bin/project-manager [OPTION] COMMAND
#
# Options
#
#   -f FILE      The project configuration file.
#                Default is '~/.config/nixpkgs/project.nix'.
#   -A ATTRIBUTE Optional attribute that selects a configuration
#                expression in the configuration file.
#   -I PATH      Add a path to the Nix expression search path.
#   -v           Verbose output
#   -n           Do a dry run, only prints what actions would be taken
#   -h           Print this help
#
# Commands
#
#   help         Print this help
#
#   edit         Open the project configuration in $EDITOR
#
#   option OPTION.NAME
#                Inspect configuration option named OPTION.NAME.
#
#   build        Build configuration into result directory
#
#   switch       Build and activate configuration
#
#   generations  List all project environment generations
#
#   remove-generations ID...
#       Remove indicated generations. Use 'generations' command to
#       find suitable generation numbers.
#
#   expire-generations TIMESTAMP
#       Remove generations older than TIMESTAMP where TIMESTAMP is
#       interpreted as in the -d argument of the date tool. For
#       example "-30 days" or "2018-01-01".
#
#   packages     List all packages installed in project-manager-path
#
#   news         Show news entries in a pager
#
#   uninstall    Remove Project Manager
#
##################################################
# Dependencies:

command -v project-manager >/dev/null
command -v grep         >/dev/null
command -v sed          >/dev/null

##################################################
# Code:

_project-manager_list-generation-identifiers ()

{

    project-manager generations  |  sed -n -e 's/^................ : id \([[:alnum:]]\+\) -> .*/\1/p'

}

# NOTES
#
# (1) the « sed -n -e 's/.../.../p' » invocation:
#
#    * the « -e '...' » option takes a Sed Script.
#    * the « -n » option only prints when « .../p » would print.
#    * the « s/xxx/yyy/ » Sed Script substitutes « yyy » whenever « xxx » is matched.
#
# (2) the « '^................ : id \([[:alnum:]]\+\) -> .*' » regular expression:
#
#    * matches « 199 », for example, in the line « 2019-03-13 15:26 : id 199 -> /nix/store/mv619y9pzgsx3kndq0q7fjfvbqqdy5k8-project-manager-generation »
#
#

#------------------------------------------------#

# shellcheck disable=SC2120
_project-manager_list-nix-attributes ()

{
    local ProjectFile
    local ProjectAttrsString
    # local ProjectAttrsArray
    # local ProjectAttr

    if   [ -z "$1" ]
    then
        ProjectFile=$(readlink -f "$(_project-manager_get-default-project-file)")
    else
        ProjectFile="$1"
    fi

    ProjectAttrsString=$(nix-instantiate --eval -E "let project = import ${ProjectFile}; in (builtins.trace (builtins.toString (builtins.attrNames project)) null)" |& grep '^trace: ')
    ProjectAttrsString="${ProjectAttrsString#trace: }"

    echo "${ProjectAttrsString}"

    # IFS=" " read -ar ProjectAttrsArray <<< "${ProjectAttrsString}"
    #
    # local ProjectAttr
    # for ProjectAttr in "${ProjectAttrsArray[@]}"
    # do
    #     echo "${ProjectAttr}"
    # done

}

# e.g.:
#
#   $ nix-instantiate --eval -E 'let project = import /home/sboo/configuration/configs/nixpkgs/project-attrs.nix; in (builtins.trace (builtins.toString (builtins.attrNames project)) null)' 1>/dev/null
#   trace: darwin linux
#
#   $ _project-manager_list-nix-attributes
#   linux darwin
#

#------------------------------------------------#

_project-manager_get-default-project-file ()

{
    local ProjectFileDefault

    ProjectFileDefault="$(_project-manager_xdg-get-config-project)/nixpkgs/project.nix"

    echo "${ProjectFileDefault}"
}

# e.g.:
#
#   $ _project-manager_get-default-project-file
#   ~/.config/nixpkgs/project.nix
#

##################################################
# XDG-BaseDirs:

_project-manager_xdg-get-config-project () {

    echo "${XDG_CONFIG_HOME:-$HOME/.config}"

}

#------------------------------------------------#

_project-manager_xdg-get-data-home () {

    echo "${XDG_DATA_HOME:-$HOME/.local/share}"

}


#------------------------------------------------#
_project-manager_xdg-get-cache-home () {

    echo "${XDG_CACHE_HOME:-$HOME/.cache}"

}

##################################################

_hm_subcommands=( "help" "edit" "build" "init" "switch" "generations" "remove-generations" "expire-generations" "packages" "news" "uninstall" )
declare -ra _hm_subcommands

# Finds the active sub-command, if any.
_project-manager_subcommand() {
    local subcommand='' i=
    for ((i = 1; i < ${#COMP_WORDS[@]}; i++)); do
        local word="${COMP_WORDS[i]}"
        if [[ " ${_hm_subcommands[*]} " == *" ${word} "* ]]; then
            subcommand="$word"
            break
        fi
    done

    echo "$subcommand"
}

# shellcheck disable=SC2207
_project-manager_completions ()
{
    local Options
    Options=( "-f" "--file" "-A" "-I" "-h" "--help" "-n" "--dry-run" "-v" \
              "--verbose" "--cores" "--debug" "--impure" "--keep-failed" \
              "--keep-going" "-j" "--max-jobs" "--no-substitute" "--no-out-link" \
              "-L" "--print-build-logs" \
              "--show-trace" "--substitute" "--builders" "--version" \
              "--update-input" "--override-input" "--experimental-features" \
              "--extra-experimental-features" "--refresh")

    # ^ « project-manager »'s options.

    #--------------------------#

    local CurrentWord
    CurrentWord="${COMP_WORDS[$COMP_CWORD]}"

    # ^ the word currently being completed

    local PreviousWord
    if [ "$COMP_CWORD" -ge 1 ]
    then
        PreviousWord="${COMP_WORDS[COMP_CWORD-1]}"
    else
        PreviousWord=""
    fi

    # ^ the word to the left of the current word.
    #
    #   e.g. in « project-manager -v -f ./<TAB> »:
    #
    #       PreviousWord="-f"
    #       CurrentWord="./"

    local CurrentCommand
    CurrentCommand="$(_project-manager_subcommand)"

    #--------------------------#

    COMPREPLY=()

    case "$CurrentCommand" in
        "init")

            COMPREPLY+=( $( compgen -W "--switch" -- "$CurrentWord" ) )
            COMPREPLY+=( $( compgen -A directory -- "$CurrentWord") )
            ;;

        "remove-generations")

            COMPREPLY+=( $( compgen -W "$(_project-manager_list-generation-identifiers)" -- "$CurrentWord" ) )
            ;;

        *)
            case "$PreviousWord" in

                "-f"|"--file")

                    COMPREPLY+=( $( compgen -A file -- "$CurrentWord") )
                    ;;

                "-I")

                    COMPREPLY+=( $( compgen -A directory -- "$CurrentWord") )
                    ;;

                "-A")

                    # shellcheck disable=SC2119
                    COMPREPLY+=( $( compgen -W "$(_project-manager_list-nix-attributes)" -- "$CurrentWord") )
                    ;;
                *)

                    if [[ ! $CurrentCommand ]]; then
                        COMPREPLY+=( $( compgen -W "${_hm_subcommands[*]}" -- "$CurrentWord" ) )
                    fi
                    COMPREPLY+=( $( compgen -W "${Options[*]}" -- "$CurrentWord" ) )
                    ;;

            esac
            ;;
    esac

    #--------------------------#
}

##################################################

complete -F _project-manager_completions -o default project-manager

#complete -W "help edit option build switch generations remove-generations expire-generations packages news" project-manager
