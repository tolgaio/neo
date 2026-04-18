---
name: proxmox-nfs-volume
description: Create a new ZFS dataset on the home proxmox-host and expose it to the local network over NFS, optionally mounting it on the current VM. Use when the user asks to create a new ZFS volume or dataset on proxmox, add a new NFS share from proxmox-host, provision storage for a project, bind a new volume to this VM from proxmox, or any variation that involves creating storage on the proxmox host and consuming it via NFS.
---

# proxmox-nfs-volume

Provision a new ZFS dataset on `proxmox-host` (node0, `10.0.100.100`),
export it via NFS using the `sharenfs` property, and optionally mount it on
the current VM by appending an `/etc/fstab` entry that matches the existing
convention.

## Environment assumptions

- SSH alias `proxmox-host` is configured and passwordless (verify with a
  quick `ssh proxmox-host hostname` before starting).
- Proxmox host pool is `datapool`. All shared datasets live as children of
  `datapool/<name>`.
- NFS is already running on the host and exports are driven by the ZFS
  `sharenfs` property — `/etc/exports` is intentionally empty and must not
  be edited.
- The VM user that will read/write the share has `uid=1000 gid=1000`
  (`tolga:tolga`). The existing shares (`datapool/src`, `datapool/neo-bot`,
  etc.) are all chowned to `1000:1000`.
- LAN is `10.0.100.0/24`; this is the only CIDR allowed to mount.

Confirm any assumption that looks off before proceeding — do not paper over
a mismatch.

## Required inputs (ask the user with AskUserQuestion)

Gather in a single AskUserQuestion call (combine questions):

1. **Volume name** — becomes `datapool/<name>`. Must be a valid ZFS dataset
   name: `[a-z0-9][a-z0-9_-]*`. Reject if the dataset already exists.
2. **Size** — integer, interpreted as GB (e.g. `50` → `quota=50G`). Sanity
   check against `zfs list datapool` free space.
3. **Mount on this VM?** — yes / no. Default yes.
4. **Mount point** (only if yes) — recommend `/mnt/<name>` to match the
   `/mnt/neo-bot` convention. Offer alternates only if the user asks.

Do not assume. If the user's prompt already specified some of these, skip
those questions and confirm the rest.

## Workflow

### Step 1 — Preflight (read-only)

```bash
ssh proxmox-host "zfs list datapool/<name> 2>&1 || echo NOT_EXISTS; zfs list datapool | tail -1"
```

- If the dataset already exists, stop and ask the user whether to pick a
  different name or reuse the existing one.
- Confirm the pool has enough free space for the requested quota.

### Step 2 — Create the dataset on proxmox-host

Run as a single chained SSH command so partial failure is obvious:

```bash
ssh proxmox-host '
  zfs create datapool/<name> &&
  zfs set quota=<size>G datapool/<name> &&
  zfs set sharenfs="rw=@10.0.100.0/24,no_root_squash,async,no_subtree_check" datapool/<name> &&
  chown 1000:1000 /datapool/<name> &&
  zfs list datapool/<name> &&
  showmount -e localhost | grep <name>
'
```

The `chown 1000:1000` is load-bearing — without it the client mount will
be read-only for the `tolga` user. Do not skip it.

### Step 3 — Mount on this VM (only if user said yes)

`sudo` is required. The Bash tool runs non-interactively, so hand the
combined command to the user to execute via `! <cmd>` in the prompt so the
output lands in the conversation:

```bash
! sudo mkdir -p <mountpoint> && \
  echo '10.0.100.100:/datapool/<name> <mountpoint> nfs defaults,nofail,_netdev,x-systemd.device-timeout=2 0 0' | sudo tee -a /etc/fstab && \
  sudo systemctl daemon-reload && \
  sudo mount <mountpoint> && \
  mount | grep <name> && \
  df -h <mountpoint>
```

Before presenting this, check `/etc/fstab` to make sure no line already
references `<mountpoint>` — appending a duplicate will break `mount -a`.

### Step 4 — Verify

After the mount lands, run a write-test as the normal user:

```bash
touch <mountpoint>/.write-test && rm <mountpoint>/.write-test && echo OK
```

If this returns `Permission denied`, the host-side `chown` in Step 2 was
skipped or the uid differs — re-run:

```bash
ssh proxmox-host 'chown 1000:1000 /datapool/<name>'
```

and re-test.

### Step 5 — Report

Summarize in ≤3 lines: dataset name, quota, mount point, write-test result.

## Fstab line format (reference)

Every NFS-from-proxmox mount on this VM follows exactly this pattern:

```
10.0.100.100:/datapool/<name> <mountpoint> nfs defaults,nofail,_netdev,x-systemd.device-timeout=2 0 0
```

`nofail` + `_netdev` + `x-systemd.device-timeout=2` is critical: without
them the VM will hang on boot if the proxmox host is unreachable. Do not
drop any of these options.

## Non-goals

- Do not create ZFS **zvols** (block devices). This skill is for filesystem
  datasets shared over NFS.
- Do not edit `/etc/exports` on the proxmox host. Exports are managed
  entirely via the `sharenfs` property.
- Do not set `sharenfs` to anything broader than `rw=@10.0.100.0/24`.
