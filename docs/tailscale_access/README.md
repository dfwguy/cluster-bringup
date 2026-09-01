# Tailscale access to overlapping private networks

Guidance for reaching a known host behind a Tailscale subnet router when its
private address overlaps a local network or another VPN.

This documentation follows the [Diátaxis](https://diataxis.fr/) framework.

| Document | Type | Use it when |
|---|---|---|
| [Reach one jumpbox through an overlapping subnet](how-to/reach-one-jumpbox.md) | How-to | A Tailscale subnet route overlaps a less-specific local or VPN route and you need one known host |
| [Why a host route helps—and when it cannot](explanation/overlapping-private-networks.md) | Explanation | You need to understand route selection, identical address spaces, and the design choices for multiple sites |

## Scope

This is a client-side workaround for one distinct destination IP. It does not
make identical private IP addresses at different sites uniquely addressable.
For that case, use a Tailscale address on each jumpbox, or have the tailnet
administrator implement a site-aware design such as 4via6 subnet routing.
