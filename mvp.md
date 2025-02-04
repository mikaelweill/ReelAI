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

## Phase 3: Core Features (In Progress)

### Camera Implementation ✓
- Camera permission handling ✓
- Video recording interface ✓
- Basic video preview ✓
- Camera flip functionality ✓
- Preview screen with playback ✓

### Video Creation Enhancements (Next)
1. Recording Controls
   - Maximum duration limit (60 seconds)
   - Minimum duration limit (3 seconds)
   - Recording timer display
   - Tap-to-focus
2. Video Quality
   - Adjust resolution settings
   - Optimize file size
3. Basic Effects
   - Flash mode toggle
   - Speed controls (0.5x, 1x, 2x)
   - Basic filters

### Video Playback Implementation (Priority)
1. Create Basic Feed Screen
   - Simple vertical scrolling list
   - Full-screen video player
   - Smooth loading transitions
2. Video Player Features
   - Auto-play when in view
   - Mute/unmute toggle
   - Loop playback
   - Loading indicators
3. Video List Management
   - Fetch from Firestore by date
   - Basic caching for smooth playback
   - Load more on scroll

### Video Management Implementation (Current Priority)
1. Video Privacy Controls
   - Add `isPrivate` boolean field to videos
   - Private: Only visible to creator
   - Public: Visible in main feed

2. Video Upload Enhancement
   - Add title prompt when saving/publishing
   - Required title field for all videos
   - Option to add description (optional)
   - Show upload progress
   - Preview thumbnail in upload dialog

3. My Videos Section UI Improvements
   - Clean card-based layout with proper spacing
   - Display video title prominently
   - Show creation date in readable format
   - Add video thumbnail/preview
   - Consistent padding and margins
   - Material Design elevation for cards
   - Clear visual hierarchy

### Database Structure
#### Videos Collection
```typescript
videos/{videoId}
{
  userId: string,
  videoUrl: string,
  title: string,        // New required field
  description: string,  // New optional field
  createdAt: timestamp,
  duration: number,
  size: number,
  aspectRatio: number,
  status: 'processing' | 'ready' | 'failed',
  isPrivate: boolean,
  lastModified: timestamp,
}
```

## Next Steps Priority:
1. ✓ Basic camera functionality
2. ✓ Video preview and upload
3. → Enhance video recording features
   - Add recording timer
   - Add speed controls
   - Add flash toggle
4. → Implement basic video feed
   - Create scrolling video list
   - Add auto-playing video player
   - Handle video loading states

## Future Enhancements (Post-MVP):
- Captions and descriptions
- Likes and views tracking
- User profiles
- Comments system
- Video sharing
- Advanced filters and effects
- Background music
- Following system

## NoSQL Data Modeling Notes:
1. Denormalized Structure
   - Store frequently accessed data together
   - Minimize number of reads needed
2. Queries to Support:
   - Get latest videos for feed
   - Get user's videos
   - Get liked videos
3. Indexes Needed:
   - videos by createdAt (for feed)
   - videos by userId (for profile)
   - videos by likes (for trending)

### Implementation Plan (Minimal Changes Required)
1. Upload Flow Updates
   - Add title input dialog before upload
   - Validate title (required, min/max length)
   - Store title in Firestore

2. UI Enhancements
   - Redesign video cards with Material Design
   - Add proper spacing and margins
   - Implement consistent typography
   - Show video titles prominently

3. Database Updates
   - Add `isPrivate` field to existing video schema
   - No migration needed, default to public for existing videos

4. UI Changes
   - Add bottom navigation bar with Home and My Videos tabs
   - Reuse existing video player component
   - Simple toggle for private/public status

5. Service Layer Updates
   - Modify video feed query to filter private videos
   - Add query for user's videos (both private and public)
   - Add privacy toggle functionality

6. Upload Flow
   - Add simple dialog with Save/Publish options
   - Update upload completion handler

### Queries to Support
1. Main Feed:
   ```typescript
   videos
     .where('isPrivate', '==', false)
     .where('status', '==', 'ready')
     .orderBy('createdAt', 'desc')
   ```

2. My Videos:
   ```typescript
   videos
     .where('userId', '==', currentUserId)
     .where('status', '==', 'ready')
     .orderBy('createdAt', 'desc')
   ```
