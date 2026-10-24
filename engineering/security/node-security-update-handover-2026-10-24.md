> **تقرير تسليم تحديثات Node.js الأمنية — Mosalam.com — 24 أكتوبر 2026**
> يتضمن التقرير نطاق تحديث الحاويات، إصدارات التشغيل، نتائج التحقق، تعديلات Docker Compose وDockerfile، وروابط الالتزامات والتقارير المرفوعة إلى مستودعات المشاريع. حُفظت التفاصيل التشغيلية بلغتها الأصلية، واستُبعدت كلمات المرور والرموز السرية ومفاتيح المصادقة. أسماء الخوادم والنطاقات والحسابات مسموح بنشرها. الأدلة الخاصة والنسخ الاحتياطية محفوظة على الخادم وليست مرفقات في هذا المستودع.

# Mosalam.com — Node.js Security Update Handover

**Date:** 24 October 2026<br>
**Company:** Mosalam.com<br>
**Server:** `root@49.12.59.140` / `hosting.mosalam.com` / `dockerstation.mosalam.com`<br>
**Classification:** Public handover copy. Passwords, tokens, private keys and private environment files excluded. Server identifiers, domains and account names retained as authorized.<br>
**Status:** Runtime rollout complete; source changes and per-repository reports pushed to all 19 associated repositories across 20 branches.

## Outcome

The inventory found 44 running containers containing Node.js across 27 Docker Compose projects, out of 156 running containers. **43 containers were updated; `bonagate-web` was already on a fixed release.** All 44 passed the final version checks. Every affected live Compose definition was updated, and application Dockerfiles were pinned for subsequent builds. No database services were recreated or upgraded.

| Verified Node version | Containers |
| --- | ---: |
| 22.23.4 | 28 |
| 24.22.1 | 15 |
| 26.12.1 | 1 |

Node 16, 18 and 20 deployments moved to supported Node 22. Existing Node 22, 24 and 26 deployments received the fixed version on their current major branch.

## Security basis

