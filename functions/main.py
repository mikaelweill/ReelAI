# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

import os
import io
import logging
import requests
import json
from datetime import datetime, timedelta
from typing import Optional
from pydantic import BaseModel
from openai import OpenAI
from firebase_admin import initialize_app, firestore, storage
from firebase_functions import https_fn
import urllib.parse

# Initialize Firebase Admin
initialize_app()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Get OpenAI API key from environment variable
openai_api_key = os.environ.get('OPENAI_API_KEY')
if not openai_api_key:
    logger.warning("OpenAI API key not found in environment variables")

class Transcript(BaseModel):
    """Transcript model for video transcriptions."""
    video_id: str
    content: str
    status: str = "completed"  # completed, failed
    error: Optional[str] = None

    class Config:
        """Pydantic config."""
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

def get_video_stream(video_id: str) -> tuple[io.BufferedReader, str]:
    """Get a direct read stream for a video from Firebase Storage.
    
    Args:
        video_id: The ID of the video document in Firestore
        
    Returns:
        tuple: (file stream, content type)
        
    Raises:
        Exception: If video is not found
    """
    logger.info(f"Getting video stream for ID: {video_id}")
    db = firestore.client()
    video_doc = db.collection('videos').document(video_id).get()
    
    if not video_doc.exists:
        raise Exception(f'Video document {video_id} not found in Firestore')
        
    video_data = video_doc.to_dict()
    video_url = video_data.get('videoUrl')
    if not video_url:
        raise Exception(f'Video URL not found in document {video_id}')
    
    # Extract storage path from URL
    # URL format: https://firebasestorage.googleapis.com/v0/b/BUCKET/o/videos%2FUID%2FFILENAME?alt=...
    storage_path = video_url.split('/o/')[1].split('?')[0]
    storage_path = urllib.parse.unquote(storage_path)
    logger.info(f"Extracted storage path: {storage_path}")
    
    # Get direct read stream using Admin SDK
    bucket = storage.bucket()
    blob = bucket.blob(storage_path)
    
    if not blob.exists():
        raise Exception(f'Video blob not found at path: {storage_path}')
    
    # Create a temporary file-like object in memory
    stream = io.BytesIO()
    blob.download_to_file(stream)
    stream.seek(0)  # Reset to start of stream
    
    return stream, blob.content_type

def create_transcript_for_video(video_id: str) -> Transcript:
    """Create a transcript for a video using Whisper API.
    
    Args:
        video_id: The ID of the video to transcribe
        
    Returns:
        Transcript: The created transcript
        
    Raises:
        Exception: If transcription fails
    """
    # Check if transcript already exists
    logger.info(f"Checking for existing transcript for video: {video_id}")
    db = firestore.client()
    transcript_ref = db.collection('transcripts').document(video_id)
    transcript_doc = transcript_ref.get()
    
    if transcript_doc.exists:
        logger.info(f"Found existing transcript for video: {video_id}")
        return Transcript(**transcript_doc.to_dict())
    
    try:
        # Get video stream directly from Firebase Storage
        logger.info(f"Getting video stream from storage: {video_id}")
        video_stream, content_type = get_video_stream(video_id)
        
        # Initialize OpenAI client with API key from config
        logger.info("Initializing OpenAI client")
        client = OpenAI(api_key=openai_api_key)
        
        # Transcribe with Whisper using the direct stream
        logger.info("Starting Whisper transcription")
        transcription = client.audio.transcriptions.create(
            file=('video.mp4', video_stream),
            model="whisper-1",
            response_format="text"
        )
        logger.info("Transcription completed successfully")
        
        # Create transcript
        transcript = Transcript(
            video_id=video_id,
            content=transcription,
            status="completed"
        )
        
        # Save to Firestore ONLY on success
        logger.info("Saving successful transcript to Firestore")
        transcript_ref.set({
            'video_id': video_id,
            'content': transcription,
            'status': 'completed'
        })
        
        return transcript
            
    except Exception as e:
        logger.error(f"Failed to create transcript for video {video_id}", exc_info=True)
        # Return failed transcript but DON'T save it
        return Transcript(
            video_id=video_id,
            content="",
            status="failed",
            error=str(e)
        )

