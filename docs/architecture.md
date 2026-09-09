<!-- ~/nixos-config/docs/architecture.md -->
> **Read this when**: adding a file to a host directory, deciding where a new
> `customConfig` option should be *declared*, or refactoring/moving existing config.
> `CLAUDE.md` carries the two lookup tables; the rules, gotchas, and the no-op proof
> recipes live here.

# Configuration Architecture

## Host File Layout

A host directory mirrors `modules/nixos/`: one file per domain, and `default.nix` is an
**importer only** (like `modules/nixos/default.nix`). Each top-level `customConfig`
attribute is owned by exactly one file per host, so "where is X set?" is a mechanical
lookup. A host only creates the files it needs.

| File | Owns `customConfig.*` | Host-specific raw NixOS config it carries |
|---|---|---|
| `default.nix` | *(nothing)* | `imports` only |
| `vars.nix` | *(not a module)* | plain attrset of host flags, `import`ed by the others |
| `system.nix` | `user`, `system`, `bootloader` | `boot.loader.*`, `boot.kernelPackages`, `users.users.<u>.initialPassword`, host-wide `sops.*` |
| `desktop.nix` | `desktop` | `services.xserver`/`displayManager`/`xrdp`, console rotation |
| `hardware.nix` | `hardware` | `hardware.nvidia.open`, `boot.initrd.kernelModules`, blacklists, `services.keyd` |
| `apps.nix` | `apps`, `programs`, `packages` | `programs.*`, `services.flatpak` |
| `home.nix` | `homeManager` | the `home-manager = lib.mkIf … { users.… }` block |
| `networking.nix` | `networking`, `services` | `networking.firewall/extraHosts/hosts/routes/wg-quick`, WG sops secret |
| `homelab.nix` | `homelab` | homelab-adjacent units (HA yaml, game-server tmpfiles) |
| `profiles.nix` | `profiles` | — |

Rules:
- **Keep the directory flat.** Host files use repo-relative paths (`../../assets/…`,
  `../../secrets/<host>.yaml`, `../../pkgs/…`); a subdirectory would silently repoint them.
- **Extra domain files are fine** where a host warrants one — `optiplex-nas/storage.nix`
  (filesystems/LUKS/swap) and `optiplex-nas/ci.nix` (self-hosted runner) follow the same
  naming logic.
- **Feature-specific `sops.secrets.<x>` live next to the feature that consumes it**;
  only host-wide sops settings go in `system.nix`.
- **A `let` binding cannot span files.** Flags needed by more than one file go in
  `vars.nix` as a plain attrset, consumed via `let vars = import ./vars.nix; in …`
  (see `hosts/gaming-pc/vars.nix`).
- **Watch list-valued options.** Two files defining the same scalar path error out, but
  the same *list* path silently concatenates. Also note a host's sub-modules merge *after*
  top-level flake modules (disko, nixos-hardware), so where the old inline config won an
  ordering race you may need `lib.mkBefore` — see `hosts/optiplex-nas/storage.nix`.

When refactoring host files, prove the change is a no-op by comparing
`nix eval --impure --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`
before and after. Hosts whose Plasma wallpaper is a repo path embed the flake-source hash
in one derivation, so theirs changes on any commit; use `nix-diff` on the two drvs to
confirm the only delta is that `…-source/assets/…` prefix.


## Module Option Layout

`customConfig` option *declarations* follow the same file-per-concern rule as everything
else. There is no central options file — `modules/nixos/common-options.nix` was dissolved.

> **The rule:** an option block is declared by the module that **owns the feature it
> configures** — normally the same-named module. `homelab/jellyfin.nix` declares
> `customConfig.homelab.jellyfin` *and* the `config` implementing it. If no single module
> owns it, it goes in that domain's `options.nix`.

An option lands in a domain `options.nix` when it is:
- **cross-cutting** — every module in the domain selects on it (`desktop.environments`)
- **home-manager-only** — nothing on the NixOS side reads it (`desktop.monitors`,
  `hardware.battery`, all of `apps.*`). These *cannot* move to `modules/home-manager/`:
  home-manager receives `customConfig` as a plain attrset via `extraSpecialArgs`, not as
  its own option tree, so only the NixOS module system can declare them.
- **split across several modules** — `homelab.reverseProxy` (nas + mini), `packages`

Where things live:

| Domain | Declared by |
|---|---|
| `homelab.*` | the matching `homelab/<service>.nix`; only `reverseProxy` in `homelab/options.nix` |
| `desktop.*` | `desktop/{kde,hyprland,xrdp,display-manager,custom-sddm-theme}.nix`; the rest in `desktop/options.nix` |
| `hardware.*` | `hardware/{nvidia,peripherals}.nix`; the rest in `hardware/options.nix` |
| `services.*` | `services/{ssh,vscode-server,wireguard-client,wireguard-server}.nix`; `autoUpdate` in `common/auto-update.nix` |
| `profiles.*` | `profiles/gaming.nix` and each `development/*.nix` — no `options.nix` |
| `programs.*` | `programs/{partydeck,claude-code}.nix`; `firefox`/`flatpak` in `programs/options.nix` |
| `apps.*` | `apps/programs.nix` (registry + `mkAppRole`), `apps/xdg-defaults.nix` (MIME) |
| `bootloader`, `networking`, `homeManager` | `common/{bootloader,networking,home-manager}.nix` |
| `user`, `system`, `packages` | `common/options.nix` |

Fallback for a namespace with no owning module: `customConfig.<X>` → `modules/nixos/<X>/`
if that directory exists, else `common/`. That is why `apps/` exists as an options-only
directory. Add every new `options.nix` to its domain's `default.nix` imports.

Gotchas when moving declarations:
- **Nix merges duplicate attrset literals silently.** `{ a = {b=1;}; a = {c=2;}; }` merges,
  which is how `customConfig.programs` and `customConfig.desktop.kde` each ended up declared
  twice in the old file without anyone noticing. But a literal will *not* merge with a path
  already extended elsewhere in the same file — `{ a.b = 1; a = {c=2;}; }` errors. Use the
  nested-path form there (see `development/*.nix`, which already declare `.devShell`).
- **A module that declares `options` cannot also use shorthand config.** Bare `boot.loader = …`
  at top level must move under an explicit `config = { … }`.
- **Check the argument list.** Defaults referencing `pkgs` or `config` need those in the
  module's arguments; the old file had them all in scope for free.

To prove a declaration move is a no-op, compare the **merged `customConfig` fixpoint**, not
just drvPaths — it catches a changed default or priority directly:

```bash
nix eval --impure --json --expr '
  let f = builtins.getFlake "/home/lando/nixos-config"; cfg = f.nixosConfigurations.<host>;
      lib = cfg.pkgs.lib;
      san = v: let r = builtins.tryEval (            # tryEval: no-default options throw
        if builtins.isFunction v then "<function>"
        else if lib.isDerivation v then "drv:" + (v.drvPath or "?")
        else if builtins.isPath v then "path:" + (baseNameOf (toString v))
        else if builtins.isList v then map san v
        else if builtins.isAttrs v then lib.mapAttrs (_: san) v
        else v); in if r.success then r.value else "<unset>";
  in san cfg.config.customConfig' | jq -S .
```

Note `config.system.build.manual.optionsJSON` is **not** useful here — it documents upstream
nixpkgs options only and never contains `customConfig`.

