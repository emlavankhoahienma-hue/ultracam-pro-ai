# UltraCam Pro 📷⚡

> **The Ultimate Next-Gen iOS Camera Application** with AI-Simulated 0.5x Ultra-Wide Lens, Zero-Latency Neural Engine Face Tracking, 4K 60fps / ProRAW Pipeline, and Apple Native-Grade Camera Experience.

[![Build & Release UltraCam Pro IPA](https://github.com/emlavankhoahienma-hue/ultracam-pro-ai/actions/workflows/build.yml/badge.svg)](https://github.com/emlavankhoahienma-hue/ultracam-pro-ai/actions/workflows/build.yml)
[![iOS](https://img.shields.io/badge/iOS-16.0%2B-blue.svg?style=flat&logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg?style=flat&logo=swift)](https://swift.org)
[![Metal](https://img.shields.io/badge/Metal-3.0-purple.svg?style=flat)](https://developer.apple.com/metal/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🌟 Key Features

### 1. 🔬 AI 0.5x Ultra-Wide Shader Engine (Role 1: Principal Metal & Algorithm Engineer)
- **Custom Metal Shaders (`UltraWideShaders.metal`)**: Inverse radial barrel distortion algorithm to expand Field-of-View (FoV) on single/dual-camera devices (iPhone 8 to iPhone XS).
- **Polynomial Radial Mapping**:
  $$r_{distorted} = r \cdot (1 + k_1 r^2 + k_2 r^4)$$
- **Bilinear Edge Anti-Aliasing & Vignette Correction**: Edge feathering and subtle chromatic aberration dispersion to eliminate pixel tearing and distortion artifacts.
- **Full AVFoundation Pipeline**: 4K 60fps video recording, Apple ProRAW (DNG) capture, and Live Photo support.

### 2. ⚡ Zero-Latency AI Face Tracking (Role 2: CoreML & AI Tracking Expert)
- **Apple Neural Engine Acceleration**: Direct Vision framework integration (`VNDetectFaceRectanglesRequestRevision3`) running at camera framerate with near-zero latency.
- **High Sensitivity**: Tracks profiles, yaw angles, pitch, and partial faces with Exponential Moving Average (EMA) bounding box stabilization.
- **Smart Auto-Focus & Auto-Exposure**: Dynamically translates Vision bounding box centers into `AVCaptureDevice` coordinate space to lock hardware focus (`focusPointOfInterest`).

### 3. 🎛 Authentic SwiftUI UI/UX (Role 3: SwiftUI UI/UX Master)
- **Apple Camera Clone & Enhancements**: Complete native interface with top utility bar, live viewfinder, yellow animated brackets, and bottom controls.
- **Interactive Zoom Dial**: Preset buttons (`0.5x`, `1x`, `2x`, `3x`, `5x`) and fine-grained dial wheel with hardware ramping (`ramp(toVideoZoomFactor:withRate:)`).
- **Pinch-to-Zoom & Haptic Engine**: Full taptic feedback on zoom increments, mode switches, and shutter presses.
- **Settings Modal**: On-the-fly resolution selection (4K60/4K30/1080p60), shader distortion tuning, ProRAW toggle, and composition grid.

### 4. 🚀 Automated DevOps & CI/CD (Role 4: DevOps & CI/CD Architect)
- **Zero-Error Xcode Project**: `project.pbxproj` configured with `ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS = NO` for seamless CI builds.
- **GitHub Actions (`.github/workflows/build.yml`)**: Automated macOS-14 runner building unsigned `.ipa` and releasing to GitHub Releases on push.

---

## 📁 Repository Architecture

```
ultracam-pro-ai/
├── .github/
│   └── workflows/
│       └── build.yml             # Automated CI/CD Workflow for IPA release
├── UltraCamPro.xcodeproj/
│   └── project.pbxproj           # Standard Xcode project definition
├── UltraCamPro/
│   ├── App/
│   │   ├── UltraCamProApp.swift  # App entry point
│   │   └── Info.plist            # Camera, Mic, Photo permissions
│   ├── Shaders/
│   │   ├── ShaderTypes.h         # SIMD Uniform definitions
│   │   └── UltraWideShaders.metal# 0.5x Barrel distortion & FoV shader
│   ├── Engine/
│   │   ├── CameraEngine.swift    # 4K60, ProRAW, Live Photo AVFoundation
│   │   ├── MetalRenderer.swift   # 60fps MTKView Metal rendering pipeline
│   │   └── MetalCameraView.swift # SwiftUI MTKView representable
│   ├── AI/
│   │   ├── AITrackingManager.swift # Neural Engine Vision face tracking
│   │   └── AIFocusController.swift # Dynamic hardware lens POI focus
│   ├── UI/
│   │   ├── CameraMainView.swift  # Main camera viewfinder view
│   │   ├── Components/
│   │   │   ├── TopBarControlsView.swift
│   │   │   ├── BottomBarControlsView.swift
│   │   │   ├── ZoomDialView.swift
│   │   │   ├── FaceBoundingBoxOverlay.swift
│   │   │   └── SettingsSheetView.swift
│   │   └── Utilities/
│   │       ├── HapticManager.swift
│   │       └── OrientationManager.swift
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
MIT License. Created with ❤️ for advanced mobile imaging.
