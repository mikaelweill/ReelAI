# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

import json
import ffmpeg
from firebase_admin import initialize_app, storage, firestore
from firebase_functions import https_fn
import urllib.parse
import os
import tempfile
import shutil
import subprocess
from datetime import timedelta
import openai
from dotenv import load_dotenv
import pkg_resources
import psutil
import gc
import re

# Load environment variables
load_dotenv()

# Initialize Firebase Admin and OpenAI
initialize_app()

def parse_vtt(vtt_content):
    """Parse VTT content into segments with timestamps."""
    segments = []
    lines = vtt_content.strip().split('\n')
    current_segment = None
    
    for line in lines:
        # Skip WebVTT header and empty lines
        if line == 'WEBVTT' or not line.strip():
            continue
            
        # Check for timestamp line (e.g., "00:00:00.000 --> 00:00:05.000")
        timestamp_match = re.match(r'(\d{2}:\d{2}:\d{2}\.\d{3}) --> (\d{2}:\d{2}:\d{2}\.\d{3})', line)
        if timestamp_match:
            if current_segment:
                segments.append(current_segment)
            current_segment = {
                'start': timestamp_match.group(1),
                'end': timestamp_match.group(2),
                'text': ''
            }
        # If we have a current segment and this isn't a timestamp line, it's text
        elif current_segment is not None:
            if current_segment['text']:
                current_segment['text'] += ' ' + line
            else:
                current_segment['text'] = line

    # Add the last segment if exists
    if current_segment:
        segments.append(current_segment)
    
    return segments

# Add version check and initialization
try:
    print("Starting OpenAI initialization and version checks...")
    
    import pkg_resources
    openai_version = pkg_resources.get_distribution('openai').version
    print(f"Detected OpenAI version: {openai_version}")
    
    if not openai_version.startswith('0.28'):
        print(f"Version mismatch: Found {openai_version}, need 0.28.x")
        raise ImportError(f"OpenAI version {openai_version} is not compatible. Required version: 0.28.x")
    print("✓ Version check passed")
    
    # Set API key if available
    openai.api_key = os.getenv('OPENAI_API_KEY')
    if not openai.api_key:
        print("⚠️ OpenAI API key not found in environment - will need to be set before using OpenAI functions")
    else:
        print("✓ API key configured")
    
    print("OpenAI initialization completed successfully")
        
except Exception as e:
    print(f"Critical initialization error: {str(e)}")
    print(f"Error type: {type(e)}")
    print("Available OpenAI attributes:", dir(openai))
    raise

def process_audio_segment(input_path, output_path, start_time, duration):
    """Process a segment of the video to audio."""
    try:
        print(f"Processing segment: input={input_path}, output={output_path}, start={start_time}, duration={duration}")
        print(f"Checking input file exists: {os.path.exists(input_path)}")
        print(f"Input file size: {os.path.getsize(input_path) if os.path.exists(input_path) else 'file not found'}")
        
        stream = ffmpeg.input(input_path, ss=start_time, t=duration)
        stream = ffmpeg.output(
            stream,
            output_path,
            acodec='libmp3lame',
            ac=1,  # Mono audio to reduce memory usage
            ar='22050',  # Lower sample rate
            audio_bitrate='64k',  # Lower bitrate
            **{
                'threads': 1,
                'loglevel': 'info',
                'f': 'mp3'
            }
        )
        
        # Get the ffmpeg command for logging
        cmd = ffmpeg.compile(stream)
        print(f"FFmpeg command: {' '.join(cmd)}")
        
        # Run with stderr capture
        out, err = ffmpeg.run(stream, capture_stdout=True, capture_stderr=True)
        print(f"FFmpeg stderr output: {err.decode() if err else 'None'}")
        
        # Verify output
        if os.path.exists(output_path):
            print(f"Output file created successfully. Size: {os.path.getsize(output_path)}")
            return True
        else:
            print("Output file was not created")
            return False
            
    except ffmpeg.Error as e:
        print(f"FFmpeg error: {str(e)}")
        print(f"FFmpeg stderr: {e.stderr.decode() if e.stderr else 'None'}")
        return False
    except Exception as e:
        print(f"General error in process_audio_segment: {str(e)}")
        print(f"Error type: {type(e)}")
        return False

def get_video_duration(video_path):
    """Get the duration of a video file."""
    try:
        probe = ffmpeg.probe(video_path)
        duration = float(probe['streams'][0]['duration'])
        return duration
    except Exception as e:
        print(f"Error getting video duration: {str(e)}")
        return None

