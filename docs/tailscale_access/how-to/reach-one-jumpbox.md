# How to reach one jumpbox through an overlapping subnet

**Goal:** prefer Tailscale for one jumpbox IP when a broader local or other-VPN
route would otherwise capture the traffic.

Use this only after confirming that Tailscale has a single intended subnet
router for the jumpbox's network. A host route chooses the Tailscale interface;
it does not choose a particular subnet router behind Tailscale.

## Before you begin

- Know the jumpbox IPv4 address, written below as `<jumpbox-ip>`.
- Confirm the subnet router advertises a route containing that address, that
  the route is approved in the Tailscale admin console, and that tailnet policy
  allows the connection you need.
- Do not use this procedure if two sites use the same jumpbox IP or advertise
  the same CIDR and you need to select between them. See [the explanation](../explanation/overlapping-private-networks.md).

On Linux, clients do not accept subnet routes by default. Enable route
acceptance if the client should receive the advertised route:

```sh
sudo tailscale set --accept-routes=true
```

On macOS and Windows, subnet routes are normally accepted by default. Check
the route in the Tailscale admin console and confirm the client is connected:

```sh
tailscale status
```

## Add a host route

A `/32` is more specific than a `/24`, so ordinary IP route selection prefers
it for this one address. Replace `<jumpbox-ip>` in the command for the client
operating system.

### Linux

```sh
sudo ip route replace <jumpbox-ip>/32 dev tailscale0
ip route get <jumpbox-ip>
```

The result should identify `tailscale0`. Linux Tailscale also uses policy
routing; if the result is surprising, inspect both rules and route tables:

```sh
ip rule show
ip route show table all | grep -E 'tailscale|<jumpbox-ip>'
```

### macOS

Find the active Tailscale tunnel interface (typically a `utun` interface), then
install and inspect the route:

```sh
ifconfig | grep '^utun'
sudo route -n add -host <jumpbox-ip> -interface utun<N>
route -n get <jumpbox-ip>
```

Replace `utun<N>` with the interface reported for the active Tailscale tunnel.
Do not assume that its number is stable across restarts.

### Windows

Open an elevated PowerShell window:

```powershell
New-NetRoute -DestinationPrefix "<jumpbox-ip>/32" -InterfaceAlias "Tailscale" -NextHop "0.0.0.0"
Get-NetRoute -DestinationPrefix "<jumpbox-ip>/32" | Format-Table -AutoSize
```

If the Tailscale adapter has a different name, find it first with
`Get-NetAdapter | Where-Object Name -Match Tailscale` and substitute that name.

## Test and remove

Test the actual service, for example:

```sh
ssh <user>@<jumpbox-ip>
```

Do not rely on ping alone: ICMP may be blocked even when SSH or RDP works.

Remove the override if the network location changes or the test reaches an
unexpected host:

```sh
# Linux
sudo ip route del <jumpbox-ip>/32 dev tailscale0

# macOS
sudo route -n delete -host <jumpbox-ip>
```

On Windows, identify the route with `Get-NetRoute` and remove it with
`Remove-NetRoute` using its destination prefix and interface alias.

## Make it persistent only after testing

Manual host routes normally disappear on reboot and may need reapplying after
Tailscale reconnects. Add the tested command to the platform's normal startup
mechanism: a systemd oneshot unit ordered after `tailscaled.service` on Linux,
a `launchd` job on macOS that discovers the current `utun` interface, or a
Windows Scheduled Task run at logon with highest privileges.

Keep the startup job limited to the one `/32`, and document the site, owner,
and reason for it. Recheck it whenever network addressing or Tailscale route
advertisements change.
