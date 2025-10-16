# 🧇 Waffle — The Grid-Based Web Browser for iPad

**Waffle** is an experimental **iPad-only web browser** that reimagines how users interact with multiple webpages at once.  
Built with **SwiftUI** and **WebKit** on **iOS 26**, it leverages the latest Apple platform features — including multi-window support, Scene-based architecture, and the new `WebView` API — to offer a lightweight, intuitive, and deeply Apple-native browsing experience.

---

## ✨ Overview

Unlike traditional tab-based browsers, **Waffle** organizes pages into a **customizable grid**.  
Each “cell” in the grid hosts its own browsing context, allowing users to visually organize workflows, research sets, and dashboards side-by-side.

Waffle is designed for:
- **iPad power users** who multitask visually.
- **Researchers and developers** who reference multiple sources simultaneously.
- **Designers and creatives** who prefer spatial memory over tab stacks.

---

## 🧱 Architecture

- **Language:** Swift  
- **Framework:** SwiftUI + WebKit (`WebView` for iOS 26)  
- **Persistence:** SwiftData  
- **Sync:** CloudKit Private Database  
- **Storage:** AppStorage + SwiftData hybrid for user preferences and layouts  
- **Multi-Window:** Scene phase awareness with independent grid persistence per scene  
- **Share Extension:** “Save to Waffle” Safari extension for capturing URLs directly into chosen cells  

___

## 🧰 Development

### Prerequisites
- **Xcode 16+**  
- **iPadOS 26 SDK**  
- **Apple Developer Account** (for CloudKit container access)  
- **macOS 15+ (Sequoia)**  
