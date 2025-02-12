import logging
from firebase_admin import storage
from typing import Tuple, Optional, Dict, Any
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

def get_video_blob(video_path: str):
    """Get a video blob from Firebase Storage.
    
    Args:
        video_path: The path to the video in Firebase Storage
        
    Returns:
        The video blob
        
    Raises:
        Exception: If video blob is not found
    """
    try:
        bucket = storage.bucket()
        blob = bucket.blob(video_path)
        
        if not blob.exists():
            raise Exception(f'Video blob not found at path: {video_path}')
            
        return blob
    except Exception as e:
        logger.error(f"Error getting video blob: {str(e)}", exc_info=True)
        raise

def save_video_file(video_data: bytes, destination_path: str, content_type: str = 'video/mp4') -> str:
    """Save video data to Firebase Storage.
    
    Args:
        video_data: The video file data as bytes
        destination_path: Where to save the video in Firebase Storage
        content_type: The MIME type of the video (default: video/mp4)
        
    Returns:
        str: The public URL of the saved video file
        
    Raises:
        Exception: If saving fails
    """
    try:
        bucket = storage.bucket()
        video_blob = bucket.blob(destination_path)
        
        # Upload the video data
        video_blob.upload_from_string(
            video_data,
            content_type=content_type
        )
        
        logger.info(f"Successfully saved video to: {destination_path}")
        return video_blob.public_url
        
    except Exception as e:
        logger.error(f"Error saving video file: {str(e)}", exc_info=True)
        raise

def save_audio_file(audio_data: bytes, destination_path: str) -> str:
    """Save audio data to Firebase Storage.
    
    Args:
        audio_data: The audio file data as bytes
        destination_path: Where to save the audio in Firebase Storage
        
    Returns:
        str: The public URL of the saved audio file
        
    Raises:
        Exception: If saving fails
    """
    try:
        bucket = storage.bucket()
        audio_blob = bucket.blob(destination_path)
        
        # Upload the audio data
        audio_blob.upload_from_string(
            audio_data,
            content_type='audio/mpeg'  # MP3 content type
        )
        
        logger.info(f"Successfully saved audio to: {destination_path}")
        return audio_blob.public_url
        
    except Exception as e:
        logger.error(f"Error saving audio file: {str(e)}", exc_info=True)
        raise

def delete_file(file_path: str) -> bool:
    """Delete a file from Firebase Storage.
    
    Args:
        file_path: The path to the file in Firebase Storage
        
    Returns:
        bool: True if deletion was successful, False otherwise
        
    Raises:
        Exception: If deletion fails
    """
    try:
        bucket = storage.bucket()
        blob = bucket.blob(file_path)
        
        if not blob.exists():
            logger.warning(f"File not found at path: {file_path}")
            return False
            
        blob.delete()
        logger.info(f"Successfully deleted file at: {file_path}")
        return True
        
    except Exception as e:
        logger.error(f"Error deleting file: {str(e)}", exc_info=True)
        raise

def get_signed_url(file_path: str, expiration_minutes: int = 60) -> str:
    """Get a signed URL for secure access to a file.
    
    Args:
        file_path: The path to the file in Firebase Storage
        expiration_minutes: Number of minutes until the URL expires (default: 60)
        
    Returns:
        str: The signed URL for the file
        
    Raises:
        Exception: If URL generation fails
    """
    try:
        bucket = storage.bucket()
        blob = bucket.blob(file_path)
        
        if not blob.exists():
            raise Exception(f'File not found at path: {file_path}')
        
        # Generate signed URL that expires in specified minutes
        expiration = datetime.utcnow() + timedelta(minutes=expiration_minutes)
        signed_url = blob.generate_signed_url(
            expiration=expiration,
            method='GET'
        )
        
        return signed_url
        
    except Exception as e:
        logger.error(f"Error generating signed URL: {str(e)}", exc_info=True)
        raise

def get_file_metadata(file_path: str) -> Dict[str, Any]:
    """Get metadata for a file in Firebase Storage.
    
    Args:
        file_path: The path to the file in Firebase Storage
        
    Returns:
        Dict[str, Any]: Dictionary containing file metadata
        
    Raises:
        Exception: If metadata retrieval fails
    """
    try:
        bucket = storage.bucket()
        blob = bucket.blob(file_path)
        
        if not blob.exists():
            raise Exception(f'File not found at path: {file_path}')
        
        # Reload to ensure we have the latest metadata
        blob.reload()
        
        metadata = {
            'name': blob.name,
            'bucket': blob.bucket.name,
            'size': blob.size,
            'content_type': blob.content_type,
            'created': blob.time_created,
            'updated': blob.updated,
            'md5_hash': blob.md5_hash,
            'public_url': blob.public_url
        }
        
        return metadata
        
    except Exception as e:
        logger.error(f"Error getting file metadata: {str(e)}", exc_info=True)
        raise

def file_exists(file_path: str) -> bool:
    """Check if a file exists in Firebase Storage.
    
    Args:
        file_path: The path to the file in Firebase Storage
        
    Returns:
        bool: True if the file exists, False otherwise
    """
    try:
        bucket = storage.bucket()
        blob = bucket.blob(file_path)
        return blob.exists()
        
    except Exception as e:
        logger.error(f"Error checking file existence: {str(e)}", exc_info=True)
        return False 