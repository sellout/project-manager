{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = filterAttrs (n: f: f.enable) config.project.file;

  projectDirectory = config.project.projectDirectory;

  ## ASCII separators, so that a target containing whitespace can’t be misread
  ## as two fields.
  ##
  ## TODO: Move these to a lib module somewhere.
  fileSeparator = builtins.fromJSON ''"\u001c"'';
  groupSeparator = builtins.fromJSON ''"\u001d"'';
  recordSeparator = builtins.fromJSON ''"\u001e"'';
  unitSeparator = builtins.fromJSON ''"\u001f"'';

  ## Which generated symlinks would dangle, so the linker knows to copy
  ## instead. Same format as the persistence list, and likewise kept whole
  ## rather than appended to a line at a time.
  brokenSymlinkFile =
    pkgs.writeText "broken-symlink.ccsv"
    (concatStringsSep recordSeparator
      ([(concatStringsSep unitSeparator ["target" "broken-symlink"])]
        ++ naturalSort
        (mapAttrsToList
          (_: f: "${f.target}${unitSeparator}${toString f.broken-symlink}")
          cfg)));

  fileType =
    (import ../lib/file-type.nix {
      inherit projectDirectory lib pkgs;
      commit-by-default = config.project.commit-by-default;
    })
    .fileType;
in {
  meta.maintainers = [lib.maintainers.sellout];

  options = {
    project.file = mkOption {
      description = ''
        Attribute set of files to link into the project root.
      '';
      default = {};
      type = fileType "project.file" "" projectDirectory;
    };

    project-files = mkOption {
      type = types.package;
      internal = true;
      description = ''
        Package to contain all project files
      '';
    };

    project.persistenceFile = mkOption {
      type = types.str;
      internal = true;
      readOnly = true;
      default = "${config.xdg.dataDir}/project-manager/persistence.ccsv";
      description = ''
        Path, relative to the project root, of every file we generate and how
        each one is persisted.

        This is committed, so that a `switch` can still tell what the last one
        produced in a checkout that has no generation of its own.
      '';
    };

    project.metadataDir = mkOption {
      type = types.str;
      internal = true;
      readOnly = true;
      default = "${config.xdg.dataDir}/project-manager/metadata";
      description = ''
        Directory, relative to the project root, that a generation keeps its
        own bookkeeping in. Unlike {option}`project.persistenceFile`, nothing
        here is linked into the worktree, so it only ever exists inside the
        generation. It lives under our own directory so that it’s unlikely to
        collide with a file some other tool wants to write.
      '';
    };
  };

  config = {
    assertions = [
      (
        let
          dups =
            attrNames
            (filterAttrs (n: v: v > 1)
              (foldAttrs (acc: v: acc + v) 0
                (mapAttrsToList (n: v: {${v.target} = 1;}) cfg)));
          dupsStr = concatStringsSep ", " dups;
        in {
          assertion = dups == [];
          message = ''
            Conflicting managed target files: ${dupsStr}

            This may happen, for example, if you have a configuration similar to

                project.file = {
                  conflict1 = { source = ./foo.nix; target = "baz"; };
                  conflict2 = { source = ./bar.nix; target = "baz"; };
                }'';
        }
      )
    ];

    project.file.${config.project.persistenceFile} = {
      commit-by-default = true;
      text =
        concatStringsSep recordSeparator
        ([(concatStringsSep unitSeparator ["target" "persistence"])]
          ++ naturalSort
          (mapAttrsToList
            (_: f: "${f.target}${unitSeparator}${f.persistence}")
            cfg));
    };

    lib.file.mkOutOfStoreSymlink = path: let
      pathStr = toString path;
      name = pm.strings.storeFileName (baseNameOf pathStr);
    in
      pkgs.runCommandLocal name {} ''ln -s ${escapeShellArg pathStr} $out'';

    # This activation script will
    #
    # 1. Remove files from the old generation that are not in the new
    #    generation.
    #
    # 2. Switch over the Project Manager gcroot and current profile
    #    links.
    #
    # 3. Symlink files from the new generation into $PROJECT_ROOT.
    #
    # This order is needed to ensure that we always know which links
    # belong to which generation. Specifically, if we're moving from
    # generation A to generation B having sets of project file links FA
    # and FB, respectively then cleaning before linking produces state
    # transitions similar to
    #
    #      FA   →   FA ∩ FB   →   (FA ∩ FB) ∪ FB = FB
    #
    # and a failure during the intermediate state FA ∩ FB will not
    # result in lost links because this set of links are in both the
    # source and target generation.
    project.activation.linkGeneration = pm.dag.entryAfter ["writeBoundary"] (
      let
        link = pkgs.writeShellScript "link" ''
          ${config.lib.bash.initProjectManagerLib}

          setRunModeVariables

          ## TODO: Extract this to be used by other scripts.
          function create_reference() {
            sourcePath="$1"
            relativePath="$2"
            targetPath="$PROJECT_ROOT/$relativePath"
            if [[ -e "$targetPath" && ! -L "$targetPath" ]] && cmp -s "$sourcePath" "$targetPath" ; then
              # The target exists but is identical – don’t do anything.
              "''${VERBOSE_ECHO}" "Skipping '$relativePath' as it is identical to '$sourcePath'"
            else
              "''${DRY_RUN_CMD[@]}" mkdir -p "$(dirname "$relativePath")"
              ## Try a symlink (if allowed), then a hard link, then a copy
              ([[ ''${persistence[$relativePath]} == worktree && ! ''${broken_symlink[$relativePath]} ]] \
                  && "''${DRY_RUN_CMD[@]}" ln -Tsf "''${VERBOSE_ARG[@]}" "$sourcePath" "$targetPath") \
                || ([[ ''${persistence[$relativePath]} != store ]] \
                      && ("''${DRY_RUN_CMD[@]}" ln -Tf "''${VERBOSE_ARG[@]}" "$sourcePath" "$targetPath" 2>/dev/null \
                          || "''${DRY_RUN_CMD[@]}" cp -T --remove-destination "''${VERBOSE_ARG[@]}" "$sourcePath" "$targetPath" \
                          || ("''${VERBOSE_ECHO}" "failed to create “$targetPath”" && exit 1))) \
                || true
            fi
          }

          newGenFiles="$1"
          shift
          declare -A persistence=( )
          pm_readCcsvPairs persistence "$newGenFiles/${config.project.persistenceFile}"
          declare -A broken_symlink=( )
          pm_readCcsvPairs broken_symlink "$newGenFiles/${config.project.metadataDir}/broken-symlink.ccsv"
          for sourcePath in "$@" ; do
            targetPath="''${sourcePath#$newGenFiles/}"
            [[ $targetPath == ${config.project.metadataDir}/* ]] && continue
            create_reference "$sourcePath" "$targetPath"
          done
        '';
      in ''
        function linkNewGen() {
          _i "Creating project file links in %s" "$PROJECT_ROOT"

          local newGenFiles
          newGenFiles="$(readlink -e "$newGenPath/project-files")"
          find "$newGenFiles" \( -type f -or -type l \) \
            -exec bash ${link} "$newGenFiles" {} +
        }

        if ! pm_profileHoldsExactly "$genProfilePath" "$newGenPath" ${config.project.packages.path}; then
          ## WAIT: Before Nix 2.21 (Nixpkgs 24.11), `nix profile remove` can’t
          ##       clear a profile, so we have a fallback. See NixOS/nix#7487.
          if pm_nixAtLeast 2.21; then
            "''${DRY_RUN_CMD[@]}" nix profile remove "''${VERBOSE_ARG[@]}" \
              --profile "$genProfilePath" --all
          else
            pm_removePackagesBySuffix "$genProfilePath" ""
          fi

          ## WAIT: With `nix profile` we can’t replace the packages in a single
          ##       generation (NixOS/nix#6349), so we currently “increment” two
          ##       generations at a time.
          if ! "''${DRY_RUN_CMD[@]}" nix profile install "''${VERBOSE_ARG[@]}" \
            --profile "$genProfilePath" \
            "$newGenPath" ${config.project.packages.path}; then
            echo
            _iError $'Oops, Nix failed to install your new Project Manager profile!\n\nPerhaps there is a conflict with a package that was installed using\n"%s"? Try running\n\n    %s\n\nand if there is a conflicting package you can remove it with\n\n    %s\n\nThen try activating your Project Manager configuration again.' \
              "nix profile install --profile $genProfilePath" \
              "nix profile list --profile $genProfilePath" \
              "nix profile remove --profile $genProfilePath {number | store path}"
            exit 1
          fi

          if [[ -v DRY_RUN ]]; then
            _i "Would create a new profile generation"
          else
            _i "Created profile generation %s" "$(pm_generationNumber "$genProfilePath")"
          fi

          "''${DRY_RUN_CMD[@]}" nix-store --realise "$newGenPath" --add-root "$newGenGcPath" > "$DRY_RUN_NULL"
        else
          _i "No change so reusing profile generation %s" "$oldGenNum"
        fi

        linkNewGen
      ''
    );

    ## Delete obsolete Project Manager files.
    project.activation.removeStaleFiles = pm.dag.entryBetween ["linkGeneration"] ["writeBoundary"] ''
      function removeStaleFiles() {
        local newGenFiles
        newGenFiles="$(readlink -e "$newGenPath/project-files")"

        local -A produced=()
        local target

        local committed="$PROJECT_ROOT/${config.project.persistenceFile}"
        if [[ -e $committed ]]; then
          pm_readCcsvPairs produced "$committed"
        fi

        if [[ -v oldGenPath && -e $oldGenPath/project-files ]]; then
          local oldGenFiles
          oldGenFiles="$(readlink -e "$oldGenPath/project-files")"
          while IFS= read -r -d $'\0' target; do
            produced[$target]=1
          done < <(find "$oldGenFiles" '(' -type f -o -type l ')' -printf '%P\0')
        fi

        for target in "''${!produced[@]}"; do
          if [[ -e $newGenFiles/$target ]]; then
            "''${VERBOSE_ECHO}" "Keeping ‘$target’: still generated"
          elif [[ -e $PROJECT_ROOT/$target ]]; then
            _i "Removing ‘%s’, which is no longer generated" "$target"
            "''${DRY_RUN_CMD[@]}" rm "''${VERBOSE_ARG[@]}" "$PROJECT_ROOT/$target" \
              || true

            ## Take any directories that this emptied with it. Relative so
            ## that `rmdir` can’t wander up out of the project.
            local directory
            directory="$(dirname "$target")"
            if [[ $directory != "." ]]; then
              pushd "$PROJECT_ROOT" > /dev/null
              "''${DRY_RUN_CMD[@]}" rmdir "''${VERBOSE_ARG[@]}" \
                -p --ignore-fail-on-non-empty "$directory" \
                || true
              popd > /dev/null
            fi
          fi
        done
      }

      removeStaleFiles
    '';

    project.activation.checkFilesChanged = pm.dag.entryBefore ["linkGeneration"] (
      let
        projectDirArg = escapeShellArg projectDirectory;
      in
        ''
          function _cmp() {
            if [[ -d $1 && -d $2 ]]; then
              diff -rq "$1" "$2" &> /dev/null
            else
              cmp --quiet "$1" "$2"
            fi
          }
          declare -A changedFiles
        ''
        + concatMapStrings (v: let
          sourceArg = escapeShellArg v.storePath;
          targetArg = escapeShellArg v.target;
        in ''
          _cmp ${sourceArg} ${projectDirArg}/${targetArg} \
            && changedFiles[${targetArg}]=0 \
            || changedFiles[${targetArg}]=1
        '') (filter (v: v.onChange != "") (attrValues cfg))
        + ''
          unset -f _cmp
        ''
    );

    project.activation.onFilesChange = pm.dag.entryAfter ["linkGeneration"] (
      concatMapStrings (v: ''
        if (( ''${changedFiles[${escapeShellArg v.target}]} == 1 )); then
          if [[ -v DRY_RUN || -v VERBOSE ]]; then
            echo "Running onChange hook for" ${escapeShellArg v.target}
          fi
          if [[ ! -v DRY_RUN ]]; then
            ${v.onChange}
          fi
        fi
      '') (filter (v: v.onChange != "") (attrValues cfg))
    );

    # Symlink directories and files that have the right execute bit.
    # Copy files that need their execute bit changed.
    project-files =
      pkgs.runCommandLocal
      "project-manager-files-for-${config.project.name}"
      {
        ## `lndir` moved in Nixpkgs 25.11. It still exists at the old location
        ## (26.05), but warns on newer Nixpkgs.
        nativeBuildInputs = [(pkgs.lndir or pkgs.xorg.lndir)];
      }
      (''
          mkdir -p $out

          # Needed in case /nix is a symbolic link.
          realOut="$(realpath -m "$out")"
          mkdir -p "$realOut/${config.project.metadataDir}"
          cp ${brokenSymlinkFile} \
            "$realOut/${config.project.metadataDir}/broken-symlink.ccsv"

          function insertFile() {
            local source="$1"
            local relTarget="$2"
            local executable="$3"
            local recursive="$4"


            # If the target already exists then we have a collision. Note, this
            # should not happen due to the assertion found in the “files” module.
            # We therefore simply log the conflict and otherwise ignore it, mainly
            # to make the `files-target-config` test work as expected.
            if [[ -e "$realOut/$relTarget" ]]; then
              echo "File conflict for file “$relTarget”" >&2
              return
            fi

            # Figure out the real absolute path to the target.
            local target
            target="$(realpath -m "$realOut/$relTarget")"

            # Target path must be within $PROJECT_ROOT.
            if [[ ! $target == $realOut* ]] ; then
              echo "Error installing file “$relTarget” outside \$PROJECT_ROOT" >&2
              exit 1
            fi

            mkdir -p "$(dirname "$target")"
            if [[ -d $source ]]; then
              if [[ $recursive ]]; then
                mkdir -p "$target"
                lndir -silent "$source" "$target"
              else
                ln -s "$source" "$target"
              fi
            else
              [[ -x $source ]] && isExecutable=1 || isExecutable=""

              # Link the file into the project file directory if possible,
              # i.e., if the executable bit of the source is the same we
              # expect for the target. Otherwise, we copy the file and
              # set the executable bit to the expected value.
              if [[ $executable == inherit || $isExecutable == $executable ]]; then
                ln -s "$source" "$target"
              else
                cp "$source" "$target"

                if [[ $executable == inherit ]]; then
                  # Don’t change file mode if it should match the source.
                  :
                elif [[ $executable ]]; then
                  chmod +x "$target"
                else
                  chmod -x "$target"
                fi
              fi
            fi
          }
        ''
        + concatStrings (
          mapAttrsToList (n: v: ''
            insertFile ${
              escapeShellArgs [
                v.storePath
                v.target
                (
                  if v.executable == null
                  then "inherit"
                  else toString v.executable
                )
                (toString v.recursive)
              ]
            }
          '')
          cfg
        ));
  };
}
