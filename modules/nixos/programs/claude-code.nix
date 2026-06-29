# ~/nixos-config/modules/nixos/programs/claude-code.nix
{ config, pkgs, lib, ... }:

{
  config = lib.mkIf config.customConfig.programs.claudeCode.enable {
    environment.systemPackages = [ pkgs.uv ];

    system.activationScripts.claudeCodeMcp = {
      text = ''
        CLAUDE_JSON="/root/.claude.json"
        MCP_NIXOS='{"type":"stdio","command":"uvx","args":["mcp-nixos"],"env":{}}'
        if [ -f "$CLAUDE_JSON" ]; then
          tmp=$(mktemp)
          if ${pkgs.jq}/bin/jq --argjson entry "$MCP_NIXOS" '.mcpServers.nixos = $entry' "$CLAUDE_JSON" > "$tmp"; then
            mv "$tmp" "$CLAUDE_JSON"
          else
            rm -f "$tmp"
          fi
        else
          echo "{\"mcpServers\":{\"nixos\":$MCP_NIXOS}}" > "$CLAUDE_JSON"
        fi
      '';
    };
  };
}
