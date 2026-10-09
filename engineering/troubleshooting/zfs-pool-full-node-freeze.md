# prox2new ZFS pool filled up and froze the node with all its VMs

> - **Date:** 2026-10-08 (around 07:00 server time, EEST)
> - **Area:** infrastructure / monitoring
> - **Severity:** Critical
> - **Status:** Temporary fix — service is back, but the pool is still at 87% (only 539G available) and the free-space alert is not in place yet
> - **Related technical reference:** `engineering/infrastructure/proxmox-setup.md` (ZFS + Snapshots) + `engineering/monitoring/monitoring-checklist.md`

## Server Info
| Item | Value |
| --- | --- |
| Hostname | `prox2new.mosalam.com` |
| Public IP | `46.4.198.134` |
| Provider | Hetzner — bare metal |
| Role | Node 3 of Proxmox cluster `mosalam` (4 nodes) |
| Proxmox | `pve-manager/9.2.20` — kernel `7.0.14-17-pve` |
| CPU | Intel Xeon W-2295 — 18 cores / 36 threads |
| RAM | 256 GB DDR4 ECC |
| Disks | 6 × Samsung PM983 1.92 TB NVMe |
| Storage | `rpool` — ZFS RAID10 (3 mirrors), 5.20 TiB usable; `local-zfs` is thin provisioned (`sparse 1`) |
| Guests | 13 VMs (9 running) + 1 LXC, plus replicas of 12 guests from other nodes |
| Replication | Guests 109, 113, 125, 126, 141, 156 replicate to `prox99` and `prox88` |

**Storage state at the time of writing (2026-10-09 03:00):**

| Metric | Value |
| --- | --- |
| Pool | 4.55T used of 5.20T — **CAP 87%** — FRAG 65% — ONLINE |
| Space available to VMs | **539G** (`local-zfs` 89.55% used) |
| Space handed out to customers | ≈ **14 TiB on a 5.2 TiB pool (≈ 2.7×)** |
| Space used by replicas of other nodes' guests | **1.62 TiB** |
| Snapshots | 79 snapshots using **352 GiB** |

## Symptom
- Around 07:00, Mahmoud Mosalam called Ahmed Raafat, then called Ahmed Maher: node `prox2new` was frozen and every VM on it was down, including critical workloads.
- Logs: `No space left on device` from `pvescheduler` and `pveproxy`; `pvestatd` hung and would not die even with `SIGKILL` (processes stuck in I/O); the guest agent of VM 109 stopped responding.
- A normal reboot hung and never finished, so a force reset was needed.

## Investigation
**Commands used:**
```bash
journalctl -b -1 -p warning | grep -i "no space left" # when the pool filled up
zpool history rpool | grep "^2026-10-08" | grep destroy  # which snapshots were deleted, and when
zpool list; zfs list -o name,used,avail,usedbysnapshots -d 1 rpool
zfs list -t snapshot -o name,used,creation -s used   # largest snapshots
pvesr status                                         # replication state
```

**Timeline (EEST):**

| Time | Event |
| --- | --- |
| 2026-10-08 05:28 | First `No space left on device`: replication job `156-1` fails to write its state file → **the pool is full** |
| 06:46 | `pveproxy` (management UI) cannot write: `No space left on device` |
| ~07:00 | Mahmoud Mosalam calls Ahmed Raafat, then Ahmed Maher — VMs are down |
| 07:00 – 07:14 | `pvestatd` hangs, then fails (timeout) |
| 07:06 | VM 109 (`dockerstation`) — `guest-ping` timeout |
| 07:14 | Snapshot `vm-117-disk-0@beforeNewGitlab` deleted + reboot started |
| 07:14 – 07:23 | Reboot hangs: services will not stop (`ip-manager-agent`, `pvescheduler`, sessions) |
| ~07:23 | **Force reset from the Hetzner console** |
| 07:24 | Server starts booting |
| 07:26 – 07:27 | VM 109 snapshots deleted: `beforeNetbirdUpdate` and `beforeS3` (plus the RAM-state volume `vm-109-state-beforeS3`) |

