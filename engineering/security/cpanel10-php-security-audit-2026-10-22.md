> **نسخة أرشيفية — تقرير فحص PHP الأمني لخادم cPanel**<br>
> يُحفظ التقرير أدناه بلغته الأصلية لضمان دقة الأوامر والنتائج. روجعت النسخة قبل النشر لاستبعاد كلمات المرور والرموز السرية ومفاتيح المصادقة؛ بقيت أسماء الخوادم والنطاقات والحسابات كما هي. ملفات الأدلة والنسخ الاحتياطية المذكورة في التقرير محفوظة في مواقعها التشغيلية وليست مرفقات في هذا المستودع.

راجع أيضاً: [التقرير المرتبط](php-security-update-handover-2026-10-22.md).

# Mosalam.com — cpanel10 PHP Security Audit

**Audit date:** 22 October 2026<br>
**Server:** `root@cpanel10.mosalam.com`<br>
**OS:** CloudLinux 9.8<br>
**Scope:** Installed managed PHP runtimes and evidence of fixes for CVE-2026-109618 / CVE-2026-109619.<br>
**Action taken:** Inspection only; no package upgrades, service restarts, or configuration changes. Package repository metadata was refreshed to check availability.

## Result

**One internal runtime remains on a pre-fix build:** `alt-php-internal` **8.2.34-3.el9**. Its CLI/common/core packages were installed on 3 October 2026; their latest changelog entry is dated 30 September and contains neither CVE fix. RPM verification reports group ownership differences but no file-content checksum differences, so the executable content still matches that older installed package. Treat this runtime as unpatched pending a fixed vendor build or explicit vendor confirmation.

The runtime is located at `/opt/alt/php-internal/usr/bin/php`; its package also supplies `php-cgi`, `lsphp`, and `phpdbg`. Installed dependencies include `ai-bolit` and `app-version-detector`, used by CloudLinux/Imunify tooling. It is not an assigned runtime in the 109 website entries returned by WHM, and no process using it was observed during the process snapshot. This does not establish that every possible indirect invocation or exposure path is absent.

After refreshing enabled repository metadata, the latest offered `alt-php-internal-cli` and `alt-php-internal-common` remained **8.2.34-3.el9**, from `alt-common` and `cloudlinux-x86_64-server-9`. No newer fixed internal package was offered in those enabled repositories at audit time. No testing repository was enabled and no package was installed.

## Patched components

- **cPanel & WHM:** `11.138.0.18`, a fixed cPanel release.
- **cPanel's bundled internal PHP:** `cpanel-php84-8.4.27-1.cp130~el9`, including the PHP-FPM runtime used by cPanel services.
- **All 26 website PHP variants:** 11 EasyApache branches (5.6, 7.0–7.4, 8.0–8.4) and 15 alt-PHP branches (5.2–5.6, 7.0–7.4, 8.0–8.4). Installed CLI/common package changelogs explicitly identify both CVEs. The installed alt-PHP FPM packages were checked separately and also record both fixes.

