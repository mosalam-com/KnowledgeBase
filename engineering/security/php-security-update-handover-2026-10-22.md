> **نسخة أرشيفية — تقرير تسليم تحديثات PHP الأمنية لخادم الاستضافة**<br>
> يُحفظ التقرير أدناه بلغته الأصلية لضمان دقة الأوامر والنتائج. روجعت النسخة قبل النشر لاستبعاد كلمات المرور والرموز السرية ومفاتيح المصادقة؛ بقيت أسماء الخوادم والنطاقات والحسابات كما هي. ملفات الأدلة والنسخ الاحتياطية المذكورة في التقرير محفوظة في مواقعها التشغيلية وليست مرفقات في هذا المستودع.

راجع أيضاً: [التقرير المرتبط](cpanel10-php-security-audit-2026-10-22.md).

# Mosalam.com — PHP Security Update Handover Report

**Document date:** 22 October 2026<br>
**Change date:** 21 October 2026<br>
**Company:** Mosalam.com<br>
**Audience:** Mosalam.com infrastructure, operations, security, and application maintainers<br>
**Classification:** Public knowledge-base copy; authentication secrets excluded.<br>
**Status:** Deployment completed; next-day runtime and HTTP checks passed. Maintenance-system source pushed to Git; the other 12 project sources await a writable repository destination.

**Fresh verification captured:** 2026-10-22 10:00:26 UTC / 2026-10-22 13:00:26 EEST (Africa/Cairo).

## 1. Outcome and scope

Mosalam.com updated all **17 PHP containers identified across 13 Docker Compose projects** on `hosting.mosalam.com`. This includes web application containers, PHP-FPM, and associated PHP cron containers. The deployed PHP versions are the emergency security releases for the compatible application branches:

| PHP version | Containers | Applications |
| --- | --- | --- |
| 8.2.35 | 6 | Production WHMCS; four legacy Moodle instances; maintenance phpMyAdmin |
| 8.3.36 | 7 | Mostafa Moodle web/cron; test WHMCS; Nextcloud web/cron; Hyper Deal WordPress; Leantime |
| 8.4.27 | 4 | Both Eramba installations and their cron containers |

All 17 containers remained running at the fresh verification, with **zero recorded container restarts** since their replacements were created. Both configured Docker health checks—Mostafa Moodle web and Leantime—reported healthy. The remaining 15 PHP containers do not define Docker health checks; their running state must not be interpreted as an independent health-check result.

The change applied the fixed release on each compatible PHP branch. It did **not** move every application to PHP 8.5. Production WHMCS moved from PHP 8.1 to 8.2 because its deployed encoded files support 8.2; moving further requires a compatible application distribution and validation.

### Security reason

The PHP project released fixes on 21 October 2026 for unauthenticated remote code execution vulnerabilities affecting PHP web request handling:

- **CVE-2026-109618:** memory corruption during out-of-memory handling.
- **CVE-2026-109619:** use of request state after its memory has been freed.

The PHP project identifies 8.2.35, 8.3.36, 8.4.27, and 8.5.12 as fixed releases. Mosalam.com's deployed versions address both CVEs. See the [official PHP security advisory](https://www.php.net/archive/2026.php#2026-10-21-5).

This was a patching operation. No forensic investigation, historical compromise assessment, or full application security audit was performed.

## 2. Server and access

| Item | Value |
| --- | --- |
| SSH endpoint | `root@hosting.mosalam.com` |
| Observed hostname | `dockerstation.mosalam.com` |
| Operating system at change | Debian; Linux kernel 6.1.0-53-amd64 |
| Deployment platform | Docker Engine with Docker Compose; Docker Swarm was inactive |
| Server-side change package | `/root/php-security-20261021/` |
| Server operational notes | `/root/php-security-20261021/README.md` |
| Local evidence accompanying this report | `mosalam-php-security-handover-evidence-2026-10-22.json` |

Connect with the existing authorized SSH key:

```sh
ssh root@hosting.mosalam.com
```

Commands in the operational sections below run **on that server as root**, unless explicitly described otherwise. No passwords, private keys, `.env` values, or application credentials are included in this report.

At the original inventory, the root filesystem had approximately 115 GB available and memory had approximately 15 GiB available. These are historical capacity observations, not current measurements. No host PHP service or additional PHP executable was found in the original host/running-container checks. The scope does not certify arbitrary offline backups, undeployed source trees, other hosts, or future containers.

## 3. Complete container inventory

The final column reflects the fresh verification on 22 October 2026. A dash under health means that the container has no configured Docker health check.

