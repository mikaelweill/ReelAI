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
import gc
import psutil

# Load environment variables
load_dotenv()

# Initialize Firebase Admin and OpenAI
initialize_app()
openai.api_key = os.getenv('OPENAI_API_KEY')

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

        # Get audio file from storage
        bucket = storage.bucket()
        audio_path = f'audio/{video_id}.mp3'
        audio_blob = bucket.blob(audio_path)
        
        if not audio_blob.exists():
            return https_fn.Response(
                response=json.dumps({"error": f"Audio file not found: {audio_path}"}),
                status=404
            )

        # Download audio to temp file
        audio_file_path = os.path.join(temp_dir, f'{video_id}.mp3')
        audio_blob.download_to_filename(audio_file_path)
        
        # Use old OpenAI syntax for version 0.28.1
        with open(audio_file_path, 'rb') as audio_file:
            transcript = openai.Audio.transcribe(
                model="whisper-1",
                file=audio_file,
                response_format="text"
            )

        # Save transcript to Firestore
        db = firestore.client()
        transcript_ref = db.collection('transcripts').document(video_id)
        transcript_ref.set({
            'content': transcript,
            'videoId': video_id,
            'createdAt': firestore.SERVER_TIMESTAMP
        })

        return https_fn.Response(
            response=json.dumps({
                "success": True,
                "transcript": {
                    "content": transcript,
                    "videoId": video_id
                }
            })
        )

    except Exception as e:
        print(f"Error in create_transcript: {str(e)}")
        return https_fn.Response(
            response=json.dumps({"error": str(e)}),
            status=500
        )
    finally:
        # Clean up
        if temp_dir and os.path.exists(temp_dir):
            shutil.rmtree(temp_dir, ignore_errors=True)

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

def log_memory(stage: str):
    """Log current memory usage with a label."""
    gc.collect()  # Force garbage collection
    mem = get_process_memory()
    print(f"MEMORY[{stage}]:")
    print(f"  RSS: {mem['rss']:.2f}MB")
    print(f"  VMS: {mem['vms']:.2f}MB")
    print(f"  Shared: {mem['shared']:.2f}MB")
    print(f"  Data: {mem['data']:.2f}MB") 