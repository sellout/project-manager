### All available options for this file are listed in
### https://sellout.github.io/project-manager/options.xhtml
{
  config,
  flaky,
  lib,
  pkgs,
  supportedSystems,
  ...
}: let
  testedNixpkgsVersions = [
    "22_11"
    "23_05"
    "23_11"
    "24_05"
    "24_11"
    "25_05" # tested, but covered by the Project Manager build
    "25_11"
  ];
in {
  project = {
    name = "project-manager";
    summary = "Home Manager, but for repos.";
    license = "MIT"; # Induced by this being basically a fork of Home Manager

    ## The base config sets this to `true`, because I want most projects to be
    ## contributable-to by non-Nix users. However, Nix-specific projects can
    ## lean into Project Manager and avoid committing extra files.
    commit-by-default = lib.mkForce false;
  };

  ## dependency management
  services.renovate.enable = true;

  ## development
  programs = {
    direnv = {
      enable = true;
      ## See the reasoning on `project.commit-by-default`.
      commit-envrc = false;
    };
    git = {
      # This should default by whether there is a .git file/dir (and whether
      # it’s a file (worktree) or dir determines other things – like where hooks
      # are installed.
      enable = true;
      ignoreRevs = [
        "85aa90127b474729fecedfbfce566c8db1760cd1" # formatting
      ];
    };
  };

  ## formatting
  editorconfig.enable = true;
  programs = {
    shellcheck.enable = true;
    treefmt = {
      enable = true;
      package = lib.mkForce pkgs.treefmt;
      ## Shell linter
      programs.shellcheck.enable = true;
      ## Shell formatter
      programs.shfmt.enable = true;
      settings = {
        formatter = let
          includes = ["project-manager/project-manager"];
        in {
          shellcheck = {inherit includes;};
          shfmt = {inherit includes;};
        };
        ## TODO: This is overly broad. It captures the files that define the
        ##       tests as well as the golden files. Consider refining the tests’
        ##       filesystem structure to make it possible to capture only golden
        ##       files.
        ##
        ##       In the mean time, it can be helpful to comment out this line,
        ##       run `project-manager fmt` and then discard the formatting
        ##       applied to golden files (running the tests and seeing what
        ##       breaks should show you which files to revert).
        global.excludes = ["*/tests/*"];
      };
    };
    vale = {
      enable = true;
      excludes = [
        "*.bash"
        "*.css"
        "*.scss"
        "*.xml" # TODO: Remove this once we get the XSL transform working.
        "./docs/manual/manpage-urls.json"
        "./docs/project-manager.1"
        "./docs/project-configuration-nix-header.5"
        "./project-manager/project-manager"
        "./project-manager/completion.fish"
        "./project-manager/completion.zsh"
      ];
      vocab.${config.project.name}.accept = [
        "alejandra"
        "babelfish"
        "[Bb]oolean"
        "composable"
        "DBus"
        "dconf"
        "declutter"
        "decluttered"
        "decluttering"
        "devenv"
        "devShell"
        "Dhall"
        "formatters"
        "NixOS"
        "Nixpkgs"
        "NMT"
        "sandboxed"
        "subcommands"
        "systemd"
        "treefmt"
        "unsandboxed"
      ];
    };
  };

  ## CI
  services.garnix = let
    ## Build certain outputs only on one platform (x86_64-linux)
    ## TODO: Move this up to Flaky, and make the selected platform configurable.
    singlePlatform = output: name:
      flaky.lib.forGarnixSystems supportedSystems (sys:
        if sys == "aarch64-darwin"
        then []
        else ["${output}.${sys}.${name}"]);
  in {
    enable = true;
    builds."*".exclude =
      [
        "checks.*.formatter-22_11"
        "checks.*.formatter-23_05"
        "checks.*.formatter-23_11"
        "checks.*.formatter-24_05"
        "checks.*.formatter-24_11"
        "checks.*.shellcheck-22_11"
        "checks.*.shellcheck-23_05"
        "checks.*.shellcheck-23_11"
        "checks.*.shellcheck-24_05"
        "checks.*.shellcheck-24_11"
      ]
      ++ lib.concatMap (singlePlatform "checks") [
        "formatter"
        "shellcheck"
        "vale"
      ];
  };
  ## FIXME: The Project Manager module needs to be fixed so that these merge
  ##        correctly, rather than having to use `lib.mkForce`.
  services.github.settings.branches.main.protection.required_status_checks.contexts = lib.mkForce (
    ["All Garnix checks"]
    ## For Garnix, these are covered by “All Garnix checks”, but for Nix CI, we
    ## need to add them individually.
    ++ lib.concatMap (sys:
      [
        "build checks.${sys}.formatter"
        "build checks.${sys}.project-manager-files"
        "build checks.${sys}.shellcheck"
        "build checks.${sys}.vale"
        "build devShells.${sys}.default"
        "build devShells.${sys}.project-manager"
        "build packages.${sys}.default"
        "build packages.${sys}.docs-html"
        "build packages.${sys}.docs-json"
        "build packages.${sys}.docs-manpages"
        "build packages.${sys}.project-manager"
      ]
      ++ lib.concatMap (nixpkgs: [
        "build checks.${sys}.formatter-${nixpkgs}"
        "build checks.${sys}.project-manager-files-${nixpkgs}"
        "build checks.${sys}.shellcheck-${nixpkgs}"
        "build checks.${sys}.vale-${nixpkgs}"
      ])
      testedNixpkgsVersions) ["x86_64-linux"]
  );
  services.nix-ci = {
    enable = true;
    ## Override this for specific project types (like Haskell and Rust), until I
    ## get them off IFD.
    allow-import-from-derivation = false;
    cachix = {
      name = "sellout";
      public-key = "sellout.cachix.org-1:v37cTpWBEycnYxSPAgSQ57Wiqd3wjljni2aC0Xry1DE=";
    };
    fail-fast = false;
  };

  ## publishing
  services.flakehub.enable = true;
  services.flakestry.enable = true;
  services.github.enable = true;
  services.github.settings.repository.homepage = "https://sellout.github.io/${config.project.name}";
  services.github.settings.repository.topics = ["development" "nix-flakes"];

  imports = [
    ./github-pages.nix
  ];
}
