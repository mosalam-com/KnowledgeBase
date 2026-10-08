# فصل SSH بعد تعديل ملف الشبكات

> - **التاريخ:** 2026-07
> - **القسم:** networking
> - **الخطورة:** حرجة
> - **الحالة:** وُثّق السبب والحل المعالج
> - **المصدر/المرجع:** `engineering/networking/proxmox-networking.md`

## الأعراض (Symptom)
- بعد تعديل `/etc/network/interfaces` وإعادة تطبيق الشبكة، تُقطع جلسة SSH فورا ولا تستطيع العودة — السيرفر يبقى شغالا لكن بلا شبكة صحيحة.

## التحقيق (Investigation)
- الخطأ في إعادة التطبيق: استخدام `systemctl restart networking` لا يُعيد تحميل الإعدادات الجديدة بأمان (يوقف/يشغّل الـ interfaces دفعة واحدة وقد يقطع الواجهة التي تحمل جلسة SSH الحالية).

## السبب الجذري (Root Cause)
- `systemctl restart networking` يطبق الشبكة بعنف ويقطع الواجهات الحالية، بينما الحل الصحيح هو **إعادة تحميل تدريجية** لا تقطع الجلسة الحالية.

## الحل المنفذ (Resolution)
- استخدام الأمر الآمن:
  ```bash
  ifreload -a
  ```
- (أو `ifup --allow=auto`) بدلا من إعادة تشغيل خدمة الشبكات.

## التحقق من الحل (Verification)
- الجلسة SSH تبقى حية، والـ interfaces الجديدة تظهر بـ `ip a`.

## هل ستتكرر؟ الوقاية (Prevention)
- قاعدة: **لا تستخدم `systemctl restart networking` أبدا** بعد تعديل الإعدادات — استخدم `ifreload -a`.
- قبل أي تعديل جوهري في الشبكة: خذ Snapshot (`zfs snapshot rpool/ROOT/pve-1@before-net`) كأمان، وجهّز خطة Rescue Mode.

## تحسين التصميم (Infrastructure Design Improvement)
- لا تعدّل public NIC عن بُعد؛ اعتمد على اتصال احتياطي (WireGuard/Console من Rescuer) قبل أي تغيير شبكي.

## تحسين المراقبة (Monitoring Improvement)
- فحص دوري لسلامة `/etc/network/interfaces` (validity) قبل إعادة التحميل، وسكربت تحقق من أن vmbr0 يحمل IP العام الصحيح بعد أي إقلاع.

## دروس مستفادة (Lessons)
- `ifreload -a` لا `systemctl restart networking`؛ وأي لمس للشبكة عن بُعد يحتاج شبكة أمان (Console/Rescue) وفيه Snapshot أول.