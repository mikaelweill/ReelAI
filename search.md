# Video Transcript Search Feature

## Requirements
- Each video in the feed should have its own search functionality
- Search through the current video's transcript only
- Jump to specific timestamps when a match is found

## Current Progress
- ❌ Previous implementation was incorrect (global search)
- Need to revert back to per-video search approach

## Data Structure
We have:
- `VideoEnhancements` model with `subtitles` list for each video
- Each subtitle has:
  - `id`
  - `startTime`
  - `endTime`
  - `text`
  - `style`

## Next Steps

### 1. Per-Video Search UI
- [ ] Add search toggle button to each VideoCard
- [ ] Add collapsible search box in each video's header
- [ ] Design in-video search results layout:
  - Matching subtitle text
  - Timestamp
  - Preview context

### 2. Search Logic (Per Video)
- [ ] Implement search in VideoCard:
  - Search current video's transcript only
  - Match partial words
  - Return timestamps for matches
- [ ] Add debouncing to search input
- [ ] Handle loading states

### 3. Timestamp Navigation
- [ ] Implement clicking on result:
  - Seek to specific timestamp in current video
  - Highlight matching text
  - Auto-play from that point

### 4. Performance Considerations
- [ ] Optimize transcript search for long videos
- [ ] Cache search results for current video
- [ ] Consider indexing current video's transcript

### 5. UI/UX Improvements
- [ ] Add loading indicator while searching
- [ ] Show "No results found" state
- [ ] Add clear search button
- [ ] Keyboard shortcuts (ESC to clear, Enter to focus first result)
- [ ] Consider highlighting matched text in results
- [ ] Make sure search UI doesn't interfere with video playback

## Questions to Resolve
1. How to handle multiple matches in the video?
2. Should we search in real-time or add a search button?
3. How to display search results without covering too much of the video?
4. Should we pause the video when showing search results?
5. Should we show context before/after the matched text? 