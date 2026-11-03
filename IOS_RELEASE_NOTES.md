# Wadgaonkar Eye Hospital — iOS App Store Release Notes

Written 2026-11-04 (IST) at the end of the first iOS release session, so a future
session (or person) knows exactly what was done, how, and what is left.
**No passwords are written here.** Where a secret lives is stated instead.

> **APPLE KEY FILES ARE SAVED IN: `/home/aladin/projects/wagaokar app/apple-keys-wadgaonkar/`**
> (inside the project folder but listed in `.gitignore`, so it is never committed; folder mode 700, files mode 600). Back this folder up somewhere else too
> (USB drive / private cloud). Contents: `AuthKey_GC735QQM4F.p8` (Sign in with Apple + push key, **Apple allows
> only ONE download**), `AuthKey_MG4VBPY9KW.p8` (App Store Connect API key), `dist.key` (private key of the
> distribution certificate), `dist.cer`, `dist.csr`, `dist.p12`, `appstore.mobileprovision`.
> Details in section 3.

---

## 1. Status at a glance

| Item | State |
|---|---|
| Android app | Live on Google Play. **Not touched** in this work. |
| iOS app 1.0.1 (build 28) | **Submitted to Apple on 2026-11-04 ~04:06 AM IST. Status: Waiting for Review.** Apple said review can take up to 48 h and will email qutubahmad3@gmail.com. |
| Release setting | Automatic release after approval, **India only**, free. |
| Backend `delete-account` endpoint | Deployed to the live server. |
| Git branch `ios-release-prep` | Pushed. **PR #1 is still OPEN, NOT merged into `main`.** |
| Real-iPhone test of Apple sign-in | **Never done** (no iPhone available). Only simulator + code tests. |

---

## 2. Key identifiers (not secrets)

- Apple Developer **Team ID**: `3G5YQ4MRUM` (account holder: Shaikh Kutub Ahamad)
- iOS **Bundle ID**: `com.wadgaonkareyehospital.wadgaonkarEyeHospital`
- **App Store Connect app (Apple ID)**: `6830161308`, SKU `WEH-PATIENT-IOS-1`
- App Store Connect **API key** for CI: Key ID `MG4VBPY9KW`, role App Manager, name "GitHub CI",
  Issuer ID `2abef1e9-c86a-47f1-b48e-94676aa0f3f5`
- **Sign in with Apple + Push (APNs) key**: Key ID `GC735QQM4F` (name "Wadgaonkar Apple Services"),
  APNs environment "Sandbox & Production", Team scoped
- **Distribution certificate**: "Apple Distribution: Shaikh kutub Ahamad (3G5YQ4MRUM)", **expires 2027-11-03**
- **Provisioning profile**: "Wadgaonkar AppStore CI" (App Store type), **expires 2027-11-03**
- Firebase project: `wadgaonkar-eye-hospital`
- GitHub repo: `Aladin-0/wadgaonkar-eye-hospital`
- Website (Firebase Hosting): https://wadgaonkar-eye-hospital.web.app
  (`/privacy`, `/terms`, `/cancellation`, `/contact`, `/delete-account`)
- Backend API (public): https://techverseservices.in/hospital-api/api/v1
- App version: `1.0.1` (pubspec says `1.0.1+24`; CI overrides the build number with the GitHub run number)

---

## 3. Where the secrets / key files are

**GitHub repo secrets** (Settings → Secrets → Actions): `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`,
`IOS_DIST_P12_B64`, `IOS_DIST_P12_PASSWORD`, `IOS_APPSTORE_PROFILE_B64`.
They cannot be read back from GitHub; only replaced.

**Local safe copy of the Apple files** (in the project folder, git-ignored via `.gitignore`; files mode 600, folder mode 700):
`/home/aladin/projects/wagaokar app/apple-keys-wadgaonkar/`
- `AuthKey_GC735QQM4F.p8` — Sign in with Apple + APNs key. **Apple lets you download this only once.** Back it up elsewhere too.
- `AuthKey_MG4VBPY9KW.p8` — App Store Connect API key (also stored in the GitHub secret).
- `dist.key` — private key for the distribution certificate. Needed to ever re-make the `.p12`.
- `dist.cer`, `dist.csr`, `dist.p12`, `appstore.mobileprovision`.
  (The `.p12` password is the value of the `IOS_DIST_P12_PASSWORD` GitHub secret; a new `.p12` can be made
  from `dist.key` + `dist.cer` with any password.)

