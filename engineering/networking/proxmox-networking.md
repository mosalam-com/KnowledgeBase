# إعدادات شبكة Proxmox

> المحادثات المصدر: `شرح_إعدادات_شبكة_Proxmox.txt` + `بناء_بيئة_داتا_سنتر_باستخدام_Proxmox.txt`
> **حالة:** مُعبأ من محادثة شرح_إعدادات_شبكة_Proxmox.

## مفاهيم ملف `/etc/network/interfaces`

### `static`
- **المعنى:** يتم تعيين عنوان IP ثابت يدويًا للـ Interface أو للـ Bridge.
- **التطبيق:** يستخدم عندما يحتاج السيرفر (أو الـBridge) إلى عنوان IP ثابت للتواصل، مثل تعيين IP للـBridge الداخلي ليصبح Gateway للـVMs.
- **مثال:**
  ```bash
  iface vmbr1 inet static
      address 192.168.1.1/24
      gateway 192.168.1.1
  ```

### `manual`
- **المعنى:** يتم رفع الـInterface (UP) لكن لا يتم تعيين أي عنوان IP له. يتم ترك إدارة Layer 3 لجهة أخرى.
- **التطبيق:** يستخدم غالبًا للكارت الفيزيائي عندما يكون جزءًا من Bridge، أو لكارت يكون تحت إدارة خدمة أخرى.
- **مثال:**
  ```bash
  iface enp5s0 inet manual
  ```

### `dhcp`
- **المعنى:** يتم الحصول على عنوان IP تلقائيًا من خادم DHCP.
- **التطبيق:** مناسب للشبكات الديناميكية، وأقل استخدامًا في السيرفرات الإنتاجية.
- **مثال:**
  ```bash
  iface eth0 inet dhcp
  ```

### `auto / allow-hotplug`
- **`auto`:** يقوم بتفعيل الـInterface تلقائيًا عند إقلاع النظام.
- **`allow-hotplug`:** يقوم بتفعيل الـInterface تلقائيًا عند توصيله (مناسب لكروت USB NIC).
- **مثال:**
  ```bash
  auto vmbr0
  allow-hotplug enp5s0
  ```

## لماذا Proxmox يستخدم `manual` للكارت الفيزيكال؟

- **الإدارة عبر Bridge:** عنوان IP الحقيقي للسيرفر يوضع على الـBridge وليس على الكارت الفيزيائي.
- **جهاز وسيط (Layer 2):** الكارت الفيزيائي يتحول إلى "Port" داخل الـBridge، وبالتالي لا يحتاج IP خاص به.
- **تجنب التعارض:** لو تم وضع IP على الكارت الفيزيائي وعلى الـBridge في نفس الوقت، سيؤدي ذلك إلى تعارض وسوء سلوك الشبكة.
- **افتراضي في Proxmox:** يتماشى مع فلسفة استخدام Bridge لتمرير الترافيك بين الVMs والشبكة الفيزيائية.

## الـ Bridges

### `vmbr0` (Public)
- **الغرض:** Bridge متصل بالكارت الفيزيائي، يستخدم لربط السيرفر بالإنترنت أو الشبكة العامة.
- **السلوك:** يمكن أن يكون:
  - `manual` + متصل بالكارت الفيزيائي (Transparent Bridge): الVMs تأخذ IP عام مباشرة.
  - `static` مع IP عام: السيرفر نفسه يستخدمه كـGateway في وضع Routing Mode.
- **مثال (Bridge Mode التقليدي):**
  ```bash
  auto vmbr0
  iface vmbr0 inet manual
      bridge-ports enp5s0
      bridge-stp off
      bridge-fd 0
  ```

### `vmbr1` (Internal)
- **الغرض:** Bridge داخلي مخصص للـVMs والـLXC بدون اتصال مباشر بالشبكة الفيزيائية.
- **السلوك:** غالبًا `static` مع شبكة خاصة (مثل `10.10.10.0/24`) ليصبح Gateway للـVMs مع NAT.
- **مثال (Routing Mode):**
  ```bash
  auto vmbr1
  iface vmbr1 inet static
      address 10.10.10.1/24
      bridge-ports none
      bridge-stp off
      bridge-fd 0
  ```

## Routing Mode (IP واحد لكل الداخل)

يستخدم هذا الوضع عندما يتوفر للسيرفر عنوان IP واحد فقط، ويُراد أن تخرج جميع الـVMs والـLXC للإنترنت عبر هذا الـIP باستخدام NAT.

