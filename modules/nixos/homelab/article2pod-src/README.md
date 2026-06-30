# article2pod

Converts article URLs to MP3 podcast episodes, served as a private RSS feed.

## Architecture

```
Android/Desktop (must be on VPN) → reader.lan:80 (nginx)
  ├── POST  /add              ingest API (bearer token)
  ├── GET   /rss/{token}      podcast RSS feed
  ├── GET   /status           queue status
  ├── GET   /health           health check
  └── GET   /audio/*.mp3      nginx static (served directly from HDD)

article2pod-worker.timer (every 2 min):
  DB queued → trafilatura extract → [FlareSolverr fallback]
            → Kokoro-FastAPI TTS (CPU, port 8880)
            → ffmpeg concat + ID3 tags
            → /mnt/storage/podcasts/audio/{guid}.mp3
            → DB done
```

## Storage layout

```
/mnt/storage/podcasts/audio/   MP3 files (one per article)
/var/lib/article2pod/db.sqlite  SQLite queue and episode index
/mnt/cache/article2pod/models/  Kokoro model weights (NVMe, persist across rebuilds)
```

## Deploy

After `rebuild` completes:

1. **Verify Kokoro is up** (model download takes several minutes on first start):
   ```bash
   systemctl status docker-kokoro-fastapi
   journalctl -u docker-kokoro-fastapi -f
   curl -s http://localhost:8880/health
   ```

2. **Pin the Kokoro image to a digest** (for reproducibility):
   ```bash
   docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/remsky/kokoro-fastapi:v0.5.0-cpu
   # Copy the sha256 digest, then in hosts/optiplex-nas/default.nix:
   #   kokoroImage = "ghcr.io/remsky/kokoro-fastapi@sha256:<digest>";
   # Then rebuild again.
   ```

3. **Retrieve your token** (needed for all operations):
   ```bash
   TOKEN=$(sudo cat /run/secrets/article2pod-token | grep -o 'ARTICLE2POD_TOKEN=[^ ]*' | cut -d= -f2)
   echo $TOKEN
   ```

4. **Test the full pipeline**:
   ```bash
   curl -s http://localhost:8100/health
   curl -X POST http://reader.lan/add \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"url":"https://www.example.com/some-article"}'
   # Wait up to 2 min for the timer to fire, then:
   curl -s http://reader.lan/status -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
   curl -s "http://reader.lan/rss/$TOKEN" | head -40
   ```

## Adding articles

### Android — HTTP Shortcuts app

1. Install **HTTP Shortcuts** (F-Droid or Play Store)
2. Create a new shortcut:
   - **Method**: POST
   - **URL**: `http://reader.lan/add`
   - **Headers**: `Authorization: Bearer <your-token>`, `Content-Type: application/json`
   - **Body**: `{"url": "{shared_text}"}`
   - **Share target**: enable "URL" sharing
3. Phone must be connected to the VPN to submit

### Desktop — bookmarklet

Paste this into your browser's bookmarks bar (replace `TOKEN` and hostname):

```javascript
javascript:(function(){
  var u=encodeURIComponent(location.href);
  fetch('http://reader.lan/add',{
    method:'POST',
    headers:{'Authorization':'Bearer TOKEN','Content-Type':'application/json'},
    body:JSON.stringify({url:location.href})
  }).then(r=>r.json()).then(d=>alert('article2pod: '+d.status));
})();
```

## Subscribing in AntennaPod

1. Open AntennaPod → Add Podcast → Add podcast by RSS address
2. Enter: `http://reader.lan/rss/<your-token>`
3. Phone must be on the VPN to subscribe and to stream/download episodes

## Switching TTS backend

Edit `hosts/optiplex-nas/default.nix`:

```nix
article2pod = {
  ttsBackend = "piper";          # switch to remote Piper
  piperUrl   = "http://mini.lan:10200";  # Wyoming HTTP endpoint on mini-server
};
```

Then `rebuild`. Kokoro container keeps running but the worker will call Piper instead.
To switch back: set `ttsBackend = "kokoro"` and rebuild.

Note: Piper lives on mini-server behind the OpenBSD firewall on a separate subnet.
Connectivity is not guaranteed — treat it as optional. Kokoro is the default and primary backend.

## Blocking a bad Cloudflare page

If FlareSolverr can't bypass a page, the article will be marked `failed` in the DB.
Check logs: `journalctl -u article2pod-worker --since "1 hour ago"`

You can retry a failed article by resetting it in the DB:
```bash
sudo -u article2pod sqlite3 /var/lib/article2pod/db.sqlite \
  "UPDATE articles SET status='queued', error=NULL WHERE url='https://...';"
```

## Monitoring

```bash
journalctl -u article2pod-api -f          # API logs
journalctl -u article2pod-worker -f       # per-run synthesis logs
journalctl -u docker-kokoro-fastapi -f    # Kokoro container logs
systemctl status article2pod-worker.timer  # timer state
```
