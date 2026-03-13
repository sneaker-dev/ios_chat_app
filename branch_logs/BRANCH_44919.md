# Branch: inango_n44919_topbar_icons_layout_ios

**Redmine:** [#44919](https://redmine.inango.com/issues/44919)

## Contents

- Replace default top-bar icons with custom AvatarSelect, SettingsIcon, and Inango logo assets
- Refactor tab buttons to use a ZStack overlay so text sits close to the icon
- Remove the divider background
- Tune button and icon sizes for visual parity with Android
- Align avatar position with the visible top-bar bottom edge

## Changes

- Add custom icon imagesets: AvatarSelect, SettingsIcon, InangoTopbarLogo, TabChat, TabSupport, TabAppStore
- Refactor `topBar` and `landscapeFullWidthTopBar` to use `brandLogo` and `topActionIcon`
- Add `modeTabButton` with fixed height (80/92pt), uniform icon sizing, and tight icon/text spacing
- Adjust avatar position (`topBarBottom + 20`), scale (1.0), and frame height
