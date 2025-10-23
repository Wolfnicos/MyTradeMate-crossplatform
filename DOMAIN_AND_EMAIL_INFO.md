# MyTradeMate - Domain & Email Information

**Last Updated:** October 23, 2025  
**Status:** ✅ CONFIRMED

---

## 🌐 Domain Information

### Primary Domain
**Domain:** mytrademate.app  
**Status:** ✅ Purchased  
**Registrar:** [Your Registrar]  
**Expiry:** [Date]

### URLs to Configure

#### Required URLs (Must be live before App Store submission):
- ✅ https://mytrademate.app (Landing page)
- ✅ https://mytrademate.app/privacy (Privacy Policy)
- ✅ https://mytrademate.app/terms (Terms of Service)
- ✅ https://mytrademate.app/support (Support & FAQ)

#### Optional URLs (Nice to have):
- ⚠️ https://mytrademate.app/contact (Contact form)
- ⚠️ https://mytrademate.app/download (Download page)
- ⚠️ https://mytrademate.app/about (About page)
- ⚠️ https://mytrademate.app/blog (Blog - future)

---

## 📧 Email Information

### Primary Email
**Email:** mytrademate.app@gmail.com  
**Type:** Gmail  
**Purpose:** All communications (support, info, legal, etc.)

### Email Aliases/Forwarding Setup

Since you have one Gmail account, set up email forwarding or aliases:

#### Option 1: Gmail Aliases (Recommended)
Gmail automatically accepts emails sent to:
- mytrademate.app@gmail.com (main)
- mytrademate.app+support@gmail.com
- mytrademate.app+info@gmail.com
- mytrademate.app+privacy@gmail.com
- mytrademate.app+legal@gmail.com

**How it works:**
- All emails go to same inbox
- Use Gmail filters to organize by "+tag"
- No additional setup needed!

#### Option 2: Custom Domain Email (Future)
When you set up hosting, you can create:
- support@mytrademate.app → forwards to mytrademate.app@gmail.com
- info@mytrademate.app → forwards to mytrademate.app@gmail.com
- privacy@mytrademate.app → forwards to mytrademate.app@gmail.com

**Cost:** Free with most hosting providers

---

## 📝 Email Addresses to Use in Documentation

### For App Store/Google Play:
- **Support Email:** mytrademate.app@gmail.com
- **Privacy Contact:** mytrademate.app@gmail.com
- **Developer Contact:** mytrademate.app@gmail.com

### For Website:
- **General Inquiries:** mytrademate.app@gmail.com
- **Support:** mytrademate.app@gmail.com
- **Legal:** mytrademate.app@gmail.com

### For In-App Links:
- **Support:** mytrademate.app@gmail.com
- **Feedback:** mytrademate.app@gmail.com
- **Bug Reports:** mytrademate.app@gmail.com

---

## 🔧 Gmail Setup Recommendations

### 1. Create Email Filters

**Filter 1: Support Emails**
- From: *
- To: mytrademate.app+support@gmail.com
- Label: "MyTradeMate/Support"
- Star it
- Mark as important

**Filter 2: Bug Reports**
- Subject: contains "bug" OR "error" OR "crash"
- Label: "MyTradeMate/Bugs"
- Star it

**Filter 3: Feature Requests**
- Subject: contains "feature" OR "request" OR "suggestion"
- Label: "MyTradeMate/Features"

**Filter 4: App Store Reviews**
- From: *@apple.com OR *@google.com
- Label: "MyTradeMate/App Store"
- Mark as important

### 2. Create Canned Responses

**Response 1: Thank You**
```
Hi [Name],

Thank you for contacting MyTradeMate! We've received your message and will respond within 24-48 hours.

In the meantime, check out our FAQ: https://mytrademate.app/support

Best regards,
MyTradeMate Team
```

**Response 2: Bug Report Received**
```
Hi [Name],

Thank you for reporting this bug! We've created ticket #[NUMBER] and our team is investigating.

We'll keep you updated on the progress.

Best regards,
MyTradeMate Support
```

### 3. Set Up Auto-Reply (Optional)

**Subject:** Re: [Original Subject]

**Message:**
```
Thank you for contacting MyTradeMate!

We've received your email and will respond within 24-48 hours.

For immediate help, visit our FAQ:
https://mytrademate.app/support

Best regards,
MyTradeMate Team

---
This is an automated response. Please do not reply to this email.
```

---

## 🌐 Hosting Recommendations

### Option 1: Netlify (Recommended)
- **Cost:** FREE
- **Features:**
  - Custom domain (mytrademate.app)
  - SSL certificate (HTTPS)
  - Continuous deployment from Git
  - Form handling
  - Email forwarding (with paid plan)
- **Setup Time:** 15 minutes
- **Website:** https://www.netlify.com

