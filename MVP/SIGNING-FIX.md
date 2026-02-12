# Fix: "Communication with Apple failed" and "No profiles for IS.inangotest"

Do these in order.

---

## 1. Click "Try Again"

Sometimes it’s a temporary Apple/network issue. In **Signing & Capabilities**, click **Try Again** and see if the errors clear.

---

## 2. Register at least one device (fixes "no devices")

The message says: *"Your team has no devices from which to generate a provisioning profile."*  
Apple needs at least one device registered for the team.

### Option A — Connect an iPhone (easiest)

1. Connect your **iPhone** to the Mac with a USB cable.
2. Unlock the iPhone and tap **Trust** if asked.
3. In Xcode: **Window → Devices and Simulators** (or **Xcode → Devices and Simulators**).
4. Select your iPhone in the left list. If it shows a **yellow** or **"Register for Development"** button, click it so the device is registered for **Inango Systems Ltd**.
5. Go back to your project → **Signing & Capabilities** and click **Try Again**.

### Option B — Add device by UDID (no cable)

1. Get the device UDID (from the user who will test, or from **Settings → General → About** on the device; or from Finder when the device is connected).
2. Go to [developer.apple.com/account](https://developer.apple.com/account) → sign in with **macdev@inango-systems.com** (or the Inango account).
3. Open **Certificates, Identifiers & Profiles** → **Devices** → **+**.
4. Enter a name and the **UDID**, then register.
5. In Xcode → **Signing & Capabilities** → **Try Again**.

---

## 3. Check the Bundle ID in Apple Developer

1. Go to [developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers/list) → sign in.
2. Under **Identifiers**, check if **IS.inangotest** exists.
3. If it **does not** exist: click **+** → **App IDs** → **App** → Description e.g. "Inango MVP", Bundle ID **IS.inangotest** → Register.
4. In Xcode → **Signing & Capabilities** → **Try Again**.

---

## 4. Sign in again to Apple in Xcode

1. **Xcode → Settings** (or **Preferences**) → **Accounts**.
2. Select **macdev@inango-systems.com**.
3. Click **Download Manual Profiles** (or **Manage Certificates**) so Xcode talks to Apple again.
4. Close Settings and go to **Signing & Capabilities** → **Try Again**.

---

## 5. Use the script to archive (if signing still fails for Run)

If the errors only appear when **running** on a device but you only need to **upload** to TestFlight:

1. In Terminal run:
   ```bash
   cd /Users/iosexpert/Desktop/Voice/MVP
   ./archive-for-testflight.sh
   ```
2. When it finishes, open **Xcode → Window → Organizer → Archives**.
3. Click **+** and add **build/MVP.xcarchive** from your project folder.
4. Select the archive → **Distribute App** → **App Store Connect** → **Upload**.

Archiving for **App Store** uses a different profile (distribution) and sometimes works even when development signing shows errors. If the upload step then asks for a distribution certificate or profile, ensure **Inango Systems Ltd** has an **Apple Distribution** certificate in [Certificates, Identifiers & Profiles → Certificates](https://developer.apple.com/account/resources/certificates/list).

---

## Summary

| Step | Action |
|------|--------|
| 1 | Click **Try Again** in Signing & Capabilities |
| 2 | Register a device: connect iPhone and register in Xcode, or add UDID in developer.apple.com → Devices |
| 3 | Ensure **IS.inangotest** exists under Identifiers in developer.apple.com |
| 4 | Xcode → Settings → Accounts → download profiles / re-sign in |
| 5 | If you only need upload: run `./archive-for-testflight.sh` and upload from Organizer |
