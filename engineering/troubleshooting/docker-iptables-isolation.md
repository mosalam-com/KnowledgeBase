# Docker يتحكم بتوجيه iptables ويكسر عزل Proxmox

> - **التاريخ:** 2026-07
> - **القسم:** virtualization / networking
> - **الخطورة:** متوسطة (أمنية)
> - **الحالة:** محلولة (عزل بحكم التصميم)
> - **المصدر/المرجع:** `engineering/infrastructure/proxmox-setup.md` + `engineering/networking/traefik-reverse-proxy.md`

## الأعراض (Symptom)
- ظهور سلاسل `DOCKER`/`DOCKER-USER` في iptables، وMASQUERADE من `172.17.0.0/16`، أو default route على `docker0` — أي أن Docker بدأ يتحكم بتوجيه Proxmox.

## التحقيق (Investigation)
- `iptables -t nat -L -n --line-numbers` → وجود chain باسم DOCKER.
- `ip route` → default على vmbr0 فقط؟ أم ظهر مسار docker0؟
- `iptables -L FORWARD -n` → وجود ACCEPT من docker0؟

## السبب الجذري (Root Cause)
- إعداد Docker الافتراضي (`"iptables": true`) يضيف قواعد NAT/FORWARD خاصة به، فإذا شُغّل على Proxmox Host مباشرة يتدخل في توجيه الـ Host وقد يربط Containers بشبكات Proxmox الداخلية — ما يكسر العزل بين البيئات.

## الحل المنفذ (Resolution)
- ضبط `/etc/docker/daemon.json`:
  ```json
  { "iptables": false }
  ```
  ثم `systemctl restart docker`.
- إبقاء Docker على شبكته الافتراضية `docker0` (subnet داخلي `172.17.0.0/16` فقط) وعدم تشغيله على `vmbr0`.
- (للأدق/الأعزل) تشغيل Docker داخل LXC Container بدل الـ Host مباشرة.

## التحقق من الحل (Verification)
- `iptables -t nat -L -n --line-numbers` → لا توجد سلاسل DOCKER/DOCKER-USER.
- `ip route` → default route على vmbr0 فقط، و docker0 `linkdown`.
- `iptables -L FORWARD -n` → لا ACCEPT من docker0.
- `docker network inspect bridge` → subnet 172.17.0.0/16 غير مرتبط بأي vmbr.

## هل ستتكرر؟ الوقاية (Prevention)
- قاعدة: `"iptables": false` ضمن خطوات تثبيت Docker في أي بيئة Proxmox.
- لا تشغّل Docker Swarm / فتح Ports على الـ Public IP.

## تحسين التصميم (Infrastructure Design Improvement)
- فصل Network Namespaces: Traefik على `traefik-net`، الخدمات مستقلة، وكل الخروج عبر NAT مركزي — فتظل الطبقات معزولة ولا يتداخل أي محرك حاويات مع توجيه الـ Host.

## تحسين المراقبة (Monitoring Improvement)
- فحص آلي أسبوعي: تشغيل `iptables -t nat -L -n --line-numbers` والبحث عن سلاسل DOCKER — تنبيه عند العثور عليها.
- إضافة فحص في كرون يتأكد أن default route على vmbr0 فقط.

## دروس مستفادة (Lessons)
- Docker على Proxmox آمن شريطة `iptables: false` + عدم لمس vmbr0 + عدم فتح Ports مباشرة — التوزيع المعزول (traefik-net) هو خط الدفاع الرئيسي.