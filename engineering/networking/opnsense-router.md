# Firewall / Router — OPNsense + pfSense

> المحادثة المصدر: `بناء_بيئة_داتا_سنتر_باستخدام_Proxmox.txt`
> **حالة:** مُعبأ من محادثة بناء_بيئة_داتا_سنتر.

## الدور داخل البيئة
- OPNsense (وكان مرشحه الأول pfSense قبل اختيار المستخدم لـ OPNsense) هو **الراوتر الداخلي الرئيسي** لكل الشبكات داخل Proxmox على Hetzner، وبيأدي 6 أدوار مع بعض: **Router** بين الشبكات (Inter-VLAN Routing)، **DHCP Server** لكل شبكة، **DNS Resolver** داخلي (Unbound)، **Firewall** للتحكم في كل الـ Traffic، **NAT Gateway** اختياري علشان الـ VMs تخرج للإنترنت، و**أساس أي Lab** بعده (Active Directory، Kubernetes، Ceph، Monitoring، DMZ، VLANs، VPN).
- بدونه تكون الشبكات الداخلية مجرد **Bridges فاضية**: أي VM هتشغّله على vmbr1/vmbr2/vmbr3 مش هياخد IP ومش هيعرف يتكلم مع باقي الشبكات.
- اختيار OPNsense بدل pfSense كان مبرَّره تقنيًا: **أخف، واجهته أنضف، وفيها Plugins جاهزة** للـ IDS/IPS والـ WireGuard و Traffic Shaping.
- التوزيع داخل بيئته:
  - `vmbr0` → شبكة Hetzner الحقيقية (Public) — البروكس نفسه بس، **ما يلمسوش**.
  - `vmbr1` → `192.168.100.0/24` → **WAN الداخلي لـ OPNsense فقط**.
  - `vmbr2` → `192.168.90.0/24` → **LAN الرئيسي** لكل الـ VMs.
  - `vmbr3` → `192.168.80.0/24` → شبكة إضافية (DMZ / LAB) باسم OPT1.
  - كلها `bridge-ports none`، Layer 2 داخلي بحت، مفيش MAC جديدة ومفيش علاقة بـ Hetzner.

## التثبيت وإعداد الـ Interfaces
- تثبيت OPNsense: **VM جديدة داخل Proxmox** بإعدادات: 2 vCPU، 2GB RAM، 20GB Disk، Machine **q35**، BIOS **UEFI**، وأجهزة الشبكة من نوع **VirtIO (paravirtualized)** لأنها الأسرع والأخف: NIC1 → `vmbr1` (WAN)، NIC2 → `vmbr2` (LAN)، NIC3 → `vmbr3` (اختياري). Boot من الـ ISO، وقت التثبيت اختار **Install** → **ZFS** أو **UFS** (**UFS أخف للـ Lab**) → اعمل Set لـ **root password** → اعمل Restart.
- Interfaces: بعد الـ Boot الأولي بيطلب الإعداد يدويًا:
  - **WAN** = `vtnet0` → IP `192.168.100.2/24` و **Gateway = `192.168.100.1`** (ده الـ IP بتاع vmbr1 عند Proxmox). المهم جدًا: WAN هنا **مش WAN حقيقي**، مجرد شبكة داخلية — **مافيش DHCP على WAN، مافيش DNS، مافيش أي Services**؛ الوصفة الوحيدة إنها "الإنترفيس اللي عليه Routing الداخلي".
  - **LAN** = `vtnet1` → IP `192.168.90.1/24` + تفعيل **DHCP** بـ Range `192.168.90.50 → 192.168.90.200` + سيب **DNS Resolver (Unbound)** شغال.
  - **OPT1** (لو استخدمت vmbr3) = `vtnet2` → IP `192.168.80.1/24` + DHCP Range `192.168.80.50 → 192.168.80.200`.
  - ترتيب الـ NICs لازم يتطابق مع الترتيب في Proxmox (vtnet0 = أول NIC = vmbr1) وإلا هتتلخبط الخريطة.
