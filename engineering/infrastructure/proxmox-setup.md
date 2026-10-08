# إعداد بيئة Proxmox على Hetzner

> المحادثة المصدر: `بناء_بيئة_داتا_سنتر_باستخدام_Proxmox.txt`
> **حالة:** مُعبأ من محادثة بناء_بيئة_داتا_سنتر.

## الهدف
- بناء بيئة Data Center Lab كاملة على سيرفر Hetzner واحد: تثبيت Proxmox VE على الـ Bare Metal مباشرة (وليس داخل VM) على قاعدة تخزين ZFS، ثم بناء طبقة شبكة داخلية معزولة (Bridges + VLANs + راوتر داخلي) وطبقة وصول آمن من الخارج، بحيث تشتغل كل الـ VMs/LXC/Docker خارج شبكة Hetzner العامة دون أي Public IP إضافي، مع خدمات أساسية (Router/DHCP/DNS/Template VMs/Monitoring) وأدوات وصول (WireGuard + Traefik) بمسارات بيانات واضحة من غير Exposure أو فتح Ports كثيرة.

## طبقة التخزين (Storage Layer)
- RAID زبد ZFS: تم تثبيت Proxmox على **ZFS RAID10** (mirror striping) على 6 أقراص NVMe بسعة 1920 GB للقرص (إجمالي 10 TiB). البدائل التي نوقشت: **RAID-Z2** (أفضل توازن أداء/حماية ومناسب للابت التعليمي)، **RAID-Z1** (أسرع قليلاً لكن حماية أقل)، و**Striped بدون RAID** (أداء أعلى لكن خطراً وغير مناسب). المعالج Intel Xeon W-2295 بـ 36 نواة وذاكرة ECC تقارب 512 GB. التثبيت أُجري عبر تجربة أولية بـ `qemu-system-x86_64` مع تمرير الأقراص الستة كأقراص raw/virtio مع تحديد اسم كارت الشبكة ونوع الـ RAID وبيانات السيرفر (الاسم/IP/البوابة) في خيارات التثبيت.
- Storage Pools: الـ Pool الأساسي بعد التثبيت هو `rpool` وجواه: `rpool/ROOT/pve-1` لنظام التشغيل، `rpool/data` لأقراص الـ VMs، و`rpool/subvol-*` لحاويات LXC. التقسيم المنطقي المعتمد للتنظيم: `local-zfs` للـ VMs، `iso-store` للـ ISOs، `backup-store` للنسخ الاحتياطية، `container-store` لحاويات LXC (وفي بداية التخطيط ذُكرت أيضاً `vmstore` لـ VMs و`iso-store` للـ ISO/Templates).
- Snapshot (ZFS) للـ VMs: الـ Snapshot لقطة لحظية (Copy-on-Write) تُخزَّن **على نفس الـ Pool** بمساحة صفرية تقريباً في البداية وتكبر مع التغييرات — وليست Backup خارجي. الأوامر التشغيلية:
  - للنظام: `zfs snapshot rpool/ROOT/pve-1@before-changes`
  - لأقراص الـ VMs: `zfs snapshot rpool/data@backup1`
  - لكل اللاب (recursive): `zfs snapshot -r rpool@full-lab`
  - عرضها: `zfs list -t snapshot`
  - الاسترجاع: `zfs rollback rpool/ROOT/pve-1@before-changes` أو `zfs rollback -r rpool@full-lab` (تحذير: يحذف كل التغييرات بعد زمن الـ Snapshot)
  - Backup حقيقي خارج الـ Pool عند الحاجة: `zfs send -R rpool@full-lab | zfs receive backup-pool/rpool`
  - السياسة العملية: Snapshot يومي + Snapshot قبل أي تغيير كبير (تثبيت Docker/WireGuard/Upgrade). تحذير: لو الـ Pool تلف يضيع الـ Snapshot معه لأنه يعيش داخل نفس الـ Pool.

