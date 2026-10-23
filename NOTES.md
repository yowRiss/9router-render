# Deploy 9router 24/7 free on Render (no credit card)

State: kit ready at `/home/ris/9router_hf/render-deploy/` (Dockerfile + render.yaml).
Free dataset repo for backups: `kaiiyrzs/9router-data` (created Oct 2026).

## What this recipe gives you

- Runs the official prebuilt image `decolua/9router:latest` → builds in ~2 min on Render's free plan
- **Backup/restore survives Render's ephemeral disks *and* the 15-min sleep cycle**:
  at every boot it restores `/app/data` (your providers, API keys, settings) from
  `kaiiyrzs/9router-data` on HF; every 10 min it uploads a fresh backup
- Public HTTPS URL like `https://9router-xxxx.onrender.com`

## Trade-offs of the Render free plan

- Sleeps after **15 min idle**; first request wakes it in ~30–60 s
- ~512 MB RAM / 0.1 CPU — fine for a single user routing CLI traffic, tight for parallel heavy chats
- Background OAuth refresh jobs pause while asleep

## Steps (user, in browser)

1. **Push the kit to GitHub** (any 3 files: `Dockerfile`, `render.yaml`, `README.md`):
   either create a repo on github.com and drag-drop the files from
   `/home/ris/9router_hf/render-deploy/`, or:
   ```bash
   cd /home/ris/9router_hf/render-deploy
   git init -b main && git add . && git commit -m "9router render deploy"
   git remote add origin https://github.com/kaiiyrzs/9router-render.git
   git push -u origin main
   ```
2. **HF token**: create one at https://huggingface.co/settings/tokens → "Write" scope
   (needed only to push the backup archive).
3. **Render**: sign in at https://dashboard.render.com with GitHub (no card).
   New + → **Blueprint** → pick your `9router-render` repo.
   When the blueprint request asks for the secret `HF_TOKEN`, paste the token → Apply.
   If not prompted, add it later: service → Environment → add `HF_TOKEN`.
4. Wait for build/deploy, then open `https://9router-xxxx.onrender.com/dashboard`
   → login `123456` → **change the password** → connect providers.

## Notes

- Never put the HF_TOKEN into the GitHub repo — only in Render's dashboard (secret).
- The backup dataset repo is private; the tarball contains your provider tokens, keep it that way.
- If RAM issues appear (502/OOM on heavy streaming), consider HF Pro ($9/mo, 16 GB) or Oracle Always Free.
- Auto-deploys on every push to the repo (autoDeploy in render.yaml).
- Update 9router later: Render "Manual Deploy → Deploy latest reference" re-pulls `decolua/9router:latest`.
