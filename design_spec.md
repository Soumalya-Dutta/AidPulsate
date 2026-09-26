# AidPulsate - Mobile UX Design Specification

This document outlines the high-fidelity UI/UX design for the AidPulsate emergency safety application, optimized for Flutter and Android-first deployment.

---

## 1. Design System (UI Foundations)

### 1.1 Color Palette
| Token | Hex Code | Usage |
| :--- | :--- | :--- |
| **Danger/SOS** | `#D32F2F` | Primary SOS buttons, Active SOS headers, Urgent alerts. |
| **Safe/Success** | `#2E7D32` | "I am Safe" buttons, Connectivity success, Resolution states. |
| **Warning/Offline** | `#FBC02D` | Internet unavailable, SMS fallback indicators. |
| **Info/Link** | `#1976D2` | GPS status, Setting icons, Metadata. |
| **Background** | `#FFFFFF` | Main screen background. |
| **Surface** | `#F8F9FA` | Cards, secondary containers. |
| **Text Primary** | `#121212` | Main headings, SOS labels. |
| **Text Secondary** | `#5F6368` | Captions, timestamps, inactive status. |

### 1.2 Typography (Material Design 3 Based)
- **Display Large**: `36pt`, Bold (Countdown numbers)
- **Headline Medium**: `24pt`, Semi-Bold (SOS Status)
- **Title Large**: `20pt`, Medium (Screen Titles)
- **Body Large**: `16pt`, Regular (Status descriptions)
- **Label Small**: `12pt`, Medium (Metadata: ID, GPS coordinates)

### 1.3 Components
- **SOS Button**: 200dp x 200dp circular button, elevation 8, high-contrast text.
- **Status Chip**: Rounded pill, background color based on state (Green/Red/Gray).
- **Action Button**: 56dp height, full-width or large pill, 8dp corner radius.
- **Information Card**: White surface, 1dp border (`#E0E0E0`), 16dp padding.

---

## 2. Screen Specifications

### 2.1 Home / Safe State
*Goal: Reassurance and readiness.*

- **Top Bar**:
    - Left: Small logo/text "AidPulsate".
    - Right: Subtle Settings (cog icon) and Profile.
- **Connectivity Status (Upper Center)**:
    - Row of two Chips:
        - `Connectivity`: Green Dot + "Online" (or Yellow + "Offline").
        - `Location`: Blue Dot + "GPS Active".
- **Primary Action (Center)**:
    - **Large Red Circular Button**.
    - Label: "HOLD TO ACTIVATE SOS".
    - *Interaction*: Long-press (1s) to prevent accidental triggers.
- **Footer**:
    - Text: "You are safe. Monitoring is currently inactive."

### 2.2 SOS Activation (Countdown)
*Goal: Quick cancellation to prevent false alarms.*

- **Layout**: Full-screen modal overlay with a semi-transparent dark background.
- **Center**:
    - Large pulsing number: **5... 4... 3...**
    - Subtext: "SOS ACTIVATING..."
- **Primary Action (Bottom)**:
    - Large Gray Button: "CANCEL".
    - *Logic*: Immediately stops the sequence and returns to Home.
- **Haptics**: Incremental vibration pulses as the countdown nears zero.

### 2.3 Active SOS (Online)
*Goal: Visibility of help and data transmission.*

- **Header (Permanent Red Banner)**:
    - Text: "SOS ACTIVE" (Flash/Pulse animation).
- **Live Status Section**:
    - Card: Map Preview (Small thumbnail) with "Broadcasting Live Location".
    - Label: `Lat: 40.7128, Lng: -74.0060`.
    - Label: `Last Sync: Just now`.
- **Event Metadata**:
    - Text: `Ref ID: #AP-8829-X`.
- **Primary Action (Bottom)**:
    - Large Green Pill Button: "I AM SAFE / END SOS".
    - *Interaction*: Tap triggers a quick confirmation dialog ("Are you sure you want to end this emergency session?").

### 2.4 Offline SOS (Fallback Mode)
*Goal: Clarity that the system is still working despite no internet.*

- **Header**: Yellow Banner "SOS ACTIVE (OFFLINE)".
- **Connectivity Card**:
    - Icon: Wi-Fi Off.
    - Text: "Internet Unavailable".
    - **Status**: "Emergency message queued via SMS Gateway."
- **Queue Progress**:
    - "Last SMS Sent: 2 mins ago".
    - "SMS Gateway Status: Waiting for delivery receipt".
- **Action**: Same "I AM SAFE" button as Active mode.

### 2.5 SOS Confirmation / Resolution
*Goal: Closure and post-event data overview.*

- **Center**:
    - Large Green Checkmark icon.
    - Title: "Emergency Session Ended".
- **Summary List**:
    - Start Time: `14:20:05`
    - End Time: `14:35:10`
    - Total Tracked Points: `42`
    - Method: `Online + SMS Fallback`
- **Primary Action**:
    - "Return to Home".

---

## 3. Implementation Priorities (Flutter)

1. **Accessibility**:
    - Use `Semantics` widgets for all SOS actions.
    - Support Dynamic Text scaling for low-vision users.
    - Ensure a minimum contrast ratio of 4.5:1.
2. **Performance**:
    - Use `RepaintBoundary` for the SOS pulsing animation.
    - Ensure the SOS button is responsive even during heavy background location processing.
3. **Discretion**:
    - The "Settings" area should be reachable but not distracting.
    - The "I am Safe" confirmation should be unambiguous.
