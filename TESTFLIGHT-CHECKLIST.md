# TestFlight & App Store Submission Checklist

## Pre-Build Steps

- [ ] Open `project.yml` and verify:
  - `MARKETING_VERSION` is `1.0.0`
  - `CURRENT_PROJECT_VERSION` is `1`
  - Deployment target is `17.0`
- [ ] Run `xcodegen generate` to regenerate `.xcodeproj` from `project.yml`
- [ ] Open `TennisIQ.xcodeproj` in Xcode
- [ ] Set your Team in Signing & Capabilities
- [ ] Verify Sign in with Apple capability is enabled in Xcode
- [ ] Add a 1024x1024 app icon PNG to `Assets.xcassets/AppIcon.appiconset/` and update `Contents.json` with the filename
- [ ] Select the `TennisIQ.storekit` configuration for StoreKit testing in Xcode scheme

## Build & Test Locally

- [ ] Build for iPhone simulator (no errors)
- [ ] Build for physical device (no errors)
- [ ] Test full flow on device:
  - [ ] App launches, onboarding screens display
  - [ ] Complete onboarding
  - [ ] Sign in with Apple works
  - [ ] Guest mode works
  - [ ] Camera permission prompt appears
  - [ ] Recording starts and stops correctly
  - [ ] Analysis processes (pose extraction + API call)
  - [ ] Skeleton overlay renders on video playback
  - [ ] Coaching cards expand with grades and feedback
  - [ ] Progress dashboard shows data after analysis
  - [ ] Session history lists completed sessions
  - [ ] Subscription paywall appears after 3 free analyses
  - [ ] StoreKit sandbox purchase works (monthly and annual)
  - [ ] Restore purchases works
  - [ ] Profile shows correct subscription status
  - [ ] Theme switching works (Court Vision, Grand Slam, Rally)
  - [ ] Legal links open in browser
  - [ ] Sign out works
  - [ ] Feedback prompt appears after 2nd analysis

## Device Testing Matrix

- [ ] iPhone 14 / 15 (6.1")
- [ ] iPhone 15 Pro Max / 16 Pro Max (6.7")
- [ ] iOS 17.x
- [ ] iOS 18.x (if available)

## Upload to TestFlight

1. In Xcode: Product > Archive
2. In Organizer: Distribute App > App Store Connect > Upload
3. Wait for processing (10-30 minutes)
4. In App Store Connect:
   - Add internal testers
   - Add build to TestFlight group
   - Fill in "What to Test" description

## App Store Connect Setup

- [ ] Create app in App Store Connect with bundle ID `com.tennique.app`
- [ ] Configure subscription products (see `app-store-metadata.md`)
- [ ] Upload screenshots for all required device sizes
- [ ] Fill in all metadata from `app-store-metadata.md`
- [ ] Set Privacy Policy URL: `https://tennisiq.com/privacy`
- [ ] Set App Store Contact Info
- [ ] Add review notes from `app-store-metadata.md`
- [ ] Submit for review

## Post-Submission

- [ ] Monitor App Store Connect for review status
- [ ] Typical review time: 24-48 hours
- [ ] If rejected, address feedback and resubmit
- [ ] Once approved, release immediately or schedule release
