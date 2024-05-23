import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'model/open_ai_model.dart';
import 'package:myfriendgpt/model/open_ai_model.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(primarySwatch: Colors.lightGreen),
    home: MainScreen(),
  ));
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  TextEditingController messageTextController = TextEditingController();
  final List<Messages> _historyList = List.empty(growable: true);

  String apiKey = "YOUR API KEY";
  String streamText = "";

  static const String _kStrings = "ChatGPT와 대화를 시작해보세요!";

  String get _currentString => _kStrings;

  ScrollController scrollController = ScrollController();
  late Animation<int> _characterCount;
  late AnimationController animationController;

  void _scrollDown() {
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 350),
      curve: Curves.fastOutSlowIn,
    );
  }

  setupAnimations() {
    animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));
    _characterCount = StepTween(begin: 0, end: _currentString.length).animate(
      CurvedAnimation(
        parent: animationController,
        curve: Curves.easeIn,
      ),
    );
    animationController.addListener(() {
      setState(() {});
    });
    animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 1)).then((value) {
          animationController.reverse();
        });
      } else if (status == AnimationStatus.dismissed) {
        Future.delayed(Duration(seconds: 1)).then(
          (value) => animationController.forward(),
        );
      }
    });

    animationController.forward();
  }

  Future requestChat(String text) async {
    ChatCompletionModel openAiModel = ChatCompletionModel(
      model: "gpt-3.5-turbo-0125",
      messages: [
        Messages(
          role: "system",
          content: "You are a helpful assistant.",
        ),
        ..._historyList,
      ],
      stream: false,
    );
    final url = Uri.https("api.openai.com", "/v1/chat/completions");
    final resp = await http.post(url,
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode(openAiModel.toJson()));
    print(resp.body);
    if (resp.statusCode == 200) {
      final jsonData = jsonDecode(utf8.decode(resp.bodyBytes)) as Map;
      String role = jsonData["choices"][0]["message"]["role"];
      String content = jsonData["choices"][0]["message"]["content"];
      _historyList.last = _historyList.last.copyWith(
        role: role,
        content: content,
      );
      setState(() {
        _scrollDown();
      });
    }
  }

  // Stream requestChatStream(String text) async* {
  //   ChatCompletionModel openAiModel = ChatCompletionModel(
  //       model: "gpt-3.5-turbo-0125",
  //       messages: [
  //         Messages(
  //           role: "system",
  //           content: "You are a helpful assistant.",
  //         ),
  //         ..._historyList,
  //       ],
  //       stream: true);
  //
  //   final url = Uri.https("api.openai.com", "v1/chat/completions");
  //   final request = http.Request("POST", url)
  //     ..headers.addAll(
  //       {
  //         "Authorization": "Bearer $apiKey",
  //         "Content-Type": "application/json; charset=UTF-8",
  //         "Connection": "keep-alive",
  //         "Accept": "*/*",
  //         "Accept-Encoding": "gzip, deflate, br",
  //       },
  //     );
  //   request.body = jsonEncode(openAiModel.toJson());
  //
  //   final resp = await http.Client().send(request);
  //   final byteStream = resp.stream.asyncExpand(
  //     /** Rx(Reactive Extensions) => 비동기 및 이벤트 기반 프로그램을 구성하기 위한 API*/
  //     (event) => Rx.timer(
  //       event,
  //       const Duration(milliseconds: 50),
  //     ),
  //   );
  //   final statusCode = resp.statusCode;
  //   var respText = "";
  //
  //   await for (final byte in byteStream) {
  //     try {
  //       var decoded = utf8.decode(byte, allowMalformed: false);
  //       final strings = decoded.split("data: ");
  //       for (final string in strings) {
  //         final trimmedString = string.trim();
  //         if (trimmedString.isNotEmpty && !trimmedString.endsWith("[DONE]")) {
  //           final map = jsonDecode(trimmedString) as Map;
  //           final choices = map["choices"] as List;
  //           final delta = choices[0]["delta"] as Map;
  //           if (delta["content"] != null) {
  //             final content = delta["content"] as String;
  //             respText += content;
  //             setState(() {
  //               streamText = respText;
  //             });
  //             yield content;
  //           }
  //         }
  //       }
  //     } catch (e) {
  //       print(e.toString());
  //     }
  //   }
  //
  //   if (respText.isNotEmpty) {
  //     setState(() {});
  //   }
  // }

  Stream<String> requestChatStream(String text) async* {
    ChatCompletionModel openAiModel = ChatCompletionModel(
      model: "gpt-3.5-turbo-0125",
      messages: [
        Messages(
          role: "system",
          content: "You are a helpful assistant.",
        ),
        ..._historyList,
      ],
      stream: true,
    );

    final url = Uri.https("api.openai.com", "v1/chat/completions");
    final request = http.Request("POST", url)
      ..headers.addAll({
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json; charset=UTF-8",
        "Connection": "keep-alive",
        "Accept": "*/*",
        "Accept-Encoding": "gzip, deflate, br",
      });
    request.body = jsonEncode(openAiModel.toJson());

    final response = await http.Client().send(request);

    var buffer = '';
    await for (var bytes in response.stream) {
      buffer += utf8.decode(bytes, allowMalformed: true);
      while (buffer.contains('\n')) {
        final index = buffer.indexOf('\n');
        final line = buffer.substring(0, index).trim();
        buffer = buffer.substring(index + 1);

        if (line.startsWith('data: ')) {
          final content = line.substring(6);
          if (content == '[DONE]') {
            break;
          }

          try {
            final json = jsonDecode(content);
            final delta = json['choices'][0]['delta'];
            if (delta != null && delta.containsKey('content')) {
              yield delta['content'];
            }
          } catch (e) {
            print('Error: $e');
          }
        }
      }
    }
  }


  @override
  void initState() {
    super.initState();
    setupAnimations();
  }

  @override
  void dispose() {
    messageTextController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future clearChat() async {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("새로운 대화 생성"),
              content: const Text("신규 대화를 생성하시겠습니까?"),
              actions: [
                TextButton(
                    onPressed: () {
                      // 현재 열린 채팅 닫힘
                      Navigator.of(context).pop();
                      setState(() {
                        messageTextController.clear();
                        _historyList.clear();
                      });
                    },
                    child: const Text("네")),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("아니요"),
                )
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
          appBar: AppBar(
            elevation: 1,
            title: const Text("내 친구 GPT"),
            centerTitle: true,
          ),
          drawer: Drawer(
            child: ListView(
              children: [
                ListTile(
                  title: const Text("New Chat"),
                  onTap: () {
                    if (_historyList.isEmpty) return;
                    clearChat();
                  },
                )
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 0, 0),
                  child: _historyList.isEmpty
                      ? Center(
                          child: AnimatedBuilder(
                            animation: _characterCount,
                            builder: (BuildContext context, Widget? child) {
                              String text = _currentString.substring(
                                  0, _characterCount.value);
                              return Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundImage:
                                        AssetImage('assets/images/gpt.png'),
                                    maxRadius: 16,
                                  ),
                                  SizedBox(
                                    width: 4,
                                  ),
                                  Text(
                                    "${text}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        )
                      : GestureDetector(
                          onTap: () => FocusScope.of(context).unfocus(),
                          child: ListView.builder(
                              controller: scrollController,
                              itemCount: _historyList.length,
                              itemBuilder: (context, index) {
                                if (_historyList[index].role == "user") {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const CircleAvatar(),
                                        const SizedBox(
                                          width: 8,
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text("User"),
                                              Text(_historyList[index].content),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const CircleAvatar(
                                      backgroundImage:
                                          AssetImage('assets/images/gpt.png'),
                                    ),
                                    const SizedBox(
                                      width: 8,
                                    ),
                                    Expanded(
                                        child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text("ChatGPT"),
                                        Text(_historyList[index].content)
                                      ],
                                    ))
                                  ],
                                );
                              }),
                        ),
                ),
              ),
              Dismissible(
                key: const Key("chat-bar"),
                direction: DismissDirection.startToEnd,
                onDismissed: (d) {
                  if (d == DismissDirection.startToEnd) {
                    //logic
                  }
                },
                background: const Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text("New Chat"),
                  ],
                ),
                confirmDismiss: (d) async {
                  if (d == DismissDirection.startToEnd) {
                    //logic
                    if (_historyList.isEmpty) return;
                    clearChat();
                  }
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 0, 4),
                        margin: const EdgeInsets.fromLTRB(16, 12, 0, 16),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all()),
                        child: TextField(
                          controller: messageTextController,
                          decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: "ChatGPT에게 메시지를 입력해보세요"),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.fromLTRB(0, 0, 0, 16),
                      child: IconButton(
                          iconSize: 32,
                          onPressed: () async {
                            if (messageTextController.text.isEmpty) {
                              return;
                            }
                            setState(() {
                              _historyList.add(
                                Messages(
                                    role: "user",
                                    content: messageTextController.text.trim()),
                              );
                              _historyList.add(
                                  Messages(role: "assistant", content: ""));
                            });
                            try {
                              var text = "";
                              final stream = requestChatStream(
                                  messageTextController.text.trim());
                              await for (final textChunk in stream) {
                                text += textChunk;
                                setState(() {
                                  _historyList.last =
                                      _historyList.last.copyWith(content: text);
                                  _scrollDown();
                                });
                              }
                              // await requestChat(messageTextController.text.trim());
                              messageTextController.clear();
                              streamText = "";
                            } catch (e) {
                              print(e.toString());
                            }
                          },
                          icon: const Icon(Icons.arrow_circle_up)),
                    )
                  ],
                ),
              )
            ],
          )),
    );
  }
}