- الوصول للواجهة: **من شبكة LAN فقط وليس WAN**، لأن OPNsense بيمنع الوصول من WAN كحماية افتراضية. الخطوات العملية: (1) أنشئ VM Ubuntu أو Windows على `vmbr2`، (2) هتاخد IP تلقائي من DHCP بتاع OPNsense مثلًا `192.168.90.50`، (3) افتح المتصفح جوّه الـ VM واكتب `https://192.168.90.1`، (4) سجّل الدخول بـ `root` وكلمة السر اللي اخترتها وقت التثبيت. يعني عنوان الإدارة الثابت = **IP الـ LAN بتاع OPNsense**.
- NAT الداخلي: علشان الـ VMs تخرج للإنترنت — **Firewall → NAT → Outbound → اختار Hybrid Outbound NAT → Save → Add Rule** بالقيم: `Interface: WAN`، `Source: 192.168.90.0/24` (ولو عندك vmbr3 ضيف قاعدة تانية بـ `Source: 192.168.80.0/24`)، `Translation: Interface Address`. وبعدها لازم قاعدة سماح: **Firewall → Rules → LAN → Add Rule** = `Action: Pass` / `Source: LAN net` / `Destination: any`. النتيجة: أي VM على LAN أو OPT1 هيخرج للإنترنت **باستخدام الـ IP بتاع OPNsense على vmbr1**، والـ Traffic يتنقل لحد Hetzner من غير أي مشاكل.

## قرار التصميم: Router للـ VMs فقط أم NAT للإنترنت؟
- عُرض على المستخدم خياران قبل التنفيذ: **(1) Router داخلي فقط** بدون إنترنت للـ VMs، أو **(2) Router + NAT** علشان الـ VMs تخرج للإنترنت — **المستخدم اختار الخيار 2**، فاتحوّل OPNsense إلى **NAT Gateway داخلي**.
- مسار الترافيك بعد القرار: `VM → LAN (vmbr2) → OPNsense → WAN الداخلي (vmbr1) → Proxmox → vmbr0 → Hetzner → Internet`.
- **ليه ده آمن 100% ومسموح في Hetzner:** مفيش MAC جديدة بتظهر، مفيش Bridge على الـ Public NIC، كل الـ NAT بيتم **جوّه السيرفر**، Hetzner شايف السيرفر كأنه جهاز واحد، مفيش DHCP خارجي، مفيش Routing خارجي، ومفيش Spoofing — وده بالضبط اللي Hetzner بتسمح بيه. شرط أساسي: **مفيش جهاز واحد جوّه اللاب ليه Public IP**؛ كل حاجة بتخرج *إنترنت فقط* من خلال الـ NAT.
- توضيح اتنطلب صراحةً: **"هل أي حاجة على vmbr1 هتخرج نت أوتوماتيك؟" → لأ.** vmbr1 مجرد Bridge داخلي: مفيش Default Gateway، مفيش NAT، مفيش Route للإنترنت، ومفيش علاقة بينها وبين vmbr0 (Proxmox مش بيعمل Routing بين الـ bridges). الإنترنت الوحيد في السيرفر هو `vmbr0 → enp5s0 → Hetzner`.
- مرجع التوزيع بعد القرار: **vmbr0** = الإنترنت الحقيقي، **vmbr1** = WAN داخلي لـ OPNsense فقط، **vmbr2** = LAN للـ VMs، **vmbr3** = شبكة إضافية للـ Labs. يعني: **VM على vmbr1 → مش هتخرج إنترنت / VM على vmbr2 → هتخرج إنترنت عن طريق OPNsense NAT**. وواضح إن WAN مش المفروض يكون عليه VMs أصلًا — الـ VMs المفروض تكون على LAN.
- وأيضًا: **خروج الـ VM للإنترنت (Outbound) ≠ قدرتك تدخل عليها من بره (Inbound)** — الاتنين موضوعين منفصلين تمامًا. للدخول من البيت عندك 3 طرق: **VPN داخل OPNsense** (الأفضل والأأمن — WireGuard / OpenVPN / IPSec، بيدّيك رؤية 192.168.90.0/24 و192.168.80.0/24 و192.168.100.0/24 **من غير ما تفتح ولا Port على Hetzner**)، أو **Port Forwarding** في OPNsense (مثل WAN Port 50001 → LAN 192.168.90.10:3389 للـ RDP، لكنه محتاج فتح Port على Hetzner وRules وأقل أمانًا)، أو **الدخول على Proxmox GUI/VNC Console** (أسهل حاجة وشغالة حتى لو الـ VM مفيهاش نت، لكنها بطيئة ومفيهاش RDP/SSH مريح). التوصية النهائية للـ Data Center Lab: **WireGuard VPN على OPNsense**.