| Compose project / service | Container | Before PHP | Deployed PHP | Running / health / restarts |
| --- | --- | --- | --- | --- |
| `docker-leantime` / `leantime` | `docker-leantime-leantime-1` | 8.3.23 | 8.3.36 | Running / healthy / 0 |
| `eramba-ahmedalemam` / `cron` | `cron-ahmedalemam` | 8.4.18 | 8.4.27 | Running / — / 0 |
| `eramba-ahmedalemam` / `eramba` | `eramba-ahmedalemam` | 8.4.18 | 8.4.27 | Running / — / 0 |
| `eramba-docker` / `cron` | `cron` | 8.4.18 | 8.4.27 | Running / — / 0 |
| `eramba-docker` / `eramba` | `eramba` | 8.4.18 | 8.4.27 | Running / — / 0 |
| `hyperdeal` / `wordpress` | `hyperdeal_wp` | 8.3.27 | 8.3.36 | Running / — / 0 |
| `maint-sys` / `phpmyadmin` | `phpmyadmin-maintenance` | 8.2.27 | 8.2.35 | Running / — / 0 |
| `moodle-lms` / `moodle` | `moodle-lms-moodle-1` | 8.2.29 | 8.2.35 | Running / — / 0 |
| `moodle-medzilla` / `moodle` | `moodle-medzilla-moodle-1` | 8.2.29 | 8.2.35 | Running / — / 0 |
| `moodle-mostafa` / `cron` | `moodle-mostafa-cron-1` | 8.3.33 | 8.3.36 | Running / — / 0 |
| `moodle-mostafa` / `moodle` | `moodle-mostafa-moodle-1` | 8.3.33 | 8.3.36 | Running / healthy / 0 |
| `moodle-pmpenough` / `moodle` | `moodle-pmpenough-moodle-1` | 8.2.29 | 8.2.35 | Running / — / 0 |
| `moodlea-m-institutioneu` / `moodle` | `moodle` | 8.2.29 | 8.2.35 | Running / — / 0 |
| `nextcloud_redimpex` / `app` | `nextcloud_app` | 8.3.25 | 8.3.36 | Running / — / 0 |
| `nextcloud_redimpex` / `cron` | `nextcloud_cron` | 8.3.25 | 8.3.36 | Running / — / 0 |
| `whmcs` / `php-fpm` | `whmcs-php-fpm-1` | 8.1.33 | 8.2.35 | Running / — / 0 |
| `whmcstest` / `php-fpm` | `whmcstest-php-fpm-1` | 8.3.27 | 8.3.36 | Running / — / 0 |

### Authoritative Compose files

These are the host files used by the live projects. Changes to application repositories or another deployment definition can supersede these host changes; reconcile them before introducing a replacement deployment path.

| Compose project | PHP service(s) | Host Compose file |
| --- | --- | --- |
| `docker-leantime` | `leantime` | `/root/docker-leantime/docker-compose.yml` |
| `eramba-ahmedalemam` | `cron`, `eramba` | `/root/eramba-docker-ahmedalemam/docker-compose-server.yml` |
| `eramba-docker` | `cron`, `eramba` | `/root/eramba-docker/docker-compose-server.yml` |
| `hyperdeal` | `wordpress` | `/home/myoussef/hyperdeal/docker-compose.yml` |
| `maint-sys` | `phpmyadmin` | `/root/maint-sys/docker-compose-server.yml` |
| `moodle-lms` | `moodle` | `/root/moodle-lms/moodle-lms.yaml` |
| `moodle-medzilla` | `moodle` | `/root/moodle-medzilla/moodle-medzilla.yaml` |
| `moodle-mostafa` | `moodle`, `cron` | `/root/moodle-mostafa/docker-compose.yml` |
| `moodle-pmpenough` | `moodle` | `/root/moodle-pmpenough/moodle-pmpenough.yaml` |
| `moodlea-m-institutioneu` | `moodle` | `/root/moodle/moodle.a-m-institution.eu/docker-compose.yml` |
| `nextcloud_redimpex` | `app`, `cron` | `/root/nextcloud_redimpex/docker-compose.yml` |
| `whmcs` | `php-fpm` | `/root/whmcs/compose/docker-compose.yml` |
| `whmcstest` | `php-fpm` | `/root/whmcs-test/whmcs/compose/docker-compose.yml` |

## 4. Image and build definitions

All affected Compose services now use explicit `local/php-security/*` image tags and retained build contexts. These are **host-local image names**, not evidence of publication to an external registry. There is no recorded registry push, source-control push, or CI/CD reconciliation for this change.

Each row below is a distinct patched image. Several containers deliberately share an image. The original image references and original immutable image IDs are retained in `inventory-before.json`; current image IDs were captured in the accompanying local evidence file.

