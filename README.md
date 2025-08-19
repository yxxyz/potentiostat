# potentiostat

Flutter application for a single-channel potentiostat system supporting CV, CA, SWV, DPV, LSV and EIS. Enables control of the fabricated potentiostat via HM10 BLE module.

## 🔧 System Requirements

Before using the application:

- Ensure **Bluetooth** and **Location** are enabled on your mobile device.
- **Do not interrupt** the measurement process once it has started.  
  If the system becomes unresponsive, **power cycle the potentiostat** (unplug and reconnect).

---

## 🚀 Flutter Development Setup

### 1. Environment Setup
- [How to Set Up Flutter in VSCode (YouTube)](https://youtu.be/EhGW4UYpKSE?si=CT6L0P2j-RBQhjBa)

### 2. Enable Developer Options (Android)
- [Android Developer Options Guide](https://developer.android.com/studio/debug/dev-options#:~:text=The%20Settings%20app%20on%20Android,Settings%20%3E%20About%20phone%20%3E%20Build%20number)

### 3. USB Debugging
To debug using a physical Android device:
- Use a **USB-C to USB-C** cable to connect your phone to your development machine.
- Enable USB debugging on the corresponding Android mobile device.
- Authorize USB debugging access when prompted on your mobile device.

---

## 📱 App Structure

The project follows a modular directory structure to ensure maintainability and scalability:

| Folder/File          | Description                                           |
|----------------------|-------------------------------------------------------|
| `lib/pages/`         | Contains the Dart files for each app screen/page     |
| `fonts/`             | Custom fonts used throughout the application         |
| `assets/`            | Static image resources used in the UI                |
| `pubspec.yaml`       | Defines dependencies, assets, and fonts configuration|

---

## 📦 Dependencies

Ensure all dependencies are installed via:

```bash
flutter pub get