CloudLinux backports retain older upstream version numbers. For example, `8.2.34`, `8.3.35` and `8.4.26` can be fixed when their package release carries the backport. The conclusion here uses package revisions and changelogs, not only `php -v`. See [CloudLinux's incident guidance](https://cloudlinux.statuspage.io/incidents/zl0vt1yq3dj5) and the [cPanel security advisory](https://support.cpanel.net/hc/en-us/articles/44397389677335-Critical-PHP-Security-Release-CVE-2026-109618-and-CVE-2026-109619).

## Installed website PHP package revisions

| Runtime package | Installed version / release | Both CVE fixes in installed changelog |
| --- | --- | --- |
| `alt-php52-common` | `5.2.17-242.el9` | Yes |
| `alt-php53-common` | `5.3.29-220.el9` | Yes |
| `alt-php54-common` | `5.4.45-203.el9` | Yes |
| `alt-php55-common` | `5.5.38-183.el9` | Yes |
| `alt-php56-common` | `5.6.40-147.el9` | Yes |
| `alt-php70-common` | `7.0.33-148.el9` | Yes |
| `alt-php71-common` | `7.1.33-114.el9` | Yes |
| `alt-php72-common` | `7.2.34-97.el9` | Yes |
| `alt-php73-common` | `7.3.33-82.el9` | Yes |
| `alt-php74-common` | `7.4.33-81.el9` | Yes |
| `alt-php80-common` | `8.0.30-69.el9` | Yes |
| `alt-php81-common` | `8.1.34-39.el9` | Yes |
| `alt-php82-common` | `8.2.34-7.el9` | Yes |
| `alt-php83-common` | `8.3.35-6.el9` | Yes |
| `alt-php84-common` | `8.4.26-5.el9` | Yes |
| `ea-php56-php-cli` | `5.6.40-25.el9.cloudlinux.18` | Yes |
| `ea-php70-php-cli` | `7.0.33-29.el9.cloudlinux.17` | Yes |
| `ea-php71-php-cli` | `7.1.33-20.el9.cloudlinux.17` | Yes |
| `ea-php72-php-cli` | `7.2.34-12.el9.cloudlinux.18` | Yes |
| `ea-php73-php-cli` | `7.3.33-15.el9.cloudlinux.18` | Yes |
| `ea-php74-php-cli` | `7.4.33-18.el9.cloudlinux.13` | Yes |
| `ea-php80-php-cli` | `8.0.30-11.el9.cloudlinux.1` | Yes |
| `ea-php81-php-cli` | `8.1.34-4.el9.cloudlinux.1` | Yes |
| `ea-php82-php-cli` | `8.2.34-2.el9.cloudlinux.1` | Yes |
| `ea-php83-php-cli` | `8.3.35-2.el9.cloudlinux.2` | Yes |
| `ea-php84-php-cli` | `8.4.26-2.el9.cloudlinux.1` | Yes |

## Website assignments

The system default is `ea-php81`, backed by the patched CloudLinux package `8.1.34-4.el9.cloudlinux.1`. WHM returned 109 website entries, including aliases/subdomains and potentially suspended entries; this count is not a count of unique customers or independently tested live websites.

| Assigned PHP version | Website entries |
| --- | --- |
| `ea-php74` | 2 |
| `ea-php80` | 1 |
| `ea-php81` | 87 |
| `ea-php82` | 18 |
| `ea-php84` | 1 |

All assigned versions in this list correspond to patched package branches. PHP Selector can redirect individual users to alt-PHP through CageFS; all installed alt-PHP branches were also checked for the fixes. No migration of customer sites to a newer PHP branch was performed.

## Running processes and CageFS

- No running PHP executable marked `(deleted)` and no deleted PHP library mappings were found in the inspected snapshots.
- The running cPanel, EasyApache and alt-PHP FPM executable hashes matched the currently installed runtime binaries.
- A running CageFS PHP 8.1 CGI process was read through `/proc/<pid>/exe`; its executable hash matched the installed patched `ea-php81` CGI binary. Its `.cagefs` pathname refers to the CageFS execution view, not the small host-side selector metadata file.
- Thirty regular EasyApache executable copies in the CageFS skeleton matched their host counterparts by SHA-256. Three PHP 8.1 entries are selector links and cannot be resolved directly as regular files outside a user's CageFS namespace; the active CGI process was verified as described above.
- The inspected alt-PHP skeleton binaries are hard links to the corresponding host binaries, including the older internal runtime.
- The root Docker-compatible container listing is an empty Podman store; no root-owned PHP container was discovered through that interface.

## Follow-up

1. Raise the remaining `alt-php-internal-8.2.34-3.el9` gap with CloudLinux/Imunify, providing the exact installed package revisions and changelog result. Request a fixed internal package or a vendor statement documenting applicability and remediation.
2. Monitor the enabled repositories for a fixed internal release; validate its changelog and consumers before promotion. A blind upgrade currently offers the same build. Do not replace scanner tooling's internal runtime with a website PHP binary without checking vendor compatibility.
3. Keep the installed website backports in place. This audit establishes the two specific PHP core fixes; it is not a certification that every legacy application or dependency is fully supported or vulnerability-free.

## Evidence and limits

Local evidence files:

- `cpanel10-php-audit-2026-10-22.json`: installed packages, managed PHP binaries, WHM versions/website assignments, and process snapshot. Contains internal customer-account and filesystem metadata; keep private.
- `cpanel10-php-audit-supplement-2026-10-22.json`: internal package changelogs, RPM file verification, CageFS copy comparisons, and deleted-library checks.
- `cpanel10-php-repository-check-2026-10-22.json`: repository availability check after metadata refresh.

No exploit requests, authenticated customer application workflows, historical compromise investigation, or exhaustive search of arbitrary customer-installed/private PHP binaries were performed. The website result applies to the installed managed runtimes inspected, not to all possible application copies or backups on disk.
