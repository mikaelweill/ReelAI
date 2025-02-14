# ReelAI - AI Features Documentation

## Concept Breakdown & Linking

### Overview
Enhanced info card creation system that combines manual control with AI assistance. Creators can choose to generate card content using AI and get smart web-sourced link suggestions, while maintaining full editorial control.

### User Experience

1. **Manual with AI Assist Flow**:
   - Creator clicks "Add Info Card" at desired timestamp
   - Creator sees two options:
     1. "Create Manually" (existing flow)
     2. "Generate with AI" (new feature)
   - If "Generate with AI" selected:
     - System analyzes video context around timestamp
     - Suggests title, description, and relevant links
     - Creator can edit/modify all suggestions
     - Creator can regenerate any part
   - Creator reviews and saves card

2. **Smart Link Enhancement**:
   - System crawls relevant educational websites
   - Ranks links by relevance and authority
   - Suggests top 3-5 high-quality resources
   - Shows preview snippets of link content
   - Creator can manually add/remove links

### Technical Implementation

#### 1. Enhanced Info Card Interface
```typescript
interface AIGeneratedContent {
  title: string;
  description: string;
  suggestedLinks: Array<{
    title: string;
    url: string;
    snippet: string;    // preview of content
    relevanceScore: number;
    authority: number;  // domain authority score
  }>;
  sourceTimestamp: number;
  confidence: number;
}

interface InfoCardGenRequest {
  videoId: string;
  timestamp: number;
  contextWindow: number;  // seconds around timestamp to analyze
  preferredSources?: string[];  // preferred domains for links
}
```

#### 2. API Endpoints

##### Generate Card Content
```http
POST /api/v1/info-card/generate
Body: {
  videoId: string,
  timestamp: number,
  contextWindow: number
}
Response: {
  content: AIGeneratedContent,
  processingMetadata: {
    duration: number,
    confidence: number
  }
}
```

##### Enhance with Web Links
```http
POST /api/v1/info-card/enhance-links
Body: {
  term: string,
  context: string,
  preferredDomains?: string[]
}
Response: {
  links: Array<{
    title: string,
    url: string,
    snippet: string,
    relevanceScore: number,
    authority: number
  }>
}
```

#### 3. AI Integration

##### Context Analysis
```typescript
const completion = await openai.chat.completions.create({
  model: "gpt-4",
  messages: [
    {
      role: "system",
      content: `You are an educational content assistant. Analyze the video context and generate a concise info card.`
    },
    {
      role: "user",
      content: `Generate an info card for this video segment:
      Timestamp: ${timestamp}
      Context: ${videoContext}`
    }
  ],
  response_format: { type: "json_object" }
});
```

##### Web Crawler Integration
```typescript
interface WebCrawlerConfig {
  allowedDomains: string[];  // e.g., '.edu', 'wikipedia.org', etc.
  maxResults: number;
  minAuthority: number;
  timeout: number;
}

async function findRelevantLinks(term: string, context: string, config: WebCrawlerConfig) {
  // 1. Generate search queries
  const queries = await generateSmartQueries(term, context);
  
  // 2. Parallel crawl top results
  const results = await Promise.all(
    queries.map(query => crawlSearchResults(query, config))
  );
  
  // 3. Rank and filter results
  return rankAndFilterLinks(results, term, context);
}
```

### Cost & Performance Optimization

1. **Caching Strategy**:
   - Cache generated content by video segments
   - Cache web crawl results for common terms
   - Implement sliding window for popular searches

2. **Resource Management**:
   - Rate limit AI generations per user/video
   - Batch web crawling requests
   - Cache link previews and metadata

3. **Cost Estimates**:
   - GPT-4 Analysis: ~$0.01 per card
   - Web Crawling: Negligible (self-hosted)
   - Total: ~$0.01-0.02 per card

### Error Handling & Quality Control

1. **AI Generation**:
   - Fallback to simpler analysis if context is unclear
   - Multiple retry attempts with different prompts
   - Quality scoring of generated content

