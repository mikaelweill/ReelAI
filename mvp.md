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

### Firebase Configuration ✓
- Set up Firebase project ✓
- Add iOS/Android configuration files ✓
- Initialize Firebase in the app ✓
- Configure App Check ✓

## Phase 2: Authentication Flow ✓

### Email/Password Authentication ✓
1. Create authentication service ✓
2. Implement login/signup screen ✓
3. Handle auth state management ✓
4. Basic navigation flow ✓

### User Profile (Next)
1. Create user profile in Firestore after signup
2. Store basic user information:
   - Display name
   - Profile picture (optional)
   - Bio (optional)
3. Profile edit screen

## Phase 3: Core Features (In Progress)

### Camera Implementation ✓
- Camera permission handling ✓
- Video recording interface ✓
- Basic video preview ✓
- Camera flip functionality ✓
- Preview screen with playback ✓

### Video Storage & Management (Next)
1. Create Firebase Storage structure
   - `/videos/{userId}/{videoId}.mp4`
   - `/thumbnails/{userId}/{videoId}.jpg`
2. Implement video upload service
   - Upload video to Firebase Storage
   - Generate and upload thumbnail
   - Create video metadata in Firestore
3. Add upload progress indicator
4. Handle upload errors and retries

### Feed Implementation (Upcoming)
- Vertical scrolling video feed
- Video player with autoplay
- Basic engagement buttons (like, comment)

### Database Structure
#### Users Collection
```typescript
users/{userId}
{
  displayName: string,
  email: string,
  profilePicture?: string,
  bio?: string,
  createdAt: timestamp,
  updatedAt: timestamp
}
```

#### Videos Collection
```typescript
videos/{videoId}
{
  userId: string,
  title: string,
  description?: string,
  videoUrl: string,
  thumbnailUrl: string,
  likes: number,
  comments: number,
  createdAt: timestamp,
  duration: number,
  size: number,
  aspectRatio: number
}
```

## Next Steps Priority:
1. ✓ Implement basic camera functionality
2. ✓ Add video preview and playback
3. → Implement video upload to Firebase Storage (Current Task)
4. Create video feed screen
5. Add video playback in feed

## Future Enhancements:
- Comments system
- Like functionality
- User following
- Video sharing
- Push notifications
- Video filters and effects
- Background music
