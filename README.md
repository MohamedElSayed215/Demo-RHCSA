# ⚡ RHCSA Terminal Lab

Terminal Linux **حقيقي** في المتصفح — مبني بـ Node.js + xterm.js + node-pty

## 🏗️ هيكل المشروع

```
rhcsa-terminal-lab/
├── server.js          # Node.js + WebSocket + node-pty
├── package.json
├── Dockerfile         # Docker container
├── render.yaml        # Render deployment
├── scripts/
│   └── setup-rhcsa-env.sh  # إعداد بيئة RHCSA
└── public/
    └── index.html     # xterm.js frontend
```

## 🚀 النشر على Render (مجاناً)

### الخطوة 1: رفع على GitHub

```bash
git init
git add .
git commit -m "⚡ RHCSA Terminal Lab"
git branch -M main
git remote add origin https://github.com/USERNAME/rhcsa-terminal-lab.git
git push -u origin main
```

### الخطوة 2: إنشاء خدمة على Render

1. اذهب إلى [render.com](https://render.com) وسجّل دخول
2. اضغط **New +** → **Web Service**
3. اختر **Connect a repository** واختر الـ repo
4. الإعدادات:
   - **Name**: rhcsa-terminal-lab
   - **Runtime**: **Docker**  ← مهم جداً
   - **Plan**: Free
5. اضغط **Create Web Service**

### الخطوة 3: انتظر 3-5 دقائق

بعد البناء، الموقع سيكون على:
```
https://rhcsa-terminal-lab.onrender.com
```

---

## ✨ المميزات

| الميزة | التفاصيل |
|--------|---------|
| 🖥️ Terminal حقيقي | node-pty يشغّل bash حقيقي |
| ⚡ xterm.js | أفضل terminal emulator للويب |
| 📋 20 مهمة RHCSA | من Network إلى LVM |
| 💡 تلميحات تدريجية | اضغط على التلميح ليظهر |
| 📋 نسخ سريع | اضغط على الكود لنسخه للـ terminal |
| ✅ تحقق تلقائي | يراقب المخرجات ويحدد الإنجاز |
| 🔄 إعادة اتصال | تلقائياً عند انقطاع الاتصال |

## 🛠️ التشغيل المحلي

```bash
npm install
node server.js
# افتح: http://localhost:3000
```

## 📋 المهام (20 مهمة)

### serverb:
1. تكوين الشبكة (nmcli)
2. Repository
3. SELinux — المنفذ 82
4. Users & Groups
5. مجلد مشترك (SGID)
6. AutoFS
7. Cron Job
8. NTP
9. find ملفات sarah
10. grep في /etc/passwd
11. useradd بـ UID محدد
12. tar archive
13. Container image (podman)
14. Container كـ systemd service
15. umask لـ natasha
16. Password expiry
17. Sudo بدون كلمة مرور

### servera:
18. LVM — إنشاء Logical Volume
19. LVM — توسيع Logical Volume
20. Tuned profile

## ⚠️ ملاحظات

- **Render Free Tier**: الخادم ينام بعد 15 دقيقة خمول — أول طلب يستغرق ~30 ثانية
- **العزل**: كل مستخدم يشارك نفس الـ bash session في Free tier
- للعزل الكامل (كل مستخدم بجلسة منفصلة): استخدم Docker-in-Docker أو Railway Pro