2. **Web Crawling**:
   - Link validation and health checks
   - Content safety verification
   - Domain authority verification
   - Backup link suggestions

### Future Enhancements

1. **Smart Features**:
   - Learning from user edits to improve suggestions
   - Automatic content categorization
   - Related video recommendations

2. **UI Improvements**:
   - Preview cards before saving
   - Bulk AI generation for multiple timestamps
   - Custom link source preferences

3. **Integration**:
   - LMS (Learning Management System) integration
   - Citation format support
   - Content recommendation engine

### Smart Web Crawler Implementation

#### 1. Hybrid Search Architecture
```typescript
interface SmartCrawlerSystem {
  // Core Components
  searchEngine: {
    traditional: StandardWebCrawler;
    aiEnhanced: AISearchEnhancer;
    embeddings: ContentEmbeddingEngine;
  };
  
  // Configuration
  config: {
    allowedDomains: string[];        // e.g., '.edu', 'wikipedia.org'
    trustScores: Record<string, number>; // domain trust scores
    maxDepth: number;                // crawl depth per site
    timeout: number;                 // ms per request
  };
}

interface SearchStrategy {
  // Phase 1: Initial Search
  standardSearch: {
    useGoogleAPI: boolean;      // Use Google Custom Search API
    useBing: boolean;           // Use Bing API
    useCustomCrawler: boolean;  // Use our crawler
  };
  
  // Phase 2: AI Enhancement
  aiEnhancement: {
    useEmbeddings: boolean;     // Use embeddings for similarity
    useGPT: boolean;            // Use GPT for content relevance
    useLinkAnalysis: boolean;   // Use AI for link quality
  };
}
```

#### 2. Search Process Flow

1. **Initial Content Discovery**:
```typescript
async function discoverContent(query: string, context: string) {
  // 1. Use search APIs for initial results
  const searchResults = await Promise.all([
    googleCustomSearch(query),
    bingSearch(query),
    customCrawler.search(query)
  ]);

  // 2. Generate embeddings for context
  const contextEmbedding = await openai.embeddings.create({
    model: "text-embedding-3-small",
    input: context,
  });

  return mergeAndDeduplicate(searchResults);
}
```

2. **AI-Enhanced Filtering**:
```typescript
async function enhanceResults(results: SearchResult[], context: string) {
  // 1. Generate embeddings for each result
  const embeddings = await generateBatchEmbeddings(
    results.map(r => r.content)
  );

  // 2. Use GPT-4 to analyze relevance
  const relevanceScores = await analyzeRelevance(results, context);

  // 3. Score and rank results
  return rankResults(results, {
    embeddings,
    relevanceScores,
    domainAuthority: await getDomainScores(results)
  });
}
```

3. **Smart Content Extraction**:
```typescript
interface ContentExtractor {
  // Intelligent content parsing
  extractRelevantContent(html: string): Promise<{
    mainContent: string;
    relevantSnippets: string[];
    metadata: {
      author?: string;
      datePublished?: string;
      citations?: string[];
    };
  }>;

  // Quality assessment
  assessContentQuality(content: string): Promise<{
    readabilityScore: number;
    technicalAccuracy: number;
    educationalValue: number;
  }>;
}
```

#### 3. AI Integration Points

1. **Query Enhancement**:
```typescript
async function enhanceSearchQuery(term: string, context: string) {
  const completion = await openai.chat.completions.create({
    model: "gpt-4",
    messages: [
      {
        role: "system",
        content: "Generate optimal search queries for educational content."
      },
      {
        role: "user",
        content: `Generate 3 search queries to find high-quality educational resources about:
        Term: ${term}
        Context: ${context}
        Focus on academic and educational sources.`
      }
    ]
  });
  
  return parseQueries(completion.choices[0].message.content);
}
```

