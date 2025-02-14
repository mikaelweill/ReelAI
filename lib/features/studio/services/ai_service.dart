import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  static const String _baseUrl = 'https://us-central1-reelai-c8ef6.cloudfunctions.net';

  /// Initialize the OpenAI API key
  static void initialize({required String apiKey}) {
    print('OpenAI API initialized');
  }

  Future<String?> convertVideoToAudio(String videoId, {Function(String status)? onProgress}) async {
    try {
      onProgress?.call('Converting video to audio...');
      
      print('Attempting to convert video to audio: $videoId');
      
      // Make direct HTTP call to the function
      final response = await http.post(
        Uri.parse('$_baseUrl/convert_to_audio'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'video_id': videoId}),
      );
      
      if (response.statusCode != 200) {
        print('Error response: ${response.body}');
        throw Exception('Failed to call function: ${response.statusCode} ${response.body}');
      }
      
      final data = json.decode(response.body);
      print('Response data: $data');
      print('Success: ${data['success']}, Audio Path: ${data['audio_path']}');
      
      if (data['success'] == true && data['audio_path'] != null) {
        if (data['skipped_conversion'] == true) {
          onProgress?.call('Using existing audio file...');
        } else {
          onProgress?.call('Audio conversion complete!');
        }
        final path = data['audio_path'];
        print('Returning audio path: $path');
        return path;
      }
      
      print('Throwing error because success=${data['success']} or audio_path=${data['audio_path']} is invalid');
      throw Exception(data['error'] ?? 'Failed to convert video to audio');
    } catch (e, stackTrace) {
      print('Error in convertVideoToAudio:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      onProgress?.call('Error: ${e.toString()}');
      return null;
    }
  }

  Future<Map<String, dynamic>> transcribeVideo(String videoId, {Function(String status)? onProgress}) async {
    try {
      onProgress?.call('Processing video...');
      
      // First convert video to audio if needed
      final audioPath = await convertVideoToAudio(videoId, onProgress: onProgress);
      print('Received audio path from conversion: $audioPath');
      if (audioPath == null) {
        print('Audio path is null, throwing error');
        throw Exception('Failed to convert video to audio');
      }
      
      onProgress?.call('Getting transcript...');
      
      print('Attempting to transcribe video: $videoId');
      
      // Make direct HTTP call to the function
      final response = await http.post(
        Uri.parse('$_baseUrl/create_transcript'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'video_id': videoId,
        }),
      );
      
      if (response.statusCode != 200) {
        print('Error response: ${response.body}');
        throw Exception('Failed to call function: ${response.statusCode} ${response.body}');
      }
      
      final data = json.decode(response.body);
      print('Response data: $data');
      
      if (data['success'] == true && data['transcript'] != null) {
        final transcript = data['transcript'];
        if (transcript['content'] != null) {
          if (data['skipped_transcription'] == true) {
            onProgress?.call('Using existing transcript...');
          } else {
            onProgress?.call('Transcription complete!');
          }
          return {
            'content': transcript['content'],
            'segments': transcript['segments'] ?? [],
          };
        }
      }
      
      throw Exception(data['error'] ?? 'Failed to get transcription');
    } catch (e, stackTrace) {
      print('Error in transcribeVideo:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      onProgress?.call('Error: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, String>> generateInfoCard(String transcription) async {
    try {
      print('Generating info card from transcript of length: ${transcription.length}');
      
      // Make direct HTTP call to the function
      final response = await http.post(
        Uri.parse('$_baseUrl/generate_info_card'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'transcript': transcription}),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to call function: ${response.statusCode} ${response.body}');
      }
      
      final data = json.decode(response.body);
      print('Response data: $data');
      
      if (data['success'] == true && (data['title'] != null || data['description'] != null)) {
        final title = data['title'] as String? ?? 'Generated Title';
        final description = data['description'] as String? ?? 'Generated Description';
        
        print('Generated title: $title');
        print('Generated description: $description');
        
        return {
          'title': title.replaceAll('",', ''),  // Clean up any extra quotes or commas
          'description': description,
        };
      }
      
      throw Exception(data['error'] ?? 'Failed to generate info card');
    } catch (e, stackTrace) {
      print('Error in generateInfoCard:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Complete flow to process a video and generate its info card
  Future<Map<String, String>> processVideoAndGenerateInfoCard(String videoId, {Function(String status)? onProgress}) async {
    try {
      // First get the transcript
      final transcript = await transcribeVideo(videoId, onProgress: onProgress);
      
      onProgress?.call('Generating title and description...');
      
      // Then generate the info card
      final infoCard = await generateInfoCard(transcript['content']);
      
      onProgress?.call('Done! Title and description generated successfully.');
      
      return infoCard;
    } catch (e) {
      print('Error in processVideoAndGenerateInfoCard: $e');
      onProgress?.call('Error: ${e.toString()}');
      rethrow;
    }
  }
} 