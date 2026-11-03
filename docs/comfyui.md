# ComfyUI

ComfyUI runs on **gaming-pc** in a GPU container (`customConfig.programs.comfyui`,
`modules/nixos/programs/comfyui.nix`). The unit is `podman-comfyui.service`.

## Reaching it

| From | Address |
|---|---|
| gaming-pc itself | `http://localhost:8188` |
| lando's full VPN peers (10.10.0.2, 10.10.0.3) | `http://10.10.0.11:8188` (gaming-pc's `wg-nas` address) |
| Main LAN, restricted VPN peers, anything else | blocked |

The container shares the host network and ComfyUI listens on every address, so the host
firewall decides who gets in. Port 8188 is never in `allowedTCPPorts`. The module adds one
`iptables` accept rule per (`interfaces` × `allowedSources`) pair instead. optiplex-fw routes
VPN peers to `10.10.0.11` with their own source addresses (no NAT, same path as
[The Batman netplay](networking.md#the-batman-netplay-port-7845)), so the source filter
holds. Check the live rules with `sudo iptables -S nixos-fw | grep 8188`.

To let in another peer, add its `/32` to `allowedSources` in `hosts/gaming-pc/apps.nix`.
Restricted peers also need a pf rule on optiplex-fw, so don't do that casually.

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

- **ComfyUI-Manager** (built into the image): *Manager → Model Manager*, or load a
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

Everything sits under `/var/lib/comfyui`, outside the store:

- `root/`: the container's `/root`. ComfyUI itself, custom nodes, pip installs. Updating
  ComfyUI or nodes through the Manager writes here and survives image bumps.
- `input/`, `output/`, `workflows/`: uploads, generated files, saved workflows.

## Operating it

```bash
systemctl status podman-comfyui      # running?
journalctl -u podman-comfyui -f      # logs (first start pulls a multi-GB image)
sudo systemctl stop podman-comfyui   # free the GPU for gaming
sudo systemctl start podman-comfyui
```

ComfyUI keeps the last model in VRAM between runs. Stop the unit before a GPU-heavy game.

**Bumping the image:** pick a newer `cu130-slim-<date>` tag (cu130 needs NVIDIA driver
580+) and take its digest:

```bash
curl -s "https://hub.docker.com/v2/repositories/yanwk/comfyui-boot/tags?name=cu130-slim" \
  | jq -r '.results[] | "\(.name) \(.digest)"'
```

Then update `image` in the module. ComfyUI in `root/` is only copied from the image on
the very first start. After that, update it through the Manager.