2. **Content Relevance Scoring**:
```typescript
async function scoreRelevance(content: string, context: string) {
  const embedding1 = await getEmbedding(content);
  const embedding2 = await getEmbedding(context);
  
  return {
    similarityScore: cosineSimilarity(embedding1, embedding2),
    contextualScore: await getGPTScore(content, context),
    technicalScore: await assessTechnicalAccuracy(content)
  };
}
```

#### 4. Performance Optimizations

1. **Caching System**:
```typescript
interface CacheStrategy {
  embeddings: {
    ttl: number;        // Time to live
    maxSize: number;    // Max cache size
  };
  searchResults: {
    ttl: number;
    maxSize: number;
  };
  domainScores: {
    ttl: number;
    updateFrequency: number;
  };
}
```

2. **Batch Processing**:
```typescript
async function batchProcessUrls(urls: string[]) {
  // 1. Group by domain to respect rate limits
  const domainGroups = groupByDomain(urls);
  
  // 2. Process in parallel with rate limiting
  return await Promise.all(
    domainGroups.map(group => 
      processWithRateLimit(group, {
        maxConcurrent: 3,
        delayMs: 1000
      })
    )
  );
}
```

#### 5. Quality Control

1. **Content Verification**:
```typescript
async function verifyContent(content: string, url: string) {
  return {
    // Check for educational value
    educationalScore: await assessEducationalValue(content),
    
    // Verify source credibility
    sourceCredibility: await checkSourceCredibility(url),
    
    // Check content freshness
    contentFreshness: await assessContentAge(content),
    
    // Technical accuracy
    technicalAccuracy: await verifyTechnicalContent(content)
  };
}
```

2. **Link Health Monitoring**:
```typescript
interface LinkHealth {
  status: 'active' | 'broken' | 'redirected';
  lastChecked: Date;
  responseTime: number;
  contentHash: string;  // For change detection
  qualityMetrics: {
    accessibility: number;
    loadTime: number;
    contentStability: number;
  };
}
```

This hybrid approach combines the efficiency of traditional web crawling with AI-enhanced search and ranking, providing:
- More relevant results through AI-powered query enhancement
- Better content quality assessment
- Intelligent ranking based on multiple factors
- Efficient caching and performance optimization
- Robust quality control and verification 

### Implementation Sequence

#### Phase 1: Basic AI Info Card Generation
**Goal**: Get basic AI-generated info cards working without web links
```typescript
// 1. Add UI Elements (Day 1-2)
- Add "Generate with AI" button to existing info card dialog
- Create loading state and error handling UI
- Add regenerate button for individual fields

// 2. Basic GPT Integration (Day 2-3)
- Set up OpenAI API connection
- Implement basic prompt for title/description generation
- Add simple context extraction from video timestamp

// 3. Testing & Refinement (Day 3-4)
- Test with various video types
- Refine prompts based on results
- Add basic error handling
```

#### Phase 2: Simple Link Enhancement
**Goal**: Add basic link suggestions using search APIs before full crawler
```typescript
// 1. Basic Search Integration (Day 5-6)
- Integrate Google Custom Search API
- Add basic link filtering
- Implement simple relevance scoring

// 2. Link Preview & Management (Day 6-7)
- Add link preview functionality
- Implement link validation
- Create link management UI

// 3. Testing & UX Refinement (Day 7-8)
- Test link suggestion quality
- Optimize UI for link management
- Add basic caching
```

#### Phase 3: Advanced AI Enhancement
**Goal**: Improve AI generation quality and add embeddings
```typescript
// 1. Context Enhancement (Day 9-10)
- Implement better video context extraction
- Add embedding-based similarity scoring
- Improve prompt engineering

// 2. Quality Improvements (Day 10-11)
- Add content quality scoring
- Implement better error handling
- Add regeneration options
```

#### Phase 4: Smart Web Crawler
**Goal**: Replace basic search with custom crawler
```typescript
// 1. Basic Crawler (Day 12-13)
- Implement basic web crawler
- Add domain filtering
- Set up rate limiting

// 2. AI Enhancement (Day 13-14)
- Add AI query enhancement
- Implement content relevance scoring
- Add domain authority checking

// 3. Performance Optimization (Day 14-15)
- Implement caching system
- Add batch processing
- Optimize crawler performance
```

