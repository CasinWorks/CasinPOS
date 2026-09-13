# CasinPOS — App Store / Play listing kit

Use these with App Store Connect and Google Play Console.

## Pricing model (paid app)

CasinPOS is a **paid application** at **₱199**. There is **no Free plan** and **no In-App Purchases**.

| Channel | How users pay |
|---------|----------------|
| Apple App Store | App price **₱199** (Price Schedule) |
| After install | Full Premium access (create store → Premium) |

### App Store Connect checklist (required)

1. **Pricing and Availability** → set base / Philippines price to **₱199**.
2. **Monetization** → remove from this app version (do **not** submit with the binary):
   - `casinpos_premium_monthly`
   - `casinpos_premium_lifetime` (if created)
   - Clear for Sale **off**, or detach from the version.
3. **App Information** → Privacy Policy URL: `https://pos.casinworks.com/privacy`
4. Terms of Use: custom EULA or link in description → `https://pos.casinworks.com/terms`
5. Resubmit binary. This clears Guideline **2.1(b)** (no IAP products for reviewers to find).

## Public policy URLs (required for account apps)

After deploy, these must open without login:

| Purpose | URL |
|--------|-----|
| App (landing) | `https://pos.casinworks.com/intro` |
| Privacy Policy | `https://pos.casinworks.com/privacy` |
| Terms of Use (EULA) | `https://pos.casinworks.com/terms` |

Also linked from Sign in, Sign up, and Store settings → Privacy / Terms.

## Account deletion (Apple Guideline 5.1.1)

**In-app path:** Support → **Delete my account**

Requires production migrations + Edge Function `delete-account` deployed.

**Support / web path (for App Store review notes):**  
Email `christianjoshuacasin@gmail.com` with the signed-in account email and request deletion within 7 days. Soft path also exists via in-app delete. In-app **Support** tab opens the same address.

## Suggested listing copy

**Name:** CasinPOS  

**Subtitle (≤30 chars):** Retail POS for tablets  

**Promotional text:** Sell faster on iPad and Android tablets. Offline-ready cart, cash register shifts, refunds, and PH-friendly receipts.

**Description:**

```
CasinPOS is a retail point-of-sale built for tablet cashiers.

One-time App Store purchase (₱199). Full access after install — no subscriptions and no in-app purchases.

• Ring up sales with search or camera barcode scan
• Cash calculator with change, GCash / Maya / card
• Open and close cash drawer shifts (X/Z style accountability)
• Partial and full refunds from Sales History
• Continue selling offline, then sync when back online
• Receipt PDF with store name, TIN, and business address
• Team invites and role-based access

Ideal for sari-sari, specialty retail, and small franchises in the Philippines.

Privacy Policy: https://pos.casinworks.com/privacy
Terms of Use (EULA): https://pos.casinworks.com/terms
```

**Keywords (App Store):** POS,retail,inventory,cashier,tablet,gcash,maya,philippines,barcode,receipt  

**Category:** Business  
**Secondary:** Shopping (optional)

## Age rating

Typically **4+** / Everyone — no unrestricted web, no gambling, no mature content. Answer questionnaires honestly (no user-generated public content beyond store inventory names).

## Data safety / App Privacy

Declare collection as used for **App Functionality** (and Account if applicable):

| Data | Collected | Linked to identity | Tracking | Purpose |
|------|-----------|--------------------|----------|---------|
| Email | Yes | Yes | No | Account |
| Name | Optional | Yes | No | Account / receipts |
| Photos | Optional (catalog) | Yes (store) | No | App functionality |
| Product / sales data | Yes | Yes (store) | No | App functionality |
| Purchase history | Yes | Yes (store) | No | App functionality |
| Diagnostics | If you enable crash tools later | Optional | No | Analytics |

We do **not** sell data. Barcode camera is on-device; images are not uploaded unless used as product photos.

## Screenshot plan (device QA capture)

Capture on **iPad** (preferred) and one phone if shipping Phone:

1. Retail POS grid + cart tray  
2. Cash calculator / amount due  
3. Cash register open shift with expected drawer  
4. Sales History with Refund  
5. Receipt PDF preview  
6. Offline indicator / pending sync (optional)  

Export PNG; avoid demo passwords on screen. Use a demo store with realistic products.

## Review notes (paste into App Store Connect)

```
Demo account: (enter in App Store Connect only)

CasinPOS is a PAID APP (₱199). There are NO In-App Purchases and NO subscriptions.
Full features after App Store purchase and install. New stores are Premium by default.

Account deletion: Support → Delete my account
Support: Sidebar → Support → email christianjoshuacasin@gmail.com
Privacy: https://pos.casinworks.com/privacy
Terms of Use (EULA): https://pos.casinworks.com/terms

Core path: Sign in → Open register → Retail POS → add item → Pay cash → Refund from Sales History
```