### WAN Interface
- **الغرض:** الكارت الفيزيائي الذي يحمل عنوان IP العام للسيرفر.
- **الإعداد:** يوضع عليه IP عام مباشرة.
- **مثال:**
  ```bash
  auto enp5s0
  iface enp5s0 inet static
      address 157.90.75.55/28
      gateway 157.90.75.49
  ```

### LAN Interface (Bridge داخلي)
- **الغرض:** شبكة داخلية خاصة للـVMs، السيرفر نفسه يصبح Gateway لها.
- **الإعداد:** `vmbr1` بدون ربط بكارت فيزيائي، ويضع عليه IP داخلي.
- **مثال:**
  ```bash
  auto vmbr1
  iface vmbr1 inet static
      address 10.10.10.1/24
      bridge-ports none
      bridge-stp off
      bridge-fd 0
  ```

### تفعيل NAT + Routing

#### في `/etc/sysctl.conf`
يجب تفعيل IP Forwarding لتحويل السيرفر إلى Router.

```conf
net.ipv4.ip_forward=1
```

ثم تطبيق التعديلات:

```bash
sysctl -p
```

> **ملاحظات هامة:**
> - لا يمكن وضع `net.ipv4.ip_forward=1` داخل كتلة `iface` في `/etc/network/interfaces`.
> - يمكن استخدام `sysctl -w net.ipv4.ip_forward=1` مؤقتًا، لكن الأفضل استخدام `/etc/sysctl.conf`.
> - يمكن أيضًا استخدام `/etc/sysctl.d/*.conf` كبديل منسّق.

#### قواعد NAT (iptables)
يتم تحويل عنوان الـVMs الداخلي إلى عنوان IP العام للسيرفر باستخدام MASQUERADE.

```bash
iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o enp5s0 -j MASQUERADE
```

**شرح القاعدة:**
- `-t nat`: جدول NAT
- `-A POSTROUTING`: في مرحلة POSTROUTING قبل الخروج
- `-s 10.10.10.0/24`: مصدر الترافيك من الشبكة الداخلية
- `-o enp5s0`: الخروج عبر كارت WAN
- `-j MASQUERADE`: تحويل العنوان ديناميكيًا للـIP العام

**لحفظ القاعدة بشكل دائم:**

```bash
iptables-save > /etc/iptables/rules.v4
```

**فتح مسار FORWARD (مهم جدًا):**

```bash
iptables -A FORWARD -i vmbr1 -o enp5s0 -j ACCEPT
iptables -A FORWARD -i enp5s0 -o vmbr1 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -P FORWARD ACCEPT
```

### اختبار
يمكن التأكد من أن Routing + NAT يعملان بعدة طرق:

1. **من داخل السيرفر:**
   ```bash
   ping -I vmbr1 8.8.8.8
   ```
2. **من داخل VM:**
   ```bash
   ping 8.8.8.8
   ping google.com
   ```
3. **التأكد من IP Forwarding:**
   ```bash
   cat /proc/sys/net/ipv4/ip_forward
   ```
4. **مراقبة الترافيك على WAN:**
   ```bash
   tcpdump -i enp5s0 icmp
   ```
5. **فحص عدادات FORWARD:**
   ```bash
   iptables -nvL FORWARD
   ```

## Path الداتا (من VM → إنترنت)

عندما تقوم VM بطلب إنترنت، يسير الترافيك كالتالي:

1. **VM → Gateway:** ترسل VM الحزمة إلى Gateway الخاص بها (`10.10.10.1`).
2. **Routing على السيرفر:** يرى السيرفر أن الوجهة خارج شبكته، ويقرر تمرير الحزمة (بفضل `ip_forward=1`).
3. **FORWARD Chain:** تمر الحزمة عبر جدول FORWARD في iptables.
4. **NAT:** يتم تغيير عنوان المصدر (Source IP) من `10.10.10.x` إلى عنوان IP العام للسيرفر (`MASQUERADE`).
5. **خروج عبر WAN:** تخرج الحزمة من `enp5s0` إلى الإنترنت.
6. **عودة الرد:** يصل الرد إلى السيرفر على عنوانه العام.
7. **فك NAT:** يقوم السيرفر بفك ترجمة العنوان وإرجاعه للـVM الأصلي.
8. **VM تستلم الرد:** تصل الحزمة للـVM عبر `vmbr1`.

