# How Services Are Hosted

Services are exposed through three complementary layers: Caddy for HTTP, Cloudflare Tunnels for public access, and Tailscale Serve for private access.

## Caddy (reverse proxy)

Caddy handles HTTP/HTTPS termination and reverse proxying. The base config (`services/caddy.nix`) enables ACME with Let's Encrypt.

Two helpers simplify configuration:

**`mkCaddyReverseProxies`** maps hostnames to local ports:

```nix
services.caddy.virtualHosts = lib.mkCaddyReverseProxies {
  "app.example.com" = 3000;
  "api.example.com" = 8080;
};
```

**`mkCaddyDdns`** adds Cloudflare Dynamic DNS for IPv6. It keeps AAAA records in sync with the host's Global Unicast Address, checking every 5 minutes. Each host filters its IPv6 by a unique token (e.g., `::e4de:a704`) to select the correct address on multi-homed machines.

## Cloudflare Tunnels (public access)

For services that need public URLs (e.g., `*.kedi.dev`), Cloudflare Tunnels provide secure ingress without opening firewall ports.

```nix
my-services.cftunnelConfig = [
  {
    tunnelId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
    tunnelName = "my-tunnel";
    ingress = {
      "app.kedi.dev" = "http://localhost:3000";
    };
  }
];
```

The module automatically wires vault-secrets for per-tunnel credentials. Multiple tunnels per host are supported.

## Tailscale (private access)

Every host runs Tailscale, and the Tailscale interface is marked as trusted in the firewall. This means any service binding to a port is automatically reachable by other tailnet machines, governed by Tailscale ACLs rather than per-port firewall rules. Most internal services (Prometheus exporters, databases, admin UIs) are accessed this way with no additional configuration: just `http://hostname:port`.

For services that need HTTPS or custom path routing on the tailnet, **Tailscale Serve** applies a JSON config at boot:

```nix
my-services.tailscaleServeConfig = {
  TCP."443".HTTPS = true;
  Web."${hostname}.tail.net:443".Handlers."/".Proxy = "http://localhost:3000";
};
```

## Typical service exposure

Most services follow one of these patterns:

| Pattern | Stack | Use case |
|---------|-------|----------|
| Public HTTPS | Caddy + Cloudflare Tunnel | Websites, public APIs |
| Public HTTPS + DDNS | Caddy + Cloudflare DDNS | Direct IPv6 access with auto-updated DNS |
| Tailnet (direct port) | Tailscale + ACLs | Most services: exporters, databases, admin UIs |
| Tailnet (HTTPS/paths) | Tailscale Serve | Services needing TLS or path-based routing on the tailnet |
| Local only | Direct port binding | Inter-service communication on the same host |
