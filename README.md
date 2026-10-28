# 📱 Face Recognition & Geofenced Smart Attendance System

An enterprise-ready, AI-powered smart attendance system combining **FaceNet deep learning biometric verification** with **GPS geofencing** to prevent proxy attendance and enforce location-based check-ins. Built with a high-performance **Flutter** mobile application and a robust **Django REST backend**.

---

## 🌟 Key Features

* **Biometric Face Recognition**:
  * Powered by **PyTorch** and **FaceNet (`facenet-pytorch`)** for high-accuracy 512-dimensional facial embeddings.
  * Multi-pose face registration (Front, Left, Right, Up, Down).
  * Fast cosine distance matching with an offline pre-computed embedding cache (`_embeddings_cache.pt`).
* **GPS Geofencing Verification**:
  * Real-time GPS coordinate validation using the **Haversine formula**.
  * Dynamic site configuration with interactive map boundary controls (latitude, longitude, radius in meters).
  * Auto-flags attempts made outside allowed site premises as `out_of_radius`.
* **Flutter Mobile App**:
  * Clean, responsive UI with **Camera** and **Interactive OpenStreetMap / ArcGIS Map** integration.
  * Real-time facial scan check-in and check-out workflows.
  * Personal attendance history and calendar heatmaps.
* **Admin Management Portal**:
  * Live attendance statistics, presentee lists, and daily logs.
  * Student / Employee directory management with bulk CSV/Excel import and export.
  * Visual geofence editor with drag-and-drop boundary tuning.

---

## 🏗️ System Architecture

```
+------------------------------------------------------------------+
|                          Mobile Client                           |
|                      (Flutter / Dart App)                        |
|   +-----------------------+           +----------------------+   |
|   |  Live Camera Stream   |           |  GPS / Geolocator    |   |
|   | (Multi-pose Capture)  |           | (Lat / Long / Acc)   |   |
|   +-----------+-----------+           +----------+-----------+   |
+---------------|----------------------------------|---------------+
                | Multipart Image                  | JSON Payload
                v                                  v
+------------------------------------------------------------------+
|                       Django REST Backend                        |
|                                                                  |
|   +-------------------------------+   +----------------------+   |
|   |   Deep Learning Pipeline      |   |  Geofence Validator  |   |
|   |   (PyTorch + FaceNet)         |   |  (Haversine Metric)  |   |
|   |   - MTCNN Face Detection      |   |  - Center Coordinates|   |
|   |   - 512-d Embedding Matching  |   |  - Radius Check (m)  |   |
|   +---------------+---------------+   +----------+-----------+   |
|                   |                              |               |
|                   +--------------+---------------+               |
|                                  |                               |
|                                  v                               |
|                     +-------------------------+                  |
|                     | SQLite / PostgreSQL DB  |                  |
|                     | (Attendance & Users)    |                  |
|                     +-------------------------+                  |
+------------------------------------------------------------------+
```

---

## 📂 Project Structure

```text
Project04/
├── backend_api/                 # Django backend & AI engine
│   ├── attendance/              # Attendance logic, models, and mobile APIs
│   │   ├── face_system.py       # FaceNet PyTorch facial recognition service
│   │   ├── mobile_api.py        # Mobile client REST endpoints
│   │   ├── models.py            # RegisteredUser, AttendanceRecord, GeofenceSetting
│   │   ├── views.py             # Web views & admin controller actions
│   │   └── urls.py              # URL routing configuration
│   ├── backend/                 # Django project core settings (wsgi, asgi, settings)
│   ├── media/                   # User face registration datasets & embedding cache
│   ├── .env.example             # Template for secret keys and environment variables
│   ├── manage.py                # Django administrative utility
│   └── requirements.txt         # Python package dependencies
│
├── mobile_app/                  # Cross-platform Flutter application
│   ├── lib/
│   │   ├── main.dart            # Main app entry, routes, and ApiConfig
│   │   ├── registration_screen.dart # 5-angle face capture & onboarding
│   │   ├── admin_dashboard.dart # Admin live telemetry and attendance feeds
│   │   ├── admin_geofencing.dart# Interactive geofence map editor
│   │   ├── admin_students.dart  # Student roster & CRUD operations
│   │   └── admin_add_student.dart # Manual profile creation form
│   └── pubspec.yaml             # Flutter dependencies & assets
│
├── start_servers.bat            # Automated ADB reverse + Django + Flutter runner
└── README.md                    # Project documentation
```

