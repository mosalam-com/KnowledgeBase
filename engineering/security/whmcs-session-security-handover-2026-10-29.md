> **Mosalam.com — تعطيل تتبع تقدم رفع الملفات في PHP — 29 أكتوبر 2026**
> طُبّق الإعداد على بيئتي WHMCS للإنتاج والاختبار، وتحققنا منه في خدمات PHP-FPM الفعلية. حُفظت التفاصيل التشغيلية بلغتها الأصلية، واستُبعدت بيانات المصادقة. يتضمن التقرير قيود صلاحيات Git والتحديثات المتبقية لتطبيق WHMCS.

# Mosalam.com — WHMCS PHP session upload progress mitigation

**Change date:** 29 October 2026<br>
**Host:** `49.12.59.140` / `hosting.mosalam.com`<br>
**Scope:** Production and test WHMCS PHP containers.<br>
**Result:** `session.upload_progress.enabled = 0` verified in both active PHP-FPM services.

## Reason and exact change

The [PHP advisory published October 23](https://www.php.net/archive/2026.php) recommends disabling session upload progress until the next regular bugfix release to mitigate CVE-2026-115560. The reported attack path requires an unusual combination of session serializer configuration and application code. Disabling the feature provides the recommended mitigation regardless of whether that combination is present. The existing October 21 PHP security patches are retained.

Added `php-fpm/session-security.ini` next to each live Compose file:

```ini
session.upload_progress.enabled = 0
```

Both `php-fpm` services now include this persistent read-only mount:

```yaml
- ./php-fpm/session-security.ini:/usr/local/etc/php/conf.d/zzzz-mosalam-session-security.ini:ro
```

The late-loaded PHP ini file applies before HTTP request parsing. This uses neither application `ini_set()` nor `.user.ini`. PHP session upload-progress tracking is disabled; the `file_uploads` setting was not changed.

## Deployment and verification

The same ini file was copied into each existing container at the configured destination, then only those two PHP containers were restarted. This activates the setting immediately without recreating containers or re-rendering their runtime environment. Container IDs and complete runtime environment arrays were checked before and after and were unchanged. The new Compose bind mounts take effect on subsequent container recreation, so the mitigation also survives replacement and image rebuilds performed through those Compose definitions.

| Environment | Container | PHP | CLI value | Active FPM value | HTTP result |
| --- | --- | --- | --- | --- | --- |
| Production | `whmcs-php-fpm-1` | 8.2.35 | 0 | 0 | `hosting.mosalam.com`: 200 |
| Test | `whmcstest-php-fpm-1` | 8.3.36 | 0 | 0 | `whmcstest.mosalam.com`: 401, expected authentication barrier |

Both live Compose definitions passed `docker compose config -q`, and PHP-FPM configuration tests passed before restart. The active-service checks used temporary PHP probes outside the application tree, invoked directly through FastCGI; each reported `fpm-fcgi` and the disabled setting. Probe files were removed afterward. Application files, databases, container images and WHMCS versions were not changed. Authenticated workflows and attachment uploads were not exhaustively tested.

## Live source locations

| Environment | Compose file | Ini file |
| --- | --- | --- |
| Production | `/root/whmcs/compose/docker-compose.yml` | `/root/whmcs/compose/php-fpm/session-security.ini` |
| Test | `/root/whmcs-test/whmcs/compose/docker-compose.yml` | `/root/whmcs-test/whmcs/compose/php-fpm/session-security.ini` |

Production is outside Git. The test checkout belongs to `EdyTheCow/docker-whmcs`, branch `master`, where the authenticated GitHub account has read access but no push permission. The company-fork attempt was also rejected for insufficient repository rights. A minimal source commit and handover report were prepared locally; the source patch and ini file are archived with the consolidated report in `mosalam-com/KnowledgeBase`. The upstream application repository has not been pushed. No credentials or environment files are in those artifacts.

The upstream patch changes only this mitigation. It does not publish earlier, unrelated host deployment edits. Apply it to the current patched deployment, and retain its existing fixed PHP image references; do not replace the live Compose file with an older upstream example.

## Evidence, rollback and remaining work

Root-only evidence: `/root/whmcs-session-security-20261029/`. `results.json` records the verified values and container identities; `backups/` contains the original Compose files. `*.inspect-private.json` contains private runtime environment data and must not be published.

To undo the mitigation, remove the new mount from both Compose files, remove the injected ini file from the existing containers and restart only the affected PHP services. Remove the corresponding source ini file if no longer used. This re-enables the advised-against feature, so keep the mitigation until an applicable PHP fix or revised official guidance is verified. Restoring an entire Compose backup is unnecessary.

WHMCS itself still needs a separate security update: production reports `8.13.2-release.1` and test `9.0.5-release.1`, both older than the [8.13.7 / 9.0.8 security fixes](https://blog.whmcs.com/133794/whmcs-908-and-8137-maintenance-releases). This session-setting change does not remediate those application vulnerabilities. The user's exact notification has not yet been supplied, so its additional requirements have not been matched.

Local upstream-source commit: `b87e2a25a4fa7e787b8d7a1577b0699d6d650d39` on `security/disable-session-upload-progress-20261029`. This commit is archived as [test-upstream.patch](whmcs-session-security-2026-10-29/test-upstream.patch), not pushed upstream.

Reproduction artifacts: [ini file](whmcs-session-security-2026-10-29/session-security.ini), [production Compose patch](whmcs-session-security-2026-10-29/production-compose.patch), [test live Compose patch](whmcs-session-security-2026-10-29/test-live-compose.patch). Compose patches use zero context to exclude unrelated private configuration. After review, apply them with `git apply --unidiff-zero` or make the equivalent mount change manually. Place the ini file under `php-fpm/session-security.ini` relative to each Compose file.
