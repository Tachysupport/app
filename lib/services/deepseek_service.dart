import 'dart:convert';
import 'package:http/http.dart' as http;

class DeepSeekService {
  // Use flutter_dotenv for API keys! Example:
  // static final String _apiKey = dotenv.get('DEEPSEEK_API_KEY');
  static const String _apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String _apiKey = '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'; // ⚠️ Replace with env variable

  Future<String> getDeepSeekResponse(String prompt) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'deepseek/deepseek-chat-v3.1:free', // Updated model identifier
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'max_tokens': 200,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices']?[0]?['message']?['content']?.trim() ?? 
             'Sorry, I could not generate a response.';
    } else {
      return 'Error: ${response.statusCode} - ${response.body}';
    }
  }
}