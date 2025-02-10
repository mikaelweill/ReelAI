# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

import os
import io
import logging
import requests
import json
from datetime import datetime
from typing import Optional
from pydantic import BaseModel
from openai import OpenAI
from firebase_admin import initialize_app, firestore, storage
from firebase_functions import https_fn

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
    created_at: datetime = datetime.utcnow()
    status: str = "completed"  # completed, failed
    error: Optional[str] = None

    class Config:
        """Pydantic config."""
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }

def get_video_url(video_id: str) -> str:
    """Get the video URL from Firebase Storage.
    
    Args:
        video_id: The ID of the video in Storage
        
    Returns:
        str: The video URL
        
    Raises:
        Exception: If video is not found
    """
    bucket = storage.bucket()
    logger.info(f"Looking for video: videos/{video_id}")
    blob = bucket.blob(f'videos/{video_id}')
    
    if not blob.exists():
        logger.error(f"Video {video_id} not found at path: videos/{video_id}")
        raise Exception(f'Video {video_id} not found in storage')
        
    return blob.generate_signed_url(expiration=300)  # URL valid for 5 minutes

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
        # Get video URL from Firebase Storage
        logger.info(f"Getting video URL from storage: {video_id}")
        video_url = get_video_url(video_id)
        
        # Stream the video data efficiently
        logger.info("Streaming video data")
        response = requests.get(video_url, stream=True)
        response.raise_for_status()
        
        # Initialize OpenAI client with API key from config
        logger.info("Initializing OpenAI client")
        client = OpenAI(api_key=openai_api_key)
        
        # Transcribe with Whisper using the streamed data
        logger.info("Starting Whisper transcription")
        transcription = client.audio.transcriptions.create(
            file=('video.mp4', response.raw),  # Pass the raw stream
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
        
        # Save to Firestore
        logger.info("Saving transcript to Firestore")
        transcript_ref.set(transcript.model_dump())
        
        return transcript
            
    except Exception as e:
        logger.error(f"Failed to create transcript for video {video_id}", exc_info=True)
        # Create failed transcript
        transcript = Transcript(
            video_id=video_id,
            content="",
            status="failed",
            error=str(e)
        )
        logger.info("Saving failed transcript status to Firestore")
        transcript_ref.set(transcript.model_dump())
        raise e

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