### Testing Strategy

#### Phase 1 Testing
```typescript
// 1. Unit Tests
- Test AI generation endpoints
- Verify prompt construction
- Test error handling

// 2. Integration Tests
- Test UI flow
- Verify API integration
- Test state management

// 3. User Testing
- Test with sample videos
- Gather feedback on generation quality
- Verify editing capabilities
```

#### Phase 2 Testing
```typescript
// 1. Link Quality Tests
- Verify link relevance
- Test link validation
- Check preview generation

// 2. Performance Tests
- Test caching effectiveness
- Verify response times
- Check error handling
```

### Dependencies & Prerequisites

1. **Phase 1 Prerequisites**:
   - OpenAI API key
   - Existing info card UI
   - Basic error handling

2. **Phase 2 Prerequisites**:
   - Google Custom Search API key
   - Link preview component
   - Basic caching system

3. **Phase 3 Prerequisites**:
   - OpenAI embeddings API
   - Enhanced error handling
   - Improved UI components

4. **Phase 4 Prerequisites**:
   - Web crawler infrastructure
   - Domain authority database
   - Rate limiting system

### Success Metrics per Phase

1. **Phase 1**:
   - 80% useful AI generations
   - < 2s generation time
   - < 5% error rate

2. **Phase 2**:
   - 70% relevant link suggestions
   - < 1s link preview load
   - 100% valid links

3. **Phase 3**:
   - 90% useful AI generations
   - 85% relevant suggestions
   - < 3s total processing time

4. **Phase 4**:
   - 95% relevant link suggestions
   - < 5s crawl time per query
   - 99.9% uptime 

### AI Info Card Generation

#### Overview
Automated info card generation system that uses AI to analyze video content and create relevant, engaging info cards. The system combines speech-to-text, content analysis, and smart formatting to generate comprehensive info cards.

#### Implementation Flow

1. **Content Analysis Pipeline**:
   ```typescript
   interface ContentAnalysis {
     // Speech to Text
     transcription: {
       text: string;
       confidence: number;
       timestamps: Array<{
         word: string;
         start: number;
         end: number;
       }>;
     };
     
     // Content Understanding
     analysis: {
       mainTopic: string;
       keyPoints: string[];
       suggestedTitle: string;
       relevantConcepts: string[];
       technicalTerms: string[];
     };
     
     // Info Card Generation
     infoCard: {
       title: string;
       description: string;
       bulletPoints: string[];
       suggestedLinks: Array<{
         url: string;
         text: string;
         relevance: number;
       }>;
     };
   }
   ```

2. **API Integration Points**:
   ```typescript
   class AIInfoCardService {
     // Speech to Text Processing
     async function processAudio(videoUrl: string, timestamp: number): Promise<string> {
       // 1. Extract audio segment around timestamp
       const audioSegment = await extractAudioSegment(videoUrl, timestamp);
       
       // 2. Convert to text using Whisper
       const transcription = await openai.audio.transcriptions.create({
         file: audioSegment,
         model: "whisper-1",
         language: "en",
         timestamp_granularities: ["word", "segment"]
       });
       
       return transcription.text;
     }
     
     // Content Analysis
     async function analyzeContent(transcription: string): Promise<ContentAnalysis> {
       const completion = await openai.chat.completions.create({
         model: "gpt-4",
         messages: [
           {
             role: "system",
             content: "Analyze video content and generate an engaging info card."
           },
           {
             role: "user",
             content: `Generate an info card from this transcription: ${transcription}`
           }
         ],
         response_format: { type: "json_object" }
       });
       
       return JSON.parse(completion.choices[0].message.content);
     }
   }
   ```