## الشبكة داخل Proxmox
- Bridge رئيسي (vmbr0): Public Bridge مربوط على الكارت الفيزيائي `enp5s0` بالعنوان `91.98.186.15/26` وبوابة `91.98.186.1` (ملف `/etc/network/interfaces` مع `bridge-ports enp5s0` و`bridge-stp off` و`bridge-fd 0`). هو **البوابة الوحيدة للإنترنت** (vmbr0 → enp5s0 → Hetzner) ويستقبل كل Traffic القادم من الخارج. القاعدة الذهبية: **لا تلمسه نهائياً** — لا تغيّر الـ IP ولا الـ MAC ولا تحذف الـ bridge-ports ولا تحوّله لـ internal، فأي غلطة فيه تعني سقوط السيرفر من النت.
- Bridge داخلي (vmbr1): شبكة داخلية `192.168.100.1/24` بـ `bridge-ports none` (بدون أي NIC فيزيائي) — تُستخدم كـ WAN الداخلي للراوتر الداخلي ولا علاقة لها بـ Hetzner. وإلى جانبها: **vmbr2** = `192.168.90.1/24` وهو LAN الرئيسي ومربوط بقاعدة NAT مباشرة على Proxmox (`post-up echo 1 > /proc/sys/net/ipv4/ip_forward` و`post-up iptables -t nat -A POSTROUTING -s 192.168.90.0/24 -o vmbr0 -j MASQUERADE`)، و**vmbr3** = `192.168.80.1/24` أو manual للاستخدام كشبكة DMZ/Labs معزولة. ملاحظة تشغيلية: أي VM على vmbr1/vmbr2/vmbr3 **لا يخرج إنترنت تلقائياً** — لا يوجد Default Gateway ولا Route للإنترنت ولا يصنع Proxmox Routing بين الـ Bridges؛ الخروج يكون فقط عبر NAT من Proxmox أو من OPNsense.
- VLANs: تفعيل VLAN-aware على الـ Bridges الداخلية والتقسيم المقترح لـ Lab محترم: VLAN 10 — Management، VLAN 20 — Storage، VLAN 30 — Internal VMs، VLAN 40 — DMZ/Public. كلها تعمل فوق `vmbr0`/الشبكات الداخلية داخلياً وبدون أي علاقة بشبكة Hetzner العامة.
- Bonding: اختياري ويُفعَّل فقط لو السيرفر الفعلي فيه أكثر من NIC (السيرفر الحالي يملك NIC واحد `enp5s0` مع Intel Gigabit Ethernet)، ويُستعد له مبكراً لدروس HA/التحمّل لاحقاً.

