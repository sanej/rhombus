# Rhombus

Voice-native product & feature tracker. Speak to add products, add features, and update feature status.
A bright, fluid SwiftUI interface (light mode) shows live status; Cloudflare Workers + D1 provide persistence.

- `backend/` – Cloudflare Worker + D1 REST API
- `ios/Core` – Swift package: models and voice command parser/resolver (unit tested, `swift test`)
- `ios/App` – SwiftUI iOS app (generate project with [XcodeGen](https://github.com/yonaskolb/XcodeGen): `cd ios && xcodegen`)

## Backend
```
cd backend
npm install
npx wrangler d1 create rhombus            # copy database_id into wrangler.toml
npx wrangler d1 migrations apply rhombus --remote
npx wrangler secret put API_TOKEN         # shared bearer token
npx wrangler deploy
npm test
```

## iOS
1. `cd ios && xcodegen && open Rhombus.xcodeproj`
2. Set your team / bundle id in `ios/project.yml`.
3. In the app's Settings (gear icon) enter the Worker URL and API token.
4. Tap the mic and say e.g.:
   - "Add product Orbit"
   - "Add feature dark launch to Orbit"
   - "Mark dark launch as done" / "Set voice login to in progress" / "Voice login is blocked"
   - "Delete feature voice login" / "Delete product Orbit"

Speech runs on-device where available (Speech framework). Launch checklist: add an app icon in
`ios/App/Assets.xcassets`, set signing, archive and upload via Xcode/TestFlight.
