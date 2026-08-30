# مزامنة وقت Dreambox - الإصدار 1.1.0

[English](README.md) | العربية

Dreambox NTP Sync هي خدمة خفيفة لمزامنة وقت النظام على أجهزة Dreambox التي تعمل بواجهة Enigma2. تدعم Python 2.7 وPython 3 ولا تعتمد على صورة Enigma2 بعينها.

## المتطلبات

- جهاز Dreambox يعمل بواجهة Enigma2.
- صورة تعتمد حزم DEB وتحتوي على `dpkg` و`dpkg-query`.
- Python 2.7 أو Python 3.
- اتصال بالإنترنت لإجراء مزامنة NTP.
- وجود `wget` أو `curl` للتثبيت التلقائي.

## التثبيت التلقائي بأمر واحد

اتصل بالرسيفر بواسطة Telnet أو SSH كمستخدم `root`، ثم نفّذ:

```sh
wget -qO- "https://raw.githubusercontent.com/Saiedf/DreamboxNTP/main/installer_dreambox_ntp_sync_auto.sh?nocache=$(date +%s)" | /bin/sh
```

يقوم سكربت التثبيت تلقائيًا بما يلي:

- قراءة أحدث إصدار من `ver.txt`.
- تنزيل حزمة DEB المطابقة من مجلد `Releases`.
- إزالة أي إصدار سابق مثبت باستخدام `dpkg --purge`.
- حذف الملفات والخدمات والسجلات وملفات التخزين المؤقت المعروفة الخاصة بالإصدار 1.0.0.
- إزالة إضافة DreamTimeSync القديمة عند اكتشافها لمنع تعارض مزامنة الوقت والرسائل المتكررة.
- تثبيت الحزمة الجديدة.
- إعادة تحميل systemd وتفعيل مؤقت المزامنة.
- إجراء اختبار مزامنة فوري.
- التحقق من الإصدار والخدمة بعد التثبيت.
- عرض رسالة نجاح واحدة ثم إعادة تشغيل الرسيفر بالكامل تلقائيًا.

لا يحتاج المستخدم إلى تنفيذ خطوات إضافية أو الإجابة عن أي أسئلة أثناء التثبيت.

## التثبيت اليدوي

نزّل الملف التالي وانقله إلى مجلد `/tmp`:

```text
dreambox-ntp-sync_1.1.0_all.deb
```

ثم نفّذ:

```sh
dpkg -i /tmp/dreambox-ntp-sync_1.1.0_all.deb
systemctl daemon-reload
systemctl enable --now dreambox-ntp-sync.timer
systemctl start dreambox-ntp-sync.service
reboot
```

## التحقق من التثبيت

```sh
/usr/bin/dreambox-ntp-sync --version
systemctl status dreambox-ntp-sync.timer --no-pager
systemctl status dreambox-ntp-sync.service --no-pager
cat /tmp/dreambox-ntp-sync.log
date
```

يجب أن يظهر المؤقت بحالة `active (waiting)`. أما الخدمة فهي من نوع one-shot، ولذلك قد تظهر بحالة `inactive (dead)` بعد انتهاء المزامنة بنجاح، وهذا طبيعي.

## ملف السجل

تُحفظ نتائج المزامنة في:

```text
/tmp/dreambox-ntp-sync.log
```

تعمل خدمة المزامنة في الخلفية دون إظهار رسائل دورية على الشاشة. قد يعرض سكربت التثبيت رسالة نجاح واحدة فقط بعد اكتمال التثبيت.

## إزالة الحزمة

```sh
dpkg --purge dreambox-ntp-sync
systemctl daemon-reload
```

## ترتيب ملفات الإصدار على GitHub

```text
README.md
README-AR.md
ver.txt
installer_dreambox_ntp_sync_auto.sh
Releases/dreambox-ntp-sync_1.1.0_all.deb
```
