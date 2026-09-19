# homelab-ci

Shared CI + host scripts for homelab apps.

## `komodo-deploy.yml`

Reusable GitHub Actions workflow: build → GHCR → Komodo `DeployStack` → ntfy.

```yaml
jobs:
  deploy:
    uses: deeepanshu/homelab-ci/.github/workflows/komodo-deploy.yml@main
    permissions:
      contents: read
      packages: write        # required: callee cannot elevate GITHUB_TOKEN
    with:
      stack: family-os
      image_name: deeepanshu/family-os-health-api
      image_tag_variable: FAMILY_OS_IMAGE_TAG
      image_path_regex: '^(apps/api/|Dockerfile$)'
      deploy_path_regex: '^(infra/docker/|grafana/dashboards/|\.github/workflows/deploy-service\.yml$)'
      caller_event: ${{ github.event_name }}
      caller_before: ${{ github.event.before }}
      image_tag: ${{ github.event.inputs.image_tag }}
    secrets: inherit
```

Secrets live on each caller repo: `KOMODO_API_KEY`, `KOMODO_API_SECRET`, `NTFY_SERVER`, `NTFY_TOPIC`, and optionally `NTFY_TOKEN`.
Komodo stack env must use `IMAGE_TAG=[[<image_tag_variable>]]`.

## `scripts/sync-grafana-dashboards.sh`

Copies an app repo's `grafana/dashboards/*.json` to the observability stack
(CT 113), where Grafana's file provider picks them up on its next poll.

Installed once per host as a **Komodo Repo resource**, so every stack shares one
copy instead of vendoring the script into each repo:

| | |
|---|---|
| Repo resource | clone `homelab-ci` on the apps server |
| Clone path | `/etc/komodo/repos/homelab-ci` |
| Stack `post_deploy.path` | `.` (the stack's own repo root) |
| Stack `post_deploy.command` | `/etc/komodo/repos/homelab-ci/scripts/sync-grafana-dashboards.sh` |
| Default `DEST_DIR` | `/etc/komodo/repos/observability/grafana/provisioning/dashboards/files/apps` |

`SRC_DIR` defaults to `grafana/dashboards` and resolves against the stack's run
directory, so each app publishes its own dashboards with no per-repo script.

Overridable by env: `SRC_DIR`, `DEST_HOST`, `DEST_DIR`.

Safe by construction: Komodo treats a `post_deploy` failure as a log, not a
failed deploy — a sync problem cannot roll back the app.