@https_fn.on_request()
def create_transcript(request: https_fn.Request) -> https_fn.Response:
    """HTTP Cloud Function to create a transcript.
    Args:
        request: The request object with video_id in the body
    Returns:
        JSON response with transcript data or error
    """
    logger.info("Received transcript creation request")
    
    # Check if request is POST
    if request.method != 'POST':
        logger.warning(f"Invalid method: {request.method}")
        return https_fn.Response(
            json={'error': 'Only POST requests are accepted'}, 
            status=405
        )
    
    try:
        request_json = request.get_json()
        if not request_json or 'video_id' not in request_json:
            return https_fn.Response(
                response=json.dumps({
                    "error": "Missing video_id in request",
                    "success": False
                }),
                status=400,
                headers={"Content-Type": "application/json"}
            )
            
        video_id = request_json['video_id']
        logger.info(f"Processing video ID: {video_id}")
        
        # Create transcript
        logger.info(f"Starting transcription for video: {video_id}")
        transcript = create_transcript_for_video(video_id)
        logger.info(f"Transcription completed for video: {video_id}")
        
        # Return response
        return https_fn.Response(
            response=json.dumps({
                'success': True,
                'transcript': transcript.model_dump(),
            }),
            headers={"Content-Type": "application/json"}
        )
        
    except Exception as e:
        logger.error(f"Error in create_transcript: {str(e)}")
        return https_fn.Response(
            response=json.dumps({
                "error": str(e),
                "success": False
            }),
            status=500,
            headers={"Content-Type": "application/json"}
        )

@https_fn.on_request()
def generate_info_card(request: https_fn.Request) -> https_fn.Response:
    """HTTP Cloud Function to generate an info card from a transcription.
    Args:
        request: The request object with transcription in the body
    Returns:
        JSON response with generated content or error
    """
    logger.info("Received info card generation request")
    
    # Check if request is POST
    if request.method != 'POST':
        logger.warning(f"Invalid method: {request.method}")
        return https_fn.Response(
            json={'error': 'Only POST requests are accepted'}, 
            status=405
        )
    
    # Get request JSON data
    request_json = request.get_json(silent=True)
    
    # Validate request
    if not request_json or 'transcription' not in request_json:
        logger.error("Missing transcription in request")
        return https_fn.Response(
            json={'error': 'Missing transcription in request body'},
            status=400
        )
    
    transcription = request_json['transcription']
    logger.info(f"Processing transcription of length: {len(transcription)}")
    
    try:
        # Initialize OpenAI client
        client = OpenAI(api_key=openai_api_key)
        
        # Generate info card content with GPT-4
        logger.info("Generating info card content with GPT-4")
        completion = client.chat.completions.create(
            model="gpt-4",
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are an AI assistant that creates concise, engaging info cards for videos. "
                        "Generate a title and description that captures the main points and would encourage viewers to watch. "
                        "Keep the title under 50 characters and the description under 200 characters. "
                        "Format your response as JSON with 'title' and 'description' fields."
                    )
                },
                {
                    "role": "user",
                    "content": f"Generate an info card from this transcription: {transcription}"
                }
            ],
            response_format={ "type": "json_object" }
        )
        
        # Parse the response
        content = completion.choices[0].message.content
        if not content:
            raise ValueError("Empty response from GPT-4")
            
        # Return the generated content
        return https_fn.Response(
            response=json.dumps({
                'success': True,
                'content': json.loads(content)
            }),
            headers={"Content-Type": "application/json"}
        )
        
    except Exception as e:
        logger.error(f"Error generating info card: {str(e)}", exc_info=True)
        return https_fn.Response(
            response=json.dumps({
                'success': False,
                'error': str(e)
            }),
            headers={"Content-Type": "application/json"},
            status=500
        )

# initialize_app()
#
#
# @https_fn.on_request()
# def on_request_example(req: https_fn.Request) -> https_fn.Response:
#     return https_fn.Response("Hello world!")

def generate_signed_url(storage_path: str) -> str:
    """Generate a signed URL for accessing a video in Firebase Storage.
    
    Args:
        storage_path: The path to the video in Firebase Storage
        
    Returns:
        str: The generated signed URL
    """
    # Get a fresh download URL using the Admin SDK
    bucket = storage.bucket()
    blob = bucket.blob(storage_path)
    fresh_url = blob.generate_signed_url(
        version="v4",
        expiration=timedelta(minutes=15),
        method="GET"
    )
    
    logger.info(f"Generated fresh download URL for video")
    return fresh_url