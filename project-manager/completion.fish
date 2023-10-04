#!/bin/env fish
##################################################

# « project-manager » command-line fish completion
#
# © 2021 "Ariel AxionL" <i at axionl dot me>
#
# MIT License
#

##################################################

### Functions
function __project_manager_generations --description "Get all generations"
    for i in (project-manager generations)
        set -l split (string split " " $i)
        set -l gen_id $split[5]
        set -l gen_datetime $split[1..2]
        set -l gen_hash (string match -r '\w{32}' $i)
        echo $gen_id\t$gen_datetime $gen_hash
    end
end


### SubCommands
complete -c project-manager -n "__fish_use_subcommand" -f -a "help" -d "Print project-manager help"
complete -c project-manager -n "__fish_use_subcommand" -f -a "edit" -d "Open the project configuration in $EDITOR"
complete -c project-manager -n "__fish_use_subcommand" -f -a "build" -d "Build configuration into result directory"
complete -c project-manager -n "__fish_use_subcommand" -f -a "switch" -d "Build and activate configuration"
complete -c project-manager -n "__fish_use_subcommand" -f -a "generations" -d "List all project environment generations"
complete -c project-manager -n "__fish_use_subcommand" -f -a "packages" -d "List all packages installed in project-manager-path"
complete -c project-manager -n "__fish_use_subcommand" -f -a "news" -d "Show news entries in a pager"
complete -c project-manager -n "__fish_use_subcommand" -f -a "uninstall" -d "Remove Project Manager"

complete -c project-manager -n "__fish_use_subcommand" -x -a "remove-generations" -d "Remove indicated generations"
complete -c project-manager -n "__fish_seen_subcommand_from remove-generations" -f -ka '(__project_manager_generations)'

complete -c project-manager -n "__fish_use_subcommand" -x -a "expire-generations" -d "Remove generations older than TIMESTAMP"

### Options
complete -c project-manager -F -s f -l "file" -d "The project configuration file"
complete -c project-manager -F -s I -d "Add a path to the Nix expression search path"
complete -c project-manager -F -l "flake" -d "Use Project Manager configuration at specified flake-uri"
complete -c project-manager -f -s v -l "verbose" -d "Verbose output"
complete -c project-manager -f -s n -l "dry-run" -d "Do a dry run, only prints what actions would be taken"
complete -c project-manager -f -s h -l "help" -d "Print this help"
complete -c project-manager -f -s h -l "version" -d "Print the Project Manager version"

complete -c project-manager -x -l "arg" -d "Override inputs passed to project-manager.nix"
complete -c project-manager -x -l "argstr" -d "Like --arg but the value is a string"
complete -c project-manager -x -l "cores" -d "Threads per job (e.g. -j argument to make)"
complete -c project-manager -x -l "debug"
complete -c project-manager -x -l "impure"
complete -c project-manager -f -l "keep-failed" -d "Keep temporary directory used by failed builds"
complete -c project-manager -f -l "keep-going" -d "Keep going in case of failed builds"
complete -c project-manager -x -s j -l "max-jobs" -d "Max number of build jobs in parallel"
complete -c project-manager -x -l "option" -d "Set Nix configuration option"
complete -c project-manager -x -l "builders" -d "Remote builders"
complete -c project-manager -f -s L -l "print-build-logs" -d "Print full build logs on standard error"
complete -c project-manager -f -l "show-trace" -d "Print stack trace of evaluation errors"
complete -c project-manager -f -l "substitute"
complete -c project-manager -f -l "no-substitute"
complete -c project-manager -f -l "no-out-link"
complete -c project-manager -f -l "update-input"
complete -c project-manager -f -l "override-input"
complete -c project-manager -f -l "experimental-features"
complete -c project-manager -f -l "extra-experimental-features"
complete -c project-manager -f -l "refresh" -d "Consider all previously downloaded files out-of-date"