## الوصول الآمن
- تفعيل **SSH Key Authentication (Passwordless)** مبكراً ثم تعطيل SSH Password Login، مع تفعيل **2FA على Proxmox GUI**، وإضافة قواعد Firewall أساسية، وتفعيل الإشعارات (Email/Webhook) — ده اللي بيخلي السيرفر Production-Ready قبل بناء أي حاجة.
- **WireGuard VPN على Proxmox Host نفسه** هو الحل القياسي للدخول من الخارج: Interface `wg0` بعنوان داخلي `10.10.10.1/24` يستمع على Port واحد فقط `51820/UDP` مفتوح على Hetzner (عبر Hetzner Firewall إن وجدت)، وقواعد `iptables` في `wg0.conf` (PostUp/PostDown لـ FORWARD وMASQUERADE عبر vmbr0)، مع `systemctl enable wg-quick@wg0` وإضافة Peer لكل عميل (AllowedIPs=`10.10.10.2/32`، وملف العميل بـ `Endpoint = 91.98.186.15:51820` و`AllowedIPs = 0.0.0.0/0` و`PersistentKeepalive = 25`)، والاختبار بـ `wg show` (Handshake).
- لماذا WireGuard بدل SSH المباشر: SSH على الـ Public IP يدخلك على **Proxmox Host فقط** وليس على الشبكات الداخلية؛ فبدون VPN ستحتاج فتح Port لكل خدمة (22/21/3389/8080/3306...) وهو خطر و غير قابل للتوسّع ويكسر iptables/NAT. WireGuard يجعلك "جوّه الشبكة" فتدخل Proxmox GUI على `:8006` وكل الـ VMs/LXC/Docker/Dashboards بدون فتح أي Port إضافي (Zero Exposure / Zero Port Forwarding). البدائل الأضعف: Port Forwarding بـ `iptables -t nat -A PREROUTING ... DNAT` لكل خدمة، أو SSH Tunnel/VNC Console عبر الـ Bare Metal.
- عزل Docker عن Proxmox (خطوة أمنية أساسية): ضبط `/etc/docker/daemon.json` بالقيمة `"iptables": false` ثم `systemctl restart docker`، والتحقق: `iptables -t nat -L -n --line-numbers` بدون أي سلاسل DOCKER/DOCKER-USER أو MASQUERADE من `172.17.0.0/16`، و`ip route` بأن الـ default route على vmbr0 فقط بينما `docker0` في وضع linkdown بدون Route، و`iptables -L FORWARD -n` نظيفة بدون ACCEPT من docker0، و`docker network inspect bridge` يظهر subnet داخلي `172.17.0.0/16` غير مربوط بأي vmbr.

## القيود/سياسات Hetzner
- **MAC واحد فقط**: Hetzner بنظام strict routing يسمح بظهور MAC واحد فقط على الشبكة العامة، وأي MAC جديد يظهر = انتهاك.
- **ممنوع**: عمل Bridge على الـ Public NIC (`vmbr0`/`enp5s0`) يمرر أجهزة أخرى عليه، أو تعديل إعداداته، أو Routing/NAT/DHCP خارجي على الـ Public NIC، أو ARP Spoofing، أو أي Traffic غير متوقع.
- **العقوبة**: قطع الإنترنت عن السيرفر كلياً وحاجة لدخول Rescue Mode وإصلاح الشبكات يدويًا — وده اللي لازم نتجنبه بأي ثمن.
- **الوضع الآمن 100%**: إبقاء الـ Public IP على الـ Bare Metal وحده على vmbr0، وجيع الشبكات الأخرى internal bridges بـ `bridge-ports none` (لا MAC جديدة، لا DHCP خارجي، لا Routing خارجي، كلها Layer 2 معزولة)، وكل NAT يتم داخل السيرفر فـ Hetzner لا يرى أي traffic داخلي ولا يعترض.
- **الخروج للإنترنت للـ VMs** مسموح وآمن عبر NAT داخلي (OPNsense أو قاعدة MASQUERADE) لأن الـ Public MAC لا يتغير والسيرفر يُعامل كجهاز واحد.
- للحصول على MAC أو IP إضافي يجب شراؤه رسمياً (vSwitch / Additional IP / Floating IP) — بدون ذلك لا تُعطى أي VM عنوان عام.
- فتح Port واحد فقط عند الحاجة: `UDP 51820` لـ WireGuard (ولو Hetzner Firewall مفعّل يجب السماح به).

