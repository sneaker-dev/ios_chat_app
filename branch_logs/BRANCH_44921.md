# Branch: inango_n44921_appstore_autologin_ios

**Redmine:** [#44921](https://redmine.inango.com/issues/44921)

## Contents

- App Store tab auto-login with saved credentials
- Persist password in Keychain on successful login
- When opening App Store tab: attempt native HTTP login first; if that fails, inject credentials into the login form and submit
- Use appstore-demo.inango.com

## Changes

- APIConfig: appStoreURL uses appstore-demo.inango.com with MVP_APP_STORE_URL env override
- KeychainService: saveLastPassword, getLastPassword, clearAll clears password
- LoginView: calls saveLastPassword on successful login
- DialogView: AppStoreNavDelegate and AppStoreWebViewStore with auth token, credential injection, native HTTP login, and flexible form detection