### Option 2: Vercel
- **Cost:** FREE
- **Features:**
  - Custom domain
  - SSL certificate
  - Git integration
  - Serverless functions
- **Setup Time:** 15 minutes
- **Website:** https://vercel.com

### Option 3: GitHub Pages
- **Cost:** FREE
- **Features:**
  - Custom domain
  - SSL certificate
  - Direct from GitHub repo
- **Limitations:**
  - Static sites only
  - No server-side code
- **Setup Time:** 10 minutes

---

## 📋 Website Setup Checklist

### Step 1: Choose Hosting
- [ ] Sign up for Netlify/Vercel
- [ ] Connect GitHub repository
- [ ] Configure build settings

### Step 2: Configure Domain
- [ ] Add custom domain (mytrademate.app)
- [ ] Update DNS settings at registrar
- [ ] Wait for DNS propagation (24-48 hours)
- [ ] Verify SSL certificate is active

### Step 3: Create Pages
- [ ] Landing page (index.html)
- [ ] Privacy Policy (/privacy)
- [ ] Terms of Service (/terms)
- [ ] Support & FAQ (/support)
- [ ] Contact page (/contact) - optional

### Step 4: Test Everything
- [ ] All URLs load correctly
- [ ] HTTPS works (no warnings)
- [ ] Mobile responsive
- [ ] Forms work (if any)
- [ ] Email links work

---

## 📄 Simple Website Structure

```
mytrademate-website/
├── index.html (Landing page)
├── privacy.html (Privacy Policy)
├── terms.html (Terms of Service)
├── support.html (Support & FAQ)
├── contact.html (Contact form)
├── css/
│   └── style.css
├── js/
│   └── main.js
└── images/
    ├── logo.png
    ├── screenshot1.png
    └── screenshot2.png
```

---

## 🎨 Quick Landing Page Template

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MyTradeMate - AI-Powered Crypto Trading</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            max-width: 800px;
            text-align: center;
        }
        h1 { font-size: 3em; margin-bottom: 20px; }
        p { font-size: 1.2em; margin-bottom: 30px; opacity: 0.9; }
        .buttons { display: flex; gap: 20px; justify-content: center; flex-wrap: wrap; }
        .btn {
            padding: 15px 30px;
            border-radius: 10px;
            text-decoration: none;
            font-weight: 600;
            transition: transform 0.2s;
        }
        .btn:hover { transform: translateY(-2px); }
        .btn-primary { background: white; color: #667eea; }
        .btn-secondary { background: rgba(255,255,255,0.2); color: white; border: 2px solid white; }
        .footer {
            margin-top: 50px;
            opacity: 0.7;
            font-size: 0.9em;
        }
        .footer a { color: white; text-decoration: none; margin: 0 10px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🤖 MyTradeMate</h1>
        <p>AI-Powered Crypto Trading Assistant</p>
        <p>Get real-time BUY/SELL signals, track your portfolio, and trade with confidence.</p>
        
        <div class="buttons">
            <a href="#" class="btn btn-primary">📱 Download on App Store</a>
            <a href="#" class="btn btn-primary">🤖 Get it on Google Play</a>
        </div>
        
        <div class="footer">
            <a href="/privacy">Privacy Policy</a> |
            <a href="/terms">Terms of Service</a> |
            <a href="/support">Support</a> |
            <a href="mailto:mytrademate.app@gmail.com">Contact</a>
        </div>
    </div>
</body>
</html>
```

---

## ✅ Final Checklist

### Domain Setup
- [x] Domain purchased (mytrademate.app)
- [ ] DNS configured
- [ ] SSL certificate active
- [ ] All URLs working

### Email Setup
- [x] Gmail account created (mytrademate.app@gmail.com)
- [ ] Gmail filters configured
- [ ] Canned responses created
- [ ] Auto-reply set up (optional)

### Website Setup
- [ ] Hosting chosen (Netlify/Vercel)
- [ ] Landing page created
- [ ] Privacy Policy uploaded
- [ ] Terms of Service uploaded
- [ ] Support & FAQ uploaded
- [ ] All links tested

### App Configuration
- [x] Settings screen updated with correct URLs
- [ ] Test all in-app links
- [ ] Verify email links work

---

## 🚀 Next Steps

1. **Today:** Set up hosting (Netlify/Vercel) - 30 minutes
2. **Today:** Create simple landing page - 1 hour
3. **Today:** Upload Privacy Policy, Terms, Support pages - 30 minutes
4. **Tomorrow:** Configure DNS and wait for propagation - 24 hours
5. **Day 3:** Test all URLs and email - 30 minutes
6. **Day 4:** Ready for App Store submission! 🎉

---

## 📞 Support

**Email:** mytrademate.app@gmail.com  
**Website:** https://mytrademate.app (coming soon)

---

**Status:** ✅ Domain purchased, Email configured, Ready for website setup

*Last Updated: October 23, 2025*
