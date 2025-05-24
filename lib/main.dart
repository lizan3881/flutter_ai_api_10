import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart';

Future<void> main() async {
  await dotenv.load(); // Load the .env file
  runApp(AIChatApp());
}

class AIChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: ChatScreen());
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  // List of available models
  final List<String> _models = [
    'deepseek/deepseek-chat-v3-0324:free',
    'qwen/qwen3-8b:free',
    'mistralai/devstral-small:free',
  ];
  String _selectedModel =
      'deepseek/deepseek-chat-v3-0324:free'; // Default model

  void _sendMessage(String message) {
    if (message.isEmpty) return;

    setState(() {
      _messages.add({'user': message});
      _isLoading = true;
    });

    final stream = _streamAIResponse(message, _selectedModel);

    stream.listen(
      (chunk) {
        setState(() {
          if (_messages.isNotEmpty && _messages.last.containsKey('bot')) {
            _messages.last['bot'] = (_messages.last['bot'] ?? '') + chunk;
          } else {
            _messages.add({'bot': chunk});
          }
        });
      },
      onDone: () {
        setState(() {
          _isLoading = false;
        });
      },
      onError: (error) {
        setState(() {
          _messages.add({'bot': '请求失败: $error'});
          _isLoading = false;
        });
      },
    );

    _controller.clear();
  }

  Stream<String> _streamAIResponse(String prompt, String model) async* {
    final apiKey = dotenv.env['API_KEY'];
    const apiUrl = 'https://openrouter.ai/api/v1/chat/completions';

    try {
      final request =
          http.Request('POST', Uri.parse(apiUrl))
            ..headers.addAll({
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            })
            ..body = json.encode({
              'model': model,
              'messages': [
                {"role": "user", "content": prompt},
              ],
              'stream': true,
            });

      print('Request: ${request.body}'); // 打印请求体

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        final stream = streamedResponse.stream.transform(utf8.decoder);
        String buffer = '';
        await for (var chunk in stream) {
          buffer += chunk;
          final lines = buffer.split('\n');
          buffer = lines.removeLast(); // 保留未完成的部分
          for (var line in lines) {
            if (line.trim().isNotEmpty) {
              try {
                final data = json.decode(line); // 尝试解析 JSON
                if (data['choices'] != null && data['choices'].isNotEmpty) {
                  yield data['choices'][0]['delta']['content'] ?? '';
                }
              } catch (e) {
                print('JSON 解析错误: $e'); // 打印解析错误
                print('原始数据: $line'); // 打印导致错误的原始数据
              }
            }
          }
        }
      } else {
        print('Error: ${streamedResponse.statusCode}'); // 打印错误状态码
        yield 'AI 无法响应，请稍后再试。错误代码: ${streamedResponse.statusCode}';
      }
    } catch (e) {
      print('Exception: $e'); // 打印异常
      yield '请求失败，请检查您的网络连接或 API 配置。错误: $e';
    }
  }

  Future<void> pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      print('Image path: ${image.path}');
      await classifyImage(
        image.path,
      ); // Pass the image to the AI model for processing
    }
  }

  Future<void> loadModel() async {
    String? res = await Tflite.loadModel(
      model: "assets/model.tflite",
      labels: "assets/labels.txt",
    );
    print(res);
  }

  Future<void> classifyImage(String imagePath) async {
    var recognitions = await Tflite.runModelOnImage(
      path: imagePath,
      numResults: 5,
      threshold: 0.5,
    );
    print(recognitions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI 聊天'), backgroundColor: Colors.blueAccent),
      body: Column(
        children: [
          // Dropdown for model selection
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text('选择模型: ', style: TextStyle(fontSize: 16)),
                DropdownButton<String>(
                  value: _selectedModel,
                  items:
                      _models.map((model) {
                        return DropdownMenuItem(
                          value: model,
                          child: Text(model),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedModel = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.containsKey('user');
                return ListTile(
                  title: Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isUser ? Colors.blue[100] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isUser ? message['user']! : message['bot']!,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
