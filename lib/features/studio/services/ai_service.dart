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

  Future<String> transcribeVideo(String videoId, {Function(String status)? onProgress}) async {
    try {
      onProgress?.call('Starting transcription...');
      
      print('Attempting to transcribe video: $videoId');
      
      // Make direct HTTP call to the function
      final response = await http.post(
        Uri.parse('$_baseUrl/create_transcript'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'video_id': videoId}),
      );
      
      if (response.statusCode != 200) {
        print('Error response: ${response.body}');
        throw Exception('Failed to call function: ${response.statusCode} ${response.body}');
      }
      
      onProgress?.call('Processing transcription...');
      final data = json.decode(response.body);
      
      if (data['success'] == true && data['transcript'] != null) {
        final transcript = data['transcript'];
        if (transcript['content'] != null && transcript['content'].isNotEmpty) {
          onProgress?.call('Transcription complete!');
          return transcript['content'];
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
      // Make direct HTTP call to the function
      final response = await http.post(
        Uri.parse('$_baseUrl/generate_info_card'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'transcription': transcription}),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to call function: ${response.statusCode} ${response.body}');
      }
      
      final data = json.decode(response.body);
      
      if (data['success'] == true && data['content'] != null) {
        return {
          'title': data['content']['title'] as String? ?? 'Generated Title',
          'description': data['content']['description'] as String? ?? 'Generated Description',
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
} 