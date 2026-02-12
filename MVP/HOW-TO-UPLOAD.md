# How to Upload the App to App Store Connect

Follow these steps in order. You need **Xcode** and your **Apple Developer account** (the one that has the app in App Store Connect).

---

## Before you start

- The app **Inango_mvp_1.0** (or your app name) is already created in App Store Connect with Bundle ID **IS.inangotest**.
- You have the **MVP** project open in Xcode on your Mac.
- **Xcode 16 or later (iOS 18 SDK)** is required to upload to App Store Connect. If you see “This app was built with the iOS 17.5 SDK”, install **Xcode 16+** from the Mac App Store or [developer.apple.com/xcode](https://developer.apple.com/xcode/), then archive and upload again.

---

## Step 1: Set signing in Xcode (one-time)

1. Open **MVP.xcodeproj** in Xcode.
2. In the **left sidebar**, click the blue **MVP** project icon (top).
3. Under **TARGETS**, select **MVP** (the app, not MVPTests).
4. Click the **Signing & Capabilities** tab at the top.
5. Check **“Automatically manage signing”**.
6. In the **Team** dropdown, select **your** Apple Developer team (your name or company).
7. Confirm **Bundle Identifier** is **IS.inangotest** (same as in App Store Connect).

If you don’t set a Team, you’ll get “Signing requires a development team” and can’t archive.

---

## Step 2: Create an archive (the .xcarchive file)

You can do this **from Xcode** or **from Terminal** if Xcode shows “Invalid Run Destination.”

### Option A — From Xcode

1. At the top of Xcode, set the run destination to **Any iOS Device (arm64)** (click the device name and choose it from the list).
2. In the menu bar: **Product** → **Archive**.
   - Do **not** press the Run (▶) button.
3. Wait for the build to finish. The **Organizer** window will open with your archive.

### Option B — From Terminal (if Option A fails)

1. Open **Terminal** (Applications → Utilities → Terminal).
2. Run (replace with your real path if different):

   ```bash
   cd /Users/iosexpert/Desktop/Voice/MVP
   ./archive-for-testflight.sh
   ```

3. When it finishes, open **Xcode** → **Window** → **Organizer**.
4. In the **Archives** tab, click the **+** at the bottom left.
5. Go to the **build** folder inside your project folder and select **MVP.xcarchive** → **Open**.

You should now see the **MVP** archive in the list.

---

## Step 3: Upload the archive to App Store Connect

1. In **Organizer** → **Archives**, select the **MVP** archive (one click).
2. Click the blue **Distribute App** button on the right.
3. Choose **App Store Connect** → **Next**.
4. Choose **Upload** → **Next**.
5. Leave the options as default (e.g. “Upload symbols”, “Manage version and build number”) → **Next**.
6. **Signing:** choose **Automatically manage signing** (or your distribution certificate if you use manual signing) → **Next**.
7. Review the summary and click **Upload**.
8. Wait until the upload finishes. You may be asked for your **Apple ID password** or to allow access. When it’s done, you’ll see a success message.

---

## Step 4: Wait for the build in App Store Connect

1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps** → your app → **TestFlight** tab.
2. Open **Builds** in the left menu.
3. Your new build will appear first. Wait until its status is **“Ready to Submit”** or **“Processing”** then **“Ready to test”** (often 15–30 minutes). Apple may send an email when it’s ready.

---

## Step 5: Use the build in External Testing

1. In TestFlight, go to **External Testing** → open the **Inango** group.
2. Click **Add Builds** and select the build you just uploaded.
3. If it’s your first external build, **Submit for Beta App Review** when prompted and wait for approval.
4. Then use **Invite Testers** → **Create Public Link** and send the link to your client.

---

## Summary

| Step | What you do |
|------|------------------|
| 1 | Xcode: **Signing & Capabilities** → set **Team**, Bundle ID **IS.inangotest** |
| 2 | **Product → Archive** (or run `./archive-for-testflight.sh` and add archive in Organizer) |
| 3 | **Organizer** → select archive → **Distribute App** → **App Store Connect** → **Upload** |
| 4 | App Store Connect → **TestFlight** → **Builds** → wait for “Ready to test” |
| 5 | **External Testing** → **Inango** → **Add Builds** → then **Invite Testers** → **Create Public Link** |

That’s the full flow from “I haven’t uploaded” to “build is on TestFlight and I can create the public link.”
