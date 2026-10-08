# Reverse Proxy — Traefik على Docker

> المحادثة المصدر: `بناء_بيئة_داتا_سنتر_باستخدام_Proxmox.txt`
> **حالة:** مُعبأ من محادثة بناء_بيئة_داتا_سنتر.

## السيناريو: نشر خدمات خلف IP واحد
- عندك **Public IP واحد فقط** (بصيغة `91.x.x.x`) مربوط على `vmbr0` وهو **البوابة الوحيدة** لأي ترافيك من الخارج، وجوّه السيرفر مجموعة خدمات عايزة تبقى متاحة من برّه من غير أي IP إضافي: مواقع على VMs، خدمات على LXC، وContainers على Docker، وFTP وSSH وRDP وDatabases. المعمارية المتفق عليها: **Traefik يستقبل كل HTTP/HTTPS ويعمل Routing حسب الدومين**، و**WireGuard يستقبل كل Non-Web Traffic**، و**Port Forwarding للطوارئ فقط** — والاتنين شغّالين على نفس الـ Public IP بدون ما نلمس شبكة Hetzner.
- مسار الطلب العام:
  `User → Internet → Hetzner → Proxmox (vmbr0) → Traefik (Docker) → الخدمة (VM / LXC / Docker)`
- **الشبكات المعنية:** `vmbr0` (Public)، `vmbr1` (192.168.100.0/24)، `vmbr2` (192.168.90.0/24 ومعها NAT)، `vmbr3` (شبكة معزولة)، وشبكات Docker: `docker0` + `traefik-net`.

## التثبيت والإعداد
1. تثبيت Traefik على Docker: `docker network create traefik-net` ثم `mkdir -p /opt/traefik` ووضع `traefik.yml` (entryPoints `web:80` + `websecure:443`، `api.dashboard: true`، `providers.docker.exposedByDefault: false`) ثم `docker-compose.yml` يشغّل صورة `traefik:latest` على منفذي 80 و443 مع تمرير `/var/run/docker.sock:ro` والكونفيج كـ volume، والشبكة `traefik-net` بـ `external: true`، ثم `docker compose up -d` والتأكد بـ `docker ps`. التفاصيل الكاملة في قسم **«الكونفيج الأساسي»** بالأسفل.
2. ربطه بالدومين: التوجيه يتم بـ **Labels على كل Container** حسب الدومين، مثل `traefik.http.routers.whoami.rule=Host(\`test.yourdomain.com\`)` مع `entrypoints=web`؛ وللخدمات خارج Docker يربط Traefik الدومين بالـ IP الداخلي مباشرة (`Host(\`site1.com\`) → 192.168.90.10:80`). **ملاحظة من المحادثة:** إعداد الدومين الفعلي (DNS + شهادة) لم يُنفَّذ بعد — كان مقترحًا كخطوة تالية.
3. Let's Encrypt SSL تلقائي: **لم يُنفَّذ في المحادثة**؛ تم عرضه كخيار رقم 1 من الخطوات التالية (`نضيف Let's Encrypt SSL تلقائيًا في Traefik`). المتطلبات المجهزة بالفعل من المحادثة: منفذا `web:80` و`websecure:443` مفتوحين على الـ Public IP، و`exposedByDefault: false` حتى لا يُصدَر أي حاوية بلا قصد. راجع ملحق النموذج في نهاية الملف.
4. Auth Dashboard: **لم يُنفَّذ في المحادثة**؛ تم عرضه كخيار رقم 2 من الخطوات التالية (`نضيف Auth Dashboard`). الوضع الحالي: `--api.dashboard=true` والوصول للوحة عبر `http://<Public_IP>:8080/dashboard/` أو عبر WireGuard من الشبكة الداخلية `http://10.10.10.1:8080`. **تحذير تشغيلي:** الكونفيج في المحادثة يفتح 80/443 فقط، فلوحة التحكم على 8080 تحتاج Port Mapping إضافي أو إتاحتها عبر WireGuard بدل فتحها للعالم.

