# قائمة مراقبة البنية وصحتها (Monitoring & Health Checklist)

> ما الذي يجب مراقبته يوماً بيوم/أسبوع/شهر — مُستخلص من أقسام «تحسين المراقبة» في `engineering/troubleshooting/` + إعدادات البنية في `engineering/*`.
> **الحلقة:** مشكلة → توثيق → هذه القائمة تلتقطها مبكراً قبل شكوى العميل.

## يومياً (فوري/تلقائي يُفضَّل)
- [ ] **توفر الخدمات (Uptime):** Proxmox Host + كل VM/LXC/Docker Container يعمل — مؤتمت عبر Ping/HTTP checks.
- [ ] **صحة ZFS:** `zpool status` بلا أخطاء، وفحص `zpool scrub` النتيجة؛ أي DEGRADED = إنذار (راجع `engineering/infrastructure/proxmox-setup.md`).
- [ ] **صحة iptables/NAT:** `ip_forward=1` + قاعدة MASQUERADE موجودة + لا سلاسل DOCKER غريبة (من `engineering/networking/proxmox-networking.md` + troubleshooting).
- [ ] **شبكات sane:** default route على vmbr0 فقط، و الداخلية `bridge-ports none` بلا MAC جديدة (`engineering/troubleshooting/hetzner-mac-block.md`).
- [ ] **فضاء القرص:** لا امتلاء حاسم → يؤثر على النسخ والـ VMs.
- [ ] **سجلات الدخول الفاشلة:** SSH/Proxmox — كشف محاولة اختراق مبكراً.

## أسبوعياً
- [ ] **نسخ احتياطي فعلياً يعمل:** تنفيذ نسخة تجريبية/استرجاع عينة من Snapshot يومي (من `engineering/troubleshooting/vm-no-internet.md` أن الفشل درجة حرجة).
- [ ] **SSL/شهادات:** لا شهادة قرب الانتهاء (مجدد تلقائي عبر Traefik، لكن راقِبه).
- [ ] **استهلاك الموارد** لكل ضيف (CPU/RAM/Disk/عمليات) — رصد Over-Provisioning بعيد (قاعدة `pricing/margins.md`).
- [ ] **ربط WireGuard:** Handshake موجودة (من `engineering/networking/wireguard-vpn.md`).
- [ ] **فحص أمان بسيط:** تحديثات نواة/حزم معلّقة مؤجلة، منافذ مفتوحة غير متوقعة.

## شهرياً
- [ ] **مراجعة الأصول والتكاليف:** تحديث `pricing/assets.md` والهامش (`pricing/margins.md`).
- [ ] **مراجعة حالات troubleshooting:** أي حالة اختارت عودة متكررة → تتحول لقاعدة/تحسين (الحلقة).
- [ ] **اختبار استرجاع كامل (DR):** من خارج الموقع إلى بيئة نظيفة — ضمن الوعد بـ«استرجاع أقل من ساعة».
- [ ] **تدقيق صلاحيات حساب** (من `infrastructure/security.md`): مفاتيح SSH، مستخدمون، 2FA مفعّل.

## فحوصات تُنشأ من المشاكل السابقة (خريطة الإنذارات المقترحة)
| الشيك | المتر/الأداة المقترحة | من مصدر الحالة |
| --- | --- | --- |
| `check_ip_forward.sh` + قاعدة NAT | Prometheus node_exporter + Alert | `troubleshooting/vm-no-internet.md` |
| سلامة `/etc/network/interfaces` و vmbr0 يحمل IP الصحيح | cron + diff مع نسخة معتمدة | `troubleshooting/ssh-drop-net-restart.md` |
| لا سلاسل DOCKER/DOCKER-USER | cron يفحص `iptables -t nat` | `troubleshooting/docker-iptables-isolation.md` |
| HTTPS على `192.168.90.1` يستجيب | cron/nagios HTTP check | `troubleshooting/opnsense-webgui-lan-only.md` |
| لا MAC جديد على الشبكة العامة | cron يفحص `ip neigh` | `troubleshooting/hetzner-mac-block.md` |
| مساحة `rpool` المتاحة > 350G + سرعة الامتلاء + snapshots أقدم من 7 أيام | Prometheus node_exporter + Alertmanager → Telegram | `troubleshooting/zfs-pool-full-node-freeze.md` |

## الأدلة التقنية المرتبطة (للتفصيل)
- `engineering/infrastructure/proxmox-setup.md` — ZFS/Storage/Snapshot
- `engineering/networking/proxmox-networking.md` — أوامر التشخيص
- `engineering/networking/wireguard-vpn.md` — wg show
- `engineering/security/proxmox-hardening.md` — iptables/ipset & حجب
- `engineering/troubleshooting/index.md` — الحالات ومصادرها