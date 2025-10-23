{
  runStrictCommand,
  lib,
  bash-strict-mode,
  callPackage,
  coreutils,
  findutils,
  gettext,
  gnused,
  jq,
  less,
  ncurses,
  nix,
  release,
  unixtools,
  # used for pkgs.path for nixos-option
  pkgs,
}: let
  nixos-option =
    pkgs.nixos-option
    or (callPackage
      (pkgs.path + "/nixos/modules/installer/tools/nixos-option") {});
in
  runStrictCommand "project-manager" {
    preferLocalBuild = true;
    buildInputs = [bash-strict-mode];
    nativeBuildInputs = [gettext];
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
        bash-strict-mode
        coreutils
        findutils
        gettext
        gnused
        jq
        less
        ncurses
        nix
        nixos-option
        unixtools.hostname
      ]
    }" \
      --subst-var-by OUT "$out" \
      --subst-var-by VERSION "${release}"

    ## See NixOS/nixpkgs#247410.
    (set +u; patchShebangs --host $out/bin/project-manager)

    install -D -m755 ${./completion.bash} \
      $out/share/bash-completion/completions/project-manager
    install -D -m755 ${./completion.zsh} \
      $out/share/zsh/site-functions/_project-manager
    install -D -m755 ${./completion.fish} \
      $out/share/fish/vendor_completions.d/project-manager.fish

    install -D -m755 ${../lib/bash/project-manager.bash} \
      "$out/share/bash/project-manager.bash"

    substituteInPlace $out/share/bash/project-manager.bash \
      --subst-var-by FLAKE_TEMPLATE '${../templates/default/flake.nix}' \
      --subst-var-by CONFIG_TEMPLATE '${../templates/default/.config/project/default.nix}'

    # for path in {./po}/*.po; do
    #   lang="''${path##*/}"
    #   lang="''${lang%%.*}"
    #   mkdir -p "$out/share/locale/$lang/LC_MESSAGES"
    #   msgfmt -o "$out/share/locale/$lang/LC_MESSAGES/project-manager.mo" "$path"
    # done
  ''
