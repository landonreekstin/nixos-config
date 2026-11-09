# ComfyUI

ComfyUI runs on **gaming-pc** in a GPU container (`customConfig.programs.comfyui`,
`modules/nixos/programs/comfyui.nix`). The unit is `podman-comfyui.service`.

## Reaching it

| From | Address |
|---|---|
| gaming-pc itself | `http://localhost:8188` |
| lando's full VPN peers (10.10.0.2, 10.10.0.3) | `http://10.10.0.11:8188` (gaming-pc's `wg-nas` address) |
| Main LAN, restricted VPN peers, anything else | blocked |

The container itself has no internet (see [Offline](#offline-no-way-out)). A small host
proxy (`comfyui-proxy.service`, socat) listens on 8188 and carries connections in to it, so
the host firewall decides who gets in. Port 8188 is never in `allowedTCPPorts`. The module
adds one `iptables` accept rule per (`interfaces` × `allowedSources`) pair instead. optiplex-fw routes
VPN peers to `10.10.0.11` with their own source addresses (no NAT, same path as
[The Batman netplay](networking.md#the-batman-netplay-port-7845)), so the source filter
holds. Check the live rules with `sudo iptables -S nixos-fw | grep 8188`.

To let in another peer, add its `/32` to `allowedSources` in `hosts/gaming-pc/apps.nix`.
Restricted peers also need a pf rule on optiplex-fw, so don't do that casually.

## Offline: no way out

ComfyUI, its custom nodes and models must not be able to send anything to the internet.
Layers, each enough on its own for the case it covers:

- **No route out.** The container is on `comfyui-offline`, an `internal` podman network
  (bridge `comfynet0`, `10.90.88.0/29`, container `10.90.88.2`): no default route, no
  NAT, no DNS (`--dns=none`). Recreated on every start by the unit's pre-start.
- **The host is no way out either.** nftables table `inet comfyui_isolation` (its own
  table, so no accept elsewhere can override it) drops every *new* packet arriving from
  `comfynet0` to gaming-pc and anything forwarded to or from it, IPv4 and IPv6. Only
  replies to connections the host opened (the proxy) pass.
- **No raw packets** (`--cap-drop=NET_RAW`).
- **Software told it's offline:** `--offline` (a Content-Security-Policy so the web UI in
  the *browser* can't contact the internet, and no paid cloud nodes), `HF_HUB_OFFLINE`,
  `TRANSFORMERS_OFFLINE`, and ComfyUI-Manager `network_mode = offline` in
  `user/__manager/config.ini` on the share.

Check it from inside: `sudo podman exec comfyui python3 -c "import socket;
socket.create_connection(('1.1.1.1',443),5)"` must fail, and
`sudo nft list table inet comfyui_isolation` must show the drops.

Not covered: what the phone app (ComfyChair) or a browser does on its own. They only get
what ComfyUI serves them, but that includes your images.

### Installing nodes and models: `comfy-maintenance`

The Manager can't download anything from the offline instance. `comfy-maintenance` stops
it and starts a second container (`podman-comfyui-maintenance`, port 8189, same firewall
rules) **with** internet, sharing ComfyUI's install, nodes and models but **none of the
personal data**: input/output are RAM-only, and `user/` is a local
`/var/lib/comfyui/maintenance-user` (its own Manager settings). Install there, then
`comfy-stop` and `comfy-start`. Don't generate in maintenance mode. Code installed there
runs later in the offline instance, where the layers above still apply.

## Models are not in Nix or git

Nothing about models is declared in this repo. Weights go in
`/var/lib/comfyui/models/<folder>/`, which is group-writable by `users`, so lando can
write there without sudo:

| Folder | What goes in it |
|---|---|
| `checkpoints/` | all-in-one checkpoints |
| `diffusion_models/` | standalone diffusion models / UNets (`.safetensors`, or `.gguf` with the ComfyUI-GGUF node) |
| `text_encoders/` | text encoders (CLIP, T5, ...) |
| `vae/` | VAEs |
| `loras/` | LoRAs |

Two ways to get them:

- **ComfyUI-Manager** in `comfy-maintenance` (the normal instance is offline): *Manager → Model Manager*, or load a
  workflow and use *Install Missing Models*. **Install Missing Custom Nodes** in the same
  menu fills in any nodes a workflow needs.
- **By hand from Hugging Face:**
  ```bash
  nix shell nixpkgs#python3Packages.huggingface-hub -c \
    hf download <org>/<repo> <file-in-repo> --local-dir /var/lib/comfyui/models/<folder>
  ```
  `--local-dir` keeps the repo's subfolders. If the file lands in a nested path, move it
  up into `<folder>/`. Gated repos need `hf auth login` first. For files that aren't on
  Hugging Face, `curl -L -o /var/lib/comfyui/models/<folder>/<name> <url>` works too.

After adding a file, refresh the browser tab (or press `r` in the graph) so the loader
nodes list it.

**VRAM:** gaming-pc has 16 GB. Large video models often ship fp16 weights that won't fit.
Pick the fp8 or GGUF (Q4–Q6) versions instead.

## Where the rest lives

ComfyUI itself, models and caches sit under `/var/lib/comfyui`, outside the store:

- `root/`: the container's `/root`. ComfyUI itself, custom nodes, pip installs. Updating
  ComfyUI or nodes through the Manager writes here and survives image bumps.
- `models/`, `hf-hub/`, `torch-hub/`: weights and download caches.

**Personal data lives on the NAS's encrypted private share**, at
`/mnt/nas-private/generated` (`private.dir`), never on gaming-pc's disk:

- `input/`: uploaded source images.
- `output/`: generated images and videos. ComfyUI embeds the prompt and workflow in each
  file's metadata, so the prompts live here too.
- `user/`: saved workflows, UI settings, ComfyUI-Manager's config, and ComfyUI's own log.

Preview and temp images go to a RAM-only tmpfs. With `private.dir` unset, the module falls
back to `input/`, `output/`, `workflows/` under `/var/lib/comfyui`.

## Operating it

ComfyUI does **not** start at boot. Two commands, run as lando (they ask for sudo, and
`comfy-start` also asks for the private share's own password; see
[networking.md](networking.md#nas-behind-firewall-specifics)):

```bash
comfy-start   # mount the private share (private-share), start ComfyUI, print its URLs
comfy-stop    # stop ComfyUI (frees the GPU), unmount the share, show GPU memory in use
```

Underneath they are just:

```bash
private-share                        # mount /mnt/nas-private (the NAS's encrypted drive)
sudo systemctl start podman-comfyui  # start ComfyUI (refuses if the share isn't mounted)
sudo systemctl stop podman-comfyui   # stop it
private-share -u                     # unmount; ComfyUI is stopped automatically if running
journalctl -u podman-comfyui -f      # logs (first start pulls a multi-GB image)
```

### Batch edits: `comfy-batch`

```bash
comfy-batch ~/some/folder "make it night"            # every image under the folder, recursively
comfy-batch --suffix _night ~/some/folder "..."      # different result name per prompt
comfy-batch --workflow batch-edit-standard DIR "..."  # pick another saved workflow
comfy-batch --list                                   # saved workflows
```

Each result is written next to its source as `<name>_edited.png` (or `--suffix`). Images
with a result are skipped, so Ctrl+C and rerunning resumes. ComfyUI-made PNGs (they carry a
`prompt` text chunk) are never used as inputs. Uploads and results go through ComfyUI's
RAM-only temp area (`type=temp`, SaveImage swapped for PreviewImage), so the only file
written is the result beside the input. Results come out at about 1 MP, the edit model's
working size.

The workflow is an API-format JSON in the saved workflows on the private share, so no model
name is in git. The default is `batch-edit`. It needs one `LoadImage`, one node whose title
contains "positive" (with a `prompt` or `text` input), and one `SaveImage`.

The unit `BindsTo` the share's mount unit (`mnt-nas\x2dprivate.mount`, which systemd creates
for any mount), and its pre-start refuses to run unless `/mnt/nas-private` is a mountpoint.
So a missing share can never leave personal files on the root filesystem.

ComfyUI keeps the last model in VRAM between runs. Run `comfy-stop` before a GPU-heavy game.

**Pure-noise output:** ComfyUI runs with `--fast fp16_accumulation`, not bare `--fast`. Bare
`--fast` also enables fp8 matrix multiplication, and some fp8 all-in-one checkpoints then
produce nothing but noise. Keep it that way in `extraArgs`.

**Bumping the image:** pick a newer `cu130-slim-<date>` tag (cu130 needs NVIDIA driver
580+) and take its digest:

```bash
curl -s "https://hub.docker.com/v2/repositories/yanwk/comfyui-boot/tags?name=cu130-slim" \
  | jq -r '.results[] | "\(.name) \(.digest)"'
```

Then update `image` in the module. ComfyUI in `root/` is only copied from the image on
the very first start. After that, update it through the Manager.
