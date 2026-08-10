# Device QA — CasinPOS (crash-free sell → pay → refund → offline → sync)

Run on a real **iPad** and/or Android tablet before Store submission.

## Prep

- [ ] Production (or staging) Supabase has migrations through `20260810000200`
- [ ] Edge Function `delete-account` deployed
- [ ] Test store with ≥3 products (barcode set on one)
- [ ] Hard-refresh web build if testing Vercel

## Happy path (online)

1. [ ] Sign in / create store (retail)
2. [ ] Store settings: set TIN + business address; Save
3. [ ] Cash register → Open with float → **Claim this shift**
4. [ ] Retail POS → add items (tap + **Scan** if camera available)
5. [ ] Checkout → review order → cash pay → change shown → Preview PDF (TIN visible)
6. [ ] Sales History → Refund (partial then full) → stock/status looks right
7. [ ] X report mid-shift → Close register (Z) with counted cash → variance dialog
8. [ ] Privacy + Terms open from login and settings (`/privacy`, `/terms`)
9. [ ] Delete account on a **throwaway** user only (verify sign-out)

## Offline → sync

1. [ ] Open register while online
2. [ ] Toggle airplane / kill Wi‑Fi
3. [ ] Sidebar shows Offline
4. [ ] Complete a sale (queued)
5. [ ] Restore network → pending sync clears → sale appears in history

## Regression smoke

- [ ] Void a sale (if allowed) — drawer / period counts sane  
- [ ] Sign out → Sign in lands on POS  
- [ ] Customer display `/display` still loads  
- [ ] No red-screen crashes through steps above  

## Pass criteria

No fatal crashes on the sell → pay → refund → offline → sync path; receipt shows store identity fields when configured.