## الـ Infrastructure الأساسية (VMs)
- Template VMs: صور جاهزة ترفع إلى `/var/lib/vz/template/iso/` ثم تُحوَّل لـ Templates: Ubuntu Cloud Image، Debian، Windows Server (2022 Evaluation)، Windows 10/11، Rocky/AlmaLinux. إعدادات Windows Template: Machine `q35`، BIOS `UEFI`، SCSI Controller `VirtIO SCSI single`، قرص `VirtIO Block` 60GB بـ Cache `Write Back`، 2 vCPU، 4GB RAM، NIC VirtIO مربوط على `vmbr2`، مع إرفاق `VirtIO Drivers ISO` كـ CD-ROM ثانٍ؛ أثناء التثبيت عند عدم ظهور القرص: `Load Driver → vioscsi → amd64 → w11/w2k22`، ثم تشغيل `virtio-win-guest-tools.exe` (Network/Balloon/QEMU Agent/SCSI/RNG) والتأكد من عمل QEMU Guest Agent، ثم إعدادات ما قبل التحويل (تعطيل IPv6/الفيرول للـ Lab، التحديثات، Timezone، NIC على DHCP)، ثم `sysprep.exe` بخيارات OOBE + Generalize + Shutdown، وأخيراً `Convert to Template` والاستنساخ بـ Clone (Linked Clone أسرع وأقل مساحة أو Full Clone مستقل).
- DHCP/DNS داخلي: عبر راوتر داخلي **OPNsense** (أو pfSense أو dnsmasq بسيط) — إعدادات VM: 2 vCPU / 2GB RAM / 20GB / q35 / UEFI / VirtIO NICs (NIC1→vmbr1 WAN، NIC2→vmbr2 LAN، NIC3→vmbr3 اختياري). التهيئة: WAN=`vtnet0` بـ `192.168.100.2/24` وبوابة `192.168.100.1` (بدون DHCP/DNS/Services عليه — مجرد Interface داخلي)، LAN=`vtnet1` بـ `192.168.90.1/24` مع DHCP Range `192.168.90.50–200`، OPT1=`vtnet2` بـ `192.168.80.1/24` مع DHCP Range `192.168.80.50–200`، وDNS Resolver (Unbound) شغال. الوصول للـ GUI من **LAN فقط** على `https://192.168.90.1` (الوصول من WAN محظور افتراضياً). لخروج الـ VMs للإنترنت: `Firewall → NAT → Outbound → Hybrid Outbound NAT` مع قاعدة (Interface: WAN، Source: `192.168.90.0/24` و`192.168.80.0/24`، Translation: Interface Address) + قاعدة `Pass` في `Firewall → Rules → LAN` (Source: LAN net، Destination: any)، ثم الاختبار من VM Ubuntu على vmbr2: `ip a` ثم `ping 192.168.90.1` ثم `ping 8.8.8.8` ثم `ping google.com`.
- Monitoring: عناصر أساسية لأي Data Center حقيقي: **Proxmox Metrics Server + Node Exporter + Prometheus + Grafana Dashboard جاهز لـ Proxmox + Proxmox Exporter** — أساس لكورس Monitoring كامل لاحقاً.

