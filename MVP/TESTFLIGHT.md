# How to Add Your Client to TestFlight (Boris.shehter@gmail.com)

Follow these steps so your client can install the app from TestFlight. They will get an email from Apple with a link—no need to send them source code.

---

## What You Need First

- **Apple Developer account** (paid, $99/year) — [developer.apple.com](https://developer.apple.com)
- **Xcode** with your project open
- **Client email:** Boris.shehter@gmail.com

---

## Step 1: Create the App in App Store Connect (one-time)

1. Go to **[appstoreconnect.apple.com](https://appstoreconnect.apple.com)** and sign in.
2. Click **Apps** → **+** → **New App**.
3. Fill in:
   - **Platform:** iOS  
   - **Name:** e.g. "MVP" or your app name  
   - **Primary Language:** your choice  
   - **Bundle ID:** pick the same one you use in Xcode (e.g. `com.yourcompany.MVP`). If it’s not in the list, create it under [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) → **Identifiers** → **+**.
   - **SKU:** any unique string (e.g. `mvp-001`)
4. Click **Create**.

---

## Step 2: Set Up Signing in Xcode

1. Open **MVP.xcodeproj** in Xcode.
2. Select the **MVP** target (left sidebar).
3. Open **Signing & Capabilities**.
4. Check **Automatically manage signing**.
5. Choose your **Team** (your Apple Developer account).
6. Set **Bundle Identifier** to exactly the same as in App Store Connect (e.g. `com.yourcompany.MVP`).

---

## Step 3: Archive and Upload the App

**If Xcode shows "Invalid Run Destination" or "The current scheme doesn't have a run destination that can produce an archive":** use the script below instead of archiving from the menu (see **Option B**).

**Option A — Archive from Xcode**

1. In Xcode, select **Any iOS Device (arm64)** (or a connected device) as the run destination—do **not** choose a simulator.
2. Menu: **Product** → **Archive** (do not press the Run ▶ button).
3. When the Organizer window opens, select the new archive and click **Distribute App**.

**Option B — Archive from Terminal (if Option A fails)**

1. Open **Terminal** and run:
   ```bash
   cd /path/to/your/MVP   # folder that contains MVP.xcodeproj
   ./archive-for-testflight.sh
   ```
2. When it finishes, in Xcode go to **Window → Organizer** → **Archives** tab.
3. Click the **+** at the bottom left, go to the `build` folder inside your project, select **MVP.xcarchive**, and open it.
4. Select the MVP archive and click **Distribute App**.
5. Choose **App Store Connect** → **Next**.
6. Choose **Upload** → **Next**.
7. Leave options as default → **Next**.
8. Select your distribution certificate and provisioning profile (or let Xcode manage) → **Next**.
9. Click **Upload** and wait until it finishes.

---

## Step 4: Wait for the Build to Process

1. In App Store Connect, open your app and go to the **TestFlight** tab.
2. Wait until the new build appears and status is **Ready to test** (often 15–30 minutes). You’ll get an email when it’s ready.

---

## Step 5: Add Your Client as a Tester

1. In App Store Connect → your app → **TestFlight** tab.
2. Under **External Testing** (or **Internal Testing** if they’re in your team):
   - If you see **Create Group**, create a group (e.g. "Beta Testers").
   - Open the group and click **+** to add testers.
3. Enter: **Boris.shehter@gmail.com**
4. Add them and save.
5. For **External Testing**, the first time you add a group you may need to submit the build for **Beta App Review** (Apple’s short review for TestFlight). Follow the on-screen steps.
6. Once the build is approved (or if using Internal Testing), click **Enable** or **Start Testing** for that build.

---

## Step 6: What Happens Next

- **Apple sends an email** to **Boris.shehter@gmail.com** with a link to install TestFlight and your app.
- Your client:
  1. Opens the email on their iPhone.
  2. Taps the link (or installs **TestFlight** from the App Store if they don’t have it).
  3. Accepts the invite and installs your app.
  4. Opens the app and uses it like normal.

You do **not** need to create or send a link yourself—Apple sends it to the email you added.

---

## Create Public Link (client’s steps: External Testing → Inango group → Public Link)

Follow these steps exactly as your client requested.

### 1. Go to App Store Connect → TestFlight

1. Go to **[appstoreconnect.apple.com](https://appstoreconnect.apple.com)** and sign in.
2. Click **My Apps**.
3. Select your app (e.g. **Inango_mvp_1.0**).
4. Open the **TestFlight** tab at the top.

### 2. External Testing

1. In the **left menu** under TestFlight, click **External Testing**.

### 3. Create tester group “Inango”

1. Click **+** or **Create Group** (wording may be “Create Tester Group” or “Add Group”).
2. Name the group: **Inango**.
3. Save / Create the group.

### 4. Add build and submit for Beta App Review

1. Open the **Inango** group you just created.
2. Under **Builds** (or “Build”), click **+** to add a build.
3. Select your **approved / ready build** (the one you uploaded; status should be “Ready to Submit” or “Ready to test”).
4. Because this is the **first external build**, you must submit it for **Beta App Review**:
   - There will be a button like **Submit for Review** or **Submit for Beta App Review**.
   - Click it and complete any required fields (e.g. “What to test”, contact info). Submit.
5. **Wait for Apple’s approval** (often 24–48 hours). You’ll get an email when the build is approved. Until then, the public link will not work for external testers.

### 5. Open the group → Testers tab

1. Stay in the **Inango** group.
2. Click the **Testers** tab (inside the group).

### 6. Create Public Link

1. Click **Create Public Link** (or “Enable Public Link” / “Get Public Link”).
2. Choose one:
   - **Open to Anyone** — anyone with the link can join, or  
   - **Set a tester limit** — e.g. limit to **100** testers.
3. Confirm / Create. Apple will generate a link (e.g. `https://testflight.apple.com/join/XXXXXX`).

### 7. Copy and share the link

1. **Copy** the generated link.
2. **Share it in the chat** (or by email) with your client as requested.

---

## Prepare a Public Link for the Client (recommended)

Your client prefers **one public link** they can open to install the app. They do **not** need to use Xcode or set any Team ID—you do everything and send them the link.

### What you do (developer)

1. **Use your own Apple Developer account**  
   In Xcode → **Signing & Capabilities** → **Team**: select **your** team (your Apple ID / company). The client never sets a Team ID.

2. **Build and upload the app**  
   Archive (Product → Archive or `./archive-for-testflight.sh`), then **Distribute App** → App Store Connect → Upload. Wait until the build is **Ready to test** in TestFlight.

3. **Turn on the public link**  
   - Go to [App Store Connect](https://appstoreconnect.apple.com) → your app (**Inango_mvp_1.0**) → **TestFlight**.
   - In the left sidebar, click **App Information** (under TestFlight).
   - Find **TestFlight Public Link** (or **App Store Connect API** section; the exact label can vary).
   - Turn **Enable Public Link** (or **Public Link**) **ON**.
   - Copy the link (e.g. `https://testflight.apple.com/join/AbCdEf`).

4. **Send the link to your client**  
   Email or message them: “Install the app from this link: [paste link]. Open it on your iPhone and follow the steps to install.”

### What the client does

- Opens the link **on their iPhone** (Safari or any browser).
- Installs **TestFlight** from the App Store if prompted.
- Taps **Accept** / **Install** and gets your app. No Xcode, no developer account, no Team ID.

---

## Summary

| Step | Action |
|------|--------|
| 1 | Create app in App Store Connect, match Bundle ID |
| 2 | Set signing in Xcode (Team + Bundle ID) |
| 3 | Product → Archive → Distribute → Upload |
| 4 | Wait for build “Ready to test” in TestFlight |
| 5 | Add **Boris.shehter@gmail.com** as tester (External or Internal) |
| 6 | Client gets email from Apple with install link |

No source code is sent—only the invite/link to install the app from TestFlight.