## توزيع الترافيك
- HTTP/HTTPS (Traefik): هو **الـ Entry Point الوحيد للويب**؛ يشغّل على `vmbr0` بالمنفذين 80 و443 (يعني `http://91.x.x.x` و`https://91.x.x.x`)، يقرأ الـ labels من Docker ويوزّع حسب الدومين: موقع على VM (`192.168.90.10:80`)، خدمة على LXC (`192.168.80.20:8080`)، Container على `traefik-net` (`172.18.0.5:3000`)، أو الـ Dashboard نفسه. لوحة التحكم تبقى شغالة على Proxmox GUI (8006) بدون أي تعارض.
- غير HTTP (Port Forwarding): SSH/RDP/FTP/SMB/Databases/Ping **مش هتمرّ على Traefik** (أصلاً بروتوكولات غير HTTP)، فالحل البديل هو DNAT من Proxmox، مثال: `iptables -t nat -A PREROUTING -p tcp --dport 2222 -j DNAT --to 192.168.90.10:22` (وده اللي بيخليك تعمل `ssh -p 2222`). ملاحظة: فتح FTP كامل (21 + passive ports 1024–65535) مستحيل عمليًا، وفتح RDP 3389 أو SSH 22 للعالم = كارثة أمنية.
- الدخول الكامل للشبكات الداخلية (WireGuard): يركب على **Proxmox Host نفسه** (مش جوّه Docker ولا VM) على `wg0` بعنوان `10.10.10.1` وPort `51820/UDP` الوحيد المفتوح على Hetzner؛ بعد الاتصال بتشوف `vmbr1/vmbr2/vmbr3/docker0/traefik-net` وكل الـ VMs والـ LXC والـ Containers كأنك قاعد جنب السيرفر — بتدخل على Proxmox GUI وعلى Traefik Dashboard ومن غير أي Port Forwarding لكل خدمة.

## قواعد عملية
- قواعد تشغيلية مستخلصة من المحادثة:
  - **ممنوع لمس `vmbr0` أو `enp5s0`/`enp5s0` الحقيقي** — أي غلطة في الشبكات = السيرفر يقع من النت وتدخل Rescue Mode؛ Hetzner بيسمح بـ MAC واحد فقط.
  - **Docker لازم يفضل معزول عن iptables بتاعة Proxmox**: خلي `/etc/docker/daemon.json` فيه `{"iptables": false}` ثم `systemctl restart docker`، وإلا Docker هيعمل NAT وFORWARD rules ويكسر الـ bridges.
  - **لا تفتح Dashboard ولا خدمات داخلية للعالم**؛ الوصول يكون عبر WireGuard فقط (Zero Exposure).
  - **كل Container جديد لازم يبقى على `traefik-net`** وعليه `traefik.enable=true`، وإلا Traefik مش هيشوفه (`exposedByDefault: false`).
  - **كل حاوية/خدمة = Label واحد للراوطي** (`Host(\`domain\`)` + entrypoint) — مفيش تعديل في كونفيج Traefik نفسه، وده الـ Service Discovery بتاعه.
  - **80/443 ملك Traefik، و8006 ملك Proxmox GUI** — لا تعارض بينهم.
  - غير Web (SSH/RDP/FTP/DB) لا يمرّ على Traefik أبدًا: WireGuard أولًا، Port Forwarding كحل أخير.
  - اختبار الوحدة: من أي VM على `vmbr2` اعمل `ping 192.168.90.1` ثم `ping 8.8.8.8` ثم `ping google.com`؛ لو الثلاثة شغالين = مسار الخروج سليم.

---

# أقسام تشغيلية تفصيلية (مستخلصة من المحادثة)

## الشبكة المعزولة `traefik-net`
```bash
docker network create traefik-net
```
- دي شبكة Docker خاصة **مفيهاش علاقة بـ vmbr0 أو vmbr1 أو vmbr2** — Traefik وكل الـ Containers هيتكلموا عليها.
- النتيجة: `traefik-net` منفصلة تمامًا، و`docker0` ليها subnet داخلي فقط (`172.17.0.0/16`) وحالتها `linkdown` بدون default route.
- مفيش overlap، مفيش iptables conflict، مفيش تأثير على الـ VMs أو الـ LXC.

## الكونفيج الأساسي `traefik.yml`
```bash
mkdir -p /opt/traefik
cd /opt/traefik
nano traefik.yml
```
```yaml
api:
  dashboard: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    exposedByDefault: false
```
النتيجة: Traefik يسمع على 80 و443، ويقرأ الـ labels من Docker، **وما يفتحش أي Container إلا لو إنت قلتله**.

