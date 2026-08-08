# YT Lite Tunnel

YouTube without ads. Everything else — direct.

A small proxy: only YouTube traffic is routed through the server to strip ads, while all other traffic connects directly. Open source, no sign-up, no logs.

## How it works

Only requests to YouTube go through the tunnel server. Everything else (all other apps and sites) connects directly, as usual — so there's no slowdown or extra load for anything unrelated to YouTube.

```
Client (Happ)
        │
        ├── youtube.com / googlevideo.com ──▶  Tunnel server (VLESS + Reality)
        │
        └── everything else ────────────────▶  Direct connection
```

Under the hood, the tunnel itself uses **VLESS + Reality** on Xray-core — the connection to the server looks like ordinary HTTPS traffic to a masking domain, so it isn't fingerprinted as a proxy. Split-tunneling rules (which domains go through the tunnel vs. direct) are applied client-side via a Happ routing profile bundled in the subscription.

## Features

* 🎬 YouTube ads removed
* 🌍 Everything else routed directly — no impact on other traffic
* 🔓 Open source code
* 🚫 No sign-up required
* 🚫 No ads in the app itself
* 🚫 No logs kept
* 🖥️ Anyone can run their own server (see below)

## Getting started (use the public server)

1. Install [Happ](https://www.happ.su/main) — available for Android, Windows, macOS, Linux, iOS, and TV.
2. Copy the subscription link from the [landing page](https://venc0707.github.io/YT-Lite-Tunnel-/) (the "📋 Copy for Happ" button).
3. In Happ, choose "From the buffer" and paste it.
4. Connect. Done — YouTube without ads, everything else as usual.

## Running your own server

Since the project is open source, you're not limited to the public server. A minimal setup is:

1. Get a VPS (Ubuntu 22.04/24.04).
2. Install Xray-core:
   ```bash
   bash <(curl -Ls https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
   ```
3. Generate keys and IDs:
   ```bash
   xray x25519          # Reality private/public key pair
   openssl rand -hex 8  # shortId
   xray uuid            # client UUID
   ```
4. Copy [`config.example.json`](./config.example.json) to `/usr/local/etc/xray/config.json` and replace every `REPLACE_WITH_*` placeholder with your own values.
5. Pick a masking domain (`serverNames`) — a real, popular HTTPS site that isn't blocked in your target region.
6. Restart the service:
   ```bash
   systemctl restart xray
   systemctl status xray
   ```

Client connection link template:

```
vless://<UUID>@<SERVER_IP>:443?security=reality&sni=<MASK_DOMAIN>&fp=firefox&pbk=<PUBLIC_KEY>&sid=<SHORT_ID>&type=raw&flow=xtls-rprx-vision#My-Tunnel
```

Want help setting up your own server? Reach out on [Telegram](https://t.me/+s87tEkPayo9iOWFi) — we're happy to help.

## Project status & costs

The public server's live status, traffic usage, and monthly running costs are shown on the [landing page](https://venc0707.github.io/YT-Lite-Tunnel-/). The project is fully volunteer-funded — it stays online as long as donations cover hosting costs.

If you'd like to support the public server, see the Support the project section on the landing page, or the donation link there.

## Contributing

Issues and pull requests are welcome. If you find a bug or have a feature request, open an issue — or reach out on [Telegram](https://t.me/+s87tEkPayo9iOWFi), we reply there.

## What's NOT in this repo

- Real private keys, UUIDs, IPs, or masking domains — these are generated individually per server.
- The live public subscription URL — that's an operational detail of the hosted service, not part of the open-source example.

## License

MIT — use it, modify it, deploy it however you like.
