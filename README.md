# portuus

NixOS infrastructure for `portuus.de`. All public traffic enters via **edge** (Hetzner VPS, static IP) and is proxied over the Tailnet to **portuus** (home server).

## Architecture

```
Internet ──► edge (Hetzner, static IP 178.105.18.167)
               ├─ nginx: TLS termination + reverse proxy (HTTP)
               ├─ nginx stream: TCP/UDP forwarding (Mail, Forgejo SSH, Minecraft, Rustdesk)
               ├─ headscale
               └─ coturn
                    │
                    │ Tailnet (Headscale)
                    │ edge: 100.64.0.1
                    │ portuus: 100.64.0.2
                    │
               portuus (Home Server)
               ├─ Forgejo + Forgejo Actions runner, GitHub Actions runner
               ├─ Nextcloud, Immich, Vaultwarden
               ├─ Matrix Synapse + Maubot
               ├─ Radicale, Jirafeau
               ├─ Mailserver
               ├─ Minecraft Servers
               └─ Rustdesk
```

Only the servers are on the Tailnet. Clients connect through the public edge.

## Git Hosting (Forgejo)

`git.portuus.de` runs [Forgejo](https://forgejo.org) on portuus (`hosts/portuus/services/forgejo/`, data in
`/data/forgejo`, custom branding in `forgejo/branding/`). It replaces the former GitLab instance, which is disabled
(`gitlab.nix` and `gitlab-runner.nix` are no longer imported).

- HTTPS: `https://git.portuus.de/<owner>/<repo>.git`, proxied by edge to portuus port 3456.
- SSH: `forgejo@git.portuus.de:<owner>/<repo>.git` on port 2222; edge forwards it to the portuus sshd (port 2299).
- CI: Forgejo Actions with a host-executor runner on portuus (`forgejo/runner.nix`, synix
  `gitea-actions-runner` module, label `portuus-nix`). Repos use `.forgejo/workflows/*.yml` with
  `runs-on: portuus-nix`.
- aarch64: portuus emulates `aarch64-linux` via binfmt/QEMU (`boot.binfmt.emulatedSystems` in
  `hosts/portuus/boot.nix`), so the runner can build ARM configs (e.g. Raspberry Pi) through the
  host's Nix daemon. Emulated builds are slow; avoid uncached kernels.

## Deploy

This repo stays on GitHub; its CI runs via GitHub Actions on a self-hosted runner on portuus:

- `.github/workflows/ci.yml`: pull requests to `master`/`develop` run `nix flake check` (deploy-rs checks +
  `pre-commit-check`) and build both hosts.
- `.github/workflows/deploy-configs.yml`: pushes to `master` deploy edge and portuus with
  [deploy-rs](https://github.com/serokell/deploy-rs).
- `.github/workflows/security.yml`: weekly (Monday) and on demand, scans the portuus and edge closures with
  vulnix and diffs them with nvd against the previous scan. Baselines live in
  `/var/lib/github-runner/portuus/security-scan/` (reset if the runner is re-registered); fails only on new CVEs
  with CVSS >= 9.0.

### Manual deploy via scp

Always delete first — `scp` doesn't overwrite existing directories properly.
Always `git commit` before copying — nix builds from the git index.

```bash
# Edge
ssh -p 2299 steffen@178.105.18.167 "rm -rf /tmp/portuus"
scp -r -P 2299 . steffen@178.105.18.167:/tmp/portuus
ssh -p 2299 steffen@178.105.18.167 "nix-shell -p git --run 'sudo nixos-rebuild switch --flake /tmp/portuus#edge'"

# Portuus
ssh -p 2299 steffen@79.248.193.69 "rm -rf /tmp/portuus"
scp -r -P 2299 . steffen@79.248.193.69:/tmp/portuus
ssh -p 2299 steffen@79.248.193.69 "sudo nixos-rebuild switch --flake /tmp/portuus#portuus"
```

## Constants

All IPs, subdomains, and ports are defined centrally in `constants.nix`.

## Secrets

Managed with [sops-nix](https://github.com/Mic92/sops-nix). Keys configured in `.sops.yaml`.

```bash
sops hosts/edge/secrets/secrets.yaml
sops hosts/portuus/secrets/secrets.yaml
```

## Troubleshooting

### TPM Lockout (Tailscale fails to start)

Portuus has a physical TPM. Tailscale encrypts its state with it. After unclean
shutdowns (freezes), the TPM lockout counter triggers and tailscaled can't unseal
its state. Fix by resetting the counter:

```bash
nix-shell -p tpm2-tools --run "sudo tpm2_dictionarylockout --clear-lockout -T device:/dev/tpmrm0"
sudo systemctl restart tailscaled
```

### nginx not loading new config after rebuild

`nixos-rebuild switch` doesn't always restart nginx. Verify and fix:

```bash
# Check which config nginx is actually using
sudo cat /proc/$(pgrep -o nginx)/cmdline | tr '\0' '\n' | grep conf

# Restart to load new config
sudo systemctl restart nginx
```

## Useful Commands

```bash
# Evaluate configs
nix eval .#nixosConfigurations.edge.config.system.build.toplevel
nix eval .#nixosConfigurations.portuus.config.system.build.toplevel

# Format nix files
nix fmt

# Lint hooks (nixfmt, statix, shellcheck, yamllint, actionlint)
nix build --no-link .#checks.x86_64-linux.pre-commit-check

# Check which nginx config is active
sudo cat /proc/$(pgrep -o nginx)/cmdline | tr '\0' '\n' | grep conf

# Check current system derivation
readlink /run/current-system
```

## Acknowledgements

Built with [synix](https://git.sid.ovh/sid/synix) by [sid](https://git.sid.ovh/sid) — a NixOS module framework that makes server configuration manageable. Thanks for the solid foundation, the reference setup at [sid.ovh](https://git.sid.ovh/sid/sid.ovh), and for building the original portuus infrastructure as a former member of this network. ❤️
