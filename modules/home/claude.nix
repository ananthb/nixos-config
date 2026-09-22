# Claude Code's settings file, declared without taking it over.
#
# ~/.claude/settings.json cannot be a home.file. That writes a symlink into
# the read-only store, and Claude Code writes this file itself -- "always
# allow" on a permission prompt, /config toggles, the auto-mode opt-in all
# land here and would silently fail against a store path. So rather than
# owning the file, merge the declared sets into whatever is already there and
# leave everything else alone.
#
# `claude.settings` is a LIST so profiles can each contribute without knowing
# about the others: dev.nix declares what every host shares, a host profile
# appends its own. jq's `*` is a recursive merge with the right side winning,
# so later entries override earlier ones key by key rather than replacing the
# document, and a key nobody declares stays whatever Claude made it. Arrays
# are replaced whole, which is what a list-valued setting wants.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.claude;
  declared = pkgs.writeText "claude-settings.json" (builtins.toJSON cfg.settings);
  settingsPath = "${config.home.homeDirectory}/.claude/settings.json";
in {
  options.claude.settings = lib.mkOption {
    type = with lib.types; listOf (attrsOf anything);
    default = [];
    description = ''
      Sets merged into ~/.claude/settings.json on activation, in order, each
      overriding the last. A key declared here is restored on every switch,
      so change it here rather than in /config; a key absent from every set
      belongs to Claude and survives untouched.
    '';
  };

  config = lib.mkIf (cfg.settings != []) {
    # home-manager's `run` wrapper cannot be used below: it becomes `echo`
    # under --dry-run, and a redirect attached to it would still truncate the
    # target and fill it with the echoed command. Guard the whole block on
    # DRY_RUN instead, the way home-manager's own modules do.
    #
    # Bad JSON in the existing file is left alone rather than overwritten --
    # it is likelier a half-written edit worth keeping than garbage.
    home.activation.claudeSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      settings="${settingsPath}"

      if [[ -v DRY_RUN ]]; then
        echo "would merge ${declared} into $settings"
      else
        mkdir -p "$(dirname "$settings")"
        [ -s "$settings" ] || echo '{}' >"$settings"

        if ${pkgs.jq}/bin/jq -e . "$settings" >/dev/null 2>&1; then
          ${pkgs.jq}/bin/jq --slurpfile decls ${declared} \
            '. as $cur | $decls[0] | reduce .[] as $d ($cur; . * $d)' \
            "$settings" >"$settings.hm-merged" \
            && mv -f "$settings.hm-merged" "$settings"
          chmod 644 "$settings"
        else
          warnEcho "$settings is not valid JSON; leaving it alone."
        fi
      fi
    '';
  };
}
