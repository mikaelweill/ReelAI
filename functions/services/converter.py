import logging
import ffmpeg
import io
import subprocess
import os
from typing import Tuple

logger = logging.getLogger(__name__)

def convert_mp4_to_mp3(video_data: bytes) -> bytes:
    """Convert MP4 video data to MP3 audio data.
    
    Args:
        video_data: The video file data as bytes
        
    Returns:
        bytes: The converted audio data
        
    Raises:
        Exception: If conversion fails
    """
    try:
        # Create temporary files for input and output
        input_path = '/tmp/input.mp4'
        output_path = '/tmp/output.mp3'
        
        # Write video data to temp file
        with open(input_path, 'wb') as f:
            f.write(video_data)
        
        logger.info("Starting MP4 to MP3 conversion")
        
        # Build ffmpeg command
        stream = (
            ffmpeg
            .input(input_path)
            .output(
                output_path,
                acodec='libmp3lame',  # Use MP3 codec
                ac=2,                 # 2 audio channels
                ar='44100',           # 44.1kHz sample rate
                loglevel='error'      # Reduce ffmpeg output
            )
        )
        
        # Run the conversion
        ffmpeg.run(stream, capture_stdout=True, capture_stderr=True)
        
        # Read the output file
        with open(output_path, 'rb') as f:
            audio_data = f.read()
            
        logger.info("MP4 to MP3 conversion completed successfully")
        
        # Clean up temp files
        os.remove(input_path)
        os.remove(output_path)
        
        return audio_data
        
    except ffmpeg.Error as e:
        error_message = f"ffmpeg error: {e.stderr.decode() if e.stderr else str(e)}"
        logger.error(error_message)
        raise Exception(error_message)
        
    except Exception as e:
        logger.error(f"Error converting video: {str(e)}", exc_info=True)
        raise
    finally:
        # Ensure temp files are cleaned up
        for path in [input_path, output_path]:
            try:
                if os.path.exists(path):
                    os.remove(path)
            except Exception as e:
                logger.warning(f"Failed to clean up temp file {path}: {str(e)}") 