# CasinPOS Premium — mobile IAP only (iOS + Android)

Premium is sold **only** in the CasinPOS **iOS and Android** apps as an auto-renewable monthly subscription via **RevenueCat** (Apple StoreKit + Google Play Billing).

There is **no** PayMongo, Stripe, or web checkout. The Flutter web build (if any) cannot sell Premium; owners must subscribe on mobile.

Product / entitlement IDs (must match everywhere):

| Item | Value |
|------|--------|
| Entitlement | `premium` |
| Product ID | `casinpos_premium_monthly` |
| Package | Monthly (RevenueCat `$rc_monthly` or linked product) |

---

## 1. App Store Connect (iOS)

1. Open [App Store Connect](https://appstoreconnect.apple.com) → your CasinPOS app.
2. **Subscriptions** → create a **Subscription Group** (e.g. `CasinPOS Premium`).
3. Add subscription:
   - Product ID: `casinpos_premium_monthly`
   - Duration: **1 month**
   - Pricing: set your PHP / regional prices
4. Add localization (display name + description).
5. Create a **Sandbox** Apple ID (Users and Access → Sandbox) for testing.
6. Agreements: Paid Apps agreement must be Active.

## 2. Google Play Console (Android)

1. Open Play Console → CasinPOS → **Monetize** → Subscriptions.
2. Create subscription with product ID **`casinpos_premium_monthly`** (same id as iOS).
3. Add a base plan (monthly auto-renewing) + regional pricing.
4. Activate the subscription.
5. Add license testers for sandbox purchases.

## 3. RevenueCat

1. Create a project at [RevenueCat](https://app.revenuecat.com).
2. Add **iOS** and **Android** apps (bundle id / application id).
3. Connect App Store (IAP key) and Google Play (service account).
4. **Products** → add / import `casinpos_premium_monthly` for both stores.
5. **Entitlements** → create `premium` → attach that product.
6. **Offerings** → create offering (e.g. `default`) → add **Monthly** package → attach product → mark offering **Current**.
7. Copy **Public** API keys (`appl_…`, `goog_…`) for Flutter.
8. Copy **Secret API key** (`sk_…`) for Supabase Edge Function `sync-my-premium`.
9. **Integrations → Webhooks**:
   - URL: `https://ftbmkqpioyfzrkziptox.supabase.co/functions/v1/revenuecat-webhook`
   - Authorization header value: a long random secret (same as `REVENUECAT_WEBHOOK_SECRET`)
   - Events: at least Initial Purchase, Renewal, Cancellation, Expiration, Billing Issue, Product Change

## 4. Supabase

```bash
# Apply SQL (plan sync RPC)
npx supabase db query --linked -f supabase/migrations/20260821000200_apply_store_subscription_from_provider.sql

# Deploy functions
npx supabase functions deploy revenuecat-webhook --project-ref ftbmkqpioyfzrkziptox
npx supabase functions deploy sync-my-premium --project-ref ftbmkqpioyfzrkziptox

# Secrets
npx supabase secrets set REVENUECAT_WEBHOOK_SECRET='your-long-random-secret' --project-ref ftbmkqpioyfzrkziptox
npx supabase secrets set REVENUECAT_SECRET_API_KEY='sk_…' --project-ref ftbmkqpioyfzrkziptox
```

## 5. Flutter build defines (native only)

```bash
# CRITICAL for TestFlight/Release: use Apple public SDK key (appl_…), NOT test_…
# RevenueCat → Apps → casinpos (App Store) → copy Public API key
flutter run -d <iphone> --dart-define-from-file=.env.flutter.local

# Or platform-specific:
# --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx
# --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx
```

`test_…` keys are **Test Store only**. Using them in a Release/TestFlight IPA causes an **instant crash on launch** (RevenueCat intentional guard).

`purchases_flutter` is already in this repo — you do **not** need `purchases_ui_flutter` unless you want RevenueCat’s prebuilt paywall UI (we use our own Upgrade dialog).

IAP does **not** run on Flutter web. Ship Premium only in App Store / Play builds.

## 6. Test

**iOS:** Sandbox Apple ID → Owner on Free → Upgrade → Subscribe → confirm `plan_tier = premium`.

**Android:** license tester → same flow via Play Billing.

Test **Restore** after reinstall.

## 7. App Review 2.1(b) (once IAP ships)

1. Restaurant/retail **business owners** (B2B). Staff use POS under the store plan; they do not buy subscriptions.
2. Premium is purchased **in the iOS/Android apps** via Apple In-App Purchase / Google Play Billing (auto-renewable monthly). There is no web or third-party checkout.
3. CasinPOS **Premium monthly** subscription only.
4. Premium unlocks more seats, higher monthly sales limit, multi-branch / franchise / aggregate reports (via store IAP).
5. No — merchant POS sales of physical goods are separate from CasinPOS Premium.

## Flow

```
Owner taps Subscribe (iOS or Android)
  → RevenueCat / StoreKit or Play Billing
  → setAttributes(store_id)
  → sync-my-premium Edge Function
  → revenuecat-webhook keeps renew / cancel / expire in sync
  → stores.plan_tier + subscriptions updated
```
