import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  Future<void> _sendMessage(String message) async {
    if (message.isEmpty) return;

    setState(() {
      _messages.add({'user': message});
      _isLoading = true;
    });

    final response = await _fetchAIResponse(message, _selectedModel);

    setState(() {
      _messages.add({'bot': response});
      _isLoading = false;
    });

    _controller.clear();
  }

  Future<String> _fetchAIResponse(String prompt, String model) async {
    final apiKey = dotenv.env['API_KEY']; // 从 .env 文件中读取 API_KEY
    if (apiKey == null || apiKey.isEmpty) {
      return 'API 密钥未配置。请检查 .env 文件中的 API_KEY。';
    }

    const apiUrl = 'https://openrouter.ai/api/v1/chat/completions';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'model': model,
          'messages': [
            {"role": "user", "content": prompt},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          return data['choices'][0]['message']['content'].trim();
        } else {
          return 'AI 无法生成响应，请稍后再试。';
        }
      } else {
        return 'AI 无法响应，请稍后再试。错误代码: ${response.statusCode}';
      }
    } catch (e) {
      return '请求失败，请检查您的网络连接或 API 配置。错误: $e';
    }
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
