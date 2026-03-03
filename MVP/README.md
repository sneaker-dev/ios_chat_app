# MVP — iOS Dialog App

iOS app for text and voice dialog with a backend, featuring login, avatar selection, and a main screen with a talking avatar, chat, and microphone input.

## Requirements

- **Xcode** 14 or later (Xcode 15+ recommended)
- **iOS 14.0+** (iPhone and iPad)
- macOS for building

## Build Instructions

1. **Open the project**
   - Open `MVP.xcodeproj` in Xcode (double-click or `File → Open`).

2. **Select target and device**
   - Select the **MVP** scheme.
   - Choose a simulator (e.g. iPhone 15) or a connected device.

3. **Configure backend (optional)**
   - The app uses a placeholder API base URL by default (`https://api.example.com`).
   - To point to your backend, either:
     - Set the `MVP_API_BASE_URL` environment variable in the scheme (Edit Scheme → Run → Arguments → Environment Variables), or
     - Change `APIConfig.baseURL` in `MVP/Services/APIConfig.swift`.

4. **Build and run**
   - Press **⌘R** or click the Run button.
   - On a real device, enable **Microphone** and **Speech Recognition** when prompted.

## Project Structure

- **MVPApp.swift** — App entry, shows `RootView`.
- **RootView.swift** — Decides between Login, Avatar Selection, or Dialog.
- **Models/** — `AvatarType`, `ChatMessage`.
- **Services/** — `KeychainService`, `AuthService`, `DialogAPIService`, `SpeechToTextService`, `TextToSpeechService`, `APIConfig`.
- **Views/** — `LoginView`, `AvatarSelectionView`, `DialogView`.
- **Views/Components/** — `AvatarView`, `ChatBubbleView`.

## voice-demo.inango.com (Real answers)

The app is configured for **https://voice-demo.inango.com**. The dialog endpoint (`POST /api/v1/intent/generic`) requires a **JWT** in the `Authorization: Bearer <token>` header. Inango’s OpenAPI states the JWT is obtained from their “AppStore login process,” not from voice-demo itself.

**To get real answers:**

1. **Ask Inango** for the exact login or token URL (and request format) that returns a JWT for voice-demo.
2. **Or**, if they give you a JWT (e.g. from a web portal or Postman):
   - Open the app → Log in screen.
   - Scroll to **“Real login for voice-demo.inango.com”**.
   - Paste the JWT into the text field and tap **“Use this token”**.
   - You will be signed in with that token and the app will use it for dialog requests.

3. **Optional:** If they provide a login API URL, set **MVP_API_BASE_URL** and **MVP_LOGIN_PATH** in the scheme’s Environment Variables so email/password login works.

## Backend API (generic)

1. **Registration** — `POST /auth/register`  
   Body: `{ "email", "password", "device_id" }`  
   Response: `{ "token": "..." }` (or `access_token`)

2. **Login** — `POST /auth/login` (or path from backend)  
   Same request/response as registration.

3. **Dialog (Inango)** — `POST /api/v1/intent/generic`  
   Headers: `Authorization: Bearer <JWT>`  
   Body: `{ "locale": "en-US", "queryText": "..." }`  
   Response: `{ "queryResponse": "..." }`

## Features

- **Registration & Login** — Email/password; token stored in Keychain.
- **Avatar selection** — Shown once after first login; male/female options.
- **Main dialog** — Greeting by avatar, scrollable chat, text input, mic for voice.
- **Speech-to-Text** — Local (iOS Speech framework); system language.
- **Text-to-Speech** — Local (AVSpeechSynthesizer); response played with avatar “speaking” state.
- **Avatar states** — Idle, speaking, loading (extensible for future lip-sync).

## Deployment (TestFlight)

1. In Xcode: select the MVP target → **Signing & Capabilities** → set your Team and Bundle ID.
2. **Product → Archive**.
3. In Organizer, choose **Distribute App** → **App Store Connect** → **Upload**.
4. In App Store Connect, add the build to TestFlight and invite testers.

## Known console messages (Simulator / server)

When running in Xcode you may see these; they are explained below.

### Simulator / system (not app bugs)

- **Failed to get sandbox extensions** — Simulator restriction; safe to ignore.
- **Query for com.apple.MobileAsset.VoiceServicesVocalizerVoice failed: 2**  
  **Query for com.apple.MobileAsset.VoiceServices.GryphonVoice failed: 2**  
  **Unable to list voice folder** — System voice-asset queries in the Simulator often fail or are limited. The app handles missing TTS voices and skips speech when none are available.
- **AddInstanceForFactory: No factory registered for id...** — Core Audio / HAL in Simulator; no real audio device.
- **HALC_ProxyIOContext::IOWorkLoop: skipping cycle due to overload**  
  **AQMEIO_HAL.cpp timeout**  
  **AudioDeviceStop: no device with given ID** — Simulator audio under load (e.g. TTS or mic); expected in Simulator and does not indicate an app bug.

None of these require a code change. On a **real device**, voice and audio typically work without these messages.

### Server 500: “Internal Server Error for url: http://10.0.5.1:8082/api/v1/users/user”

- **What it means:** The app calls `https://voice-demo.inango.com/api/v1/intent/generic` correctly. The **voice-demo** backend then calls an **internal** service at `http://10.0.5.1:8082/api/v1/users/user`. That internal call fails, and voice-demo returns **500** with the message above.
- **Who can fix it:** The failure is **on the server/infra side** (voice-demo.inango.com or the service at 10.0.5.1:8082). The app cannot fix it.
- **What to do:** Share the console line with the API provider (Inango) so they can fix their backend or the users service. The app will show “Voice server is temporarily unavailable” and will retry; when the server is fixed, the dialog will work.

## License

Open-source libraries and system APIs only; no third-party SDKs requiring separate licensing.