**Server / deploy password**: currently hard-coded in plain text in `deploy.sh` and `deploy_fast.sh`
(see "Known issues").

**Review demo account** (for Apple's reviewers): Google account `aathvaniii@gmail.com`;
password is saved in App Store Connect → Version 1.0.1 → App Review Information.

### 3.1 If a key or file is LOST — how to get a new one

**First, stay calm:** losing these files does **not** affect the app already submitted/live, and does not affect Apple's
review. It only blocks *new builds* (signing), *push notifications*, or *Apple sign-in setup* until replaced.
Only the Apple account holder/admin (qutubahmad3@gmail.com, team 3G5YQ4MRUM) can do these in the Apple websites.

| Lost item | Can it be downloaded again? | What to do |
|---|---|---|
| `AuthKey_GC735QQM4F.p8` (Sign in with Apple + push) | **No** (Apple gives it once) | developer.apple.com → Certificates, Identifiers & Profiles → **Keys** → "+" → name it, tick **Apple Push Notifications service (APNs)** (Configure → environment "Sandbox & Production", Team Scoped) and **Sign in with Apple** (Configure → primary App ID = the Wadgaonkar app) → Register → **Download the .p8 immediately** and save it in the keys folder. Then **upload it to Firebase**: Firebase console → project `wadgaonkar-eye-hospital` → Project settings → Cloud Messaging → Apple app configuration → APNs Authentication Key → Upload (Key ID = the new key's ID, Team ID `3G5YQ4MRUM`). Optionally revoke the old key (Keys → old key → Revoke). Apple allows only a few APNs keys per team, so revoke the old one if "+" is refused. Apple sign-in in Firebase needs no key for the native iOS app (the Firebase Apple provider was enabled with the other fields blank). |
| `AuthKey_MG4VBPY9KW.p8` (App Store Connect API key used by CI) | **No** (once only) | appstoreconnect.apple.com → **Users and Access → Integrations → App Store Connect API → Team Keys** → "+" → name "GitHub CI", access **App Manager** → Generate → download the .p8 once. Update 3 GitHub secrets: `ASC_KEY_ID` (new key ID), `ASC_ISSUER_ID` (same issuer ID as before, shown on that page), `ASC_KEY_P8` (full file contents). Revoke the old key. |
| `dist.key` (private key of the distribution certificate) | **No** — a private key lives only on the machine that made it | Make a new one (commands below), then in developer.apple.com → **Certificates** → "+" → **Apple Distribution** → upload the new `.csr` → download the new `.cer`. Build a new `.p12` (below). The old certificate can be revoked (this does **not** affect apps already published). Then **make a new App Store provisioning profile** (profiles are tied to one certificate): Profiles → "+" → **App Store Connect** → App ID = the Wadgaonkar app → select the NEW certificate → name it → download. Update the 3 GitHub secrets `IOS_DIST_P12_B64`, `IOS_DIST_P12_PASSWORD`, `IOS_APPSTORE_PROFILE_B64`. |
| `dist.cer` | **Yes** — Apple portal → Certificates → click it → Download | — |
| `appstore.mobileprovision` | **Yes** — Apple portal → Profiles → click it → Download (or Edit → regenerate) | If the profile is "Invalid", Edit → Save/Generate again, download, update `IOS_APPSTORE_PROFILE_B64`. |
| `dist.p12` | Rebuildable from `dist.key` + `dist.cer` | Commands below. |
| `dist.csr` | Rebuildable | Commands below. |
| A GitHub secret (value unknown) | GitHub never shows secret values | Just set it again from the files in the keys folder (commands below). |

**Commands** (run inside the keys folder; use a new password of your choice and remember it in `IOS_DIST_P12_PASSWORD`):

```bash
cd "/home/aladin/projects/wagaokar app/apple-keys-wadgaonkar"

# 1) New private key + signing request (only if dist.key is lost)
openssl genrsa -out dist.key 2048
openssl req -new -key dist.key -out dist.csr \
  -subj "/emailAddress=qutubahmad3@gmail.com/CN=Wadgaonkar Eye Hospital/C=IN"
chmod 600 dist.key dist.csr
#    -> upload dist.csr on developer.apple.com (Certificates -> + -> Apple Distribution), download dist.cer

# 2) Build the .p12 from the key + downloaded certificate
openssl x509 -inform der -in dist.cer -out dist.pem
openssl pkcs12 -export -inkey dist.key -in dist.pem -out dist.p12 -passout pass:CHOOSE_A_PASSWORD

# 3) Put them into GitHub secrets (from the project folder; the repo is auto-detected)
base64 -w0 dist.p12 | gh secret set IOS_DIST_P12_B64
gh secret set IOS_DIST_P12_PASSWORD --body "CHOOSE_A_PASSWORD"
base64 -w0 appstore.mobileprovision | gh secret set IOS_APPSTORE_PROFILE_B64
# App Store Connect API key secrets (only if that key was replaced):
gh secret set ASC_KEY_ID --body "NEW_KEY_ID"
gh secret set ASC_ISSUER_ID --body "ISSUER_ID"
gh secret set ASC_KEY_P8 < AuthKey_NEWKEYID.p8
```

Note: Claude Code's permission system may ask the user to approve writing GitHub secrets and creating Apple
credentials; the user can approve those one at a time. Apple's own websites block Google sign-in in automated
browsers, so Firebase steps must be done by the user in a normal browser.

After replacing anything, run a build to confirm: `gh workflow run ios-patient.yml --ref ios-release-prep`.

---

## 4. What was done, in order

### 4.1 Privacy policy and website
- Rewrote the privacy policy (Last Updated Nov 3, 2026) for India's DPDP Act: what data is collected,
  Google/Apple sign-in, Razorpay, Firebase, retention, rights, in-app Delete Account, children, grievance, contact.
  Source: `apps/patient_app/lib/core/constants/app_policies.dart`.
- Generated static pages from it into `apps/website/public/*.html` and deployed to Firebase Hosting
  (`cd apps/website && firebase deploy --only hosting`). `firebase.json` has clean URLs + security headers.

### 4.2 App code (Flutter, `apps/patient_app`)
- **Sign in with Apple** (Apple rule 4.8): `sign_in_with_apple` package, button shown **only on iOS**,
  `AuthRepository.signInWithApple()` with SHA-256 nonce → Firebase `apple.com` credential → backend sync.
- **In-app account deletion** (Apple rule 5.1.1(v)): red "Delete Account" button in Profile
  (`profile_screen.dart`) → `AuthProvider.deleteAccount()` → backend → deletes Firebase user → logs out.
- **Login screen text fix**: replaced "Digital Health Records — access prescriptions, vision test charts &
  diagnostics" (the app does not do that) with "Appointments & OPD Pass — view your upcoming and past visits and
  your OPD pass." The line "Hospital Verified & Secure — NABH standards…" was left (user said it is correct).
  This change is in code for Android too, but **no Android build was made**.
- Fixed old analyzer warnings (e.g. `withOpacity` → `withValues`, unused imports) and old broken tests;
  `flutter analyze` clean, 32/32 tests pass (tested with Flutter 3.44.8).
- **iOS config**: `ios/Runner/Runner.entitlements` (Sign in with Apple + push), team/entitlements in
  `project.pbxproj`, `ios/ExportOptions.plist`, `ITSAppUsesNonExemptEncryption = false` in `Info.plist`
  (avoids the export-compliance question), and **iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`) so Apple does not ask for iPad screenshots.

### 4.3 Backend (Django, `backend/`)
- New endpoint `POST /api/v1/auth/delete-account/` (`apps/authentication/views.py`, `urls.py`):
  needs a Firebase ID token (`Authorization: Bearer …`), anonymises appointments and payment orders
  (name → "Deleted User", mobile cleared), deletes the patient profile and non-staff user, then deletes the
  Firebase user. 3 tests in `apps/authentication/tests.py` pass.
- **Deployed** to the live server (see section 7). Verified: no token → 401, existing API → 200.
- Fixed the `backend-web-1` Docker health check (it used `curl`, which the image lacks → always "unhealthy").
  Now uses Python; container is "healthy". **This one-line change in `backend/docker-compose.yml` exists in the
  working folder and on the server but may not be committed to git** — check `git status`.

### 4.4 Apple developer / App Store Connect setup (done in Firefox via automation)
- Registered the App ID with Sign in with Apple + Push capabilities; created the App Store Connect app record.
- Created: App Store Connect API key (App Manager), Apple Distribution certificate, App Store provisioning
  profile, and the combined Sign in with Apple + APNs key.
- Uploaded the APNs key to Firebase → Cloud Messaging, and enabled Apple as a provider in Firebase Authentication
  (the user did these two in their own browser because Google blocks sign-in in automated browsers).
- Listing: name, subtitle ("Book eye doctor appointments"), description, promo text, keywords, support URL
  (`/contact`), marketing URL, copyright, **5 screenshots** (from real Android screens, status bar painted over,
  resized to 1206×2622), category **Medical** (secondary Health & Fitness), age rating **4+**,
  content rights "no third-party content", privacy policy URL, **App Privacy questionnaire published**
  (Name, Email, Phone, Health, Purchase history, User ID, Device ID, Other data — all "App Functionality",
  linked to user, **not** used for tracking), pricing **free** (base India INR ₹0), availability **India only**.
- Review contact: Kutub Ahemad, +917083321725, wadgaonkareyeehospital@gmail.com.
- Review notes tell the reviewer: how to log in, how to book, that Razorpay is **LIVE** (real charge at the last
  step), where Delete Account is.

### 4.5 CI / builds (GitHub Actions, `.github/workflows/ios-patient.yml`)
- Job `ios`: analyze, test, unsigned build.
- Job `simulator`: boots an iPhone simulator, installs the app, taps "Allow" on the notification prompt,
  takes screenshots, checks the app is still running (proof that it launches, shows the login screen, with
  Google and Apple buttons).
- Job `testflight` (manual only, `workflow_dispatch`): builds, archives unsigned, installs the distribution cert + profile
  into a temporary keychain, **exports the IPA with manual signing**, uploads to App Store Connect with `altool`.
- Lessons learned: (a) automatic cloud signing fails with an App Manager API key ("Cloud signing permission error"),
  so manual cert+profile signing is used; (b) a pull-request run used to cancel the manual run because they shared
  a concurrency group — fixed by adding the event name to the group; (c) GitHub's macOS runners are sometimes busy,
  so runs can sit "queued" or get cancelled; just re-run; (d) the simulator job occasionally fails on a slow runner
  (blank blue screen) — re-check with the pull-request run before assuming a crash.

---

## 5. How to make and upload a new iOS build

1. Commit and push your changes to `ios-release-prep` (or to `main` if merged — then change `--ref`).
2. Run: `gh workflow run ios-patient.yml --ref ios-release-prep`
3. Wait ~25–30 min for the `testflight` job to finish. Build number = GitHub run number (must be higher than all earlier ones; builds so far: 18, 20, 21, 28).
4. Wait ~10–15 min for Apple to process it (App Store Connect → TestFlight shows "Ready to Submit").
5. App Store Connect → Distribution → version page → remove the old build, add the new one (Add Build "+"), Save,
   then Add for Review → Submit for Review.
   (For a *new version* number, bump `version:` in `apps/patient_app/pubspec.yaml` and create a new version in App Store Connect first.)

**Yearly renewal:** the distribution certificate and provisioning profile expire **2027-11-03**. Before then, make a
new Apple Distribution certificate (use the saved `dist.csr`/`dist.key` or a new CSR) and a new App Store profile, and
replace the three `IOS_*` GitHub secrets. The Apple Developer membership also renews yearly (Apple emails first).

---

## 6. What is LEFT / next steps

1. **Wait for Apple's review result** (up to ~48 h; emails go to qutubahmad3@gmail.com). Answer any message in
   App Store Connect quickly.
2. **If Apple rejects over payment** (reviewer cannot finish a booking because Razorpay is live): add a mock/sandbox
   payment **only for the demo account** (`aathvaniii@gmail.com`), checked **on the server** (not only in the app),
   explain it in the review notes, build, resubmit. Note: a "pay at desk" option exists in code
   (`bookPayAtDesk`, `_paymentOption == 'desk'`) but **no button in the UI selects it**.
3. **Merge PR #1** (see section 8) — recommended after Apple's decision.
4. **Android**: not rebuilt. When you next build/update Android, it will include the new login text and the Delete Account
   button (once the branch is merged or built from the branch). Test it on a phone first. The CI used Flutter 3.44.8;
   your PC's Flutter may need updating.
5. **Commit pending local changes** if any (`git status`): the docker-compose health check, this notes file.
6. **Security clean-up** (see Known issues): move the server password out of `deploy.sh` / `deploy_fast.sh`.
7. Optional: real-iPhone test of Apple sign-in (borrow a phone / free cloud-device trial). Never done.
8. Optional: EU trader status is **not** needed while the app is India-only. Needed if you ever add EU countries.
9. The old Django `/privacy/` page on the server (techverseservices.in) may still show the old policy text; the
   official URL for Apple is the Firebase one.

---

## 7. Server / deployment details (backend)

- VPS: `techverse@182.70.63.4`, SSH port **2222**. Our project folder: `/home/techverse/wadgaonkar_eye_hospital/backend`.
- **The server hosts many other projects** (mediflow_*, restro_*, sanscrutilase, techverse nginx, etc.). Do not touch them.
  Ours are the containers named `backend-web-1`, `backend-celery_worker-1`, `backend-celery_beat-1`, `backend-redis-1`, `backend-db-1`.
- Public path: host nginx → `127.0.0.1:8000/` for `/hospital-api/`. Port 8000 is not reachable directly from outside.
- Code is **baked into the Docker image** (no mounted volume). To deploy a change safely:
  1. `cp` the changed files on the server to `*.bak-…`, tag the current image (e.g. `docker tag backend-web:latest backend-web:pre-…`).
  2. Copy **only the changed files** (do not use the full `deploy.sh`: it unpacks the whole local `backend/` over the server,
     overwriting the server's `.env` and Firebase key).
  3. `cd …/backend && docker compose build web && docker compose up -d --no-deps web` (only restarts `web`).
  4. Test: `curl https://techverseservices.in/hospital-api/api/v1/services/` → 200.
- Rollback points left on the server: image `backend-web:pre-delete-account`;
  files `apps/authentication/views.py.bak-pre-delete`, `urls.py.bak-pre-delete`; `docker-compose.yml.bak-pre-health`.
- The server's `.env` uses a **live** Razorpay key (`rzp_live_…`); `settings.py` has a test-key fallback.

---

## 8. Git details (what "branch", "PR" and "merge" mean here)

- `main` = your main/official code. **Unchanged by this work.**
- `ios-release-prep` = side branch where **all** this work lives (pushed to GitHub).
- **PR #1** = "Prepare iOS release: Apple sign-in, account deletion, policies, test fixes",
  `ios-release-prep → main`, 36 files, +1895 / −189, state **OPEN**.
  https://github.com/Aladin-0/wadgaonkar-eye-hospital/pull/1
  A pull request is a request to copy the side branch into `main`. Merging = clicking "Merge pull request" (or `gh pr merge 1`).
- **If merged:** `main` has the iOS work, backend endpoint, policies, CI workflow. Android builds from `main` get the new login text
  and Delete Account button (untested on Android devices — test first).
- **If not merged:** nothing breaks (Apple build and live Android are unaffected), but `main` is out of date and
  future Android builds from `main` miss all of it; the branch can drift from `main`.
- Recommended: merge **after** Apple's decision, then build/test Android from `main` before publishing an update.
- Commit messages from Claude end with `Co-Authored-By: Claude Sonnet 5.5`.
- Important commits on the branch (newest first, roughly): concurrency fix, login-text fix, iPhone-only,
  manual-signing export, TestFlight job, simulator job, Apple sign-in/account deletion/policies.

---

## 9. Known issues / risks

- **Server password in plain text** in `deploy.sh` and `deploy_fast.sh` (both in the repo). Move to an SSH key or env var;
  do not make the repo public as is. Also consider changing that password.
- **Razorpay is live**; a reviewer completing online payment makes a real ₹500 payment (see Left #2).
- Apple sign-in not tested on a real iPhone.
- Backend token verification: the existing auth flow's weakness (offered earlier, not changed) is unresolved.
- The doctor "kutub" (fee ₹0) and test appointments exist in the live data (seen in screenshots); clean up if unwanted.
- Possible conflicting statements in the app UI should be re-checked before each submission ("NABH standards" claim is the hospital's responsibility).
- Another site on the same server (techverseservices.in StorePage) showed an "error loading dynamically imported module"
  after a redeploy by its owner — **unrelated, not touched**.

---

## 10. Useful commands

```bash
# Start an iOS build + TestFlight upload
gh workflow run ios-patient.yml --ref ios-release-prep
gh run list --workflow ios-patient.yml --limit 5

# Local checks (use Flutter 3.44.8 or newer)
cd apps/patient_app && flutter analyze && flutter test
cd backend && venv/bin/python -m pytest apps/authentication/tests.py

# Website
cd apps/website && firebase deploy --only hosting

# PR
gh pr view 1
gh pr merge 1 --merge     # only when ready
```
