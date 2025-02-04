# TikTok Clone MVP Specification

## Phase 1: Project Setup & Dependencies ✓

### Initial Setup ✓
- Create new Flutter project ✓
- Configure Firebase project ✓
- Add necessary dependencies in `pubspec.yaml`: ✓
  - `firebase_core`: Firebase initialization ✓
  - `firebase_auth`: Authentication ✓
  - `cloud_functions`: Cloud Functions ✓
  - `firebase_storage`: Video storage ✓
  - `camera`: Native camera access ✓
  - `video_player`: Video playback ✓
  - `cloud_firestore`: Database ✓

### Firebase Configuration (In Progress)
- Set up Firebase project ✓
- Add iOS/Android configuration files (Pending)
- Initialize Firebase in the app (Pending)

## Phase 2: Authentication Flow (Next)

### Magic Link Authentication
1. Create Firebase Function for magic link generation
2. Implement email input screen
3. Create authentication service
4. Handle deep links for magic link verification
5. Implement auth state management

### Screens Needed
- Email input screen
- Loading/verification screen
- Auth check wrapper

## Phase 3: Core Features

### Camera Implementation
- Camera permission handling
- Video recording interface
- Basic video preview
- Upload functionality

### Feed Implementation
- Vertical scrolling video feed
- Video player with autoplay
- Basic engagement buttons (like, comment)

### Database Structure