| Patched image tag | Container(s) | Build context |
| --- | --- | --- |
| `local/php-security/cron-ahmedalemam:8.4.27-20261021` | `cron-ahmedalemam`<br>`eramba-ahmedalemam`<br>`cron`<br>`eramba` | `/root/php-security-20261021/images/cron-ahmedalemam` |
| `local/php-security/hyperdeal-wp:8.3.36-20261021` | `hyperdeal_wp` | `/root/php-security-20261021/images/hyperdeal-wp` |
| `local/php-security/leantime:8.3.36-20261021` | `docker-leantime-leantime-1` | `/root/php-security-20261021/images/leantime` |
| `local/php-security/moodle-lms-moodle-1:8.2.35-20261021` | `moodle-lms-moodle-1` | `/root/php-security-20261021/images/moodle-lms-moodle-1` |
| `local/php-security/moodle-medzilla-moodle-1:8.2.35-20261021` | `moodle-medzilla-moodle-1`<br>`moodle`<br>`moodle-pmpenough-moodle-1` | `/root/php-security-20261021/images/moodle-medzilla-moodle-1` |
| `local/php-security/moodle-mostafa-moodle-1:8.3.36-20261021` | `moodle-mostafa-moodle-1`<br>`moodle-mostafa-cron-1` | `/root/php-security-20261021/images/moodle-mostafa-moodle-1` |
| `local/php-security/nextcloud-app:8.3.36-20261021` | `nextcloud_app` | `/root/php-security-20261021/images/nextcloud-app` |
| `local/php-security/nextcloud-cron:8.3.36-20261021` | `nextcloud_cron` | `/root/php-security-20261021/images/nextcloud-cron` |
| `local/php-security/phpmyadmin-maintenance:8.2.35-20261021` | `phpmyadmin-maintenance` | `/root/php-security-20261021/images/phpmyadmin-maintenance` |
| `local/php-security/whmcs-production:8.2.35-20261021` | `whmcs-php-fpm-1` | `/root/whmcs/compose/php-fpm` |
| `local/php-security/whmcstest-php-fpm-1:8.3.36-20261021` | `whmcstest-php-fpm-1` | `/root/php-security-20261021/images/whmcstest-php-fpm-1` |

### Standard runtime replacement

Nine derivative image builds cover 15 containers. Each starts from the original application image retained on the host and imports the fixed PHP runtime from an official PHP image pinned by digest, using the same PHP branch, Linux distribution, and Apache/FPM variant.

The replacement includes PHP CLI and web SAPI binaries, core OPcache/sodium modules, PHP headers/build tools, and the fixed PHP source archive. Existing application files, third-party extensions, and runtime configurations are retained. Validation compared loaded extensions with the original running containers and checked Apache/FPM configuration before deployment.

### Production WHMCS

- Container: `whmcs-php-fpm-1`; PHP **8.1.33 → 8.2.35**.
- Dockerfile: `/root/whmcs/compose/php-fpm/Dockerfile`, updated in place; the original is retained under the change package's `backups/` tree.
- Base: official PHP 8.2.35 FPM on Debian bookworm, pinned by digest.
- Required extensions are rebuilt for PHP 8.2, including ZIP, PDO MySQL, mysqli, GD, intl, OPcache, SOAP, and FTP; the base supplies the other core modules.
- ionCube PHP 8.2 loader **15.5.1** was verified. The download URL in the Dockerfile is a vendor rolling archive and was not pinned to a checksum; a future rebuild may obtain a later loader.
- The deployed encoded application headers advertise PHP 8.2 compatibility. The chosen release avoids requiring replacement of the WHMCS application distribution during the emergency change.
- Requiring `/var/www/html/init.php` against the existing application configuration/database succeeded before deployment and again after deployment.
- Test WHMCS retained its PHP 8.3 application environment and ionCube **15.0.0**; its application bootstrap also succeeded on PHP 8.3.36.

The bootstrap checks did not perform payment, provisioning, cancellation, or other business workflows.

### Leantime

- Container: `docker-leantime-leantime-1`; PHP **8.3.23 → 8.3.36**.
- Its original application image uses Alpine 3.22. The required official `php:8.3.36-fpm-alpine3.22` tag was unavailable during the change.
- PHP was therefore compiled from the 8.3.36 source archive supplied by a pinned official PHP image, inside the retained Alpine application image.
- The build retains the original configure options where applicable, uses PHP's compiler hardening flags, preserves third-party modules, and restores the `www-data` runtime user. The deprecated PEAR installer was disabled for this rebuild; no missing loaded runtime extensions were found.
- Build tooling and development packages are removed after compilation. Original FPM/application configuration remains in place.
- The final build and module preflight passed, and the replacement container's Docker health check is healthy.

### Scope of configuration changes

A parsed comparison of all 13 original and final Compose files confirmed that **only the targeted PHP services' `image` and `build` fields changed**. Volume definitions, service configuration, environment wiring, labels, networks, commands, and unrelated services were unchanged by those Compose edits. YAML formatting/comments may differ because the files were serialized during editing.

Production WHMCS's Dockerfile was also changed as described above. Other application code was not edited. No data/image prune or database migration was intentionally performed, and unrelated database services were not included in the PHP recreation commands.

## 5. Rollout and validation evidence

Container replacement start timestamps range from **21 October 2026 20:48:12 UTC to 20:56:15 UTC** (23:48:12 to 23:56:15 in Cairo). These timestamps describe the rollout sequence, not measured per-site downtime. Containers were recreated, so brief service interruptions were possible; zero downtime was not established.

