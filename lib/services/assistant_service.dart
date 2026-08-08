import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/location_service.dart';

class AssistantReply {
  final String answer;
  final List<String> toolCalls;

  const AssistantReply({required this.answer, this.toolCalls = const []});

  /// True when the reply came from real tool results rather than the model alone.
  bool get isGrounded => toolCalls.isNotEmpty;
}

/// Strips the markdown a chat bubble cannot render.
///
/// The bubble is a plain Text widget, so "**Total Distance:** 128.2 km" was
/// shown with the asterisks in it. The prompt asks for plain text; this is the
/// guard for when the model reaches for markdown anyway. Emoji are left alone.
String plainText(String raw) {
  var text = raw;

  // Bold/italic markers, including the ** that wrapped every label.
  text = text.replaceAll(RegExp(r'\*\*|__'), '');
  // Headings: "## Steps" -> "Steps".
  text = text.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
  // Bullets, whether "* ", "- " or "1. ", into one consistent mark.
  text = text.replaceAll(RegExp(r'^\s*[*-]\s+', multiLine: true), '• ');
  // Leftover single asterisks used for emphasis mid-line.
  text = text.replaceAll(RegExp(r'(?<!\S)\*(?=\S)|(?<=\S)\*(?!\S)'), '');
  // Runs of blank lines collapse to one.
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return text.trim();
}

class AssistantService {
  final ApiClient _apiClient;

  AssistantService(this._apiClient);

  /// [from] is the user's position when known, so "how do I get to Digha"
  /// plans from where they are standing instead of asking for a starting point.
  Future<ApiResponse<AssistantReply>> ask(String question, {UserLocation? from}) async {
    try {
      // The model may make several tool calls, so allow more than the default.
      final response = await _apiClient.client.post(
        '/assistant/ask',
        data: {
          'question': question,
          // Only a real fix is sent. Passing the Kolkata fallback would tell
          // the assistant someone in Bardhaman is standing at Esplanade.
          if (from != null && from.isLive) ...{
            'lat': from.latitude,
            'lng': from.longitude,
          },
        },
        options: Options(receiveTimeout: const Duration(seconds: 90)),
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final answer = plainText(data['answer'] ?? '');

      // An empty answer rendered as a blank bubble with a "from live route
      // data" badge under it, which reads as a broken app rather than a
      // failed request.
      if (answer.isEmpty) {
        return ApiResponse(
          success: false,
          error: 'No answer came back. Try naming both places, '
              'for example "Sealdah to Bongaon".',
        );
      }

      return ApiResponse(
        success: true,
        data: AssistantReply(
          answer: answer,
          toolCalls: List<String>.from(data['toolCalls'] ?? const []),
        ),
      );
    } on DioException catch (e) {
      return ApiResponse(success: false, error: friendlyError(e));
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }
}
