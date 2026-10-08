# الحظر من Hetzner عند لمس vmbr0 / MAC إضافي

> - **التاريخ:** 2026-07
> - **القسم:** networking
> - **الخطورة:** حرجة
> - **الحالة:** تجنّبتها بتصميم — مشكلة محتملة توثيقا وقائيا
> - **المصدر/المرجع:** `engineering/networking/proxmox-networking.md` + `engineering/infrastructure/proxmox-setup.md`

## الأعراض (Symptom)
- السيرفر يُفصل كليا من الإنترنت، ولا يُستعاد إلا عبر **Rescue Mode** من لوحة Hetzner ثم إصلاح الشبكة يدويا.
- يحدث عند: إضافة MAC إضافي على الشبكة العامة، أو عمل Bridge على الـ Public NIC يمرر أجهزة أخرى، أو تعديل إعدادات vmbr0/enp5s0.

## التحقيق (Investigation)
- مراجعة سياسات Hetzner (strict routing): يسمح بـ **MAC واحد فقط** على الشبكة العامة، وأي MAC جديد = انتهاك.

## السبب الجذري (Root Cause)
- Hetzner يعمل بـ **strict routing** على الشبكة العامة؛ أي Bridge/VM/NAT خارجي يظهر MAC جديدا على الشبكة العامة فيُحوَّل السيرفر إلى "غير موثوق" فيُحجب.

## الحل المنفذ (Resolution)
- لم نقع فيها، بل تجنّبناها بالتصميم:
  - إبقاء الـ Public IP وحده على vmbr0 (`address 91.98.186.15/26` + `gateway 91.98.186.1` + `bridge-ports enp5s0`).
  - كل الشبكات الداخلية vmbr1/vmbr2/vmbr3 بـ `bridge-ports none` (Layer 2 معزول، لا MAC جديدة).
  - كل NAT يتم **داخل السيرفر** (MASQUERADE أو OPNsense) فلا يظهر أي MAC للعالم الخارجي.
  - عدم وضع VMs مباشرة على الشبكة العامة؛ الخروج للإنترنت فقط عبر NAT.

## التحقق من الحل (Verification)
- ip a → لا IP عام إلا على vmbr0، والداخلية `bridge-ports none`.
- Hetzner لا يرى أي MAC إضافي (اختبار بالمراجعة من لوحة التحكم).

## هل ستتكرر؟ الوقاية (Prevention)
- القاعدة الذهبية: **لا تلمس vmbr0 ولا enp5s0**.
- قبل أي تعديل شبكة: `ifreload -a` بدلا من إعادة التشغيل المفاجئة، وسحب Snapshot قبلها.

## تحسين التصميم (Infrastructure Design Improvement)
- إبقاء الوصول العام للويب حصرا عبر Traefik (80/443) والدخول الإداري عبر WireGuard (51820/UDP) — لا فتح أي Port غيرها.
- أي IP/MAC إضافي يجب شراؤه رسميا (Additional IP / vSwitch).

## تحسين المراقبة (Monitoring Improvement)
- مراقبة واجهات الشبكة (`ip a`, `ip -s link`) دوريا كفحص آلية في كرون يشك في أي واجهة غير متوقعة على الشبكة العامة.
- تنبيه عند ظهور أي MAC جديد في ARP table (`ip neigh`).

## دروس مستفادة (Lessons)
- Hetzner يعمل strict routing: MAC واحد، NAT داخلي فقط، ولا لمس للـ Public NIC — أي مخالفة = حجب كامل.