The recorded checks covered:

1. PHP executable discovery across running containers and host PHP service discovery.
2. PHP version verification in all 17 affected containers.
3. Extension loading/module preservation and Apache or PHP-FPM configuration preflight.
4. SHA-256 comparison of each deployed web SAPI executable/module against its selected patched image artifact: 16 match official PHP runtime images; Leantime matches its source-built security image.
5. Both WHMCS application bootstraps and ionCube loading.
6. Container state, restart count, and configured health checks.
7. HTTPS routing and final HTTP response after redirects for 15 hostnames.
8. Page-title/content checks during the rollout, and a scan for PHP fatal/startup errors in sampled logs.
9. Comparison of original and updated Compose configuration to confirm change scope.

### HTTP results

The fresh checks use host-local routing through the server's reverse proxy: `curl --resolve <host>:443:127.0.0.1 -k -L`. They exercise application routing and page responses. They do **not** establish external DNS reachability, public network reachability, or certificate trust/expiry, because TLS certificate validation was disabled. Redirects to another hostname may use normal resolution.

| Hostname | Initial response at rollout | Final response at rollout | Fresh final response | Interpretation |
| --- | --- | --- | --- | --- |
| `ahmedalemam.com` | 302 | 200 | 200 | Expected home/login page |
| `app.hyprdeal.com` | 200 | 200 | 200 | Expected home/login page |
| `eramba.mosalam.com` | 302 | 200 | 200 | Expected home/login page |
| `fileshare.redimpexgroup.com` | 302 | 200 | 200 | Expected home/login page |
| `hosting.mosalam.com` | 200 | 200 | 200 | Expected home/login page |
| `leantime.mosalam.com` | 302 | 200 | 200 | Expected home/login page |
| `lms.hololpms.ws` | 200 | 200 | 200 | Expected home/login page |
| `lms.pmpenough.com` | 303 | 200 | 200 | Expected home/login page |
| `medzilla.online` | 303 | 200 | 200 | Expected home/login page |
| `moodle.a-m-institution.eu` | 200 | 200 | 200 | Expected home/login page |
| `moodle.pmpenough.com` | 200 | 200 | 200 | Expected home/login page |
| `mostafamoodle.mosalam.com` | 303 | 200 | 200 | Expected home/login page |
| `pma-maintenancesystem.mosalam.com` | 200 | 200 | 200 | Expected home/login page |
| `whmcstest.mosalam.com` | 401 | 401 | 401 | Expected authentication challenge |
| `www.medzilla.online` | 200 | 200 | 200 | Expected home/login page |

Test WHMCS's HTTP 401 is an expected authentication barrier, not evidence that an authenticated user journey was tested. Its PHP/application bootstrap was separately checked from inside the PHP container.

No recorded PHP fatal errors, missing-module errors, or container restart loops were found at completion. WordPress WPForms warnings described below were observed. Application uploads, background job completion, authenticated user journeys, payments, and provisioning were not comprehensively tested.

## 6. Files retained for handover

The server-side evidence root is `/root/php-security-20261021/`. Paths below are relative to that directory unless stated otherwise.