---

## أقسام تقنية إضافية

### بنية الشبكة المبدئية على Bare Metal (الأساس اللي بُني فوقه OPNsense)
```
auto vmbr0
iface vmbr0 inet static
        address 91.98.186.15
        netmask 255.255.255.192
        gateway 91.98.186.1
        bridge-ports enp5s0
        bridge-stp off
        bridge-fd 0

auto vmbr1
iface vmbr1 inet static
        address 192.168.100.1
        netmask 255.255.255.0
        bridge-ports none
        bridge-stp off
        bridge-fd 0

auto vmbr2
iface vmbr2 inet static
        address 192.168.90.1
        netmask 255.255.255.0
        bridge-ports none
        bridge-stp off
        bridge-fd 0

auto vmbr3
iface vmbr3 inet static
        address 192.168.80.1
        netmask 255.255.255.0
        bridge-ports none
        bridge-stp off
        bridge-fd 0
```
- **القاعدة الذهبية:** ما تلمسش `vmbr0` ولا `enp5s0` نهائيًا — ده الـ Public NIC بتاع Hetzner، وأي تعديل عليه معناه السيرفر يقع من النت ويضطر تدخل Rescue Mode وتصلّح يدويًا. Hetzner شغال بنظام strict routing وبيسمح بـ MAC واحد فقط.
- كل الـ bridges الداخلية `bridge-ports none` = Layer 2 خالص، مفيش physical NIC، مفيش MAC جديدة، Hetzner مش بيشوف أي ترافيك داخلي.

### ليه WAN لـ OPNsense على vmbr1 مش على vmbr0؟
- لأننا **مش عاوزين OPNsense يلمس Hetzner Network نهائيًا**. الـ WAN هنا معناها ببساطة "الإنترفيس اللي عليه Routing و DHCP الداخلي"، مش WAN حقيقي.
- لو حطيته على vmbr0، الـ Firewall VM هيلمس الشبكة العامة directly = مخاطرة بـ MAC جديد / Spoofing / حجب من Hetzner.

### الإعداد الكامل لـ NAT بعد قرار الخيار 2 (خطوة بخطوة)
1. **Interfaces → WAN** → Static IP `192.168.100.2/24`، Gateway `192.168.100.1`.
2. **Interfaces → LAN** → `192.168.90.1/24`، فعّل DHCP `192.168.90.50–200`، سيب Unbound DNS Resolver شغال.
3. **Interfaces → OPT1** (اختياري على vmbr3) → `192.168.80.1/24`، DHCP `192.168.80.50–200`.
4. **Firewall → NAT → Outbound** → **Hybrid Outbound NAT** → Save → Add Rule: `Interface: WAN`، `Source: 192.168.90.0/24`، `Translation: Interface Address` (وقاعدة تانية بـ `192.168.80.0/24` لو فيه OPT1).
5. **Firewall → Rules → LAN** → Add Rule: `Action: Pass`، `Source: LAN net`، `Destination: any` — ده اللي بيسمح للـ VMs تطلع للإنترنت.

### اختبار الإنترنت (Checklist)
اعمل VM Ubuntu على vmbr2 (NIC = VirtIO، Bridge = vmbr2) وبعد الإقلاع:
```
ip a
ping 192.168.90.1      # الـ Gateway (OPNsense LAN)
ping 8.8.8.8           # NAT شغال؟
ping google.com        # DNS شغال؟
```
لو التلاتة شغالين → الإنترنت شغال 100%.
ولو Windows Template: الـ VM هتاخد IP من DHCP بتاع OPNsense وتخرج للإنترنت عادي تعمل Updates والانضمام للـ Domain بعدين.