## `docker-compose.yml`
```bash
nano docker-compose.yml
```
```yaml
version: "3.9"

services:
  traefik:
    image: traefik:latest
    container_name: traefik
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedByDefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--api.dashboard=true"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/traefik.yml:ro
    networks:
      - traefik-net
    restart: always

networks:
  traefik-net:
    external: true
```
**ملاحظات:**
- المنفذان 80 و443 بيتفتحوا على Proxmox Host، لكن **كل الـ Routing بيتم جوّه Traefik** — Proxmox نفسه مش بيتأثر.
- لو عايز تغيّر منفذ الـ Dashboard (8080) يعدّل بسهولة.

## التشغيل والاختبار
```bash
docker compose up -d
docker ps
```
فحص الـ Dashboard:
```text
http://YOUR_PROXMOX_PUBLIC_IP:8080/dashboard/
```
أو عبر WireGuard من الشبكة الداخلية:
```text
http://10.10.10.1:8080
```

## ربط أي Container بـ Traefik (Service Discovery)
```bash
docker run -d \
  --name whoami \
  --network traefik-net \
  -l "traefik.enable=true" \
  -l "traefik.http.routers.whoami.rule=Host(`test.yourdomain.com`)" \
  -l "traefik.http.routers.whoami.entrypoints=web" \
  traefik/whoami
```
- Traefik هيمسك الـ Routing **تلقائيًا** من غير أي تعديل في كونفيج Traefik.
- أول ما تشغّل Container جديد وتحط له labels، Traefik يلقطها فورًا؛ وخدمة وقعت → بتشيلها من الترافيك تلقائيًا.

## كيف يصل Traefik للـ VMs والـ LXC (3 طرق)
1. **Internal Reverse Proxy:** Traefik شايف كل الشبكات الداخلية ويروح لها بالـ IP مباشرة:
   ```text
   http://192.168.90.10:80      (VM على vmbr2)
   http://192.168.80.20:8080    (LXC على vmbr3)
   http://172.18.0.5:3000       (Container على traefik-net)
   ```
2. **توجيه داخلي بالدومين:** `Host(\`site1.com\`) → 192.168.90.10:80`.
3. **Docker Network Linking:** `docker run --network traefik-net ...` → Traefik يشوفها مباشرة.

## مسار الريكويستات الكامل (Data Flow)
```text
User → Internet → Hetzner → Proxmox (vmbr0) → Traefik (Docker) → Service (VM/LXC/Docker)   # مواقع و APIs
User → Proxmox → Traefik → Docker Container
User → Proxmox → Traefik → VM (192.168.90.10)
User → Proxmox → Traefik → LXC (192.168.80.20)
User → Proxmox → Port Forwarding → VM/LXC                                                   # FTP/SSH
User → WireGuard VPN → كل الشبكات الداخلية                                                  # دخول كامل
```
- **Web Traffic:** `Internet → Proxmox (vmbr0) → Traefik → (VM / LXC / Docker)`
- **Non-Web Traffic:** `Internet → Proxmox → WireGuard → Internal Networks → (VM / LXC / Docker)`
- **Admin Access:** `Laptop → WireGuard → Proxmox GUI / SSH / VMs / LXC / Docker`

## الدياجرام النصي للمعمارية
```text
                       Internet
                           │
                           ▼
                 Public IP (vmbr0)
                           │
        ┌──────────────────┼──────────────────┐
        ▼                                     ▼
 WireGuard (wg0)                       Traefik (Docker)
 Port 51820/UDP                        Ports 80 / 443
 Full VPN Access                       HTTP/HTTPS Only
        │                                     │
        └──────────────────┬──────────────────┘
                           ▼
 ─────────────────── Internal Networks ───────────────────
  vmbr1: 192.168.100.0/24  (WAN داخلي اختياري)
  vmbr2: 192.168.90.0/24   (LAN + NAT)
  vmbr3: شبكة معزولة
  traefik-net: شبكة Docker
     VMs / LXC / Containers  ←─ Traefik Routes (domain → internal IP)
 ─────────────────────────────────────────────────────────
```

