# UltraCam Pro 📷⚡ (Version 2.0 Pro)

> **The Ultimate Next-Gen iOS Camera Application** with AI-Simulated 0.5x Ultra-Wide Lens, Real-Time AI Cinematic Bokeh, 3D Film Simulation LUTs, AI Magic Eraser, Zero-Latency Neural Engine Face Tracking, 4K 60fps / ProRAW Pipeline, and Apple Native-Grade Camera Experience.

[![Build & Release UltraCam Pro IPA](https://github.com/emlavankhoahienma-hue/ultracam-pro-ai/actions/workflows/build.yml/badge.svg)](https://github.com/emlavankhoahienma-hue/ultracam-pro-ai/actions/workflows/build.yml)
[![iOS](https://img.shields.io/badge/iOS-16.0%2B-blue.svg?style=flat&logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg?style=flat&logo=swift)](https://swift.org)
[![Metal](https://img.shields.io/badge/Metal-3.0-purple.svg?style=flat)](https://developer.apple.com/metal/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🌟 Version 2.0 Pro Features

### 1. 🎬 AI Cinematic Video (Real-Time Depth of Field)
- **Neural Engine Person Segmentation**: Uses `VNGeneratePersonSegmentationRequest` running at 60fps to separate subject from background.
- **Metal Bokeh Multi-Tap Disk Shader**: Generates creamy optical background blur with aperture control from $f/1.4$ down to $f/16$.

### 2. 🎞 Pro 3D LUTs Color Engine
- Real-time 3D film simulation LUTs with zero performance overhead:
  - **Fuji Classic Chrome**: Soft highlights, rich documentary greens, subtle contrast.
  - **Kodak Portra 400**: Warm skin tones, pastel highlights, creamy shadows.
  - **Leica Monochrome**: Deep analog black and white with high dynamic range.
  - **Cinestill 800T**: Tungsten balanced with warm halation glow and electric cyan tones.
  - **Teal & Orange**: Modern blockbuster cinematic split toning.
  - **Natural (Clean)**: Unprocessed pure sensor output.

### 3. ✨ AI Magic Eraser (Inpainting Editor)
- Built-in full-screen photo inspector with finger brush canvas.
- Neural inpainting algorithm (`AIEraser.swift` / `CIInpaintFilter`) to remove unwanted background objects, people, and power lines with seamless texture reconstruction.
- Direct save back to Photos library.

### 4. 🔬 0.5x Ultra-Wide Metal Shader (FoV Expansion)
- Polynomial inverse barrel distortion:
  $$r_{distorted} = r \cdot (1 + k_1 r^2 + k_2 r^4)$$
- Bilinear anti-aliasing edge clamping, vignette falloff compensation, and peripheral chromatic aberration.

### 5. ⚡ Zero-Latency AI Face Tracking
- Direct Apple Vision Neural Engine pipeline (`VNDetectFaceRectanglesRequestRevision3`) with Exponential Moving Average (EMA) stabilization.
- Real-time hardware auto-focus (`focusPointOfInterest`) and auto-exposure lock.

### 6. 📱 iOS 17 Apple Camera Experience
- **Touch-Priority Isolation (Z-Index 100)**: Completely resolved gesture conflicts; Zoom dial, mode selector, and shutter button always take touch priority.
- **Dynamic Island & Notch Protection**: Floating glass capsules strictly bounded within Safe Area.
- **Portrait Orientation Lock**: 100% distortion-free, native portrait preview and capture stream.

---

## 📁 Repository Structure

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
│   │   └── UltraWideShaders.metal# 0.5x Barrel, 3D LUTs & Cinematic Bokeh
│   ├── Engine/
│   │   ├── CameraEngine.swift    # 4K60, ProRAW, Live Photo, Orientation Lock
│   │   ├── MetalRenderer.swift   # 60fps MTKView Metal rendering pipeline
│   │   ├── MetalCameraView.swift # SwiftUI MTKView representable
│   │   ├── CinematicEngine.swift # Real-time person segmentation & Bokeh
│   │   ├── LUTEngine.swift       # 3D Film simulation color grading
│   │   └── AIEraser.swift        # Neural inpainting object removal
│   ├── AI/
│   │   ├── AITrackingManager.swift # Neural Engine Vision face tracking
│   │   └── AIFocusController.swift # Dynamic hardware lens POI focus
│   ├── UI/
│   │   ├── CameraMainView.swift  # Main camera viewfinder view & layer isolation
│   │   ├── Components/
│   │   │   ├── TopBarControlsView.swift
│   │   │   ├── BottomBarControlsView.swift
│   │   │   ├── ZoomDialView.swift
│   │   │   ├── FaceBoundingBoxOverlay.swift
│   │   │   ├── SettingsSheetView.swift
│   │   │   ├── CameraModeSelectorView.swift
│   │   │   ├── LUTSelectorView.swift
│   │   │   └── GalleryEditorView.swift
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
MIT License. Created for advanced mobile imaging.
