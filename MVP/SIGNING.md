# Fix: "Signing for MVP requires a development team"

This error means Xcode doesn’t know which **Apple Developer account (team)** to use for code signing. You must choose it in Xcode.

## Steps (do this in Xcode)

1. Open **MVP.xcodeproj** in Xcode.
2. In the **left sidebar**, click the blue **MVP** project icon (top).
3. Under **TARGETS**, select **MVP** (the app target, not MVPTests or MVPUITests).
4. Open the **Signing & Capabilities** tab at the top.
5. Under **Signing**, check **"Automatically manage signing"**.
6. In the **Team** dropdown, choose **your development team**:
   - It will look like your name or your company name (e.g. "Your Name (Personal Team)" or "Inango").
   - If you see **"Add an Account..."**, click it, sign in with your **Apple ID** (the one used for the Apple Developer Program), then pick that account’s team.
7. Leave **Bundle Identifier** as **IS.inangotest** (it must match App Store Connect).

After you select a team, the red error should go away and you can archive/upload again.

## If you don’t have a team

- You need an **Apple Developer Program** membership ($99/year): [developer.apple.com/programs](https://developer.apple.com/programs).
- After you enroll, your account appears as a team in Xcode. Sign in under **Xcode → Settings → Accounts** with that Apple ID, then pick that team in **Signing & Capabilities**.
