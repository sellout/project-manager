{
  runCommand,
  lib,
  bash-strict-mode,
  callPackage,
  coreutils,
  findutils,
  gettext,
  gnused,
  jq,
  less,
  makeWrapper,
  ncurses,
  unixtools,
  # used for pkgs.path for nixos-option
  pkgs,
}: let
  nixos-option =
    pkgs.nixos-option
    or (callPackage
      (pkgs.path + "/nixos/modules/installer/tools/nixos-option") {});
in
  runCommand "project-manager" {
    preferLocalBuild = true;
    nativeBuildInputs = [gettext makeWrapper];
    meta = with lib; {
      mainProgram = "project-manager";
      description = "A project environment configurator";
      maintainers = [maintainers.sellout];
      platforms = platforms.unix;
      license = licenses.mit;
    };
  } ''
    install -v -D -m755  ${./project-manager} $out/bin/project-manager

    substituteInPlace $out/bin/project-manager \
      --subst-var-by DEP_PATH "${
      lib.makeBinPath [
        coreutils
        findutils
        gettext
        gnused
        jq
        less
        ncurses
        nixos-option
        unixtools.hostname
      ]
    }" \
      --subst-var-by PROJECT_MANAGER_LIB '${../lib/bash/project-manager.sh}' \
      --subst-var-by OUT "$out"

    ## TODO: I feel like this should use
    ##      `patchShebangs --host $out/bin/project-manager` instead of
    ##      `wrapProgram`, but I can’t seem to get it to actually replace the
    ##      `strict-bash` reference.
    wrapProgram $out/bin/project-manager --prefix PATH : "${
      lib.makeBinPath [
        bash-strict-mode
      ]
    }"

    install -D -m755 ${./completion.bash} \
      $out/share/bash-completion/completions/project-manager
    install -D -m755 ${./completion.zsh} \
      $out/share/zsh/site-functions/_project-manager
    install -D -m755 ${./completion.fish} \
      $out/share/fish/vendor_completions.d/project-manager.fish

    install -D -m755 ${../lib/bash/project-manager.sh} \
      "$out/share/bash/project-manager.sh"

    # for path in {./po}/*.po; do
    #   lang="''${path##*/}"
    #   lang="''${lang%%.*}"
    #   mkdir -p "$out/share/locale/$lang/LC_MESSAGES"
    #   msgfmt -o "$out/share/locale/$lang/LC_MESSAGES/project-manager.mo" "$path"
    # done
  ''
