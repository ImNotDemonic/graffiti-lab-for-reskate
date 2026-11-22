# Graffiti Lab gallery service

The ReSkate ZIP contains the gallery client. The Worker and its D1 database run separately. Publishing is open to provisioned creators. Browsing and downloading are public. The creator name comes from the account, and each account can unpublish its own work. The first frame supplies the thumbnail. Static rectangles and up to eight silent animation frames use the same versioned ink format. No uploaded executable, asset path, URL or compressed archive is accepted.

## Live Graffiti Lab test

The live Worker is `https://graffiti-lab-gallery.graffiti-lab-gallery.workers.dev`. Check `GET /v1/browse` for a real database response. Its D1 database is named `graffiti-lab-gallery` and the binding is `DB`. The plugin manifest lists that exact hostname. Browse uses GET. Signed-in download uses POST /v1/download and returns the downloader's server-verified display name alongside the original creator. Guests can also download.

In ReSkate, open **Ctrl+L → Public Artworks**. **Account** lists operator-issued keys stored only on this PC in `Mods/.reskate_plugin_data/GraffitiLab/gallery/accounts/NAME.key`. Choose a profile before publishing. **Publish** lists local imports and saved Blackbook files. Preview a piece, enter its public metadata and confirm. **Browse** searches, previews and downloads to **Premade Art → My imports**. The downloaded record preserves title, creator, tags and description separately from the original source. Repeated downloads leave the local copy intact. Version 0.7.0 places static ink artwork and reports unsupported animation or sound.

On 21 November 2026, Lab Test Artist published the original two-colour Lab Relay design in San Vansterdam. Lab Test Visitor then selected it in Browse and downloaded it on the same ReSkate installation. ReSkate logged both operations with ID `bcf77607-bbd5-484c-a608-59d04ffe59ba`. The published frame and the frame saved on disk matched byte for byte. The original uses Windows line endings, which the service normalises. The canvas dimensions, seven ink rectangles and both colours survived the exchange. [Public listing](https://graffiti-lab-gallery.graffiti-lab-gallery.workers.dev/v1/browse?q=Lab%20Relay)

For an independent two-machine check, put a different creator key on each machine, publish a test drawing on the first, then browse, select and download it on the second. Restart the second client without contacting the gallery and place the copy from My imports. Keep test keys private.

## Deploy

1. Sign in to Cloudflare and create a Workers subdomain. Create a D1 database named `graffiti-lab-gallery`. Copy its database ID into the `DB` binding in `wrangler.jsonc`.
2. Install Node 24 and pnpm. From this directory, run `pnpm install --frozen-lockfile`. Sign in with `pnpm exec wrangler login`. Apply the versioned schema with `pnpm exec wrangler d1 migrations apply graffiti-lab-gallery --remote`, then run `pnpm exec wrangler deploy`. A Hello World starter alone has no gallery API.
3. Visit `https://YOUR-WORKER/v1/browse`. A fresh database should return a JSON page with an empty `items` array. Configure that exact hostname in the client package before distributing it. ReSkate requires HTTPS on port 443, public DNS, no redirect and a manifest domain allowlist.
4. Run `node creator.mjs "Artist name"` privately for each publisher. Run its single INSERT in D1. Give only the creator key to its owner privately. Do not commit the key, put it in a URL, or include it in a mod ZIP. To revoke an account's publishing key, replace its hash in D1.
5. Review reports with `SELECT * FROM reports`. To hide reported work, set `visible=0` on that artwork in the authenticated D1 console. Public discovery and download both stop serving it. Offline copies already downloaded stay with their owners.

The client uses GET for discovery and download and POST with a JSON body for authenticated writes. Do not log request bodies. A publication uses a caller-generated operation ID so a lost reply can be retried without creating a second piece. For production, configure rate limiting in the hosting account, restrict D1 operator access and use database backups.

## Test locally

Run `node test.mjs` with Node 24+. It runs the Worker handler through a real HTTP socket and an isolated SQLite database. It exercises two creator identities. For Cloudflare's runtime, use `pnpm exec wrangler d1 migrations apply graffiti-lab-gallery --local` and `pnpm exec wrangler dev`. ReSkate cannot call the local address. The final transport test requires a deployed public Worker and a package configured for its hostname.

[Workers hosting](https://developers.cloudflare.com/workers/configuration/routing/workers-dev/) · [D1 setup](https://developers.cloudflare.com/d1/get-started/)
