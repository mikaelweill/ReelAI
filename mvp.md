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
- Press-and-hold recording with visual feedback ✓
- 30-second recording limit with progress indicator ✓

### Video Management Implementation ✓
1. Video Privacy Controls ✓
   - Add `isPrivate` boolean field to videos ✓
   - Private: Only visible to creator ✓
   - Public: Visible in main feed ✓

2. Video Upload Enhancement ✓
   - Add title input dialog (required) ✓
     - Minimum length: 3 characters ✓
     - Maximum length: 50 characters ✓
     - Show error if empty or invalid ✓
   - Add optional description field ✓
     - Maximum length: 200 characters ✓
     - Placeholder text for guidance ✓
   - Show character count for both fields ✓
   - Improved error handling during upload ✓
   - Better crash protection and state management ✓

### Current Priority: Video Creation & Playback
1. Recording Controls (In Progress)
   - ~~Maximum duration limit (60 seconds)~~ Changed to 30 seconds ✓
   - Press-and-hold recording mechanism ✓
   - Visual recording progress indicator ✓
   - Tap-to-focus (TODO)
   - Minimum duration limit (3 seconds) (TODO)

2. Video Quality (TODO)
   - Adjust resolution settings
   - Optimize file size
   - Generate and upload thumbnails
   - Add loading placeholders

3. Video Player Features (Partial)
   - Auto-play when in view ✓
   - Loop playback ✓
   - Loading indicators ✓
   - Mute/unmute toggle (TODO)
   - Double-tap to like (TODO)
   - Share button (TODO)

### Next Steps:
1. UI/UX Improvements (In Progress)
   - Add loading states for video uploads ✓
   - Improve error messages and handling ✓
   - Add pull-to-refresh in feeds (TODO)
   - Add infinite scroll pagination (TODO)
   - Enhance video card design (TODO)
   - Add animations and transitions (TODO)
   - Add logout functionality to all screens ✓

2. Social Features
   - Implement likes system
   - Add comments section
   - Add view count tracking
   - User profiles
   - Following system

3. Performance Optimization
   - Implement video caching
   - Optimize feed loading
   - Add preloading for next video
   - Reduce initial load time
   - Implement HLS/DASH streaming:
     - Convert uploaded videos to HLS/DASH format
     - Generate multiple quality variants (360p, 480p, 720p)
     - Create manifest files (.m3u8/.mpd)
     - Implement adaptive bitrate streaming
     - Add quality selection controls
   - Memory optimization:
     - Limit active video controllers
     - Release resources for off-screen videos
     - Implement progressive loading
   - Network optimization:
     - Smart preloading based on scroll direction
     - Bandwidth-aware quality selection
     - Efficient cache management

### Video Streaming Implementation
1. Backend Processing
   - Set up video transcoding pipeline
   - Generate multiple quality variants
   - Create HLS/DASH segments
   - Generate video thumbnails
   - Implement CDN integration

2. Frontend Implementation
   - Integrate HLS/DASH player
   - Add quality selection UI
   - Implement bandwidth monitoring
   - Add buffering indicators
   - Smart preloading logic
   - Memory-efficient player management

3. Caching Strategy
   - Cache manifest files
   - Implement segment caching
   - Smart cache invalidation
   - Preload adjacent segments
   - Cache quality preferences

### Database Structure ✓
#### Videos Collection ✓
```typescript
videos/{videoId} ✓
{
  userId: string,        // User who uploaded the video ✓
  videoUrl: string,      // Storage URL for the video ✓
  title: string,        // Required, 3-50 chars ✓
  description: string?, // Optional, max 200 chars ✓
  createdAt: timestamp, // Server timestamp ✓
  duration: number,     // Video duration in seconds ✓
  size: number,        // File size in bytes ✓
  aspectRatio: number, // Video aspect ratio ✓
  status: 'processing' | 'ready' | 'failed', ✓
  isPrivate: boolean,  // Privacy setting ✓
  thumbnailUrl: string?, // TODO: Implement thumbnail generation
  likes: number,       // Like counter
  comments: number,    // Comment counter
  views: number,       // View counter
  streamingUrls: {     // New: URLs for different streaming formats
    hls: string,       // HLS manifest URL
    dash: string,      // DASH manifest URL
    fallback: string   // Direct video URL fallback
  },
  qualities: string[], // Available quality variants
}
```

## Future Enhancements (Post-MVP):
- Advanced video editing
  - Filters and effects
  - Speed controls
  - Background music
  - Text overlays
- Content discovery
  - Hashtags system
  - Search functionality
  - Trending videos
  - Categories/topics
- Engagement features
  - Direct messaging
  - Video responses
  - Duets/collaborations
  - Challenges/contests

### Implementation Notes:
1. Video Upload Flow ✓
   - Record video ✓
   - Preview and confirm ✓
   - Add metadata (title, description, privacy) ✓
   - Upload to Storage ✓
   - Create Firestore document ✓
   - Handle upload progress ✓
   - Show success/error states ✓
   - Generate streaming variants (NEW)
   - Create manifest files (NEW)

2. Feed Implementation
   - Implement infinite scroll
   - Handle video preloading
   - Manage memory usage
   - Track view counts
   - Sort by relevance/date
   - Smart quality selection
   - Adaptive streaming playback

3. Error Handling
   - Network failures
   - Upload interruptions
   - Invalid file types
   - Size limits
   - Rate limiting
   - Streaming fallback options
   - Quality switching errors