---

## 🚀 Getting Started

### Prerequisites

* **Python 3.10 – 3.12** installed
* **Flutter SDK (3.12+)** and **Dart SDK** installed
* **Android Studio / Platform Tools** with ADB configured
* An Android physical device (Developer Mode & USB Debugging ON) or Android Emulator

---

### 1. Backend Setup (Django & PyTorch)

1. **Navigate to the backend directory**:
   ```bash
   cd backend_api
   ```

2. **Create and activate a virtual environment**:
   ```bash
   # Windows
   python -m venv venv
   .\venv\Scripts\activate

   # macOS / Linux
   python3 -m venv venv
   source venv/bin/activate
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment variables**:
   Create a `.env` file based on `.env.example`:
   ```bash
   # Windows (cmd)
   copy .env.example .env

   # Linux / macOS
   cp .env.example .env
   ```
   *Edit `.env` and provide a secure `SECRET_KEY`.*

5. **Apply database migrations**:
   ```bash
   python manage.py migrate
   ```

6. **Create an admin superuser**:
   ```bash
   python manage.py createsuperuser
   ```

7. **Start the local development server**:
   ```bash
   python manage.py runserver 0.0.0.0:8000
   ```
   *The API will be accessible locally at `http://127.0.0.1:8000`.*

---

### 2. Mobile App Setup (Flutter)

1. **Navigate to the mobile app directory**:
   ```bash
   cd mobile_app
   ```

2. **Install Flutter packages**:
   ```bash
   flutter pub get
   ```

3. **Configure API Host (`lib/main.dart`)**:
   In `lib/main.dart`, the `ApiConfig` class controls the server URL:
   * **For Android Emulator with ADB Reverse**: Defaults to `http://127.0.0.1:8000` (requires `adb reverse tcp:8000 tcp:8000`).
   * **For Physical Android Phone on same Wi-Fi**: Change `127.0.0.1` to your computer's local LAN IP (e.g., `http://192.168.1.15:8000`).
   * **For Production / Cloud**: Set to your deployed HTTPS URL (e.g., `https://api.yourdomain.com`).

4. **Run the App in Debug Mode**:
   ```bash
   flutter run
   ```

---

### ⚡ One-Click Local Development (Windows)

A convenience script `start_servers.bat` is included in the project root:
```cmd
start_servers.bat
```
This batch script automatically:
1. Configures `adb reverse tcp:8000 tcp:8000` so Android emulators/devices can access `localhost:8000`.
2. Starts the Django backend server in a dedicated window.
3. Launches the Flutter mobile application.

---

## 📡 Key API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/mobile/login/` | User/Admin authentication |
| `POST` | `/api/mobile/register/` | 5-angle biometric face registration |
| `POST` | `/attendance/checkin/scan/` | Face recognition check-in + GPS validation |
| `POST` | `/attendance/checkout/scan/` | Face recognition check-out + GPS validation |
| `GET`  | `/api/mobile/profile/` | Fetch user attendance history & stats |
| `GET`  | `/api/mobile/admin/dashboard/` | Real-time admin analytics and presentee counts |
| `GET`  | `/api/mobile/admin/geofence/` | Retrieve current geofence coordinates and radius |
| `POST` | `/api/mobile/admin/geofence/update/` | Update geofence coordinates and allowed radius |
| `GET`  | `/api/mobile/admin/students/` | List all registered members |
| `POST` | `/api/mobile/admin/students/import/` | Bulk import users via CSV or Excel |

---

## 📦 Building a Standalone APK for Production

To distribute the app to users without running Flutter or terminal commands:

1. Update `baseUrl` in `mobile_app/lib/main.dart` to your public cloud API URL.
2. Build the release APK:
   ```bash
   cd mobile_app
   flutter build apk --release
   ```
3. The generated standalone installer will be at:
   ```
   mobile_app/build/app/outputs/flutter-apk/app-release.apk
   ```
   *Transfer this `.apk` to any Android device to install and use directly.*

---

## 🔒 Security & Privacy

* Face images are processed to extract mathematical embedding vectors; raw test embeddings are cached locally to minimize disk I/O.
* Sensitive configurations and secret keys are loaded via `.env` and are strictly excluded from version control via `.gitignore`.
* Geofence coordinates can enforce mock-location blocking to prevent GPS spoofing apps.

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

