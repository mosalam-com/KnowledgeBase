# المعرفة التقنية (Engineering Knowledge)

البيت الفعلي لكل "كيف تعمل الشركة تقنياً" — التشغيل والتنفيذ بالخطوات، وليس الوصف التسويقي.
هنا تجد runbooks و configs وأدلة التنفيذ التي يشتغل بها الفريق الهندسي يومياً.

## موقع هذا الفولدر ضمن القاعدة
| الفولدر | اختصاصه | الحد |
| --- | --- | --- |
| `engineering/` (هنا) | **كيف ننفّذ**: خطوات فعلية، أوامر، إعدادات، Runbooks | لا يُكتب هنا وصف الخدمة |
| `services/` | عرض الخدمة للعميل (المواصفات المعلنة) | ليس دليلاً تنفيذياً |
| `infrastructure/` | الاستراتيجية والعناوين والأصل (أين، لماذا) | ليس الخطوات |
| `operations/` | سير العمل اليومي والإجراءات العامة (من، متى) | ليس الأوامر/الإعدادات |

## البنية المعتمدة
```
engineering/
├── 00-template.md              ← انسخه لأي process/runbook جديد
├── infrastructure/             ← المعدات والسيرفرات والاستراتيجية الفنية
│   ├── server-selection.md     ← معايير اختيار Dedicated Server
│   ├── proxmox-setup.md        ← إعداد بيئة Proxmox على Hetzner
│   ├── micro-datacenter-strategy.md ← خطة Micro/Nano DC والخدمات
│   └── cost-optimization.md    ← خفض التكلفة تقنياً
├── networking/                 ← الشبكات و VPN و Reverse Proxy
│   ├── proxmox-networking.md   ← ملف interfaces و Bridges و NAT
│   ├── opnsense-router.md      ← OPNsense/pfSense كجدار و Router
│   ├── traefik-reverse-proxy.md ← Traefik على Docker + Let's Encrypt
│   └── wireguard-vpn.md        ← VPN داخلي WireGuard
├── hosting/                    ← إنشاء حساب/VPS ورفع العميل (قيد التعبئة)
├── backup-restore/             ← نسخ احتياطي (ZFS) واسترجاع VMs (قيد التعبئة)
├── troubleshooting/            ← مرجع المشاكل والحلول والأسباب — يغذّي التصميم والمراقبة
│   ├── 00-template.md          ← قالب لأي مشكلة جديدة
│   └── <case>.md               ← حالة موثقة (السبب + الحل + الوقاية + تحسين التصميم/المراقبة)
└── security/                   ← تحصين و طبقات الحماية
    └── proxmox-hardening.md    ← طبقات الحماية العشر
```

## المصادر المعبأة
- كل الملفات تقريباً معبأة من محادثات كوبيلوت التقنية (`/tmp/opencode/copilot_digest`) — كل ملف يحمل رأساً يحدد محادثته المصدر.
- `infrastructure/datacenters.md` و `operations/processes.md` — ابدأ منها ووسّعها بالتفصيل العملي.
- **قيد التعبئة:** `hosting/` و `backup-restore/` (لها `index.md`) — تُستخرج من الممارسة الفعلية والمحادثات اللاحقة.

> **قاعدة:** أي خطوة تنفيذية يُعاد تكرارها مرتين تتحول إلى runbook هنا — العمل القابل لإعادة الاستخدام لا يبقى في المخزنات المؤقتة.