**Findings:**
- **Storage overselling:** ≈ 14 TiB handed out to customers on a 5.2 TiB pool, with thin provisioning. Each disk only takes real space as data is written, so nothing stops the pool from filling up.
- **Replication also uses space here:** 1.62 TiB on this server is replicas of guests that run on other nodes. A replicated guest uses its space on 3 servers.
- **Old manual snapshots were never cleaned up.** Still present now:
  - `vm-141-disk-0@beforeMig` from 2026-03-04 — **166G**
  - 3 snapshots on `vm-402-disk-0` from Aug 3–7 — **319G** of snapshot space on that disk
- **No free-space alert anywhere:**
  - The on-server script `/usr/local/scripts/zfs_health_check.sh` (every 10 minutes) sends a Telegram message **only when the pool state is not ONLINE**. The pool stayed ONLINE while 100% full, so nothing was sent.
  - No Alertmanager rule for disk space, and the daily Telegram report does not include free space.
  - No `node_exporter` is running on `prox2new`.

## Root Cause
1. **Storage overselling (main cause):** far more space was handed out to customers than physically exists (≈ 2.7×), on the assumption that customers would not all fill their space quickly at the same time.
2. **Pure negligence by Ahmed Raafat and Ahmed Maher (main cause):** the overselling was a known, deliberate decision, yet no free-space alert was ever added, and old manual snapshots were left for months holding hundreds of GB.
3. **Trigger:** a VM on the server consumed space quickly. Because old snapshots existed, data rewritten inside the VM kept its old blocks pinned in the snapshot, so usage grew even faster.
4. **Why the whole node froze, not just one VM:**
   - Once the pool is full, ZFS rejects every write (`ENOSPC`), and QEMU pauses any VM whose disk write fails for lack of space, so all VMs stopped together.
   - The Proxmox host itself (`rpool/ROOT`) lives on the same pool, so its services failed too (`pveproxy`, `pvestatd`, `pvescheduler`), and even the reboot hung.

## Resolution
1. SSH into the server and delete the snapshots that were bloating VM disk usage:
   - `vm-117-disk-0@beforeNewGitlab` (07:14, before the reset)
   - `vm-109-disk-0@beforeNetbirdUpdate` and `vm-109-disk-1@beforeNetbirdUpdate`
   - `vm-109-disk-0@beforeS3`, `vm-109-disk-1@beforeS3` and `vm-109-state-beforeS3`
2. The normal reboot hung, so the server was **force reset from the Hetzner console**. It was back at 07:24.

## Verification
- The server has been up since 2026-10-08 07:24, and all 9 running VMs and the LXC came back.
- Cluster `mosalam` is quorate (4/4 votes).
- All replication jobs are `OK` with `FailCount 0`.
- No `No space left on device` in the log since boot.
- **But:** the pool is still at 87% with only 539G available. The risk has been postponed, not removed.

**Follow-up needed:** `/etc/pve/qemu-server/117.conf` still has a `[beforeNewGitlab]` section even though the ZFS snapshot is gone (it was deleted with `zfs destroy` directly, not through Proxmox). Clean it up:
```bash
qm delsnapshot 117 beforeNewGitlab --force
```

## Prevention
**Planned for tomorrow (2026-10-10):**
- An Alertmanager rule that notifies us when free space on the server drops below **350 GB** (on `prox2new` and every node in the cluster).