The [official Node.js October 2026 security advisory](https://nodejs.org/en/blog/vulnerability/october-2026-security-releases), published October 21, identifies fixed releases **22.23.4, 24.22.1 and 26.12.1**. This rollout addresses CVE-2026-111497 (Brotli decoder memory corruption) and the other branch-specific issues covered by that release. Use the advisory for the precise affected-version and CVE matrix. Release versions were cross-checked against the [official release index](https://nodejs.org/dist/index.json).

The patched Node version and the exact official executable hash are the verification criteria. A backported fix may retain an older Brotli component version string; that string alone is not evidence that the fix is absent.

## Runtime deployment method

Twenty-eight patched derivative images were built from the existing application images. Each copies the Node executable from an official image pinned by digest into the original executable path, preserving the deployed application code, dependencies, user, entrypoint, command, volumes and networking. This avoided rebuilding unrelated application changes during the emergency rollout. Original images remain tagged `local/node-security-original/<container>:20261024`; patched images use `local/node-security/<container>:<fixed-version>-20261024`.

Images were validated before applying sequential, service-scoped Compose updates with `up -d --no-deps --no-build --pull never`. Application source Dockerfiles were separately pinned to the patched Node versions and digests for normal future source builds. Those full application/dependency builds were not performed during this rollout. Existing npm versions and inherited operating-system packages were retained; this is a Node security release rollout, not a complete OS/dependency audit.

Special cases:

- Frappe/ERPNext images use Node inside NVM directories. The binary was replaced at the exact existing NVM path, preserving vendor startup behavior.
- One hardened n8n image uses Node at `/usr/bin/node`, and another at `/opt/nodejs/node-v24.13.1/bin/node`. These locations were preserved.
- The Node 26 hardened n8n image needed `libatomic.so.1`; it was copied from the same pinned official donor before deployment.
- Native addon load tests compared original and candidate images. No new addon load failures occurred, so no production dependency rebuild was needed. Platform-specific addons that already failed on the original image were not counted as regressions.

## Container-by-container record

| Project | Container | Before | Verified after | Image action |
| --- | --- | --- | --- | --- |
| `bonagate` | `bonagate-web` | v22.23.4 | v22.23.4 | Already patched; source pin added |
| `bonagate` | `bonagate-api` | v20.20.2 | v22.23.4 | Rebuilt and recreated |
| `versai` | `versai-versai-app-1` | v18.20.8 | v22.23.4 | Rebuilt and recreated |
| `the-battle-for-sovereignty` | `the-battle-for-sovereignty` | v20.20.2 | v22.23.4 | Rebuilt and recreated |
| `mosalam-social` | `mosalam-social-app-1` | v24.22.0 | v24.22.1 | Rebuilt and recreated |
| `muraji` | `muraji_app` | v22.23.3 | v22.23.4 | Rebuilt and recreated |
| `n8n-sam` | `n8n-sam-n8nsam-1` | v26.7.0 | v26.12.1 | Rebuilt and recreated |
| `amfurniture` | `amfurniture_web` | v20.20.2 | v22.23.4 | Rebuilt and recreated |
| `almarine-endpoint` | `almarine-endpoint-api-1` | v22.23.1 | v22.23.4 | Rebuilt and recreated |
| `physioaionline` | `physioai` | v22.23.2 | v22.23.4 | Rebuilt and recreated |
| `mosalam-erp` | `mosalam-erp-app-1` | v22.23.1 | v22.23.4 | Rebuilt and recreated |
| `deploy` | `deploy-ip-manager-api-1` | v22.23.1 | v22.23.4 | Rebuilt and recreated |
| `amigoo` | `backend` | v22.21.1 | v22.23.4 | Rebuilt and recreated |
| `aytaam-sys` | `raqi-backend` | v20.20.2 | v22.23.4 | Rebuilt and recreated |
| `construction-management` | `construction-management_api` | v20.20.2 | v22.23.4 | Rebuilt and recreated |
| `elmahdy-erp` | `elmahdy-api` | v22.23.1 | v22.23.4 | Rebuilt and recreated |
| `e-commerse` | `e-commerse-server-1` | v18.20.8 | v22.23.4 | Rebuilt and recreated |
| `filledin-talent` | `filledin_web` | v20.20.1 | v22.23.4 | Rebuilt and recreated |
| `n8n` | `n8n-n8n-1` | v22.21.0 | v22.23.4 | Rebuilt and recreated |
| `healthcare` | `healthcare-frontend-1` | v20.19.2 | v22.23.4 | Rebuilt and recreated |
| `maint-sys` | `maintenance-app` | v18.20.8 | v22.23.4 | Rebuilt and recreated |
| `erpnext-mosalam` | `erpnext-mosalam-frontend-1` | v24.12.0 | v24.22.1 | Rebuilt and recreated |
| `erpnext-mosalam` | `erpnext-mosalam-websocket-1` | v24.12.0 | v24.22.1 | Rebuilt and recreated |
| `erpnext-mosalam` | `erpnext-mosalam-backend-1` | v24.12.0 | v24.22.1 | Rebuilt and recreated |
| `erpnext-mosalam` | `erpnext-mosalam-queue-short-1` | v24.12.0 | v24.22.1 | Rebuilt and recreated |
| `erpnext-mosalam` | `erpnext-mosalam-scheduler-1` | v24.12.0 | v24.22.1 | Rebuilt and recreated |
| `erpnext-mosalam` | `erpnext-mosalam-queue-long-1` | v24.12.0 | v24.22.1 | Rebuilt and recreated |
| `fetrareact` | `ftrah_web` | v20.20.1 | v22.23.4 | Rebuilt and recreated |
| `ansar-elsona-backend` | `ansar-elsona-backend` | v20.20.2 | v22.23.4 | Rebuilt and recreated |
| `n8n-malekarksousisite` | `n8n-malekarksousisite-n8nmalekarksousi-1` | v24.13.1 | v24.22.1 | Rebuilt and recreated |
| `erpnext-buildingplants` | `erpnext-buildingplants-frontend-1` | v24.12.0 | v24.22.1 | Rebuilt and recreated |
| `erpnext-buildingplants` | `erpnext-buildingplants-backend-1` | v24.12.0 | v24.22.1 | Rebuilt and recreated |
| `erpnext-buildingplants` | `erpnext-buildingplants-queue-long-1` | v24.12.0 | v24.22.1 | Rebuilt and recreated |
| `erpnext-buildingplants` | `erpnext-buildingplants-scheduler-1` | v24.12.0 | v24.22.1 | Rebuilt and recreated |
| `erpnext-buildingplants` | `erpnext-buildingplants-queue-short-1` | v24.12.0 | v24.22.1 | Rebuilt and recreated |
| `erpnext-buildingplants` | `erpnext-buildingplants-websocket-1` | v24.12.0 | v24.22.1 | Rebuilt and recreated |
| `auditsystems` | `auditsystems-auditsystem.client-1` | v24.12.0 | v24.22.1 | Rebuilt and recreated |
| `amigoo` | `amigoo-frontend-1` | v16.20.2 | v22.23.4 | Rebuilt and recreated |
| `e-commerse-mosalam` | `e-commerse-mosalam-server-1` | v18.20.8 | v22.23.4 | Rebuilt and recreated |
| `healthcare` | `healthcare-backend-1` | v20.19.2 | v22.23.4 | Rebuilt and recreated |
| `healthcare` | `healthcare-scheduler-1` | v20.19.2 | v22.23.4 | Rebuilt and recreated |
| `healthcare` | `healthcare-websocket-1` | v20.19.2 | v22.23.4 | Rebuilt and recreated |
| `healthcare` | `healthcare-queue-short-1` | v20.19.2 | v22.23.4 | Rebuilt and recreated |
| `healthcare` | `healthcare-queue-long-1` | v20.19.2 | v22.23.4 | Rebuilt and recreated |

## Verification evidence

Final verification captured at **2026-10-24T00:19:17.004328+00:00**.

- All 44 in-scope containers reported their expected fixed Node version.
- All 43 replaced runtime executables matched the SHA-256 of the pinned official donor binary.
- Node processes inspected inside the affected containers matched their container's patched executable hash; no stale executable was observed.
- Brotli compression/decompression round trips passed.
- All 15 configured Docker health checks in scope were healthy. The other 29 containers do not define a Docker health check; a running state is not an independent health check.
- All 32 checked virtual-host root HTTP responses matched the pre-update baseline.
- All 113 containers outside the recreation set retained their original container IDs. This includes the already-patched `bonagate-web` and the database services.
- GitHub branch heads were read back after each push and matched the security commit IDs listed below.

These are infrastructure, executable, native-addon and HTTP smoke checks. Authenticated business workflows, background job correctness and full application regression suites were not exhaustively exercised.

| Virtual host | Before | After |
| --- | ---: | ---: |
| `7elhmbenhm.com` | 200 | 200 |
| `amfurniture.online` | 307 | 307 |
| `amigostore.online` | 200 | 200 |
| `ansar-elsona-backend.mosalam.com` | 404 | 404 |
| `api.almarinelogistic.com` | 404 | 404 |
| `api.amigostore.online` | 404 | 404 |
| `api.raqi.info` | 404 | 404 |
| `auditsystem.online` | 200 | 200 |
| `bonagate-backend.mosalam.com` | 404 | 404 |
| `bonagate.mosalam.com` | 307 | 307 |
| `construction-management.mosalam.com` | 404 | 404 |
| `e-commerce.mosalam.com` | 404 | 404 |
| `e-commerce.versai-home.com` | 404 | 404 |
| `elmahdy-app.mosalam.com` | 404 | 404 |
| `erp.buildingplants.com` | 200 | 200 |
| `erp.mosalam.com` | 200 | 200 |
| `erpp.mosalam.com` | 307 | 307 |
| `filledintalent.com` | 307 | 307 |
| `ftrah.com` | 200 | 200 |
| `healthcare.mosalam.com` | 500 | 500 |
| `ip-manager.mosalam.com` | 200 | 200 |
| `maintenancesystem.mosalam.com` | 404 | 404 |
| `moraje3.mosalam.com` | 200 | 200 |
| `n8n.a3elank.com` | 200 | 200 |
| `n8nsam.mosalam.com` | 200 | 200 |
| `n8nsy.mosalam.com` | 200 | 200 |
| `physioai.online` | 307 | 307 |
| `social.mosalam.com` | 303 | 303 |
| `versai-home.com` | 307 | 307 |
| `www.7elhmbenhm.com` | 200 | 200 |
| `www.auditsystem.online` | 200 | 200 |
| `www.physioai.online` | 301 | 301 |

## Incidents and existing faults

**Mosalam ERP configuration drift, resolved during rollout.** After container recreation, the app initially failed database authentication because the Compose defaults differed from the running database credential. The app authentication secret was also absent from the Compose invocation. The private live app database URL was reconciled with the existing, verified database credential, and the existing authentication secret was restored from the server's private delivery configuration. The database and its credential were not changed. Container health and the original HTTP 307 response were restored. Do not publish the corrected private Compose values or delivery environment file.

**Amigoo backend, pre-existing restart loop.** The container named `backend` already had over 43,000 restarts in the baseline. The Node runtime was updated, but this maintenance does not resolve that existing application issue. Its API root response remained HTTP 404.

**Healthcare, pre-existing HTTP 500.** `healthcare.mosalam.com` returned HTTP 500 before and after maintenance and needs separate application investigation. API root HTTP 404 responses elsewhere also matched their baseline behavior.

## Git changes and handover reports

Each of the following commits contains the relevant Dockerfile/Compose changes and `docs/operations/node-security-2026-10-24.md`. The report records the deployment, verification, limitations and recovery procedure for that repository. Commits use `[skip ci]` because production was already updated service by service; the source reconciliation did not trigger a second full-stack deployment pipeline.

Changes were prepared from clean mirrors of the current remote branches. Unrelated host edits, tracked live database data, environment files and credentials were excluded. Original live worktrees and their branch/index state were preserved; some live checkouts were behind their remote branch before this maintenance. Do not assume a clean live worktree merely because the corresponding remote security commit is pushed. Review local drift before any later pull, reset or full redeploy.

| Repository | Branch | Verified pushed commit | Projects |
| --- | --- | --- | --- |
| [Abdalaziz0486m/Bonagat-Project](https://github.com/Abdalaziz0486m/Bonagat-Project) | `main` | [99849c3b571f](https://github.com/Abdalaziz0486m/Bonagat-Project/commit/99849c3b571fcbb6e0482f51d3b176745d2b2f4b) | `bonagate` |
| [Abdalaziz0486m/almarine-mono](https://github.com/Abdalaziz0486m/almarine-mono) | `main` | [bf8b21505d06](https://github.com/Abdalaziz0486m/almarine-mono/commit/bf8b21505d06087cc5779565b2a5b236b2065dea) | `almarine-endpoint` |
| [Abdalaziz0486m/muraji](https://github.com/Abdalaziz0486m/muraji) | `master` | [be664cb569af](https://github.com/Abdalaziz0486m/muraji/commit/be664cb569af1008224011f99e5984b1c5ec4be3) | `muraji` |
| [Abdalaziz0486m/versai](https://github.com/Abdalaziz0486m/versai) | `master` | [aacb072f498e](https://github.com/Abdalaziz0486m/versai/commit/aacb072f498e7e611efb0f0c7f73d5aa8a888897) | `versai` |
| [Mohammed-Hafez-M/E-Commerse](https://github.com/Mohammed-Hafez-M/E-Commerse) | `main` | [289d29d5c958](https://github.com/Mohammed-Hafez-M/E-Commerse/commit/289d29d5c958f8194496f92844431ea2c7131924) | `e-commerse`, `e-commerse-mosalam` |
| [Mohammed-Hafez-M/al-mahdi-erp](https://github.com/Mohammed-Hafez-M/al-mahdi-erp) | `main` | [6da1a47ed3c7](https://github.com/Mohammed-Hafez-M/al-mahdi-erp/commit/6da1a47ed3c7798b2826ff1d72813749614b18b2) | `elmahdy-erp` |
| [Mohammed-Hafez-M/aytaam-sys](https://github.com/Mohammed-Hafez-M/aytaam-sys) | `ansar-elsona` | [ad44fd7b7222](https://github.com/Mohammed-Hafez-M/aytaam-sys/commit/ad44fd7b7222e65562cb191a098179a0b1187a07) | `ansar-elsona-backend` |
| [Mohammed-Hafez-M/aytaam-sys](https://github.com/Mohammed-Hafez-M/aytaam-sys) | `main` | [b4da4f7eef05](https://github.com/Mohammed-Hafez-M/aytaam-sys/commit/b4da4f7eef0512d72acf5947c37b93062e052abf) | `aytaam-sys` |
| [Mohammed-Hafez-M/construction-management](https://github.com/Mohammed-Hafez-M/construction-management) | `main` | [06a3267bf934](https://github.com/Mohammed-Hafez-M/construction-management/commit/06a3267bf934652855103cba68bb635e02b9f54c) | `construction-management` |
| [Mohammed-Hafez-M/maint-sys](https://github.com/Mohammed-Hafez-M/maint-sys) | `main` | [77c27dccf37a](https://github.com/Mohammed-Hafez-M/maint-sys/commit/77c27dccf37a22d49a7a0968cac0636290ee530e) | `maint-sys` |
| [NOUR-AWAWDEH/AuditSystems](https://github.com/NOUR-AWAWDEH/AuditSystems) | `main` | [cdb07ecab3a8](https://github.com/NOUR-AWAWDEH/AuditSystems/commit/cdb07ecab3a8b5e73d2a8fe53ae2a7da484999e6) | `auditsystems` |
| [ahmed2006tayson/mosalam-erp](https://github.com/ahmed2006tayson/mosalam-erp) | `main` | [6cfdf827ed0a](https://github.com/ahmed2006tayson/mosalam-erp/commit/6cfdf827ed0ab64c968f7dc7247c11a22686f4eb) | `mosalam-erp` |
| [ahmed2006tayson/mosalam-social-scheduler](https://github.com/ahmed2006tayson/mosalam-social-scheduler) | `main` | [1b1697e2ddea](https://github.com/ahmed2006tayson/mosalam-social-scheduler/commit/1b1697e2ddeaf218206dac261c7d2930850aadcc) | `mosalam-social` |
| [maher-elattar/proxmox-whmcs-cluster-ip-pool-manager](https://github.com/maher-elattar/proxmox-whmcs-cluster-ip-pool-manager) | `main` | [83a9673f4326](https://github.com/maher-elattar/proxmox-whmcs-cluster-ip-pool-manager/commit/83a9673f4326f3eab2214247976edd6e7c76bbe1) | `deploy` |
| [mosallamabdulrahman/7elhmbenhm-Game](https://github.com/mosallamabdulrahman/7elhmbenhm-Game) | `main` | [36372544e769](https://github.com/mosallamabdulrahman/7elhmbenhm-Game/commit/36372544e769c4b2ae43750decc20f7e4eeeb9f5) | `the-battle-for-sovereignty` |
| [mostafaomar7/Amigoo](https://github.com/mostafaomar7/Amigoo) | `main` | [dffcba665a20](https://github.com/mostafaomar7/Amigoo/commit/dffcba665a20afef24af41ac1d33c0c20ebabac7) | `amigoo` |
| [yasameenmsa/AMFurniture](https://github.com/yasameenmsa/AMFurniture) | `main` | [05fb0359aa4f](https://github.com/yasameenmsa/AMFurniture/commit/05fb0359aa4f97064eeb8c5cf1d3bd553f089266) | `amfurniture` |
| [yasameenmsa/FetraReact](https://github.com/yasameenmsa/FetraReact) | `main` | [01eeb706cf9e](https://github.com/yasameenmsa/FetraReact/commit/01eeb706cf9e54ed9e2c1150306c485f74a7ffdf) | `fetrareact` |
| [yasameenmsa/filledin-talent-Nextjs](https://github.com/yasameenmsa/filledin-talent-Nextjs) | `main` | [7061311ab7ab](https://github.com/yasameenmsa/filledin-talent-Nextjs/commit/7061311ab7abd408f03b3617761e0a4ba2bbf9b7) | `filledin-talent` |
| [yasameenmsa/physioaionline](https://github.com/yasameenmsa/physioaionline) | `main` | [92dd47aa2daa](https://github.com/yasameenmsa/physioaionline/commit/92dd47aa2daa1297f3f584caa9bb21996f6f5c16) | `physioaionline` |

Two E-Commerse deployments share the same repository and `main` branch, so they are covered by one source commit and one report. Their live Compose files retain their distinct deployment image tags and host settings. The two aytaam deployments use separate `main` and `ansar-elsona` branches and were pushed separately.

Some deployment Dockerfiles or Compose files had only existed on the host. Their required security definitions were added to the associated repository, with environment placeholders for sensitive settings. Added-line scans found no credential literals, credential-bearing URLs, private keys or GitHub token patterns in the published changes. This was a review of this change, not a historical secret audit of every repository.

## Projects without Git repositories

These six Compose projects had no Git repository at their deployment paths. Their live Compose files and rebuild definitions were updated on the server, and their changes are covered by this consolidated report in KnowledgeBase. No application repository push is applicable to them.

| Project | Live Compose file |
| --- | --- |
| `n8n-sam` | `/root/n8n-sam/docker-compose.yml` |
| `n8n` | `/root/n8n/docker-compose.yml` |
| `healthcare` | `/root/healthcare/healthcare.yaml` |
| `erpnext-mosalam` | `/root/gitops/erpnext-mosalam.yaml` |
| `n8n-malekarksousisite` | `/root/n8n-malekarksousisite/docker-compose.yml` |
| `erpnext-buildingplants` | `/root/gitops/erpnext-buildingplants.yaml` |

For services that originally had no build definition, patched overlay Dockerfiles are retained next to Compose under `ops/node-security/<image-name>/Dockerfile`. These vendor/application overlays rely on the retained original base image tag or pinned vendor digest. Custom `local/node-security-original/*` images are host-local and have not been published to a registry. A fresh server must restore those base images or rebuild the application from its patched source before rebuilding the overlay. Do not prune these original tags while they remain a recovery or rebuild dependency.

## Pinned official runtime donors

| Official image | Immutable digest |
| --- | --- |
| `node:22.23.4-alpine` | `sha256:fe4f6d74e20370acb04ad889077d14d0f64a9c8ea6a42bc60cddf1e844699914` |
| `node:22.23.4-bookworm-slim` | `sha256:de170b39439eb0e5a3444ad7d60b015614a381e10fecae2e30ec9e735122f38d` |
| `node:24.22.1-alpine` | `sha256:06d7adf3e0ef61a13f1d28682726366f97a15aa1888c934d3ecec86c33918b53` |
| `node:24.22.1-bookworm-slim` | `sha256:55fb5f5a527ea2c5c4a95f963e48ef90aa38c7b346054fdc8ee9957a2b55d205` |
| `node:26.12.1-alpine` | `sha256:40cd011b55415bc894e45b02fdd5a5dfde056921b7d23a64c74f80497af48797` |
| `node:22.23.4-bookworm` (full source-build base) | `sha256:63538dfe497cc29dfafdda25ada09b46db68a3f4cc205abf1f5d6bf0913f3384` |

## Operational evidence and retention

Root-only evidence directory: `/root/node-security-20261024/`.

| Artifact | Purpose |
| --- | --- |
| `inventory-before.json` | Original runtime versions, projects, paths and mounts |
| `all-containers-before.json` | Container IDs used to verify unrelated services were retained |
| `image-results.json` | Candidate images, pinned donors, original tags and addon preflight results |
| `deployment-results.json` | Per-container immediate version checks after recreation |
| `verification.json` | Final versions, health, executable hashes, HTTP comparison and unchanged IDs |
| `source-changes.json` | Modified host source paths |
| `backups/` | Original Dockerfiles and Compose files; private settings may be present |
| `images/` | Exact emergency image overlay Dockerfiles |
| `*.build.log`, `*.deploy.log` | Build and deployment logs |
| `git-push-manifest.json` | Final source commit IDs and verified remote branch heads |
| `Mosalam.com-Node-Security-Update-Handover-2026-10-24.md` | Consolidated handover copy |

Do not upload raw inventories, backups, runtime logs, private source exports or environment files to the public knowledge base without a separate secret review. This report intentionally carries the operational conclusions rather than those private files.

## Future deployments and recovery

For each project, use its actual Compose file and project name from the inventory. First check the private environment and `docker compose -p PROJECT -f COMPOSE config -q`. A future source rebuild should use the committed, pinned Dockerfiles and the correct build secrets. Existing patched images can be recreated with:

```sh
docker compose -p PROJECT -f COMPOSE up -d --no-deps --no-build --pull never SERVICE
docker exec CONTAINER node --version
```

Repeat health and virtual-host checks after any recreation. A successful root HTTP response does not replace application workflow testing. Preserve host-specific image tags when deploying two instances from the same repository branch.

For emergency incident recovery, record the current private settings, change only the affected service image reference to its retained `local/node-security-original/<container>:20261024` tag, then recreate only that service with `--no-deps --no-build --pull never`. Do not restore entire backups over the corrected ERP credentials, run `down`, remove volumes or stop databases. A rollback restores a vulnerable Node version and is temporary recovery, not a security-complete end state.

Follow-up work: investigate the existing Amigoo backend restart loop and healthcare HTTP 500; reconcile live Git/configuration drift under controlled application testing; publish reproducible vendor updates or retained custom base images to a suitable private registry before migrating this host.
