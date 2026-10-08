# VPN داخلي — WireGuard

> المحادثة المصدر: `بناء_بيئة_داتا_سنتر_باستخدام_Proxmox.txt`
> **حالة:** مُعبأ من محادثة بناء_بيئة_داتا_سنتر.

## الوضع المستهدف
- الوصول من أي مكان (البيت) لكل الشبكات الداخلية vmbr1/vmbr2/vmbr3 دون فتح أي Port إضافي على Hetzner إلا **51820/UDP واحد فقط**.
- لا تعرّض SSH أو أي خدمات للعام — VPN يعاملك كأنك داخل الشبكة الداخلية، ويدخل على Proxmox GUI وVMs وLXC وDocker Containers.
- **تفضيل عن Port Forwarding:** Port Forwarding يتطلب فتح Port وإنشاء DNAT لكل VM/خدمة (مش scalable)، بينما WireGuard يعطيك دخول كامل للماكينات من غير أي تعقيد.

## التثبيت
- **على Proxmox مباشرة** (وليس داخل LXC) في الحالة الحالية؛ الخيار الأفضل للعزل الأعلى أن يوضع Docker داخل LXC، لكن WireGuard نفسه على الـ Host.
- لا تعارض بين WireGuard (Layer 3 — Interface `wg0`) وDocker (`docker0` — Layer 2/3) و bridges Proxmox (vmbr0..3)؛ كل واحد في طبقة مستقلة، بشرط عدم تشغيل Docker على vmbr0 (Public NIC).

### خطوات التثبيت
1) `apt update && apt install wireguard -y` (يضيف wg + wg-quick + kernel module)
2) `mkdir -p /etc/wireguard && cd /etc/wireguard`
3) إنشاء المفاتيح: `wg genkey | tee server_private.key | wg pubkey > server_public.key`
4) إنشاء `/etc/wireguard/wg0.conf` (نموذج أدناه)
5) تشغيل: `wg-quick up wg0` + تلقائي: `systemctl enable wg-quick@wg0`
6) إضافة Client: `wg genkey | tee client_private.key | wg pubkey > client_public.key`
7) إضافة العميل في `[Peer]` داخل wg0.conf
8) فتح **UDP 51820** في Hetzner Firewall (لو شغال)
9) اختبار: `wg show` على السيرفر (تشوف Handshake) و`wg` على العميل

## التكوين

### ملف السيرفر `/etc/wireguard/wg0.conf`
```
[Interface]
Address = 10.10.10.1/24
ListenPort = 51820
PrivateKey = SERVER_PRIVATE_KEY_HERE

# Allow traffic to internal networks
PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT
PostUp   = iptables -A FORWARD -o wg0 -j ACCEPT
PostUp   = iptables -t nat -A POSTROUTING -o vmbr0 -j MASQUERADE

PostDown = iptables -D FORWARD -i wg0 -j ACCEPT
PostDown = iptables -D FORWARD -o wg0 -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -o vmbr0 -j MASQUERADE
```

### إضافة عميل داخل wg0.conf
```
[Peer]
PublicKey = CLIENT_PUBLIC_KEY
AllowedIPs = 10.10.10.2/32
```

### ملف العميل (يُحمَّل في الموبايل/اللابتوب)
```
[Interface]
PrivateKey = CLIENT_PRIVATE_KEY
Address = 10.10.10.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = <SERVER_PUBLIC_IP>:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

## النتائج بعد الربط
- Proxmox GUI: `https://192.168.90.1:8006`
- أي VM على vmbr2: `192.168.90.x`
- أي VM على vmbr1: `192.168.100.x`
- أي LXC على vmbr3: `192.168.80.x`
- Docker Containers: عبر Traefik (traefik-net) أو مباشرة (docker0)
- Traefik Dashboard: `http://10.10.10.1:8080` (لو فتحه على Port 8080)

## الأمان
- سبق إجراء **Snapshot قبل تثبيت WireGuard** كنقطة استرجاع.
- مصادقة بمفاتيح Curves (Curve25519) — لا كلمات مرور.
- Port واحد مفتوح فقط (51820/UDP) على Hetzner.
- قاعدة MASQUERADE تخرج حركة wg0 عبر vmbr0 بنفس الأساس (Layer 3 دون لمس bridges).
- **تحذير:** لا تشغّل Docker على vmbr0، ولا تعدّل iptables بشكل uncontrolled — اترك Docker على `docker0` الافتراضي.

## أخطاء شائعة
- نسيان فتح UDP 51820 في Hetzner Firewall → لا يحدث Handshake.
- عدم تعيين `PersistentKeepalive` على العميل → انقطاع بعد NAT في شبكات البيت.
- حذف مسار `PostUp MASQUERADE` → العميل يصل لكن دون إنترنت/دخول للشبكات الخارجية.