### الوصول للـ VMs من البيت (Inbound) — مقارنة الطرق
| الطريقة | الآلية | المميزات / العيوب |
|---|---|---|
| **WireGuard VPN على OPNsense** ⭐ | VPN Server جوّه OPNsense والجهاز في البيت يبقى كأنه جوّه vmbr2/vmbr3 | أمان عالي، **Zero ports exposed**، تشوف كل الشبكات، GUI + RDP + SSH |
| **Port Forwarding في OPNsense** | فتح Port على WAN الداخلي وForward لـ VM | لازم فتح Port على Hetzner (مش محبّذ) + Rules، أقل أمانًا، تُستخدم لخدمة واحدة Public بس |
| **Proxmox Console / GUI** | الدخول على Proxmox عنده Public IP وفتح Console | أسهل طريقة ومفيش إعدادات، Console شغالة حتى لو الـ VM مفيهاش نت، لكنها بطيئة ومش RDP/SSH |

### بدائل بدون OPNsense (لو شِلت الموضوع مؤقتًا)
- **Port Forwarding من Proxmox نفسه** عن طريق iptables:
  ```
  iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 50022 -j DNAT --to-destination 192.168.90.10:22
  iptables -t nat -A POSTROUTING -o vmbr0 -j MASQUERADE
  ```
  وبعدها من البيت: `ssh root@91.x.x.x -p 50022` — سريع وبسيط، لكن كل VM عايز Port خاص، مش آمن زي VPN، ومش Scalable.
- **WireGuard على Proxmox مباشرة** (الأنسب وقتها): إنشاء Interface `wg0` بـ IP داخلي مثلًا `10.10.10.1`، إضافة AllowedIPs للـ Clients، وفتح **Port واحد بس** على Hetzner = `UDP 51820`، وبعدها من البيت تدخل على كل الـ VMs على vmbr1/vmbr2/vmbr3 بدون Port Forwarding وبدون OPNsense.
- **ممنوع:** تشغيل NAT/Routing على الـ Public NIC، أو إضافة MAC جديد، أو DHCP خارجي — دي الحاجات اللي بتخلي Hetzner يحجب السيرفر.
- **Docker Engine على Proxmox** مفيهوش تعارض مع WireGuard VPN (طبقتين مختلفتين)، بشرط مراقبة iptables: لو شفت `default route` على `docker0` أو قواعد NAT بتاعته، يبقى Docker بيتحكم في التوجيه (غلط على Proxmox) — استخدم `iptables -t nat -L -n --line-numbers` للتحقق، لأن Docker بيضيف قواعد NAT خاصة بيه وProxmox نفسه بيدير الـ bridges بتاعته.

### أخطاء شائعة تُجنَّب
- وضع Management من WAN (زي `https://192.168.100.2`) → محجوب افتراضيًا، **الإدارة من LAN فقط**.
- نسيان قاعدة `Firewall → Rules → LAN` → الـ NAT شغال بس الـ VM مش قادر يطلع.
- تغيير ترتيب الـ NICs بين Proxmox و OPNsense → WAN و LAN بيتبادلا المكان.
- إعطاء أي VM على vmbr1 Gateway وتوقّع إنها هتخرج نت → مش هيحصل من غير NAT صريح من OPNsense.
- وضع VMs على vmbr1 (WAN) → مش منطقي؛ الـ VMs تكون على LAN (vmbr2).

### المرحلة التالية بعد OPNsense
بعد ما يبقى عندك: شبكات داخلية + Router + DHCP + DNS + NAT + Firewall + إنترنت للـ VMs → ابنِ **Templates** جاهزة (Ubuntu Cloud-Init / Debian / Windows Server 2022 مع VirtIO Drivers و Sysprep و Convert to Template) مربوطة على `vmbr2`، وبعدها Infrastructure Services: Active Directory، DNS داخلي، NTP، Prometheus + Grafana، GitLab/Gitea، Ansible، Terraform — وبعدها VLANs جوه OPNsense (Management / DMZ / Storage / LAB) كلها على نفس الـ Bridge.