## خطوات التنفيذ المتبعة (Runbook)
1. تجهيز السيرفر وتثبيت Proxmox VE: تنزيل `proxmox-ve_9.1-1.iso`، تجربة الإقلاع عبر `qemu-system-x86_64 -enable-kvm` مع ربط الأقراص NVMe الستة كأقراص raw/virtio وVNC على `127.0.0.1:1`، ثم أثناء التثبيت الحقيقي إدخال اسم كارت الشبكة (`enp5s0`)، اختيار نوع الـ RAID (ZFS RAID10)، وبيانات السيرفر الكاملة (الاسم/الـ IP/البوابة) — حتى يقف Proxmox شغالاً.
2. تأمين الوصول فوراً: تفعيل SSH Key Authentication (Passwordless)، تعطيل Password Login، تفعيل 2FA على Proxmox GUI، إضافة قواعد Firewall أساسية، وتفعيل الإشعارات.
3. التحقق من `/etc/network/interfaces` والتأكد من بقاء `vmbr0` كما هي (`91.98.186.15/26` + `gateway 91.98.186.1` + `bridge-ports enp5s0`) دون أي تعديل — أي تغيير فيها = السيرفر يقع من النت.
4. إنشاء الشبكات الداخلية بـ `bridge-ports none` (بدون أي NIC فيزيائي): `vmbr1` = `192.168.100.1/24` (WAN داخلي)، `vmbr2` = `192.168.100.1`→ `192.168.90.1/24` (LAN)، `vmbr3` = `192.168.80.1/24` أو manual (DMZ/Labs)، مع `bridge-stp off` و`bridge-fd 0`.
5. تفعيل الخروج للإنترنت لشبكة LAN: تفعيل `ip_forward` وإضافة قاعدة `MASQUERADE` من `192.168.90.0/24` نحو `vmbr0` (عبر `post-up iptables` في كونفيج الشبكة أو عبر OPNsense).
6. إنشاء VM خاص بـ OPNsense (2 vCPU / 2GB RAM / 20GB / q35 / UEFI / VirtIO) وربط NICs على vmbr1/vmbr2/vmbr3 ثم تثبيته من ISO (اختيار UFS للـ Lab أو ZFS).
7. ضبط داخل OPNsense: WAN/LAN/OPT1 بأرقامها، DHCP وDNS Resolver، قواعد Firewall، وOutbound NAT (Hybrid) — ثم اختبار الإنترنت من VM على vmbr2 (`ping 192.168.90.1` / `8.8.8.8` / `google.com`).
8. تجهيز Templates: رفع ISOs إلى `/var/lib/vz/template/iso/`، بناء Ubuntu Cloud-Init Template وWindows Server Template (VirtIO Drivers + Sysprep + Convert to Template)، وربطها بـ `vmbr2`.
9. تثبيت Docker Engine على Proxmox Host بالطريقة النظيفة: تحديث النظام، إضافة Docker Repository الرسمي، تثبيت `docker-ce` + Compose، ضبط `"iptables": false` في `daemon.json` وإعادة التشغيل، ثم التحقق من العزل (`iptables -t nat -L -n`، `ip route`، `docker network ls`) وتشغيل `docker run hello-world`.
10. رفع Reverse Proxy: إنشاء شبكة `docker network create traefik-net`، إنشاء `/opt/traefik` مع `traefik.yml` و`docker-compose.yml` (Ports 80/443، `exposedByDefault: false`، `docker.sock` للقراءة فقط)، ثم `docker compose up -d` واختبار Dashboard وإضافة Services عبر Labels.
11. تثبيت WireGuard على Proxmox: `apt install wireguard`، توليد المفاتيح، كتابة `/etc/wireguard/wg0.conf` (Address=`10.10.10.1/24`، ListenPort=`51820`، قواعد PostUp/PostDown)، `wg-quick up wg0` وتفعيله تلقائياً، إضافة Peer للعميل وملف الكونفيج الخاص به، فتح UDP 51820 في Hetzner Firewall، ثم الاختبار (`wg show` من السيرفر و`wg` من العميل).
12. اختبار الوصول الشامل عبر VPN: دخول Proxmox GUI على `:8006`، SSH لأي VM/LXC، فتح أي Web Panel أو Database أو Dashboard داخلي، والتأكد من خروج الإنترنت للـ VMs — دون فتح أي Port جديد.
13. تفعيل سياسة Snapshot دورية: `zfs snapshot -r rpool@<اسم وتاريخ>` قبل وبعد كل تغيير كبير (Upgrade/Docker/WireGuard/أي تجربة) مع تنظيف دوري للـ Snapshots القديمة.

