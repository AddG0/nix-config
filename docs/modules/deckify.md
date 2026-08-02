# Deckify

Spotify in Gaming Mode. The only manual setup under `nixos/gaming` — Spotify
needs an app registered under your own account.

## Setup

1. Create an app at [developer.spotify.com](https://developer.spotify.com/dashboard).
   Under "Which API/SDKs are you planning to use?" tick **Web API** only.
2. Add a redirect URI of `https://<hostname>:39281/callback`, using that
   machine's hostname. Byte-for-byte, port and `/callback` included:

   ```
   https://freya:39281/callback
   https://demon:39281/callback
   ```

3. Gaming Mode → Deckify → Spotify Login, scan the QR with a phone on the same
   network.
4. Click past the certificate warning.
5. Paste the Client ID into the landing page.

Playback needs Spotify Premium. An app in dev mode allows 5 users.

## Troubleshooting

**Dashboard rejects the URI** — set `networking.domain` on the host, point the
resulting FQDN at its LAN address in DNS, and register that instead.

**Certificate has the wrong name** — only regenerated when absent:

```bash
rm /var/lib/decky-loader/data/Deckify/{cert.pem,key.pem}
```

**URL doesn't resolve on the phone** — the phone uses the router's DNS:

```bash
dig +short @<router-ip> <hostname> A
```

**Backend errors** — `/var/lib/decky-loader/logs/Deckify`.

## See Also

- [Modules](README.md)
- [adv-inn/Deckify](https://github.com/adv-inn/Deckify)
