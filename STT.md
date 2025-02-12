# Speech-to-Text (STT) Firebase Functions Strategy

## Current State
- We have two versions of the code:
  1. Local version: Basic implementation
  2. Deployed version: More advanced but with issues

## Requirements
1. **MP4 to MP3 Conversion**
   - Input: MP4 video from Firebase Storage
   - Output: MP3 file saved back to Firebase Storage
   - Requirements: Efficient conversion, maintain audio quality

2. **Speech-to-Text Processing**
   - Input: MP3 file from Firebase Storage
   - Output: Raw transcription text
   - Using: OpenAI Whisper API

3. **Summary Generation**
   - Input: Raw transcription
   - Output: Concise summary
   - Using: OpenAI GPT API

## Proposed Architecture

### 1. File Structure
```
functions/
├── main.py              # Main entry point with function definitions
├── services/
│   ├── storage.py       # Firebase Storage operations
│   ├── converter.py     # MP4 to MP3 conversion
│   ├── transcriber.py   # OpenAI Whisper integration
│   └── summarizer.py    # OpenAI GPT integration
├── models/
│   ├── video.py         # Video data model
│   └── transcript.py    # Transcript data model
└── utils/
    └── logger.py        # Centralized logging
```

### 2. Function Separation
We'll create three separate Cloud Functions:

1. `convert_to_audio`
   - Triggered by: New video upload in Storage
   - Actions: 
     - Extract audio from MP4
     - Save as MP3
     - Trigger next function
   - Expected duration: 1-2 minutes max

2. `create_transcript`
   - Triggered by: New MP3 file
   - Actions:
     - Send to Whisper API
     - Save transcription
     - Trigger summary generation
   - Expected duration: 2-3 minutes

3. `generate_summary`
   - Triggered by: New transcription
   - Actions:
     - Process transcription
     - Generate summary with GPT
     - Save results
   - Expected duration: 30 seconds

### 3. Implementation Strategy

#### Phase 1: Audio Conversion
1. Start with simple MP4 to MP3 conversion
2. Test with small files first
3. Implement proper error handling
4. Add progress tracking

#### Phase 2: Transcription
1. Basic Whisper API integration
2. Handle large audio files
3. Implement retry logic
4. Add transcription status updates

#### Phase 3: Summary Generation
1. Basic GPT integration
2. Optimize prompt engineering
3. Handle long transcriptions
4. Add customization options

## Success Metrics
1. Reliable conversion of videos up to 10 minutes
2. Transcription accuracy > 95%
3. Function execution time < 5 minutes total
4. Error rate < 1%

## Testing Strategy
1. Unit tests for each service
2. Integration tests for full pipeline
3. Test with various video lengths/types
4. Error scenario testing

## Deployment Strategy
1. Deploy functions one at a time
2. Start with development environment
3. Monitor performance and costs
4. Gradually increase quotas

## Next Steps
1. [ ] Set up basic project structure
2. [ ] Implement MP4 to MP3 conversion
3. [ ] Test conversion with small files
4. [ ] Add proper error handling
5. [ ] Move to transcription implementation

## Dependencies
```python
# requirements.txt
firebase-admin==6.4.0
firebase-functions==0.1.0
openai==1.12.0
ffmpeg-python==0.2.0  # For audio conversion
pydantic==2.5.3      # For data validation
python-dotenv==1.0.1 # For environment management
```

## Notes
- Keep functions focused and single-purpose
- Implement proper logging throughout
- Use async where beneficial
- Monitor memory usage
- Implement proper cleanup
- Add detailed error messages 