3. **User Interface Flow**:
   ```typescript
   interface AIGenerationUI {
     states: {
       INITIAL: 'ready',
       PROCESSING_AUDIO: 'processing_audio',
       ANALYZING_CONTENT: 'analyzing_content',
       GENERATING_CARD: 'generating_card',
       COMPLETE: 'complete',
       ERROR: 'error'
     };
     
     userControls: {
       generateButton: {
         text: string;
         isEnabled: boolean;
       };
       progressIndicator: {
         progress: number;
         stage: string;
       };
       editControls: {
         isVisible: boolean;
         fields: string[];
       };
     };
   }
   ```

#### Processing Steps

1. **Audio Processing**:
   - Extract audio segment (±30 seconds around timestamp)
   - Convert to required format (mp3/wav)
   - Process through Whisper API
   - Handle multiple languages

2. **Content Analysis**:
   - Identify main topic and key points
   - Extract technical terms and concepts
   - Generate concise description
   - Create bullet points
   - Suggest relevant links

3. **Quality Assurance**:
   - Verify transcription quality
   - Check content relevance
   - Validate generated card format
   - Ensure link validity

#### Error Handling

1. **Audio Processing Errors**:
   ```typescript
   interface AudioProcessingError {
     type: 'EXTRACTION' | 'CONVERSION' | 'API' | 'QUALITY';
     message: string;
     retryable: boolean;
     suggestedAction?: string;
   }
   ```

2. **Content Analysis Errors**:
   ```typescript
   interface ContentAnalysisError {
     type: 'INSUFFICIENT_CONTENT' | 'LOW_CONFIDENCE' | 'API_ERROR';
     message: string;
     fallbackOption?: 'manual_entry' | 'partial_generation';
   }
   ```

#### Performance Optimization

1. **Caching Strategy**:
   ```typescript
   interface CacheConfig {
     transcriptions: {
       ttl: number;  // Time to live in seconds
       maxSize: number;  // Max cache size in MB
     };
     analyses: {
       ttl: number;
       maxSize: number;
     };
   }
   ```

2. **Resource Management**:
   - Implement request queuing
   - Batch similar requests
   - Cache common responses
   - Optimize audio segments

#### Cost Estimates

1. **API Usage**:
   - Whisper API: ~$0.006 per minute
   - GPT-4: ~$0.03 per generation
   - Total per card: ~$0.04-0.06

2. **Optimization Potential**:
   - Caching: 30-40% cost reduction
   - Batching: 20-30% cost reduction
   - Smart segmentation: 15-25% cost reduction

#### Implementation Phases

1. **Phase 1: Basic Integration**
   - Implement Whisper integration
   - Basic GPT-4 content analysis
   - Simple UI for generation

2. **Phase 2: Enhanced Analysis**
   - Add advanced content analysis
   - Implement link suggestions
   - Improve error handling

3. **Phase 3: Optimization**
   - Add caching system
   - Implement batching
   - Optimize resource usage

4. **Phase 4: Advanced Features**
   - Multi-language support
   - Custom templates
   - Learning from user edits

#### Success Metrics

1. **Quality Metrics**:
   - Transcription accuracy > 95%
   - Content relevance score > 90%
   - User edit rate < 20%

2. **Performance Metrics**:
   - Generation time < 5 seconds
   - Error rate < 5%
   - Cache hit rate > 40%

3. **User Metrics**:
   - Usage rate > 50%
   - User satisfaction > 4.5/5
   - Edit time reduction > 70% 

## Current Implementation Status

### ✅ Completed Features
1. **AI-Generated Info Cards**
   - Automatic transcription of video content
   - GPT-based title and description generation
   - Real-time progress updates during generation
   - Error handling and retry mechanisms
   - Support for regenerating content
   - Character limits enforcement (100 for title, 500 for description)

2. **User Experience**
   - Seamless integration with video editor
   - Loading indicators and progress feedback
   - Error messages and status updates
   - Edit/Delete functionality for AI-generated content
   - Option to regenerate while keeping existing content

### 🚧 In Progress
1. **Smart Link Enhancement**
   - Web crawling implementation
   - Link relevance scoring
   - Domain authority verification
   - Link preview generation

### 🎯 Next Features to Implement

