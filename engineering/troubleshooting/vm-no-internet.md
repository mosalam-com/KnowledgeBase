# VM لا تصل للإنترنت رغم وجود NAT

> - **التاريخ:** 2026-07
> - **القسم:** networking
> - **الخطورة:** متوسطة
> - **الحالة:** محلولة (وثّقنا أسبابها من محادثة الشبكات)
> - **المصدر/المرجع:** `engineering/networking/proxmox-networking.md`

## الأعراض (Symptom)
- VM على الشبكة الداخلية تصل إلى الـ Gateway (ping 192.168.90.1 يعمل) لكنها لا تخرج للإنترنت (ping 8.8.8.8 / google.com يفشل).

## التحقيق (Investigation)
- فحص `sysctl net.ipv4.ip_forward` → قد تكون 0.
- فحص `iptables -t nat -nvL POSTROUTING` → قد تكون قاعدة MASQUERADE مفقودة أو بشكل خاطئ.
- فحص `iptables -nvL FORWARD` → قد تكون السلسلة محظورة.

## السبب الجذري (Root Cause)
- من ثلاثة أسباب محتملة:
  1. **IP Forwarding معطل**: `net.ipv4.ip_forward=1` غير مفعل في `/etc/sysctl.conf`.
  2. **قاعدة NAT مفقودة/خاطئة**: لا توجد `MASQUERADE` من الشبكة الداخلية نحو vmbr0، أو استُخدم `-s vmbr1` (اسم interface) بدل `-s 192.168.90.0/24` (نطاق IP) — iptables لا يقبل اسم interface في `-s`.
  3. **FORWARD chain محظور**: لا قاعدة تسمح بالمرور بين vmbr1 → vmbr0.

## الحل المنفذ (Resolution)
1. تفعيل التوجيه بشكل دائم:
   ```conf
   net.ipv4.ip_forward=1
   ```
   ثم `sysctl -p`.
2. إضافة قاعدة NAT صحيحة:
   ```bash
   iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o enp5s0 -j MASQUERADE
   iptables-save > /etc/iptables/rules.v4
   ```
3. فتح FORWARD:
   ```bash
   iptables -A FORWARD -i vmbr1 -o enp5s0 -j ACCEPT
   iptables -A FORWARD -i enp5s0 -o vmbr1 -m state --state RELATED,ESTABLISHED -j ACCEPT
   ```

## التحقق من الحل (Verification)
- من داخل الـ VM: `ping 8.8.8.8` ثم `ping google.com` — كلاهما يعمل.
- `cat /proc/sys/net/ipv4/ip_forward` → 1
- `iptables -nvL FORWARD` → عدادات تزداد.

## هل ستتكرر؟ الوقاية (Prevention)
- وضع `net.ipv4.ip_forward=1` في `/etc/sysctl.conf` (وليس في `iface` داخل interfaces).
- حفظ قواعد NAT/iptables في `/etc/iptables/rules.v4` (وليس hooks داخل `/etc/network/interfaces`) لتفادي تكرارها أو ضياعها عند إعادة الإقلاع.

## تحسين التصميم (Infrastructure Design Improvement)
- مسار خروج واضح واحد مفاهيميًا: VM → vmbr2 → OPNsense (NAT) → vmbr1 → Proxmox → vmbr0 → Hetzner. لا تعتمد على قواعد MASQUERADE يدوية على Proxmox إلا كحل مؤقت.

## تحسين المراقبة (Monitoring Improvement)
- فحص دوري آلي: `check_ip_forward.sh` يتأكد أن `ip_forward=1` وقاعدة MASQUERADE موجودة — خطوة في كرون أو ضمن فحص صحة الشبكة الأسبوعي.

## دروس مستفادة (Lessons)
- 80% من مشاكل خروج الـ VMs = ip_forward معطل أو قاعدة NAT بسياق خاطئ أو FORWARD محظور. افحص الثلاثة بالترتيب قبل أي شيء آخر.