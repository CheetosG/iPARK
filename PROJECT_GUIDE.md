# iPARK - Project Technical Guide 🚗💨

Welcome to the **iPARK** Technical Guide. This document is designed to help you understand every part of your project, from the visual app (Frontend) to the brain of the system (Backend). Use this to study for your presentation or to make changes to the code.

---

## 1. Project High-Level Architecture
iPARK is a **Full-Stack Application** built using the following technologies:
*   **Frontend:** Flutter (Dart) - For the mobile/web interface.
*   **Backend:** Node.js & Express (JavaScript) - The server logic.
*   **Database:** MongoDB - Where all users, reservations, and parking spots are stored.
*   **Real-time:** Socket.IO - For instant updates (like spot status changing).

### How they talk:
1.  **REST API:** For one-time actions (Login, Register, Booking).
2.  **WebSockets:** For a permanent connection that sends instant alerts.

---

## 2. Frontend Structure (`frontend/lib`)
The frontend is organized by **Responsibility**. Each folder has a specific job:

### 📁 `lib/main.dart`
The **Entry Point**. It initializes the app, sets up the navigation routes, and connects to the **SocketService** as soon as the app starts.

### 📁 `lib/theme/`
*   **`app_theme.dart`**: The **Design System**. If you want to change the app's colors (Blue, Dark Mode, etc.) or fonts, this is where you do it.

### 📁 `lib/services/` (The "Waiters")
These files handle all communication with the server:
*   **`api_config.dart`**: Contains the Server URL (Ngrok or Local). **Change this if your server address changes.**
*   **`base_api_service.dart`**: The base logic for sending data and handling errors.
*   **`socket_service.dart`**: Manages the live "tunnel" for real-time parking updates.
*   **`auth_service.dart`**: Specifically handles login and logout.

### 📁 `lib/screens/` (The Pages)
Each folder here represents a feature:
*   **`auth/`**: Login, Register, OTP screens.
*   **`home/`**: The main dashboard showing parking spots.
*   **`admin/`**: Screens only accessible by administrators.
*   **`support/`**: Chat and help screens.

### 📁 `lib/widgets/` (Reusable Components)
Small UI pieces used in multiple screens (Buttons, Cards, AppBars).
*   **`spot_card.dart`**: The visual box for a parking spot.

### 📁 `lib/providers/` (State Management)
Uses the "Provider" pattern to share data across different screens without refreshing the whole app.

---

## 3. Backend Structure (`backend/`)
The backend is organized into a **Model-View-Controller (MVC)** pattern:

### 📁 `server.js`
The **Heart** of the server. It connects to the database, sets up the security middleware, and starts the Socket.IO listener.

### 📁 `models/` (Data Structure)
Defines how data is saved in MongoDB:
*   **`User.js`**: Stores email, password, role (admin/user).
*   **`Spot.js`**: Stores parking spot status (available/occupied).
*   **`Reservation.js`**: Stores who booked which spot and for how long.

### 📁 `controllers/` (The Logic/Chefs)
Contains the actual functions that do the work:
*   **`authController.js`**: Logic for checking passwords and creating tokens.
*   **`reservationController.js`**: Logic for calculating prices and saving bookings.

### 📁 `routes/` (The Menu)
Defines the "Endpoints" (URLs) that the frontend can call:
*   Example: `POST /api/auth/login` maps to the login logic.

### 📁 `middleware/` (The Security)
*   **`auth.js`**: Verifies if a user is logged in before allowing them to access private data.

---

## 4. How to Edit the Project (Practical Examples)

### A. Changing the App Colors (Frontend)
1.  Open `frontend/lib/theme/app_theme.dart`.
2.  Find the lines starting with `static const Color primaryLight = ...`.
3.  Change the hex code (e.g., `0xFF00B4D8` is blue) to your new color.

### B. Changing the Server Address (Frontend)
1.  Open `frontend/lib/services/api_config.dart`.
2.  Update the `ngrokUrl` variable with your latest link from the terminal.
3.  Ensure `useNgrok` is set to `true`.

### C. Adding a New Data Field (Backend)
1.  Open the Model file (e.g., `backend/models/User.js`).
2.  Add a new line inside the `new mongoose.Schema({ ... })` block.
    *   Example: `phoneNumber: { type: String }`

### D. Changing Booking Prices (Backend)
1.  Open `backend/controllers/reservationController.js`.
2.  Look for the calculation logic inside the `createReservation` function.
3.  Change the multiplier (e.g., `totalPrice = hours * 10`).

---

## 5. Detailed File Reference

### Frontend Critical Files:
*   **`lib/services/socket_service.dart`**: 
    *   **Listen for events:** Look at `socket!.on('event_name', ...)`.
    *   **Send events:** Use `socket!.emit('event_name', data)`.
*   **`lib/widgets/spot_card.dart`**:
    *   **Edit UI:** Find the `build` method. This handles how each parking spot looks on the grid.

### Backend Critical Files:
*   **`server.js`**: 
    *   **Database Connection:** Look for `mongoose.connect()`.
    *   **Socket.IO Init:** Look for `io.on('connection', ...)`.
*   **`routes/admin.js`**:
    *   Lists all URLs that only the Admin can access (like viewing all users).

---

## 6. Key Workflows (The Logic)

### A. How Login Works
1.  **Frontend:** User types email/password in `login_screen.dart`.
2.  **Service:** `auth_service.dart` sends this to the server.
3.  **Backend:** `authController.js` checks the database. If correct, it sends back a **JWT Token**.
4.  **Frontend:** Saves the Token in `SharedPreferences` (so you stay logged in).

### B. How Real-time Parking Works
1.  **Backend:** A parking spot status changes (e.g., via `socket.emit('spot_status_changed')`).
2.  **Frontend:** `socket_service.dart` is listening. It hears the message.
3.  **UI:** The `spot_status_stream` updates, and the `SpotCard` on the user's screen instantly turns red or green.

---

## 7. How to Run for a Presentation
1.  **Backend:** Open terminal in `/backend`, run `npm run dev`.
2.  **Ngrok (Optional):** Start ngrok and update the URL in `api_config.dart`.
3.  **Frontend:** Connect your phone or emulator, run `flutter run`.

---
*Created with ❤️ for iPARK Development.*