## الراوتر الداخلي OPNsense (تفاصيل تشغيلية)
- اختيار OPNsense على pfSense للأسباب: أخف، واجهة أنظف، وplugins جاهزة لـ IDS/IPS وWireGuard وTraffic Shaping.
- منطق الشبكة: `vmbr1` = WAN الداخلي لـ OPNsense، `vmbr2` = LAN الرئيسي، `vmbr3` = DMZ/Lab إضافي — وكلها internal bridges بدون أي علاقة بـ Hetzner.
- بعد التثبيت: أول Boot يطلب تعيين الـ Interfaces (vtnet0/vtnet1/vtnet2)، ثم الوصول للـ GUI من أي VM على `vmbr2` عبر `https://192.168.90.1` (root + كلمة المرور المختارة أثناء التثبيت).
- مسار الإنترنت الكامل: `VM → LAN (vmbr2) → OPNsense → WAN الداخلي (vmbr1) → Proxmox → vmbr0 → Hetzner → Internet`.
- ملاحظة: لو لم يُستخدم OPNsense، يمكن استبداله بقاعدة NAT مباشرة على Proxmox نفسها (MASQUERADE على vmbr2) مع بقاء vmbr1 للاستخدام الداخلي فقط.

## Docker + Traefik على Proxmox Host (العزل والـ Reverse Proxy)
- Docker يعمل على `docker0` (subnet داخلي `172.17.0.0/16`) وهو معزول عن `vmbr0/vmbr1/vmbr2/vmbr3` وعن `wg0` — كل واحد في Layer مختلف ولا يتداخل إلا لو ربطته يدويًا. الممنوع الوحيد: تشغيل Docker مربوطاً بـ `vmbr0` (الـ Public NIC) أو فتح Docker Swarm Ports على العام.
- ممارسة فرض العزل: `"iptables": false` داخل `/etc/docker/daemon.json` حتى لا يضيف Docker قواعد NAT/FORWARD على iptables الخاصة بـ Proxmox، ثم `systemctl restart docker`.
- شبكة اختيارية لربط Containers بالشبكة الداخلية: `docker network create --driver=bridge --subnet=192.168.90.0/24 --gateway=192.168.90.1 proxnet` ثم `docker run --network proxnet ...`.
- Traefik كـ Entry Point للويب: يستمع على `80/443` على الـ Host (بدون تعارض مع Proxmox GUI على `8006`)، ويركّب على شبكة خارجية `traefik-net` مع `providers.docker` و`exposedByDefault: false`، ويقرأ الـ labels ليعمل Routing تلقائياً (مثال: `-l "traefik.http.routers.whoami.rule=Host(\`test.domain.com\`)"`) — وأي Service (VM/LXC/Docker) تُعرَّف عليه يصبح متاحاً عبر الدومين بدون IP إضافي.
- أفضل ممارسة: تشغيل Docker داخل LXC Container بدل الـ Host مباشرة لو أردت عزل أعلى وأمان أكبر مع Snapshot/Backup سهل.

## المعمارية النهائية لمسارات الطلب (Public IP واحد فقط)
- **Web Traffic (HTTP/HTTPS)**: `Internet → Hetzner → Proxmox (vmbr0) → Traefik (80/443) → VM / LXC / Docker` — Traefik هو الـ Entry Point الوحيد ويوزّع حسب الدومين إلى IP داخلي (مثال: `Host(site1.com) → 192.168.90.10:80` أو إلى Container على `traefik-net`).
- **Non-Web Traffic (SSH/RDP/FTP/SMB/Databases/Monitoring)**: `Internet → Proxmox → WireGuard (wg0, 51820/UDP) → الشبكات الداخلية (vmbr1/vmbr2/vmbr3/docker0/traefik-net)` — لا يمر على Traefik لأنه لا يدعم هذه البروتوكولات.
- **Admin Access**: `Laptop/Phone → WireGuard → Proxmox GUI / SSH / VMs / LXC / Docker` مع رؤية كاملة لـ `192.168.100.0/24` و`192.168.90.0/24` و`192.168.80.0/24` كأنك قاعد جنب السيرفر، وبدون فتح أي Port على Hetzner غير 51820.
- الخلاصة: Traefik للـ Web، WireGuard للوصول الكامل، Proxmox هو الـ Gateway الوحيد، وكل الخدمات (VMs/LXC/Docker) خلفه — بدون أي IP إضافي وبدون تعارض في الشبكات.
