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
  - `video_compress`: Video compression ✓
  - `image_picker`: Media selection ✓
  - `uuid`: Unique identifiers ✓
  - `visibility_detector`: Video playback control ✓

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

### Current Priority: Studio Features (In Progress)
1. Basic Studio Implementation ✓
   - Studio screen layout ✓
   - Video list view ✓
   - Basic metadata display ✓
   - Navigation integration ✓
   - Video compression service ✓
   - Upload progress tracking ✓
   - Thumbnail generation (Not Started)

2. Video Editor UI (In Progress)
   - Video preview player ✓
   - Basic playback controls ✓
   - Timeline scrubber (Studio only)
     - Basic slider functionality ✓
     - Current/total time display ✓
     - Marker positions for chapters (In Progress)
       - Visual markers on timeline
       - Chapter titles on hover/scrub
     - Smooth seeking behavior ✓
     - Visual feedback during scrubbing ✓
   - Text overlay editor (Deprioritized)
     - Basic text input dialog ✓
     - Text rendering on video (Buggy)
     - Time-based visibility (Not Working)
     - Custom duration control (Not Started)
     - Style presets (Not Started)
   - Chapter marker interface (High Priority)
     - Add markers in Studio ✓
     - Delete markers in Studio (NEW)
     - Title and descriptions ✓
     - Quick navigation in Studio ✓
     - Feed view integration:
       - Chronological chapter list below video ✓
       - Click to seek functionality ✓
       - Maintain normal auto-play behavior ✓
     - Chapter visualization on timeline ✓
     - Scrollable chapter list in feed (NEW)
   - Studio view improvements:
     - Chronological ordering of chapter list ✓
     - Delete functionality for chapters (NEW)
     - Visual markers on timeline scrubber ✓
     - Chapter titles near markers when scrubbing ✓

3. Enhancement Features (Next)
   - Text overlay animations
   - Custom fonts and styles
   - Chapter preview thumbnails
   - Sound adjustment controls
   - Export with enhancements

### Next Steps:
1. Studio View:
   - Add delete functionality for chapters (Next)
   - Ensure smooth visual feedback after deletion

2. Feed View:
   - Make chapter list scrollable
   - Handle overflow properly
   - Maintain smooth transitions

3. Future Improvements (Post Chapters)
   - Fix text overlay rendering and visibility
   - Add custom duration for text overlays
   - Implement thumbnail generation
   - Implement overlay drag-and-drop
   - Add style presets for text

4. Feed View (Current) ✓
   - Keep minimal interface ✓
   - Simple chapter/timestamp buttons ✓
   - No scrubbing functionality ✓
   - Focus on content consumption ✓

5. Future Considerations
   - Detail view implementation (Deprioritized)
   - Advanced playback controls
   - Enhanced navigation
   - Additional player features

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
   - Feed View:
     - Clean, minimal interface
     - Chapter/timestamp buttons
     - No scrubbing in feed
   - Studio View:
     - Full scrubber controls
     - Precise navigation
     - Editing tools
   - Detail View (Future):
     - Basic scrubber
     - Chapter navigation
     - Enhanced playback controls

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

#### Video Edits Collection (NEW) ✓
```typescript
video_edits/{videoId} ✓
{
  textOverlays: [{
    id: string,          // Unique identifier ✓
    text: string,        // Overlay text ✓
    startTime: number,   // Start time in seconds ✓
    endTime: number,     // End time in seconds ✓
    top: number,         // Position from top (0-1) ✓
    left: number,        // Position from left (0-1) ✓
    style: string,       // Predefined style name ✓
  }],
  chapters: [{
    id: string,          // Unique identifier ✓
    title: string,       // Chapter title ✓
    timestamp: number,   // Time in seconds ✓
    description: string? // Optional description ✓
  }],
  soundEdits: {         // Sound modifications
    volume: number,      // Master volume
    fadeIn: number?,     // Fade in duration
    fadeOut: number?,    // Fade out duration
  },
  lastModified: timestamp ✓
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