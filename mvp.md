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

### Video Playback Implementation ✓
1. Full-Screen Experience ✓
   - Vertical scroll pagination ✓
   - Proper aspect ratio handling ✓
   - Black letterboxing for different ratios ✓
   - Centered video display ✓
   - Tap to play/pause ✓

2. Memory & Performance ✓
   - Limit active video controllers ✓
   - Release resources for off-screen videos ✓
   - Add buffering indicators ✓
   - Progressive loading implementation ✓
   - Better error handling for video playback ✓

3. UI/UX Improvements ✓
   - Text shadows for readability ✓
   - Semi-transparent control buttons ✓
   - Proper safe area handling ✓
   - Improved video metadata display ✓
   - Privacy controls with visual feedback ✓

### Current Priority: Social Features
1. Video Interactions
   - Double-tap to like
   - Like counter
   - Share functionality
   - Comment system
   - View tracking

2. User Engagement
   - User profiles
   - Following system
   - Activity feed
   - Notifications

3. Content Discovery
   - For You page
   - Following feed
   - Search functionality
   - Hashtags system

### Next Steps:
1. Performance Optimization
   - Smart preloading of adjacent videos
   - Better memory management
   - Efficient cache handling
   - Network optimization
   - Video compression

2. Advanced Features
   - Background audio support
   - Video filters
   - Custom thumbnails
   - Video trimming
   - Music library

### Video Quality (Next Priority)
   - Generate and upload thumbnails
   - Optimize initial load time
   - Add loading placeholders
   - Adjust resolution settings
   - Optimize file size

3. Video Player Features (In Progress)
   - Auto-play when in view ✓
   - Loop playback ✓
   - Loading indicators ✓
   - Progressive buffering ✓
   - Mute/unmute toggle (Next)
   - Double-tap to like (Next)
   - Share button (Next)

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

#### Video Enhancements Collection (NEW)
```typescript
video_enhancements/{videoId} {
  subtitles: [{
    id: string,          // Unique identifier
    startTime: number,   // Start time in seconds
    endTime: number,     // End time in seconds
    text: string,        // Subtitle text
    style: {             // Text styling
      color: string,     // Text color
      size: number,      // Font size
      position: {        // Position on screen
        x: number,       // 0-1 (percentage from left)
        y: number        // 0-1 (percentage from top)
      },
      background: string?, // Optional background color
      fontWeight: string  // normal, bold, etc.
    }
  }],
  timestamps: [{
    id: string,          // Unique identifier
    time: number,        // Timestamp in seconds
    title: string,       // Short description
    description: string?, // Optional longer description
    thumbnail: string?   // Optional thumbnail for this timestamp
  }],
  lastModified: timestamp,
  version: number        // For handling schema updates
}
```

#### User Interactions Collection (NEW)
```typescript
video_interactions/{videoId}/interactions/{userId} {
  timestampClicks: [{    // Track which timestamps users click
    timestampId: string,
    clickedAt: timestamp
  }],
  viewProgress: number,  // How far user watched (percentage)
  lastViewedAt: timestamp,
  completedViews: number // Number of complete views
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