**مخطط مبسط:**

```text
VM (10.10.10.x) → vmbr1 → Kernel (IP Forward) → iptables (FORWARD + NAT) → enp5s0 (Public IP) → Internet
Internet → enp5s0 → iptables (Reverse NAT) → vmbr1 → VM
```

## أخطاء شائعة

| الخطأ | السبب | الحل |
|---|---|---|
| **VM لا ترى الإنترنت** | `ip_forward=0` | تفعيل `net.ipv4.ip_forward=1` في `/etc/sysctl.conf` ثم `sysctl -p` |
| **VM لا ترى الإنترنت رغم Forwarding** | FORWARD chain محظور | فتح FORWARD بـ `iptables -P FORWARD ACCEPT` أو القواعد المناسبة |
| **VM ترى السيرفر لكن لا ترى الإنترنت** | قاعدة NAT مفقودة | إضافة قاعدة `MASQUERADE` وحفظها بـ `iptables-save` |
| **لا يمكن الوصول للـGateway من VM** | `vmbr1` معرف كـ `manual` بدل `static` | تغيير `iface vmbr1 inet manual` إلى `iface vmbr1 inet static` مع `address` |
| **فصل SSH بعد تعديل الشبكة** | خطأ في ملف `/etc/network/interfaces` | استخدام `ifreload -a` بدل `systemctl restart networking` لتفادي القطع |
| **NAT لا يعمل** | استخدام `-s vmbr1` بدل `-s 10.10.10.0/24` في iptables | يجب استخدام نطاق IP وليس اسم Interface في `-s` |
| **تكرار قواعد iptables** | وضع قواعد في `post-up/down` داخل interfaces | الأفضل حفظ القواعد في `/etc/iptables/rules.v4` بدلاً من hooks |
| **بطء WireGuard بعد الاتصال** | MTU غير مضبوط أو AllowedIPs خاطئ أو DNS بطيء | تجربة `MTU=1280` أو `MTU=1420`، مراجعة `AllowedIPs`، واستخدام DNS سريع مثل `1.1.1.1` |

## نماذج شائعة لملف `/etc/network/interfaces`

### نموذج 1: Bridge Mode (VMs تأخذ IP عام)
```bash
auto lo
iface lo inet loopback

auto enp5s0
iface enp5s0 inet manual

auto vmbr0
iface vmbr0 inet manual
    bridge-ports enp5s0
    bridge-stp off
    bridge-fd 0
```

### نموذج 2: Routing Mode (IP واحد + NAT)
```bash
auto lo
iface lo inet loopback

auto enp5s0
iface enp5s0 inet static
    address 157.90.75.55/28
    gateway 157.90.75.49

auto vmbr1
iface vmbr1 inet static
    address 10.10.10.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
```

## أوامر مفيدة للتشخيص

| الأمر | الاستخدام |
|---|---|
| `ip a` | عرض جميع Interfaces وعناوين IP |
| `ip r` | عرض Routing Table |
| `ip link show` | عرض حالة الـInterfaces |
| `sysctl net.ipv4.ip_forward` | التحقق من حالة IP Forwarding |
| `iptables -t nat -nvL POSTROUTING` | عرض قواعد NAT |
| `iptables -nvL FORWARD` | عرض عدادات FORWARD |
| `tcpdump -i enp5s0 icmp` | مراقبة ICMP على WAN |
| `ping -I vmbr1 8.8.8.8` | اختبار Forwarding من داخل السيرفر |
| `ifreload -a` | إعادة تحميل الشبكة بأمان دون قطع SSH |

## ملاحظات إضافية

- **Bridge بدون كارت فيزيائي (`bridge-ports none`):** يستخدم لعمل شبكة داخلية خالصة.
- **Bridge مع كارت فيزيائي:** يستخدم لربط الـVMs بالشبكة الفيزيائية مباشرة.
- **`bridge-stp off`:** يوقف Spanning Tree Protocol لتفادي التأخير، ويُستخدم في بيئات بسيطة.
- **`bridge-fd 0`:** يزيل Forward Delay لتسريع تفعيل البورت.
- **`MASQUERADE` vs `SNAT`:** يفضل `MASQUERADE` في السيرفرات ذات IP الديناميكي، أما `SNAT` فيفضل مع IP ثابت دائمًا.
- **أفضل مكان لقواعد NAT:** حفظها في `/etc/iptables/rules.v4` وليس داخل `/etc/network/interfaces`.