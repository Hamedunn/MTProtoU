# MTProto Proxy Manager
📌 **GitHub Repository:** [Hamedunn/MTProtoU](https://github.com/Hamedunn/MTProtoU)


یک رابط کاربری تحت وب و کاربرپسند برای مدیریت سرویس‌های MTProto Proxy (نسخه‌های Official، Python و Golang) بدون نیاز به استفاده از دستورات ترمینال.  
این ابزار به شما اجازه می‌دهد تا پراکسی‌ها را **نصب، پیکربندی، اجرا، توقف، ری‌استارت و حذف** کنید، همه از طریق یک UI مدرن که با **React و Tailwind CSS** ساخته شده و یک **سرور Node.js** آن را پشتیبانی می‌کند.

---

## ✨ ویژگی‌ها

- **داشبورد:** مشاهده تمام پراکسی‌های نصب شده همراه با وضعیت، پورت و لینک اتصال.  
- **نصب:** نصب پراکسی Official، Python یا Golang با تنظیمات قابل سفارشی‌سازی (پورت، سکرت، AD Tag، Workers، TLS Domain، NAT و ...).  
- **مدیریت:** استارت، استاپ، ری‌استارت یا حذف سرویس‌ها تنها با یک کلیک.  
- **پیکربندی:** مدیریت سکرت‌ها، AD Tag، Workers، تنظیمات NAT و حالت‌های امن از طریق فرم‌ها.  
- **فایروال:** ایجاد و اعمال قوانین فایروال برای CentOS، Ubuntu یا Debian.  
- **بدون ترمینال:** مناسب کاربران غیر فنی، بدون نیاز به دستورات CLI.  
- **پورت تصادفی:** سرور روی یک پورت تصادفی و آزاد اجرا می‌شود تا امنیت و انعطاف بیشتری داشته باشد.  

---

## 📋 پیش‌نیازها

- یک سرور با Ubuntu، Debian یا CentOS  
- دسترسی Root  
- نصب بودن Node.js و npm  
- وابستگی‌ها: `lsof`, `curl`, `python3`, `pip`, `jq`  
- دسترسی به اینترنت برای دانلود و پیکربندی‌ها  

---

## ⚙️ نصب

### 1. نصب وابستگی‌های سیستمی

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y nodejs npm lsof curl python3 python3-pip jq
```

**CentOS:**
```bash
sudo yum install -y epel-release
sudo yum install -y nodejs npm lsof curl python3 python3-pip jq
```

---

### 2. کلون کردن مخزن
```bash
git clone https://github.com/Hamedunn/MTProtoU.git /opt/mtproxy-manager
cd /opt/mtproxy-manager
```

---

### 3. نصب وابستگی‌های Node.js
```bash
npm install express
```

---

### 4. تنظیم ساختار فایل‌ها
مطمئن شوید فایل‌های زیر در مسیر `/opt/mtproxy-manager` وجود داشته باشند:
- `index.html` (رابط کاربری React)
- `server.js` (بک‌اند Node.js)
- `MTProtoProxyOfficialInstall.sh` (اسکریپت نصب Official Proxy)
- `MTProtoProxyInstall.sh` (اسکریپت نصب Python Proxy)
- `MTGInstall.sh` (اسکریپت نصب Golang Proxy)

سپس:

```bash
mkdir -p public
mv index.html public/
chmod +x *.sh
```

---

### 5. اجرای سرور
```bash
node server.js
```

سرور روی یک پورت تصادفی (مثلاً `http://localhost:54321`) اجرا خواهد شد.  
آدرس در ترمینال نمایش داده می‌شود.

---

### 6. دسترسی به UI
- مرورگر خود را باز کنید و آدرس نمایش داده شده (مثلاً `http://localhost:54321`) را وارد کنید.  
- اگر از راه دور وصل می‌شوید، مطمئن شوید فایروال سرور اجازه دسترسی به پورت مربوطه را می‌دهد (`ufw` یا `firewall-cmd`).  

---

## 🚀 استفاده

- **داشبورد:** مشاهده پراکسی‌های نصب‌شده، وضعیت و لینک اتصال Telegram.  
- **نصب پراکسی:**  
  - انتخاب "Install Official Proxy"، "Install Python Proxy" یا "Install Golang Proxy".  
  - پر کردن فرم (پورت، سکرت، AD Tag، Workers، TLS Domain، NAT و ...).  
- **مدیریت:** اجرای دستورات Start, Stop, Restart یا Uninstall.  
- **پیکربندی:** تغییر سکرت، AD Tag یا سایر تنظیمات از طریق بخش Configure.  
- **قوانین فایروال:** حین نصب نمایش داده می‌شوند و قابل اعمال هستند.  
- **لینک اتصال:** کپی `tg://proxy` از داشبورد برای استفاده در Telegram.  

---

## 📌 نکات

- **امنیت:** اجرای سرور باید با دسترسی Root باشد. برای محیط Production پیشنهاد می‌شود **احراز هویت** به UI اضافه شود.  
- **Erlang Proxy:** پشتیبانی از نسخه Erlang (mtp_install.sh) فعلاً وجود ندارد اما می‌توان به بک‌اند اضافه کرد.  
- **وابستگی‌ها:** مطمئن شوید `jq` نصب است تا اسکریپت Python درست کار کند.  
- **تداخل پورت:** سرور همیشه یک پورت تصادفی انتخاب می‌کند. در صورت عدم دسترسی، تنظیمات فایروال را بررسی کنید.  
- **به‌روزرسانی:** برای تغییر سکرت یا TLS Domain از بخش "Configure" استفاده کنید.  

---

## 🤝 مشارکت

پیشنهادات و بهبودها خوشحالمان می‌کند! لطفاً Pull Request بفرستید یا Issue باز کنید.  

---

## 📄 لایسنس

این پروژه تحت **MIT License** منتشر شده است. جزئیات در فایل [LICENSE](LICENSE).  

---

## 🙏 تقدیر و تشکر

- اسکریپت‌های اصلی پراکسی توسط **Hirbod Behnam**  
- رابط کاربری ساخته‌شده با **React** و **Tailwind CSS**  
- بک‌اند توسعه‌یافته با **Node.js**  