def stream_blob_to_file(blob, destination_path, chunk_size=2*1024*1024):  # 2MB chunks
    """Stream a blob to a file in chunks to minimize memory usage."""
    with open(destination_path, 'wb') as f:
        blob.download_to_file(f)

def stream_file_to_blob(source_path, blob, chunk_size=2*1024*1024):  # 2MB chunks
    """Stream a file to a blob in chunks to minimize memory usage."""
    with open(source_path, 'rb') as f:
        blob.upload_from_file(f)

def get_process_memory():
    """Get current process memory usage in MB."""
    process = psutil.Process(os.getpid())
    mem = process.memory_info()
    return {
        'rss': mem.rss / 1024 / 1024,  # Resident Set Size
        'vms': mem.vms / 1024 / 1024,  # Virtual Memory Size
        'shared': getattr(mem, 'shared', 0) / 1024 / 1024,  # Shared memory
        'data': getattr(mem, 'data', 0) / 1024 / 1024  # Data segment memory
    }

def log_memory(label):
    """Log current memory usage with a label."""
    gc.collect()  # Force garbage collection
    mem = get_process_memory()
    print(f"MEMORY[{label}]:")
    print(f"  RSS: {mem['rss']:.2f}MB")
    print(f"  VMS: {mem['vms']:.2f}MB")
    print(f"  Shared: {mem['shared']:.2f}MB")
    print(f"  Data: {mem['data']:.2f}MB")
    
    # Log Python's memory allocator stats
    import sys
    print(f"  Python malloc stats:")
    for key, value in sys.getallocators()[0].get_stats().items():
        print(f"    {key}: {value}")

@https_fn.on_request()
def convert_to_audio(request: https_fn.Request) -> https_fn.Response:
    """Convert MP4 video to MP3 audio."""
    temp_dir = None
    try:
        # Create a temporary directory for our files
        temp_dir = tempfile.mkdtemp(prefix='video_conversion_')
        
        # Get video_id from request
        data = request.get_json()
        video_id = data.get('video_id')
        if not video_id:
            return https_fn.Response(
                response=json.dumps({"error": "No video_id provided"}),
                status=400
            )

        # Check if audio file already exists
        bucket = storage.bucket()
        audio_path = f'audio/{video_id}.mp3'
        audio_blob = bucket.blob(audio_path)
        
        if audio_blob.exists():
            print(f"Audio file already exists at {audio_path}, skipping conversion")
            return https_fn.Response(
                response=json.dumps({
                    "success": True,
                    "audio_path": audio_path,
                    "audio_size": audio_blob.size,
                    "skipped_conversion": True
                })
            )

        # Get video document from Firestore
        db = firestore.client()
        video_doc = db.collection('videos').document(video_id).get()
        
        if not video_doc.exists:
            return https_fn.Response(
                response=json.dumps({"error": f"Video document {video_id} not found"}),
                status=404
            )
            
        video_data = video_doc.to_dict()
        video_url = video_data.get('videoUrl')
        
        if not video_url:
            return https_fn.Response(
                response=json.dumps({"error": f"Video URL not found in document {video_id}"}),
                status=404
            )

        # Extract storage path from URL
        storage_path = video_url.split('/o/')[1].split('?')[0]
        storage_path = urllib.parse.unquote(storage_path)

        # Get video from storage
        bucket = storage.bucket()
        video_blob = bucket.blob(storage_path)
        audio_blob = bucket.blob(f'audio/{video_id}.mp3')  # Simple path with just video ID

        # Download video to temp file using streaming
        video_path = os.path.join(temp_dir, f'{video_id}.mp4')
        stream_blob_to_file(video_blob, video_path)

        try:
            # Get video duration
            duration = get_video_duration(video_path)
            if not duration:
                raise Exception("Could not determine video duration")

            # Process video in shorter segments to reduce memory usage
            segment_duration = 15  # Reduced from 30 to 15 seconds
            segments = []
            
            # Create segments directory
            segments_dir = os.path.join(temp_dir, 'segments')
            os.makedirs(segments_dir)
            
            # Process each segment
            for start_time in range(0, int(duration), segment_duration):
                segment_path = os.path.join(segments_dir, f'segment_{start_time}.mp3')
                if process_audio_segment(video_path, segment_path, start_time, segment_duration):
                    segments.append(segment_path)
                else:
                    raise Exception(f"Failed to process segment at {start_time} seconds")

            # Concatenate segments
            audio_path = os.path.join(temp_dir, f'{video_id}.mp3')
            with open(os.path.join(temp_dir, 'segments.txt'), 'w') as f:
                for segment in segments:
                    f.write(f"file '{segment}'\n")

            # Use FFmpeg to concatenate with minimal memory usage
            concat_cmd = [
                'ffmpeg', '-f', 'concat', '-safe', '0',
                '-i', os.path.join(temp_dir, 'segments.txt'),
                '-c', 'copy', 
                '-y',  # Overwrite output file
                audio_path
            ]
            subprocess.run(concat_cmd, check=True)

            # Verify the audio file exists and is valid
            if not os.path.exists(audio_path):
                raise Exception("Final audio file was not created")
                
            # Check file size
            audio_size = os.path.getsize(audio_path)
            print(f"Audio file size: {audio_size} bytes")
            
            if audio_size == 0:
                raise Exception("Audio file is empty")
            
            # Set proper content type for the audio blob
            audio_blob.content_type = 'audio/mpeg'
            
            # Upload audio file using streaming
            print(f"Starting upload of audio file to {audio_blob.name}")
            stream_file_to_blob(audio_path, audio_blob)
            print(f"Successfully uploaded audio file to {audio_blob.name}")

            # Verify the upload
            if not audio_blob.exists():
                raise Exception("Audio file failed to upload to storage")

            # Instead of signed URL, return the storage path
            audio_path = f"audio/{video_id}.mp3"
            
            return https_fn.Response(
                response=json.dumps({
                    "success": True,
                    "audio_path": audio_path,
                    "audio_size": audio_size
                })
            )
        except ffmpeg.Error as e:
            print(f"FFmpeg error output: {e.stderr.decode() if e.stderr else str(e)}")
            raise Exception(f"FFmpeg conversion failed: {str(e)}")
        except Exception as e:
            print(f"Error during audio processing: {str(e)}")
            raise
    except Exception as e:
        return https_fn.Response(
            response=json.dumps({"error": str(e)}),
            status=500
        )
    finally:
        # Clean up temporary directory and all its contents
        if temp_dir and os.path.exists(temp_dir):
            shutil.rmtree(temp_dir, ignore_errors=True)

