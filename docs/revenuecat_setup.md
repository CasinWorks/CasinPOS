# CasinPOS billing — paid app (IAP retired)

CasinPOS on Apple is a **paid application (₱199)**. There is **no Free plan** and **no In-App Purchase** in the shipping binary.

| Item | Status |
|------|--------|
| App Store price | **₱199** (Pricing and Availability) |
| IAP `casinpos_premium_monthly` | **Retired** — detach from version / Clear for Sale off |
| IAP `casinpos_premium_lifetime` | **Do not ship** |
| Store plan after signup | **Premium** (lifetime) on native; web requires **₱199 PayMongo** first |
| RevenueCat / StoreKit in app | **Disabled** (`BillingConfig.iapEnabled = false`) |

## Web (pos.casinworks.com)

New owner signup is allowed. Creating a store sets `subscriptions.provider = pending_web` until the owner pays **₱199** via PayMongo (GCash / Maya / QR Ph / card). Invite join stays free. Apply Script O in `docs/production_sql_paste.md` and redeploy `create-premium-checkout`.

## App Store Connect

1. Set app price to **₱199**.
2. Remove all IAPs from the submitted version (fixes Guideline **2.1(b)**).
3. Resubmit IPA built with Supabase dart-defines (`./scripts/build_ios_ipa.sh`). RevenueCat keys are optional.

## Google Play

Set Play to a matching paid / one-time model separately when you ship Android. Do not reintroduce auto-renewable subscriptions without updating this doc.

## Legacy code (dormant)

RevenueCat helpers may remain in the repo for ops/history. **PayMongo web checkout is live** for web registration / Premium unlock on pos.casinworks.com.