| Artifact | Purpose / limitation |
| --- | --- |
| README.md | Host operational notes and completion summary. |
| inventory-before.json | Original container names, PHP versions, image references/IDs, Compose files, and service mapping. |
| inventory-after.json | Final rollout snapshot: versions, modules, runtime, health, start timestamps, and restarts. |
| completion-summary.json | Recorded 17-container / 13-project completion totals. |
| runtime-image-plan.json; runtime-image-results.json | Nine standard derivative builds, covering 15 containers; production WHMCS and Leantime use their separate build paths. |
| images/*/Dockerfile | Nine standard derivative definitions and the separate Leantime definition. |
| /root/whmcs/compose/php-fpm/Dockerfile | Production WHMCS definition outside the evidence directory. |
| backups/ | Original Compose files and production WHMCS Dockerfile, preserving absolute-path structure underneath backups/. May contain credentials in configuration. |
| *.build.log; *.deploy.log | Build and deployment output, including failed/intermediate attempts where retained. The successful final state is identified by completion and final verification artifacts. |
| leantime-preflight.json | Leantime PHP 8.3.36 module check; no missing original loaded extensions. |
| whmcs-production-preflight.log | Production WHMCS pre-deployment bootstrap result. |
| http-before.json; http-after.json | HTTP baseline and final rollout checks; initial baseline covers 13 hosts, while final checks cover 15. |
| http-content-checks.json | Rollout page/title and fatal-error marker checks; collected before the final Leantime recreation. |
| web-runtime-hashes.json | 17 web SAPI artifact hash matches. |
| runtime-log-checks.json | Sampled runtime/startup log scan; includes WPForms warning evidence and was collected before final Leantime recreation. |
| all-container-php-binaries.json | Final broad running-container PHP executable scan. |
| compose-scope-verification.json | Parsed check confirming only targeted image/build fields changed in 13 projects. |
| build-runtime-images.py; deploy.py; verify.py; check-runtime-hashes.py | Retained build, deployment, and verification helpers. |

The local companion file `mosalam-php-security-handover-evidence-2026-10-22.json` (retained with the operator; not included in this repository) contains sanitized copies of the selected JSON artifacts, Dockerfiles/helper source, and a separate fresh runtime/HTTP snapshot captured at 2026-10-22 10:00:26 UTC. It does not include the server's `.env` files, application data, configuration backups, or image layers. The handover preparation did not redeploy services or overwrite the server's historical completion evidence.

Configuration backups and retained images are **not** a database backup. No new database backup, full host backup, or restore exercise was recorded as part of this change. Keep the server-side backup directory access restricted and handle configuration backups through Mosalam.com's protected storage process.

## 7. Operator runbook

### Inspect a single service

Example for production WHMCS:

```sh
docker inspect whmcs-php-fpm-1 --format '{{json .State}}'
docker exec whmcs-php-fpm-1 php -v
docker exec whmcs-php-fpm-1 php -m
docker exec whmcs-php-fpm-1 php-fpm -t
docker logs --since 15m --tail 100 whmcs-php-fpm-1
```

For an Apache service, use `apache2ctl -t` inside its container instead of `php-fpm -t`. Review log output before sharing it because application logs can contain sensitive information.

### Recreate an existing patched service

This example uses its already-built local security image and does not recreate its database:

```sh
docker compose -p whmcs \
  -f /root/whmcs/compose/docker-compose.yml config -q

docker compose -p whmcs \
  -f /root/whmcs/compose/docker-compose.yml \
  up -d --no-deps --no-build --pull never php-fpm
```

Use the exact project, file, and service names in section 3 for another deployment. Avoid a blanket `docker compose pull` for these custom local tags: they have not been published to a registry. Do not use `down -v` or prune images/volumes during routine recovery.

### Rebuild standard derivative images

The retained baseline, original application images, pinned donor images or registry access to them, Python 3, Docker, and build contexts are required:

```sh
python3 /root/php-security-20261021/build-runtime-images.py
```

This builds the **nine standard derivatives covering 15 containers**. It does not build production WHMCS or Leantime. Successful results are written to `runtime-image-results.json`; review every `ok`, missing-module list, and stderr value before deploying:

```sh
python3 /root/php-security-20261021/deploy.py
```

The deployment helper groups the baseline containers by Compose file, updates their image/build fields, validates Compose, and runs `up -d --no-deps --no-build --pull never`. It checks deployed PHP versions. Its default mode deploys the successful standard image results; it is not an all-or-nothing transaction, so a failed group does not undo earlier successful groups.

### Rebuild and deploy production WHMCS

```sh
docker build \
  -t local/php-security/whmcs-production:8.2.35-20261021 \
  /root/whmcs/compose/php-fpm

python3 /root/php-security-20261021/deploy.py production
```

Before deploying a **new rebuild**, repeat the WHMCS bootstrap/module preflight using the candidate image and the existing application's configuration/mounts in a controlled container. A successful bootstrap was demonstrated for the deployed artifact, but the deployment helper does not repeat that application-level check automatically. Verify current ionCube compatibility if its rolling download has changed.

### Rebuild and deploy Leantime

```sh
docker build \
  -t local/php-security/leantime:8.3.36-20261021 \
  /root/php-security-20261021/images/leantime

python3 /root/php-security-20261021/deploy.py leantime
```

Before deploying a **new rebuild**, compare loaded modules against the baseline and confirm the candidate has PHP 8.3.36 with a valid FPM configuration. A future build can obtain different Alpine packages from the package repositories, so rebuilds are not guaranteed to be byte-for-byte identical.

### Run saved verification helpers

These helpers write or replace their usual output JSON files. Preserve any historical files needed for incident records before rerunning them:

```sh
python3 /root/php-security-20261021/verify.py
python3 /root/php-security-20261021/check-runtime-hashes.py
```

`verify.py` collects observations; its successful exit alone is **not** a pass/fail guarantee. Review the JSON and check all of the following:

- Exactly 17 baseline PHP containers are present, running on their intended patched versions.
- Docker health is healthy where a check exists; no missing-extension stderr or restart loops appear.
- Each host returns HTTP 200 after redirects, except the expected test WHMCS HTTP 401.
- Every web runtime hash comparison reports `match: true`.

The hash helper validates artifact identity for web SAPI files; it is not a vulnerability scanner or a full filesystem integrity check. These helpers use this incident's baseline container list and fixed image plan, so update the verification baseline deliberately when undertaking a later release.

## 8. Recovery and rollback

**Preferred recovery:** diagnose the affected PHP container and repair forward with a patched image. The pre-change PHP versions are vulnerable to the incident CVEs.

For an incident requiring recovery:

1. Identify the exact affected project, service, and container using section 3. Preserve its current logs, image ID, Compose file, and verification output.
2. Check PHP version/modules, Apache/FPM configuration, mounts, container health, and the associated proxy route before changing application data.
3. Use the retained patched Dockerfile/image to rebuild or recreate only the affected PHP service. Keep its current volumes and database services.
4. If a temporary rollback is explicitly approved by the incident owner, first isolate public access to the affected application. Locate its original Compose file at `/root/php-security-20261021/backups/<original absolute path without the leading slash>` and its original image ID in `inventory-before.json`. Do not infer the original image from a mutable `latest` tag.
5. Restore only the necessary service definition/image after reviewing differences against any subsequent changes; use the exact original local image ID or retained `local/php-security-original/*:20261021` tag. Recreate the target with `--no-deps --no-build --pull never`; do not remove volumes. Verify functionality, record the temporary vulnerability exposure, then reapply a fixed image before restoring public access.

No rollback was required or performed during the completed rollout. The original images were retained for diagnosis/recovery. Production WHMCS's original immutable image ID is in `inventory-before.json`; a dedicated original-tag name should not be assumed for that image.

For recovery on a different or rebuilt host, the Dockerfiles alone are insufficient: the standard derivatives depend on the retained original application images. Preserve or securely export **both original and patched image artifacts**, the build contexts, required service configuration, and independently backed-up application/database data. Registry publication and off-host recovery validation remain follow-up work.

## 9. Known observations, limits, and follow-up ownership

| Priority | Action / observation | Suggested Mosalam.com owner | Status |
| --- | --- | --- | --- |
| High | Securely back up original and patched image artifacts plus build contexts; publish reviewed security images to the approved registry and reconcile authoritative repositories/CI so a later deployment cannot restore vulnerable images. | Infrastructure / DevOps | Not recorded as completed; host definitions and images are present. |
| High | Plan migration of the six PHP 8.2 containers before upstream security support ends on 31 December 2026. Production WHMCS requires a PHP-compatible encoded application release; legacy Moodle/phpMyAdmin need compatibility checks. | Application owners + infrastructure | Open follow-up. |
| Normal | Review WPForms Lite undefined array keys "url" and "path" in wp-content/plugins/wpforms-lite/src/Forms/IconChoices.php, lines 127–128. The WordPress homepage returned HTTP 200; plugin code was not edited. The evidence does not establish when these warnings first began. | WordPress / Hyper Deal maintainer | Observed during rollout; no plugin fix included. |
| Normal | Leantime logs contain a Supervisor pkg_resources deprecation warning and FPM notices about user/group directives while running as a non-root user. FPM/nginx/scheduler entered running state and health passed. | Leantime maintainer | Observed; no associated startup failure. |
| Normal | Add service-specific health checks where appropriate; 15 PHP containers currently have no Docker health check. | Infrastructure + application owners | Open improvement. |
| Normal | Perform external DNS/TLS checks and authenticated application-specific smoke tests, including relevant uploads, cron work, billing/provisioning, and backup/restore verification. | Operations + application owners | Beyond the completed smoke-test scope. |

The PHP 8.2 support deadline is documented in the [official supported versions table](https://www.php.net/supported-versions.php). Record named owners and delivery dates in Mosalam.com's normal change/issue system; the owner labels above are suggested responsibilities, not confirmed assignments.

The rollout addresses the two named PHP core CVEs in the identified runtimes. Existing application versions and most base-image packages were retained; no claim is made that all operating-system, dependency, plugin, or application vulnerabilities have been eliminated.

## 10. Receiving-team acceptance

The technical change is complete. The receiving team should:

- Confirm access to the host, report, companion evidence, and restricted server-side backups.
- Review the container/image/Compose mapping and confirm application ownership.
- Preserve original and patched image artifacts before image cleanup or host migration.
- Reconcile registry/source/CI deployment paths and assign the PHP 8.2 migration work.
- Record authenticated application checks, external TLS/DNS checks, and formal business acceptance separately.

No named receiving engineer, formal change-ticket reference, or business sign-off was provided in this workstream. Do not treat this report as a record of that acceptance.

## Appendix A. Pinned official PHP donors

These immutable donor digests were used for runtime replacement or source. Original application base images remain separate dependencies, identified in the baseline evidence.

| Official image / variant | Pinned digest |
| --- | --- |
| `php:8.2.35-apache-bookworm` | `sha256:92d2d6a7c7d372d3f19192b23366001edf55a054dc0e727a52c587f9d142fc81` |
| `php:8.2.35-apache-trixie` | `sha256:9e5766bc6f10979a782e11e883837f9ef35a344dbc1a9d0628a2307e8c21f9da` |
| `php:8.2.35-fpm-bookworm` | `sha256:df02d5357c8c1cd645c9a7e7d87efb278c8e2628016ae4556fdab24da7030c1e` |
| `php:8.3.36-apache-bookworm` | `sha256:28e0194d65d1c25ae279366137a027e2d8a835f1b37d8b96724a32c401ef99eb` |
| `php:8.3.36-apache-trixie` | `sha256:d89e8b3d2033c3179dcd9999d913670eb12a07410a95e60205c64e7d0fac7aef` |
| `php:8.3.36-fpm-trixie` | `sha256:0cd1acdea990e98f36f6605d01ce55f47eb7d49eb0f23c0765bd8b5621056f75` |
| `php:8.4.27-apache-trixie` | `sha256:e6bad969f0b673ce9121c88dabb53488ab1ca139d8ebfac1d1b1ab63f245f725` |

Leantime uses only the source archive from the FPM trixie donor; its runtime remains Alpine. The saved `images/*/Dockerfile` files identify the exact donor used for each derivative.

## Appendix B. Original images for recovery reference

Original image IDs below identify vulnerable pre-change artifacts. They are retained for evidence and controlled recovery, not routine redeployment.

| Original image reference | Original immutable image ID | Container(s) |
| --- | --- | --- |
| `ellakcy/moodle:postgresql_apache_403_php8.2` | `sha256:cd4e8e44cb8e4db34c08a2024ace507d8b0bcdf3731880597489bd1d62a80f71` | `moodle-medzilla-moodle-1`<br>`moodle`<br>`moodle-pmpenough-moodle-1` |
| `ellakcy/moodle:postgresql_apache_403_php8.2` | `sha256:43d2222d1ade1b7b1c811f52f935ae75f705e605bae0c1b032eaacdec9d89c50` | `moodle-lms-moodle-1` |
| `ghcr.io/edythecow/whmcs-php-fpm:php-8.3` | `sha256:0de109f00d70c29caf7cf185fe2eead3940d470c6e35b80a39b478f4da9cc5b2` | `whmcstest-php-fpm-1` |
| `ghcr.io/eramba/eramba:latest` | `sha256:10a665765961a484c249c42f07b11acd0cf167aa90f5a43c7126d5025af08a67` | `cron-ahmedalemam`<br>`eramba-ahmedalemam`<br>`cron`<br>`eramba` |
| `leantime/leantime:latest` | `sha256:0508bdf3a97aa8d974728cf8c82bb70fd6e92a3bc0bd1dc4b186a74452f7f146` | `docker-leantime-leantime-1` |
| `moodle-mostafa:5.2.2-php8.3` | `sha256:8a4e15036165bfc12925db1818210040a6a1546f85011878f0d23e2f1b6c0ce5` | `moodle-mostafa-moodle-1`<br>`moodle-mostafa-cron-1` |
| `nextcloud:30-apache` | `sha256:5232c0c6f22fac06feb17e005303b73867df828df2bbcebcf334e2c9acffaba0` | `nextcloud_app` |
| `nextcloud:apache` | `sha256:b443f21adbfa3536466b22c1e4126bd567d85d9e2f51c7c2e5f784b806b9b515` | `nextcloud_cron` |
| `phpmyadmin/phpmyadmin` | `sha256:0276a66ce3224417caa58f620278c4662a891c953b51dc604829e2cc286f531b` | `phpmyadmin-maintenance` |
| `whmcs-php-fpm` | `sha256:199a2d2294b79538b5b3d0f6a7b5330f15c4ed68307374ea292638319b438be4` | `whmcs-php-fpm-1` |
| `wordpress:php8.3-apache` | `sha256:7332768c717ffdc11b604ae2b4cd782ae434fd429d7a9365eecf40634e768ea0` | `hyperdeal_wp` |

## Appendix C. Web runtime integrity evidence

The table records the SHA-256 value of the Apache PHP module or FPM executable in each patched container. All comparisons matched the selected patched image artifact at rollout. The fresh verification reconfirmed image references and PHP versions; it did not repeat the entire file hash audit.

| Container | Web runtime file | SHA-256 | Matched |
| --- | --- | --- | --- |
| `cron` | `/usr/lib/apache2/modules/libphp.so` | `992b4b07fd4880b2dd5be75a4912e0dc619ca08e1a4ff0c7eac0dce4c1aa7c31` | Yes |
| `cron-ahmedalemam` | `/usr/lib/apache2/modules/libphp.so` | `992b4b07fd4880b2dd5be75a4912e0dc619ca08e1a4ff0c7eac0dce4c1aa7c31` | Yes |
| `docker-leantime-leantime-1` | `/usr/local/sbin/php-fpm` | `9802711af38af11ef029b34402617308d7b7dcd0ac67e71cb9a0e3913cb6e4be` | Yes |
| `eramba` | `/usr/lib/apache2/modules/libphp.so` | `992b4b07fd4880b2dd5be75a4912e0dc619ca08e1a4ff0c7eac0dce4c1aa7c31` | Yes |
| `eramba-ahmedalemam` | `/usr/lib/apache2/modules/libphp.so` | `992b4b07fd4880b2dd5be75a4912e0dc619ca08e1a4ff0c7eac0dce4c1aa7c31` | Yes |
| `hyperdeal_wp` | `/usr/lib/apache2/modules/libphp.so` | `eafbc01bd696bb4511eff14785520b730bed900a88cc5ca1837f52689c835416` | Yes |
| `moodle` | `/usr/lib/apache2/modules/libphp.so` | `caa626e6e5b520f5921bb0d9f01781a7cf0b9eab4d9e4cf1ee43324e619240ab` | Yes |
| `moodle-lms-moodle-1` | `/usr/lib/apache2/modules/libphp.so` | `09bdcae45ed6f81e890c0fc5ad47d45fcda7f09522a935677ab72bcc56fb33f9` | Yes |
| `moodle-medzilla-moodle-1` | `/usr/lib/apache2/modules/libphp.so` | `caa626e6e5b520f5921bb0d9f01781a7cf0b9eab4d9e4cf1ee43324e619240ab` | Yes |
| `moodle-mostafa-cron-1` | `/usr/lib/apache2/modules/libphp.so` | `9467c3d832d14355e2d260371e5777f59bbf5481d9eaf6abd0469fb1a26ff138` | Yes |
| `moodle-mostafa-moodle-1` | `/usr/lib/apache2/modules/libphp.so` | `9467c3d832d14355e2d260371e5777f59bbf5481d9eaf6abd0469fb1a26ff138` | Yes |
| `moodle-pmpenough-moodle-1` | `/usr/lib/apache2/modules/libphp.so` | `caa626e6e5b520f5921bb0d9f01781a7cf0b9eab4d9e4cf1ee43324e619240ab` | Yes |
| `nextcloud_app` | `/usr/lib/apache2/modules/libphp.so` | `eafbc01bd696bb4511eff14785520b730bed900a88cc5ca1837f52689c835416` | Yes |
| `nextcloud_cron` | `/usr/lib/apache2/modules/libphp.so` | `eafbc01bd696bb4511eff14785520b730bed900a88cc5ca1837f52689c835416` | Yes |
| `phpmyadmin-maintenance` | `/usr/lib/apache2/modules/libphp.so` | `09bdcae45ed6f81e890c0fc5ad47d45fcda7f09522a935677ab72bcc56fb33f9` | Yes |
| `whmcs-php-fpm-1` | `/usr/local/sbin/php-fpm` | `75eca080f8f0b47965e30ed781f65bfef5acb5d621bae6f2e427222c7e2381c5` | Yes |
| `whmcstest-php-fpm-1` | `/usr/local/sbin/php-fpm` | `c05fc7b4fa52c240c93ee21f2497bf897bd0bcdea3da0166c18cb06354ee4cdb` | Yes |

## References

- [PHP security advisory, 21 October 2026](https://www.php.net/archive/2026.php#2026-10-21-5).
- [PHP supported versions and security support dates](https://www.php.net/supported-versions.php).
- Host evidence: `/root/php-security-20261021/` on `hosting.mosalam.com`.

## Source-control addendum — 22 October 2026

This addendum supersedes the initial report's statement that no source-control push had been recorded.

- Maintenance system: the Compose phpMyAdmin image/build fields and a pinned, portable Dockerfile/operating notes were pushed to `Mohammed-Hafez-M/maint-sys`, branch `main`, [commit 2034204](https://github.com/Mohammed-Hafez-M/maint-sys/commit/203420485cd866a4820efebcd02f913b1b5f323c). The host Git checkout was fast-forwarded to this commit, preserving pre-existing application/database working-tree changes. Its live Compose build context now points to `./ops/php-security/phpmyadmin`. No container restart was performed for this source reconciliation.
- The commit skips CI because the existing main-branch workflow invokes a full-stack force recreation; the running PHP service was already patched and verified. The portable replacement image was independently rebuilt and checked at PHP 8.2.35 with valid Apache configuration.
- A complete proposed hosting source package covering all 13 projects and 17 PHP containers is prepared at `/home/maher/mosalam-php-security-git-sync/hosting-php-security/`, with a review copy at `/root/php-security-20261021/git-sync-review/hosting-php-security/` on the host. It contains 11 build contexts with pinned vendor bases, credential-free Compose sources, a project manifest, private credential extraction and Compose wrappers, and validation records.
- Nineteen credential fields were externalized into required private dotenv references. All 13 source Compose definitions were compared against the live resolved configurations using the existing credentials; they matched apart from the intended PHP build context. No credential values were published.
- Publication of the remaining 12 projects is pending a writable repository destination: eight stacks have no Git checkout, and four checkouts point to upstream vendor repositories where the authenticated account lacks push permission. The complete proposed package has not been pushed or adopted as the live entrypoint. The maintenance-system commit is the only completed Git push in this follow-up.

See `git-publication-status.json` and `source-config-validation.json` in the proposed package for the precise publication and validation state.