@https_fn.on_request()
def test(request: https_fn.Request) -> https_fn.Response:
    """Simple test function that returns a JSON response."""
    return https_fn.Response(
        response=json.dumps({
            "message": "Hello from Firebase Functions!",
            "success": True
        }),
        headers={"Content-Type": "application/json"}
    )

@https_fn.on_request()
def create_transcript(request: https_fn.Request) -> https_fn.Response:
    """Create transcript from MP3 using OpenAI Whisper."""
    temp_dir = None
    try:
        # Create temporary directory
        temp_dir = tempfile.mkdtemp(prefix='transcription_')
        
        # Get video_id from request
        data = request.get_json()
        video_id = data.get('video_id')
        if not video_id:
            return https_fn.Response(
                response=json.dumps({"error": "No video_id provided"}),
                status=400
            )

        # Check if transcript already exists in Firestore
        db = firestore.client()
        transcript_ref = db.collection('transcripts').document(video_id)
        transcript_doc = transcript_ref.get()
        
        if transcript_doc.exists:
            print(f"Transcript already exists for video {video_id}")
            transcript_data = transcript_doc.to_dict()
            return https_fn.Response(
                response=json.dumps({
                    "success": True,
                    "transcript": {
                        "content": transcript_data.get('content'),
                        "videoId": video_id,
                        "audioFileSize": transcript_data.get('audioFileSize'),
                        "transcriptLength": transcript_data.get('transcriptLength')
                    },
                    "skipped_transcription": True
                })
            )

        # Get audio file from storage
        bucket = storage.bucket()
        audio_path = f'audio/{video_id}.mp3'
        audio_blob = bucket.blob(audio_path)
        
        if not audio_blob.exists():
            return https_fn.Response(
                response=json.dumps({"error": f"Audio file not found: {audio_path}"}),
                status=404
            )

        # Reload blob to get latest metadata
        audio_blob.reload()
        
        # Get file size before downloading
        file_size = audio_blob.size
        print(f"Audio file size: {file_size} bytes ({file_size/1024/1024:.2f}MB)")
        
        # Download audio to temp file using streaming
        audio_file_path = os.path.join(temp_dir, f'{video_id}.mp3')
        
        # Stream download in chunks
        chunk_size = 1024 * 1024  # 1MB chunks
        with open(audio_file_path, 'wb') as f:
            audio_blob.download_to_file(f)
            f.flush()
            os.fsync(f.fileno())  # Ensure all data is written to disk
        
        # Verify downloaded file size
        downloaded_size = os.path.getsize(audio_file_path)
        print(f"Downloaded file size: {downloaded_size} bytes ({downloaded_size/1024/1024:.2f}MB)")
        
        if downloaded_size != file_size:
            raise Exception(f"File size mismatch. Expected: {file_size}, Got: {downloaded_size}")
        
        print("Starting OpenAI transcription...")
        
        # Open and send to Whisper API directly
        with open(audio_file_path, 'rb') as audio_file:
            response = openai.Audio.transcribe(
                model="whisper-1",
                file=audio_file,
                response_format="vtt",
                timestamp_granularities=["word", "segment"]
            )
        print("OpenAI transcription completed")
        
        # Parse VTT content to get segments with timestamps
        segments = parse_vtt(response)
        
        # Extract full text content from segments
        full_text = ' '.join(segment['text'] for segment in segments)
        
        # Get transcript length for logging
        transcript_length = len(full_text) if full_text else 0
        print(f"Transcript length: {transcript_length} characters")
        print(f"Number of segments: {len(segments)}")
        print(f"First few segments: {segments[:2]}")  # Log first few segments for debugging

        # Save transcript to Firestore
        transcript_ref.set({
            'content': full_text,
            'segments': segments,  # Make sure segments are included
            'videoId': video_id,
            'createdAt': firestore.SERVER_TIMESTAMP,
            'audioFileSize': file_size,
            'transcriptLength': transcript_length
        })

        return https_fn.Response(
            response=json.dumps({
                "success": True,
                "transcript": {
                    "content": full_text,
                    "segments": segments,  # Include segments in response
                    "videoId": video_id,
                    "audioFileSize": file_size,
                    "transcriptLength": transcript_length
                }
            })
        )

    except Exception as e:
        print(f"Error in create_transcript: {str(e)}")
        print(f"Error type: {type(e)}")
        return https_fn.Response(
            response=json.dumps({"error": str(e)}),
            status=500
        )
    finally:
        # Clean up
        if temp_dir and os.path.exists(temp_dir):
            shutil.rmtree(temp_dir, ignore_errors=True)

