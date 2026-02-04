# Canvas Browser - Domain Setup Guide

This document outlines everything needed to set up a domain for Universal Links, Handoff, and web-based sharing features in Canvas Browser.

---

## 1. Domain Requirements

### Recommended Domain Names
- `canvas-browser.com` (primary recommendation)
- `canvasbrowser.app`
- `getcanvas.app`
- `usecanvas.com`

### Domain Registrars
Any registrar works. Popular options:
- [Cloudflare Registrar](https://www.cloudflare.com/products/registrar/) - Cheapest, at-cost pricing
- [Namecheap](https://www.namecheap.com)
- [Google Domains](https://domains.google) (now Squarespace)
- [Hover](https://www.hover.com)

---

## 2. Hosting Requirements

You need a web server that can:
1. Serve static files over **HTTPS** (required by Apple)
2. Serve files from the `/.well-known/` path
3. Return proper `Content-Type: application/json` headers

### Recommended Hosting Options

**Option A: GitHub Pages (Free)**
```bash
# Create a repo named: yourdomain.com
# Add CNAME file with your domain
# Enable HTTPS in repo settings
```

**Option B: Cloudflare Pages (Free)**
- Automatic HTTPS
- Fast global CDN
- Easy deployment

**Option C: Vercel/Netlify (Free tier)**
- Simple static site deployment
- Automatic HTTPS

**Option D: Your own server**
- Any server with HTTPS (nginx, Apache, Caddy)

---

## 3. Apple App Site Association File

Create this file at: `https://yourdomain.com/.well-known/apple-app-site-association`

**Important:** No `.json` extension! The file must be named exactly `apple-app-site-association`

### File Contents

```json
{
    "applinks": {
        "apps": [],
        "details": [
            {
                "appIDs": [
                    "XXXXXXXXXX.com.canvas.browser"
                ],
                "components": [
                    {
                        "/": "/open/*",
                        "comment": "Open URL in Canvas"
                    },
                    {
                        "/": "/gentab/*",
                        "comment": "Open shared GenTab"
                    },
                    {
                        "/": "/share/*",
                        "comment": "Handle shared content"
                    }
                ]
            }
        ]
    },
    "activitycontinuation": {
        "apps": [
            "XXXXXXXXXX.com.canvas.browser"
        ]
    },
    "webcredentials": {
        "apps": [
            "XXXXXXXXXX.com.canvas.browser"
        ]
    },
    "appclips": {
        "apps": []
    }
}
```

### Replace XXXXXXXXXX with Your Team ID
Find your Team ID at: https://developer.apple.com/account → Membership → Team ID

---

## 4. Server Configuration

### Required Headers
The server must return these headers for the AASA file:

```
Content-Type: application/json
```

### Nginx Configuration
```nginx
location /.well-known/apple-app-site-association {
    default_type application/json;
}
```

### Apache Configuration
```apache
<Files "apple-app-site-association">
    Header set Content-Type "application/json"
</Files>
```

### Cloudflare Pages (_headers file)
```
/.well-known/*
  Content-Type: application/json
  Access-Control-Allow-Origin: *
```

---

## 5. DNS Configuration

### Required DNS Records

| Type | Name | Value | Purpose |
|------|------|-------|---------|
| A | @ | Your server IP | Root domain |
| CNAME | www | yourdomain.com | www subdomain |
| CNAME | _domainconnect | (if using Cloudflare) | Domain verification |

### If Using Cloudflare (Recommended)
1. Add domain to Cloudflare
2. Update nameservers at registrar
3. Enable "Full (Strict)" SSL mode
4. Enable "Always Use HTTPS"

---

## 6. Apple Developer Portal Configuration

### Add Associated Domains Capability

1. Go to https://developer.apple.com/account/resources/identifiers
2. Select your App ID (com.canvas.browser)
3. Enable "Associated Domains" capability
4. Save

### Entitlements File Update

Add to `CanvasBrowser.entitlements`:
```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:yourdomain.com</string>
    <string>activitycontinuation:yourdomain.com</string>
    <string>webcredentials:yourdomain.com</string>
</array>
```

---

## 7. Verification Steps

### Step 1: Validate AASA File
Use Apple's validator:
```bash
# Check if file is accessible
curl -I https://yourdomain.com/.well-known/apple-app-site-association

# Should return:
# HTTP/2 200
# content-type: application/json
```

### Step 2: Apple CDN Validation
Apple caches AASA files. Check their cached version:
```bash
curl "https://app-site-association.cdn-apple.com/a/v1/yourdomain.com"
```

### Step 3: Test Universal Links
1. Build and install app on device
2. Send yourself a link: `https://yourdomain.com/open/https://example.com`
3. Tap link - should open in Canvas, not Safari

### Step 4: Test Handoff
1. Ensure same iCloud account on Mac and iPhone
2. Browse in Canvas on Mac
3. Check iPhone lock screen for Handoff icon

---

## 8. URL Scheme Design

### Proposed URL Structure

| URL Pattern | Action |
|-------------|--------|
| `yourdomain.com/open/{encoded-url}` | Open URL in Canvas |
| `yourdomain.com/gentab/{id}` | Open shared GenTab |
| `yourdomain.com/share?url={url}&title={title}` | Add to reading list |
| `yourdomain.com/search?q={query}` | Search in Canvas |
| `yourdomain.com/ask?q={question}` | Ask Canvas AI |

### Example URLs
```
https://canvas-browser.com/open/https%3A%2F%2Fwww.apple.com
https://canvas-browser.com/gentab/abc123
https://canvas-browser.com/share?url=https://example.com&title=Example
https://canvas-browser.com/search?q=swift+programming
```

---

## 9. Fallback Web Pages

For users without Canvas installed, create landing pages:

### `/open/*` Landing Page
```html
<!DOCTYPE html>
<html>
<head>
    <title>Open in Canvas Browser</title>
    <meta http-equiv="refresh" content="0; url=https://apps.apple.com/app/canvas-browser/id123456789">
</head>
<body>
    <h1>Opening in Canvas Browser...</h1>
    <p>Don't have Canvas? <a href="https://apps.apple.com/app/canvas-browser/id123456789">Download it here</a></p>
    <p>Or continue to: <a id="fallback-link"></a></p>
    <script>
        const url = decodeURIComponent(window.location.pathname.replace('/open/', ''));
        document.getElementById('fallback-link').href = url;
        document.getElementById('fallback-link').textContent = url;
    </script>
</body>
</html>
```

---

## 10. Timeline & Checklist

### Before App Store Submission
- [ ] Purchase domain
- [ ] Set up HTTPS hosting
- [ ] Create and deploy AASA file
- [ ] Add Associated Domains entitlement to app
- [ ] Test Universal Links on device
- [ ] Create fallback web pages

### After Domain Setup
- [ ] Verify AASA file via Apple CDN
- [ ] Test on multiple devices
- [ ] Monitor for any CDN caching issues

---

## 11. Troubleshooting

### Universal Links Not Working

1. **Check AASA syntax:** Use JSONLint to validate
2. **Check HTTPS:** Must be valid certificate
3. **Check Content-Type:** Must be `application/json`
4. **Wait for Apple CDN:** Can take 24-48 hours to update
5. **Reinstall app:** Links are checked at install time
6. **Check device mode:** Links don't work in simulator

### Handoff Not Working

1. **Same iCloud account:** Must be logged in on both devices
2. **Bluetooth enabled:** Required for Handoff discovery
3. **WiFi on same network:** Or Bluetooth range
4. **Handoff enabled:** Check System Settings → General → AirDrop & Handoff

### Passkeys Not Working

1. **iCloud Keychain enabled:** Required for passkey sync
2. **Correct associated domain:** Must match exactly
3. **HTTPS required:** No exceptions

---

## 12. Cost Estimate

| Item | Annual Cost |
|------|-------------|
| Domain (.com) | $10-15 |
| Hosting (Cloudflare Pages) | Free |
| SSL Certificate | Free (via Cloudflare/Let's Encrypt) |
| **Total** | **~$12/year** |

---

## 13. Support Resources

- [Apple Associated Domains Documentation](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
- [Universal Links Guide](https://developer.apple.com/ios/universal-links/)
- [Handoff Programming Guide](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/Handoff/HandoffFundamentals/HandoffFundamentals.html)
- [AASA Validator Tool](https://branch.io/resources/aasa-validator/)
