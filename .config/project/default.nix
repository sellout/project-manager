{
  config,
  flaky,
  lib,
  pkgs,
  ...
}: let
  testedNixpkgsVersions = ["22_11" "23_05" "23_11" "24_05"];
in {
  project = {
    name = "project-manager";
    summary = "Home Manager, but for repos.";
    license = "MIT"; # Induced by this being basically a fork of Home Manager

    ## The base config sets this to `true`, because I want most projects to be
    ## contributable-to by non-Nix users. However, Nix-specific projects can
    ## lean into Project Manager and avoid committing extra files.
    commit-by-default = lib.mkForce false;

    devPackages = [pkgs.nix-schema];
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
      ## Shell linter
      programs.shellcheck.enable = true;
      ## Shell formatter
      programs.shfmt.enable = true;
      settings.formatter = let
        includes = ["project-manager/project-manager"];
      in {
        shellcheck = {inherit includes;};
        shfmt = {inherit includes;};
      };
    };
    vale = {
      enable = true;
      formatSettings."*.xml".Transform =
        "${pkgs.docbook-xsl-ns}/share/xml/docbook-xsl-ns/html/docbook.xsl";
      excludes = [
        "*.bash"
        "*.xml" # TODO: Remove this once we get the XSL transform working.
        "./project-manager/project-manager"
        "./project-manager/completion.fish"
        "./project-manager/completion.zsh"
      ];
      vocab.${config.project.name}.accept = [
        "babelfish"
        "[Bb]oolean"
        "declutter"
        "Dhall"
        "formatter"
        "NMT"
        "sandboxed"
        "systemd"
        "treefmt"
        "unsandboxed"
      ];
    };
  };

  ## CI
  services.garnix = {
    enable = true;
    builds.exclude =
      [
        # TODO: Remove once garnix-io/garnix#285 is fixed.
        "homeConfigurations.x86_64-darwin-${config.project.name}-example"
      ]
      ## NB: Explicitly excluded because they’re not sandboxed, but since the
      ##     checks are renamed, they’re not caught by the auto-exclusion.
      ++ lib.concatMap
      (nixpkgs: [
        "checks.*.project-manager-files-${nixpkgs}"
        "checks.*.vale-${nixpkgs}"
      ])
      testedNixpkgsVersions;
  };
  services.github.settings.branches.main.protection.required_status_checks.contexts = lib.mkForce (lib.concatMap flaky.lib.garnixChecks ([
      (sys: "check shellcheck [${sys}]")
      (sys: "package docs-html [${sys}]")
      (sys: "package docs-manpages [${sys}]")
      (sys: "package default [${sys}]")
      (sys: "package docs-json [${sys}]")
      (sys: "package project-manager [${sys}]")
      ## FIXME: These are duplicated from the base config
      (sys: "check formatter [${sys}]")
      (sys: "devShell default [${sys}]")
    ]
    ++ lib.concatMap (nixpkgs: [
      (sys: "check formatter-${nixpkgs} [${sys}]")
      (sys: "check shellcheck-${nixpkgs} [${sys}]")
    ])
    testedNixpkgsVersions));

  ## publishing
  services.flakehub.enable = true;
  services.flakestry.enable = true;
  services.github.enable = true;
  services.github.settings.repository.homepage = "https://sellout.github.io/${config.project.name}";
  services.github.settings.repository.topics = ["development" "nix-flakes"];

  imports = [
    ./github-pages.nix
    ./mustache.nix
  ];
}
