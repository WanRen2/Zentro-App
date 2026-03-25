# Zentro

E2EE messaging app with GitHub storage.

## Features

- End-to-end encrypted messaging
- QR code invite system
- Local key generation (X25519)
- GitHub-based message storage (via backend)

## Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Configure backend URL in `lib/config.dart`:
   ```dart
   static const String backendUrl = 'http://YOUR_IP:3000';
   ```

3. Run:
   ```bash
   flutter run
   ```

## First Launch

1. Create your profile (name + keys are generated automatically)
2. Create or join a chat
3. Start messaging securely!

## Security

- Keys are generated and stored locally on your device
- Messages are encrypted before being sent
- Backend server never sees your encryption keys
- GitHub stores only encrypted ciphertext
