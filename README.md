# UltraCam Pro 📷⚡ (Version 3.0 Native)

> **The Authentic Native iPhone X/XS Apple Camera Experience**: Hardware Dual Camera Optical Switching (1x Wide / 2x Telephoto), Buttery-Smooth Zoom Ramping, Zero-Latency Neural Engine AI Face Tracking, 4K 60fps Pipeline, and 100% Native iOS Camera UI.

[![Build & Release UltraCam Pro IPA](https://github.com/emlavankhoahienma-hue/ultracam-pro-ai/actions/workflows/build.yml/badge.svg)](https://github.com/emlavankhoahienma-hue/ultracam-pro-ai/actions/workflows/build.yml)
[![iOS](https://img.shields.io/badge/iOS-16.0%2B-blue.svg?style=flat&logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg?style=flat&logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🌟 UltraCam Pro V3.0 Highlights

### 1. 🔬 Native Dual Camera Hardware (iPhone X / XS)
- **Physical Lens Switching**: Seamless hardware switching between Wide-Angle (1x) and Telephoto (2x) via `AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera, .builtInTelephotoCamera])`.
- **Buttery-Smooth Zoom Ramping**: Full hardware `ramp(toVideoZoomFactor:withRate: 15.0)` integration with pinch-to-zoom support up to 10x.
- **Pure Native Preview**: Direct GPU compositing with `AVCaptureVideoPreviewLayer` for zero latency, 60fps/120fps fluid response, and zero frame buffer copies.
- **Background Thread Session Architecture**: All session configurations and camera switches execute asynchronously on dedicated serial queues for zero UI lockups.

### 2. ⚡ Zero-Latency AI Face Tracking
- **Apple Neural Engine Acceleration**: Direct `VNDetectFaceRectanglesRequestRevision3` with `preferBackgroundProcessing = false`.
- **Real-Time Hardware Auto-Focus & Auto-Exposure**: Direct injection into `focusPointOfInterest` and `exposurePointOfInterest`.
- **Apple Yellow Reticle**: Smooth spring-animated corner brackets tracking faces in real-time.

### 3. 📱 Pure Native Apple Camera UI
- **Authentic iPhone X/XS UI**: Clean, deep-black interface perfectly inset below the Notch / Dynamic Island.
- **Instant Taptic Feedback**: Tactile responses on shutter click, zoom steps, and mode switches.
- **3 Simple Modes**: **PHOTO**, **VIDEO**, and **PORTRAIT**.
- **Native Shutter Button**: 78pt outer ring (4.5pt stroke) with 64pt solid inner circle.

---

## 📁 Repository Structure

```
ultracam-pro-ai/
├── .github/
│   └── workflows/
│       └── build.yml             # Automated CI/CD Workflow for IPA release
├── UltraCamPro.xcodeproj/
│   └── project.pbxproj           # Clean Xcode project definition
├── UltraCamPro/
│   ├── App/
│   │   ├── UltraCamProApp.swift  # App entry point
│   │   └── Info.plist            # Camera, Mic, Photo permissions
│   ├── Core/
│   │   ├── CameraManager.swift   # AVFoundation pipeline & dual-camera ramping
│   │   ├── CameraPreviewView.swift # Native AVCaptureVideoPreviewLayer
│   │   ├── FaceTrackingEngine.swift # Zero-latency Vision face tracking
│   │   └── HapticManager.swift   # Tactile haptics engine
│   ├── UI/
│   │   └── CameraView.swift      # 100% authentic Apple Camera UI
│   └── Assets.xcassets/          # App icons & accent colors
└── README.md
```

---

## 📲 Sideloading the IPA

Download the latest `UltraCamPro-v2.0.0-unsigned.ipa` from the [Releases](https://github.com/emlavankhoahienma-hue/ultracam-pro-ai/releases) tab and install using:
- **TrollStore** (Recommended for iOS 14.0 - 17.0)
- **AltStore / AltServer**
- **SideStore**
- **Scarlet / Sideloadly**

---

## 📄 License
MIT License. Created for advanced mobile imaging.