**Suggested additions to the same change:**
- **An earlier warning tier** (e.g. below 600 GB, or pool above 85%). Note: this warning will fire immediately, because the pool is at 87% now. That is correct: the current state needs action.
- **A fill-rate alert** (`predict_linear`): catches a VM eating space fast before the threshold is reached, which is exactly what happened here.
- **A free-space check in the on-server script** `/usr/local/scripts/zfs_health_check.sh`, next to the ONLINE check, as a separate Telegram channel that does not depend on Prometheus.
- **Free space in the daily Telegram report:** `zpool list` for each node + the largest snapshots + any snapshot older than 7 days.
- **Snapshot policy:** every manual (`before...`) snapshot is deleted within 7 days at most, once the change is confirmed good.
- **Clean up what is left now** (after confirming with each VM's owner): `vm-141@beforeMig` (166G, from March) and the August snapshots of VM 402 (delete them through Proxmox on the node where VM 402 runs, then confirm the space was freed here).

## Infrastructure Design Improvement
- **A per-node overselling cap:** set a maximum overcommit ratio and a "stop selling" line at 75–80% real usage. At that point, move VMs to another node or add disks, and sell no new space on that node.
- **Capacity planning must include replication:** a guest replicated to 2 nodes uses its space 3 times across the cluster. Any capacity plan that ignores replicas is wrong.
- **An emergency reserve inside the pool:** an empty dataset with a reservation. When the pool fills up, release it to regain control immediately, without a force reset:
  ```bash
  zfs create -o mountpoint=none -o reservation=100G rpool/emergency-reserve
  # in an emergency:
  zfs set reservation=none rpool/emergency-reserve
  ```

## Monitoring Improvement
- `node_exporter` is not installed on `prox2new` today. Install it first (or use `prometheus-pve-exporter`).
- Example Prometheus rules (routed through Alertmanager to Telegram). On Proxmox with a ZFS root, the available space of `/` equals the available space of the whole `rpool`:
  ```yaml
  groups:
    - name: proxmox-storage
      rules:
        - alert: ZFSPoolFreeSpaceCritical
          expr: node_filesystem_avail_bytes{fstype="zfs", mountpoint="/"} < 350 * 1024^3
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "{{ $labels.instance }}: rpool free space below 350G"
        - alert: ZFSPoolFreeSpaceWarning
          expr: node_filesystem_avail_bytes{fstype="zfs", mountpoint="/"} < 600 * 1024^3
          for: 15m
          labels:
            severity: warning
        - alert: ZFSPoolFillingFast
          expr: predict_linear(node_filesystem_avail_bytes{fstype="zfs", mountpoint="/"}[6h], 24 * 3600) < 0
          for: 30m
          labels:
            severity: critical
          annotations:
            summary: "{{ $labels.instance }}: rpool will be full within 24h at current rate"
  ```
  Alternative with `prometheus-pve-exporter`:
  `pve_disk_size_bytes{id="storage/prox2new/local-zfs"} - pve_disk_usage_bytes{id="storage/prox2new/local-zfs"}`
- **Same alert for PBS:** the backup datastore on `prox99` is also 89% used, which puts backups at the same risk.

## Lessons
- Overselling without a free-space alert and a clear stop-selling line is a time bomb. It also contradicts our "We sell Uninterrupted" pledge (`pricing/margins.md`).
- "The pool is healthy" does not mean "the pool has space": an ONLINE pool can be 100% full.
- A snapshot is not a backup. It holds space on the same pool (and on every replica), so it needs a deletion date.

---

# النسخة العربية — امتلاء ZFS pool على prox2new أدى لتجمّد السيرفر وكل الـ VMs عليه

> - **التاريخ:** 2026-10-08 (حوالي 07:00 بتوقيت السيرفر EEST)
> - **القسم:** infrastructure / monitoring
> - **الخطورة:** حرجة
> - **الحالة:** فيها حل مؤقت — الخدمة رجعت، لكن الـ pool ما زال 87% (539G متاحة فقط) وتنبيه المساحة لم يُنفَّذ بعد
> - **المصدر/المرجع التقني ذو الصلة:** `engineering/infrastructure/proxmox-setup.md` (ZFS + Snapshots) + `engineering/monitoring/monitoring-checklist.md`

## بيانات السيرفر (Server Info)
| البند | القيمة |
| --- | --- |
| Hostname | `prox2new.mosalam.com` |
| Public IP | `46.4.198.134` |
| المزود | Hetzner — Bare Metal |
| الدور | Node 3 في Proxmox cluster `mosalam` (4 nodes) |
| Proxmox | `pve-manager/9.2.20` — kernel `7.0.14-17-pve` |
| CPU | Intel Xeon W-2295 — 18 cores / 36 threads |
| RAM | 256 GB DDR4 ECC |
| الأقراص | 6 × Samsung PM983 1.92 TB NVMe |
| التخزين | `rpool` — ZFS RAID10 (3 mirrors)، سعة صافية 5.20 TiB؛ `local-zfs` بـ Thin Provisioning (`sparse 1`) |
| الضيوف | 13 VM (9 شغالة) + 1 LXC، بالإضافة لنسخ replication لـ 12 guest من nodes أخرى |
| Replication | الضيوف 109, 113, 125, 126, 141, 156 تُنسخ إلى `prox99` و `prox88` |

**حالة التخزين وقت كتابة التقرير (2026-10-09 03:00):**

| المؤشر | القيمة |
| --- | --- |
| الـ Pool | 4.55T مستخدمة من 5.20T — **CAP 87%** — FRAG 65% — ONLINE |
| المساحة المتاحة للـ VMs | **539G** (`local-zfs` مستخدم 89.55%) |
| المساحة الموزعة على العملاء | ≈ **14 TiB على pool سعته 5.2 TiB (≈ 2.7×)** |
| مساحة نسخ replication لضيوف nodes أخرى | **1.62 TiB** |
| Snapshots | 79 snapshot تستهلك **352 GiB** |

## الأعراض (Symptom)
- حوالي الساعة 07:00 اتصل محمود مسلم (Mahmoud Mosalam) بأحمد رأفت، ثم بأحمد ماهر: node `prox2new` متجمد وكل الـ VMs عليه لا تعمل، بما فيها workloads حرجة.
- في السجلات: `No space left on device` من `pvescheduler` و `pveproxy`، و `pvestatd` معلّق لا يتوقف حتى بـ `SIGKILL` (عمليات عالقة في I/O)، و guest agent الخاص بـ VM 109 لا يرد.
- أمر الـ reboot العادي علق ولم يكتمل — احتجنا Force Reset.

## التحقيق (Investigation)
**الأوامر المستخدمة:**
```bash
journalctl -b -1 -p warning | grep -i "no space left" # بداية الامتلاء
zpool history rpool | grep "^2026-10-08" | grep destroy  # أي snapshots اتحذفت ومتى
zpool list; zfs list -o name,used,avail,usedbysnapshots -d 1 rpool
zfs list -t snapshot -o name,used,creation -s used   # أكبر snapshots
pvesr status                                         # حالة الـ replication
```

**التسلسل الزمني (بتوقيت EEST):**

| الوقت | الحدث |
| --- | --- |
| 2026-10-08 05:28 | أول `No space left on device`: فشل replication job `156-1` في كتابة ملف الحالة → **الـ pool امتلأ فعليا** |
| 06:46 | `pveproxy` (واجهة الإدارة) لا يقدر يكتب: `No space left on device` |
| ~07:00 | محمود مسلم يتصل بأحمد رأفت ثم بأحمد ماهر — الـ VMs متوقفة |
| 07:00 – 07:14 | `pvestatd` يعلق ثم يفشل (timeout) |
| 07:06 | VM 109 (`dockerstation`) — `guest-ping` timeout |
| 07:14 | حذف snapshot `vm-117-disk-0@beforeNewGitlab` + بدء reboot |
| 07:14 – 07:23 | الـ reboot علق: خدمات لا تتوقف (`ip-manager-agent`، `pvescheduler`، sessions) |
| ~07:23 | **Force Reset من Hetzner console** |
| 07:24 | بداية الإقلاع |
| 07:26 – 07:27 | حذف snapshots الـ VM 109: `beforeNetbirdUpdate` و `beforeS3` (مع volume الـ RAM state `vm-109-state-beforeS3`) |

**ما وجدناه:**
- **Overselling للمساحة:** ≈ 14 TiB موزعة على العملاء فوق pool سعته 5.2 TiB مع Thin Provisioning — أي أن كل قرص يأخذ مساحة فعلية فقط عند الكتابة، فلا شيء يمنع الامتلاء.
- **Replication يستهلك المساحة هنا أيضا:** 1.62 TiB على هذا السيرفر هي نسخ لضيوف يعملون على nodes أخرى. كل guest عليه replication يستهلك مساحته على 3 سيرفرات.
- **Snapshots يدوية قديمة لم تُحذف:** وما زال منها حتى الآن:
  - `vm-141-disk-0@beforeMig` من 2026-03-04 — **166G**
  - 3 snapshots على `vm-402-disk-0` من 3–7 أغسطس — **319G** إجمالي مساحة snapshots على هذا القرص
- **لا يوجد أي تنبيه على المساحة:**
  - السكربت الموجود على السيرفر `/usr/local/scripts/zfs_health_check.sh` (كل 10 دقائق) يرسل Telegram **فقط لو حالة الـ pool ليست ONLINE** — والـ pool ظل ONLINE وهو ممتلئ 100%، فلم يصل أي تنبيه.
  - لا قاعدة في Alertmanager لمساحة القرص، والتقرير اليومي على Telegram لا يحتوي المساحة المتاحة.
  - لا يوجد `node_exporter` يعمل على `prox2new`.

## السبب الجذري (Root Cause)
1. **Overselling للمساحة (السبب الرئيسي):** تم توزيع مساحة على العملاء أكبر بكثير من المساحة الفعلية (≈ 2.7×)، اعتمادا على أن العملاء لن يملؤوا مساحاتهم كلهم في نفس الوقت وبسرعة.
2. **إهمال صريح من أحمد رأفت (Ahmed Raafat) وأحمد ماهر (Ahmed Maher) (السبب الرئيسي):** قرار الـ overselling كان معروفا ومقصودا، ومع ذلك لم يُضَف أي تنبيه على المساحة المتاحة، ولم تُراجَع الـ snapshots اليدوية القديمة التي ظلت شهورا تحجز مئات الـ GB.
3. **الشرارة:** VM على السيرفر استهلك المساحة بسرعة. مع وجود snapshots قديمة، أي بيانات يُعاد كتابتها داخل الـ VM تبقى البلوكات القديمة محجوزة في الـ snapshot، فيكبر الاستهلاك أسرع.
4. **لماذا توقف السيرفر كله وليس VM واحد:**
   - عند امتلاء الـ pool يرفض ZFS أي كتابة (`ENOSPC`)، و QEMU يوقف (pause) أي VM تفشل كتابته بسبب امتلاء القرص — فتوقفت الـ VMs معا.
   - نظام Proxmox نفسه (`rpool/ROOT`) على نفس الـ pool، فتوقفت خدماته أيضا (`pveproxy`، `pvestatd`، `pvescheduler`) وعلق حتى أمر الـ reboot.

## الحل المنفذ (Resolution)
1. الدخول على السيرفر بـ SSH وحذف snapshots كانت تضخّم مساحة الـ VMs:
   - `vm-117-disk-0@beforeNewGitlab` (07:14 — قبل الـ reset)
   - `vm-109-disk-0@beforeNetbirdUpdate` و `vm-109-disk-1@beforeNetbirdUpdate`
   - `vm-109-disk-0@beforeS3` و `vm-109-disk-1@beforeS3` و `vm-109-state-beforeS3`
2. الـ reboot العادي علق، فتم عمل **Force Reset من Hetzner console**، ورجع السيرفر 07:24.

## التحقق من الحل (Verification)
- السيرفر شغال منذ 2026-10-08 07:24، والـ 9 VMs والـ LXC الشغالين رجعوا كلهم.
- الـ cluster `mosalam` Quorate (4/4 votes).
- كل replication jobs حالتها `OK` و `FailCount 0`.
- لا يوجد أي `No space left on device` في السجل منذ الإقلاع.
- **لكن:** الـ pool ما زال 87% والمتاح 539G فقط — الخطر لم ينته، فقط تأجّل.

**متابعة مطلوبة:** ملف `/etc/pve/qemu-server/117.conf` ما زال فيه القسم `[beforeNewGitlab]` رغم أن الـ ZFS snapshot اتحذف (اتحذف بـ `zfs destroy` مباشرة وليس من Proxmox). يجب تنظيفه:
```bash
qm delsnapshot 117 beforeNewGitlab --force
```

## هل ستتكرر؟ الوقاية (Prevention)
**مخطط تنفيذه غدا (2026-10-10):**
- قاعدة Alertmanager ترسل لنا تنبيه عندما تقل المساحة المتاحة على السيرفر عن **350 GB** (على `prox2new` وكل nodes الـ cluster).

**إضافات مقترحة مع نفس التنفيذ:**
- **مستوى تحذير أبكر** (مثلا أقل من 600 GB أو الـ pool فوق 85%). ملاحظة: هذا التحذير سيعمل فورا الآن لأن الـ pool على 87% — وهذا صحيح، لأن الوضع الحالي يستحق التحرك.
- **تنبيه على سرعة الامتلاء** (`predict_linear`): يرصد VM يأكل المساحة بسرعة قبل الوصول للحد — وهذا بالضبط ما حدث.
- **فحص المساحة في سكربت السيرفر** `/usr/local/scripts/zfs_health_check.sh` بجانب فحص ONLINE، كقناة Telegram مستقلة لا تعتمد على Prometheus.
- **المساحة في التقرير اليومي على Telegram:** `zpool list` لكل node + أكبر snapshots + أي snapshot عمره أكثر من 7 أيام.
- **سياسة Snapshots:** أي snapshot يدوي (`before...`) يُحذف خلال 7 أيام بحد أقصى بعد التأكد من سلامة التغيير.
- **تنظيف المتبقي الآن** (بعد التأكيد مع صاحب كل VM): `vm-141@beforeMig` (166G من مارس)، و snapshots الـ VM 402 من أغسطس (تُحذف من الـ node الذي يعمل عليه VM 402 عن طريق Proxmox، ثم التأكد أن المساحة رجعت هنا).

## تحسين التصميم (Infrastructure Design Improvement)
- **حد أقصى للـ Overselling لكل node:** تحديد نسبة overcommit قصوى، وخط "إيقاف بيع" عند 75–80% استخدام فعلي — عنده إما ننقل VMs لـ node آخر أو نزيد أقراص، ولا نبيع مساحة جديدة على هذا الـ node.
- **حساب السعة يشمل الـ replication:** كل guest عليه replication لـ 2 nodes يستهلك مساحته 3 مرات في الـ cluster. أي خطة سعة لا تحسب الـ replicas خاطئة.
- **احتياطي طوارئ داخل الـ pool:** dataset فارغ بـ reservation؛ عند الامتلاء نحرره فورا ونستعيد التحكم بدون Force Reset:
  ```bash
  zfs create -o mountpoint=none -o reservation=100G rpool/emergency-reserve
  # وقت الطوارئ:
  zfs set reservation=none rpool/emergency-reserve
  ```

## تحسين المراقبة (Monitoring Improvement)
- لا يوجد `node_exporter` على `prox2new` حاليا — يجب تثبيته أولا (أو استخدام `prometheus-pve-exporter`).
- قواعد Prometheus المقترحة موجودة في قسم **Monitoring Improvement** في النسخة الإنجليزية أعلاه (حد 350G، تحذير 600G، وتنبيه سرعة الامتلاء)، وتُرسل عبر Alertmanager إلى Telegram.
- **نفس التنبيه على PBS:** الـ datastore الخاص بالنسخ الاحتياطية على `prox99` مستخدم 89% أيضا — نفس الخطر على النسخ الاحتياطية.

## دروس مستفادة (Lessons)
- الـ Overselling بدون تنبيه على المساحة ووقف بيع واضح = قنبلة موقوتة. هذا يتعارض مع وعدنا "We sell Uninterrupted" (`pricing/margins.md`).
- "الـ pool سليم" لا يعني "الـ pool فيه مساحة": pool بحالة ONLINE ممكن يكون ممتلئ 100%.
- الـ Snapshot ليس backup ويحجز مساحة على نفس الـ pool (وعلى كل replica) — لازم يكون له تاريخ حذف.