@https_fn.on_request()
def generate_info_card(request: https_fn.Request) -> https_fn.Response:
    """Generate title and description for an info card based on a transcript."""
    try:
        # Get transcript from request
        data = request.get_json()
        transcript = data.get('transcript')
        
        if not transcript:
            return https_fn.Response(
                response=json.dumps({"error": "No transcript provided"}),
                status=400
            )

        print("Starting OpenAI title and description generation...")

        # Create the prompt for GPT-3.5
        prompt = f"""Based on the following transcript, generate a title and description for a video info card.
        Keep the title under 100 characters and the description under 500 characters.
        Format the response as JSON with 'title' and 'description' fields.
        
        Transcript:
        {transcript}"""

        # Call OpenAI API
        response = openai.ChatCompletion.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "You are a helpful assistant that generates concise and engaging video titles and descriptions."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.7,
            max_tokens=300
        )
        print("OpenAI generation completed")

        # Parse the response
        try:
            content = response.choices[0].message.content
            info_card = json.loads(content)
            
            # Validate the response format
            if not isinstance(info_card, dict) or 'title' not in info_card or 'description' not in info_card:
                raise ValueError("Invalid response format")
                
            return https_fn.Response(
                response=json.dumps({
                    "success": True,
                    "title": info_card['title'],
                    "description": info_card['description']
                }),
                status=200
            )
            
        except (json.JSONDecodeError, ValueError) as e:
            # If JSON parsing fails, try to extract title and description using string manipulation
            content = response.choices[0].message.content
            try:
                # Attempt to parse the content as a string
                lines = content.split('\n')
                title = next(line.split(': ', 1)[1].strip(' "\'') for line in lines if 'title' in line.lower())
                description = next(line.split(': ', 1)[1].strip(' "\'') for line in lines if 'description' in line.lower())
                
                return https_fn.Response(
                    response=json.dumps({
                        "success": True,
                        "title": title,
                        "description": description
                    }),
                    status=200
                )
            except Exception as inner_e:
                return https_fn.Response(
                    response=json.dumps({
                        "error": f"Failed to parse OpenAI response: {str(inner_e)}",
                        "raw_response": content
                    }),
                    status=500
                )
                
    except Exception as e:
        print(f"Error in generate_info_card: {str(e)}")
        print(f"Error type: {type(e)}")
        return https_fn.Response(
            response=json.dumps({
                "error": f"Error generating info card: {str(e)}"
            }),
            status=500
        )

if __name__ == "__main__":
    from functions_framework import create_app
    target_function = os.environ.get("FUNCTION_TARGET", "convert_to_audio")
    app = create_app(target=target_function)
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)