## فحص عزل Docker عن Proxmox (قبل وبعد تثبيت Traefik)
```bash
cat /etc/docker/daemon.json          # لازم يكون فيه "iptables": false
iptables -t nat -L -n --line-numbers # مفيش Chains اسمها DOCKER/DOCKER-USER
ip route                             # default via vmbr0 فقط، docker0 بدون default route
sysctl net.ipv4.ip_forward           # = 1 (طبيعي)
iptables -L FORWARD -n              # مفيش ACCEPT من/to docker0
docker network ls                   # traefik-net موجودة وغير مربوطة بأي vmbr
docker network inspect bridge       # Subnet = 172.17.0.0/16 (داخلي فقط)
```
شروط النجاح: مفيش DOCKER chains، مفيش MASQUERADE من `172.17.0.0/16`، و`docker0` حالتها `linkdown` → **Docker معزول 100%** ومش هيأثر على WireGuard ولا VMs ولا LXC.

## مكان كل عنصر في المعمارية
- **Traefik:** Docker Container على Proxmox — `Ports: 80, 443` — `Network: traefik-net` — يستقبل كل Web Traffic، مش محتاج Bridge خاص.
- **WireGuard:** على Proxmox Host — `wg0` / `10.10.10.1` / `51820/UDP` — يستقبل كل Non-Web Traffic، مش محتاج Bridge.
- **Port Forwarding:** احتياطي فقط وللبروتوكولات غير الـ Web.
- **vmbr0** = الإنترنت الحقيقي وحده؛ باقي الـ bridges معزولة داخليًا (مفيش Default Gateway ولا NAT غير ما تضيفه بنفسك).

## الوصول بعد تفعيل WireGuard
```text
https://192.168.90.1:8006        # Proxmox GUI
ssh root@192.168.90.10           # أي VM على vmbr2
ssh root@192.168.80.5            # أي LXC على vmbr3
docker exec -it container bash   # أي Docker Container
http://192.168.90.10:8080        # أي Web Panel داخلي
mysql -h 192.168.90.20           # Database داخلية
http://10.10.10.1:8080           # Traefik Dashboard
```
الخلاصة: `SSH على الـ Public IP = دخول على Proxmox فقط`، أما `WireGuard = دخول على اللاب كله` بـ Port واحد فقط.

## حالة الخطوات التالية في المحادثة (لم تُنفَّذ)
كانت هناك 3 اختيارات مقترحة ولم يُختر أي منها بعد نهاية المحادثة:
1. إضافة **Let's Encrypt SSL تلقائي** في Traefik.
2. إضافة **Auth** على الـ Dashboard.
3. **ربط Traefik بالدومين** الفعلي.
المشروع توقف عند: تركيب WireGuard تم، وTraefik جاهز للتركيب (`docker compose up -d`) ولم يُثبَّت فعليًا في نهاية النص.

---

## ملحق: نماذج إعداد مقترحة للتنفيذ لاحقًا
> ⚠️ هذه النماذج **ليست من المحادثة** (المحادثة توقفت قبل تنفيذها)، وهي مُدرجة هنا تمهيدًا للخطوات الثلاث التالية أعلاه.

**1) Let's Encrypt (ACME) في `traefik.yml`:**
```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@yourdomain.com
      storage: acme.json
      httpChallenge:
        entryPoint: web
```
مع إضافة في `command` الخاص بالـ compose:
```text
- "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
- "--certificatesresolvers.letsencrypt.acme.email=admin@yourdomain.com"
- "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
```
و Label على الحاوية: `traefik.http.routers.whoami.tls.certresolver=letsencrypt`.

**2) حماية الـ Dashboard بـ BasicAuth:**
```bash
openssl passwd -apr1   # لتوليد هاش المستخدم
```
```yaml
labels:
  - "traefik.http.routers.dashboard.rule=Host(`dash.yourdomain.com`)"
  - "traefik.http.routers.dashboard.entrypoints=websecure"
  - "traefik.http.routers.dashboard.tls=true"
  - "traefik.http.middlewares.auth.basicauth.users=admin:$apr1$..."
  - "traefik.http.routers.dashboard.middlewares=auth"
```

**3) شروط ربط الدومين:** سجل الدومين → A Record على `91.x.x.x` → فتح 80/443 → تشغيل Traefik → إضافة الـ Labels لكل خدمة.
