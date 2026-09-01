# Why a host route helps—and when it cannot

## The useful case: a distinct jumpbox behind an overlapping route

Suppose a Tailscale subnet router advertises `10.0.0.0/24`, while the client
also has a competing route for that range from its LAN or another VPN. If the
needed jumpbox is uniquely `10.0.0.5`, a client route for `10.0.0.5/32` through
the Tailscale interface is more specific than either `/24`. Standard
longest-prefix matching therefore selects the host route for that destination.

This limits the override to one host instead of sending the whole private
subnet through Tailscale. It is a pragmatic access path when the subnet router
cannot be changed and the jumpbox is the only system required.

## What the route does not do

There are two decisions in this design:

1. The client operating system chooses an interface based on the destination
   prefix.
2. Tailscale chooses an eligible subnet router for an advertised route.

The `/32` changes only the first decision. It makes packets for one address
enter Tailscale, but it does not attach a site identity to those packets or
force Tailscale to use a selected router.

Tailscale can use longest-prefix matching when advertisements have different
prefixes. For example, a `10.0.0.0/24` route is more specific than a
`10.0.0.0/16` route. However, routers advertising the *same* prefix are an HA
or regional-routing group, not separately selectable destinations. In the
default failover mode, Tailscale uses one primary router for that exact prefix.

Consequently, this does **not** work for three independent sites that all
advertise `10.0.0.0/24` and each contain `10.0.0.5`. Three identical commands
for `10.0.0.5/32` create only one route; neither the operating system nor
Tailscale can infer which site's `10.0.0.5` is meant.

## Designs for multiple sites

Choose the option that creates a real site-specific destination.

| Situation | Recommended access path |
|---|---|
| You control each jumpbox | Install Tailscale on each jumpbox and connect to its unique Tailscale IP or MagicDNS name. This is the simplest option. |
| You control the subnet routers and tailnet policy | Use Tailscale [4via6 subnet routing](https://tailscale.com/docs/features/subnet-routers/4via6-subnets), which gives identical IPv4 site networks distinct IPv6 route space. |
| Sites overlap only partially and target hosts have different IPv4 addresses | Advertise site-specific, more-specific prefixes where feasible, then use a `/32` client override only to beat a local competing route. |
| You control neither jumpboxes nor routers | Ask the network/tailnet administrator for a unique access endpoint. A client-side route cannot solve an ambiguous remote address. |

An exit node is not a general fix for two identical remote private networks:
it routes traffic through one chosen machine, but the private destination is
still ambiguous if multiple sites use the same address.

## Operational caveats

- A manual route can be lost on reboot, network changes, or Tailscale restart.
  Treat its persistence mechanism as configuration that needs an owner.
- A route only provides a path. Tailnet ACLs/grants and the jumpbox's own
  firewall and service authentication must still permit the connection.
- Test a named service such as SSH or RDP and verify the remote host identity.
  A successful connection to an IP address alone does not prove it is the
  intended site.
- More-specific Tailscale advertisements can deliberately take precedence over
  broader ones. If the more-specific router fails, Tailscale does not
  automatically fall back to a less-specific prefix; plan redundant routers to
  advertise the exact prefix when availability matters.

For Tailscale's routing behavior, see its documentation on [route injection](https://tailscale.com/docs/reference/route-injection), [overlapping-route failover](https://tailscale.com/docs/reference/troubleshooting/network-configuration/overlapping-subnet-route-failover), and [site-to-site networking](https://tailscale.com/docs/features/site-to-site).
