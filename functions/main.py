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
import re

# Load environment variables
load_dotenv()

# Initialize Firebase Admin and OpenAI
initialize_app()
openai.api_key = os.getenv('OPENAI_API_KEY')

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
                        "segments": transcript_data.get('segments', []),
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

        # Save transcript to Firestore
        transcript_ref.set({
            'content': full_text,
            'segments': segments,
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
                    "segments": segments,
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