1. **Enhanced Content Analysis**
   - Sentiment analysis of video content
   - Key topics extraction
   - Automatic chapter suggestions
   - Content categorization
   - Timestamp-based insights

2. **Smart Editing Suggestions**
   - AI-powered trim points detection
   - Highlight reel generation
   - Dead space detection
   - Engagement optimization suggestions
   - Automatic B-roll suggestions

3. **Accessibility Features**
   - Automatic caption generation
   - Multi-language support
   - Reading level analysis
   - Alt text generation for visuals
   - Audio description suggestions

4. **Educational Enhancement**
   - Learning objectives detection
   - Quiz generation from content
   - Related resources suggestions
   - Study guide generation
   - Key concepts extraction

5. **Engagement Optimization**
   - Viewer retention analysis
   - Engagement point prediction
   - Call-to-action placement suggestions
   - Thumbnail optimization
   - Title A/B testing suggestions

6. **Content Safety & Quality**
   - Content moderation
   - Quality scoring
   - Brand safety analysis
   - Age-appropriate content detection
   - Trigger warning suggestions

## Technical Implementation

[Previous technical implementation details remain unchanged...]

## Cost & Performance Optimization

[Previous optimization details remain unchanged...]

## Future Roadmap

### Phase 1: Enhanced Content Understanding
1. **Smart Chapter Detection**
   ```typescript
   interface ChapterDetection {
     timestamp: number;
     confidence: number;
     title: string;
     topics: string[];
     keyPoints: string[];
   }
   ```

2. **Content Insights Engine**
   ```typescript
   interface ContentInsights {
     topics: TopicBreakdown[];
     engagementPredictions: EngagementMetrics;
     suggestedImprovements: Suggestion[];
     audienceMatch: AudienceProfile;
   }
   ```

### Phase 2: Interactive Learning Features
1. **Quiz Generation**
   ```typescript
   interface QuizGeneration {
     questions: Question[];
     difficulty: 'basic' | 'intermediate' | 'advanced';
     learningObjectives: string[];
     assessmentType: 'multiple_choice' | 'open_ended' | 'true_false';
   }
   ```

2. **Study Materials**
   ```typescript
   interface StudyMaterials {
     summary: string;
     keyTerms: Term[];
     practiceExercises: Exercise[];
     supplementaryResources: Resource[];
   }
   ```

### Phase 3: Engagement Optimization
1. **Viewer Retention Analysis**
   ```typescript
   interface RetentionAnalysis {
     dropoffPoints: Timestamp[];
     engagementScores: number[];
     improvementSuggestions: string[];
     comparativeMetrics: BenchmarkData;
   }
   ```

2. **Content Enhancement**
   ```typescript
   interface ContentEnhancement {
     suggestedEdits: Edit[];
     visualImprovements: VisualSuggestion[];
     paceAnalysis: PaceMetrics;
     structureOptimization: StructureSuggestion[];
   }
   ```

## Success Metrics

### Current Metrics (Info Cards)
- Generation Success Rate: 95%
- Average Generation Time: < 5s
- User Edit Rate: < 30%
- Error Rate: < 5%

### Target Metrics (New Features)
1. **Content Analysis**
   - Topic Detection Accuracy: > 90%
   - Chapter Suggestion Accuracy: > 85%
   - Processing Time: < 10s

2. **Learning Features**
   - Quiz Quality Rating: > 4.5/5
   - Learning Objective Match: > 90%
   - Resource Relevance: > 85%

3. **Engagement Features**
   - Retention Improvement: > 20%
   - Engagement Score Accuracy: > 80%
   - Suggestion Implementation Rate: > 40%

## Implementation Timeline

### Q2 2024
- Enhanced Content Analysis
- Smart Chapter Detection
- Basic Quiz Generation

### Q3 2024
- Full Learning Feature Suite
- Engagement Analytics
- Content Safety Tools

### Q4 2024
- Multi-language Support
- Advanced Optimization Tools
- Integration with LMS Platforms 