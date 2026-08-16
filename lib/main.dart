
import 'package:flutter/material.dart';
import 'dart:convert';
import 'models/message.dart';
import 'package:http/http.dart' as http;

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
  TextEditingController taskController = TextEditingController();
  ScrollController scrollController = ScrollController();
  List<Message> tasklist = [];
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
      displayText = prompt;
      taskController.clear();
    });
    scrolltobottom();
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/chat/'),
        headers: {"Content-type": "application/json"},
        body: jsonEncode({'user_message': prompt}),
      );
      final data = jsonDecode(response.body);
      final aiReply = data['reply'];
      setState(() {
        isLoading = false;
        tasklist.add(Message(text: aiReply, isUser: false));
      });
      scrolltobottom();
      print("STATUS:${response.statusCode}");
      print("BODY:${response.body}");
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
      appBar: AppBar(
        title: Text(
          "CHATGENZ",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.black,
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
                        "Thinking...",
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: EdgeInsets.all(10),
                  child: Align(
                    alignment: tasklist[index].isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: EdgeInsets.all(12),

                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        color: tasklist[index].isUser
                            ? Colors.black
                            : Colors.black54,
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
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: taskController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      hintText: ('Enter Your Prompt'),
                    ),
                  ),
                ),
                Expanded(
                  flex: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(0),
                    child: MaterialButton(
                      padding: EdgeInsets.all(20),
                      onPressed: sendprompt,

                      shape: CircleBorder(),
                      color: Colors.black,

                      child: Icon(Icons.send, color: Colors.white),
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
