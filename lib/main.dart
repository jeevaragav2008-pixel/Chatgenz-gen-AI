import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'models/message.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class Chat {
  String title;
  List<Message> messages;
  Chat({required this.title, required this.messages});
}

void main() {
  runApp(
    MaterialApp(debugShowCheckedModeBanner: false, home: const Mainpage()),
  );
}

class Mainpage extends StatefulWidget {
  const Mainpage({super.key});

  @override
  State<Mainpage> createState() => _MainpageState();
}

class _MainpageState extends State<Mainpage> {
  String displayText = '';
  bool isLoading = false;
  int thinkDots = 0;
  TextEditingController taskController = TextEditingController();
  ScrollController scrollController = ScrollController();
  FocusNode inputFocusnode = FocusNode();
  FocusNode keyboardFocusnode = FocusNode();
  List<Message> tasklist = [];
  List<Chat> chathistory = [];
  int? activeChatIndex;
  void scrolltobottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void startThinking() {
    Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!isLoading) {
        timer.cancel();
        return;
      }
      setState(() {
        thinkDots = (thinkDots + 1) % 4;
      });
    });
  }

  Future<void> pickFile() async {
    String prompt = taskController.text.trim();
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null) {
      PlatformFile file = result.files.single;
      print("Selected image :${file.name}");

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:8000/chat/upload-image'),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
      );
      request.fields['prompt'] = prompt;
      setState(() {
        isLoading = true;
        thinkDots = 0;
      });
      startThinking();
      try {
        final response = await request.send();

        final responsebody = await response.stream.bytesToString();
        final data = jsonDecode(responsebody);
        if (response.statusCode == 200) {
          final reply = data['reply'];
          setState(() {
            tasklist.add(Message(text: prompt, isUser: true));
            tasklist.add(Message(text: reply, isUser: false));

            if (activeChatIndex == null) {
              chathistory.add(
                Chat(title: "Query about image", messages: List.from(tasklist)),
              );
              activeChatIndex = chathistory.length - 1;
            } else {
              chathistory[activeChatIndex!].messages = List.from(tasklist);
            }
          });
          taskController.clear();
          scrolltobottom();
        }
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> sendprompt() async {
    final prompt = taskController.text;
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("The prompt should not be empty!")),
      );

      return;
    }

    setState(() {
      tasklist.add(Message(text: prompt, isUser: true));
      if (activeChatIndex == null) {
        chathistory.add(Chat(title: "New Chat", messages: List.from(tasklist)));
        activeChatIndex = chathistory.length - 1;
      } else {
        chathistory[activeChatIndex!].messages = List.from(tasklist);
      }
      displayText = prompt;
      taskController.clear();
    });
    scrolltobottom();
    setState(() {
      isLoading = true;
      thinkDots = 0;
    });
    startThinking();
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/chat/'),
        headers: {"Content-type": "application/json"},
        body: jsonEncode({
          'messages': tasklist
              .map(
                (message) => {
                  'role': message.isUser ? 'user' : 'assistant',
                  'content': message.text,
                },
              )
              .toList(),
        }),
      );
      print("STATUS:${response.statusCode}");
      print("BODY:${response.body}");
      final data = jsonDecode(response.body);
      final aiReply = data['reply'];
      final aiTitle = data['title'];
      setState(() {
        isLoading = false;
        tasklist.add(Message(text: aiReply, isUser: false));
        if (activeChatIndex != null) {
          chathistory[activeChatIndex!].messages = List.from(tasklist);
          if (aiTitle != null && aiTitle.toString().isNotEmpty) {
            chathistory[activeChatIndex!].title = aiTitle;
          }
        }
      });
      scrolltobottom();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print("ERROR:$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable

    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0D1026),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF151A32)),
              child: Text(
                "Chat History",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.add, color: Colors.white),
              title: Text(
                "New Chat",

                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);

                setState(() {
                  if (tasklist.isNotEmpty) {
                    if (activeChatIndex == null) {
                      String title = tasklist.first.text.trim();
                      chathistory.add(
                        Chat(title: title, messages: List.from(tasklist)),
                      );
                    } else {
                      chathistory[activeChatIndex!].messages = List.from(
                        tasklist,
                      );
                    }
                  }
                  tasklist.clear();
                  activeChatIndex = null;
                });
              },
            ),
            ...chathistory.asMap().entries.map((entry) {
              int index = entry.key;
              Chat chat = entry.value;
              return ListTile(
                leading: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white70,
                ),
                title: Text(
                  chat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(fontSize: 22, color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);

                  setState(() {
                    tasklist = List.from(chat.messages);

                    activeChatIndex = index;
                  });
                  scrolltobottom();
                },
              );
            }),
          ],
        ),
      ),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.jpeg', width: 40, height: 40),
            const SizedBox(width: 8),

            const Text(
              "CHATGENZ",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFF5F5FF),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0D1026),
        centerTitle: true,
      ),

      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: isLoading == true
                  ? tasklist.length + 1
                  : tasklist.length,

              itemBuilder: (context, index) {
                if (isLoading && index == tasklist.length) {
                  return Padding(
                    padding: EdgeInsets.all(10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Thinking${"." * thinkDots}",
                        style: TextStyle(fontSize: 15, color: Colors.white),
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: EdgeInsets.all(13),
                  child: Align(
                    alignment: tasklist[index].isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.all(19),

                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: tasklist[index].isUser
                            ? const Color(0xFF25204A)
                            : const Color(0xFF151A32),
                      ),
                      child: Text(
                        tasklist[index].text,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(10),

            child: Row(
              children: [
                IconButton(
                  onPressed: pickFile,
                  icon: const Icon(Icons.attach_file, color: Colors.white),
                ),
                Expanded(
                  child: KeyboardListener(
                    focusNode: keyboardFocusnode,
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter) {
                        if (HardwareKeyboard.instance.isShiftPressed) {
                          return;
                        }
                        sendprompt();
                      }
                    },
                    child: TextField(
                      controller: taskController,
                      focusNode: inputFocusnode,
                      maxLines: null,
                      style: const TextStyle(
                        color: Color(0xFFF5F5FF),
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: ('Ask CHATGENZ anything. . .').trim(),
                        hintStyle: const TextStyle(color: Color(0xFF9CA3C7)),
                        filled: true,
                        fillColor: const Color(0xFF151A32),

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(0),
                  child: MaterialButton(
                    padding: EdgeInsets.all(20),
                    onPressed: sendprompt,

                    shape: CircleBorder(),
                    color: const Color(0xFF7C4DFF),

                    child: const Icon(
                      Icons.send_rounded,
                      color: Color(0xFFF5F5FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
