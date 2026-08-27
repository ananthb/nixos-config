# Chromebook home profile for the ChromeOS Baguette VM. Reuses the same shared
# dev environment as home/coder.nix (nixvim, fish + yazelix, git, direnv) and
# carries NO secrets: this guest has no YubiKey and no sops age key, so commits
# stay unsigned here. Clipboard, xdg-open and the X/Wayland bridge come from the
# baguette module rather than from this profile.
{
  inputs,
  pkgs,
  lib,
  username,
  ...
}: {
  imports = [
    inputs.nix-index-database.homeModules.nix-index
    ../modules/home/options.nix
    ../modules/home/shell.nix
    ../modules/home/dev.nix
  ];

  home = {
    # mkDefault so the NixOS home-manager module's values (taken from
    # users.users.${username} in hosts/chromebook.nix) win, matching the
    # pattern in home/coder.nix.
    username = lib.mkDefault username;
    homeDirectory = lib.mkDefault "/home/${username}";
    stateVersion = "25.05";
    sessionVariables.EDITOR = "nvim";

    packages = with pkgs; [
      delta
      devenv
      fd
      fzf
      gh
      git
      git-absorb
      jq
      lazygit
      nix-output-monitor
      ripgrep
    ];
  };

  programs = {
    home-manager.enable = true;

    git = {
      settings.user = {
        name = "Ananth Bhaskararaman";
        email = "antsub@gmail.com";
        useConfigOnly = "true";
      };
      # dev.nix leaves git signing unset (mkDefault null); no YubiKey reaches
      # this guest, so keep commits unsigned.
      signing.signByDefault = lib.mkForce false;
    };

    # The LSP set in the shared dev.nix is sized for a workstation. On a 20G VM
    # the heavyweights cost more store than they earn on a machine that mostly
    # sees this repo: rust_analyzer drags in rustc and cargo, clangd drags in
    # LLVM, ltex is a JVM app, and pyright / ts_ls / html / cssls / dockerls each
    # bring Node. Keep the languages this host actually edits — Nix, Go,
    # Terraform/HCL, shell, YAML, Markdown, Lua — and drop the rest. These stay
    # enabled on discovery and coder; delete a line here to get one back.
    nixvim.plugins = {
      lsp.servers = {
        clangd.enable = lib.mkForce false;
        cssls.enable = lib.mkForce false;
        dockerls.enable = lib.mkForce false;
        html.enable = lib.mkForce false;
        ltex.enable = lib.mkForce false;
        pyright.enable = lib.mkForce false;
        rust_analyzer.enable = lib.mkForce false;
        ts_ls.enable = lib.mkForce false;
        zls.enable = lib.mkForce false;
      };

      # Linters for the languages dropped above. golangci_lint, terraform_validate
      # and yamllint stay: they cover what this host still edits.
      none-ls.sources.diagnostics = {
        ansiblelint.enable = lib.mkForce false;
        mypy.enable = lib.mkForce false;
        pylint.enable = lib.mkForce false;
        tfsec.enable = lib.mkForce false;
      };

      # Debug adapters and helpers for those same languages. dap, dap-go and
      # dap-ui stay; dap-lldb in particular would pull LLDB back in.
      dap-lldb.enable = lib.mkForce false;
      dap-python.enable = lib.mkForce false;
      zig.enable = lib.mkForce false;
    };
  };
}
