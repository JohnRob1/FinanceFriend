import 'package:financefriend/home.dart';
import 'package:flutter/material.dart';
import 'package:financefriend/social_hub_widgets/social_page_widget.dart';
import 'package:financefriend/messages.dart';

class DirectMessages extends StatefulWidget {
  final Map<String, String> friendsProfilePics;
  final List<String> friendsList;
  final String userName;

  const DirectMessages({
    Key? key,
    required this.userName,
    required this.friendsProfilePics,
    required this.friendsList,
  }) : super(key: key);

  @override
  _DirectMessagesState createState() => _DirectMessagesState();
}

class _DirectMessagesState extends State<DirectMessages> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          "Direct Messages:",
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        Container(
          height: 500,
          width: 400,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.black,
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: widget.friendsList
                .map(
                  (friend) => DirectMessageTile(
                    friend: friend,
                    profilePicUrl: widget.friendsProfilePics[friend]!,
                    onOpenDirectMessage: () {
                      _openDirectMessageDialog(context, friend);
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  void _openDirectMessageDialog(BuildContext context, String friend) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DirectMessageDialog(
          friend: friend,
          userName: widget.userName,
          profilePics: widget.friendsProfilePics,
          onSendMessage: (message) {
            // Send message logic here
            sendMessage(widget.userName, friend, message);
          },
        );
      },
    );
  }
}

class DirectMessageTile extends StatelessWidget {
  final String friend;
  final String profilePicUrl;
  final VoidCallback onOpenDirectMessage;

  const DirectMessageTile({
    Key? key,
    required this.friend,
    required this.profilePicUrl,
    required this.onOpenDirectMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(profilePicUrl),
      ),
      title: Text(friend),
      trailing: ElevatedButton(
        onPressed: onOpenDirectMessage,
        child: const Text("Open DM"),
      ),
    );
  }
}

class DirectMessageDialog extends StatefulWidget {
  final String friend;
  final ValueChanged<String> onSendMessage;
  final String userName;
  final Map<String, String> profilePics;

  const DirectMessageDialog({
    Key? key,
    required this.friend,
    required this.onSendMessage,
    required this.userName,
    required this.profilePics,
  }) : super(key: key);

  @override
  _DirectMessageDialogState createState() => _DirectMessageDialogState();
}

class _DirectMessageDialogState extends State<DirectMessageDialog> {
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Direct Message with ${widget.friend}"),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 435,
            width: 450,
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2.0),
                borderRadius: BorderRadius.circular(15),
                color: Colors.white),
            // Display messages here using a StreamBuilder or ListView
            child: StreamBuilder<List<Message>>(
              stream: getMessages(widget.userName, widget.friend),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  if (snapshot.data!.isEmpty) {
                    // No messages yet
                    return Center(
                      child: Text("Send a message to ${widget.friend}!"),
                    );
                  }
                  // Display messages
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    reverse:
                        false, // To display the latest message at the bottom
                    itemBuilder: (context, index) {
                      final isCurrentUser =
                          snapshot.data![index].sender == widget.userName;

                      if (isCurrentUser) {
                        return Column(children: [
                          const SizedBox(
                            height: 10,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(children: [
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                      getFormattedTime(
                                          snapshot.data![index].timestamp),
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 10)),
                                ),
                                getProfileHeader(snapshot.data![index].sender),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            // border: Border.all(
                                            //     color: Colors.black, width: 1),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            color: Colors.green,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey
                                                    .withOpacity(0.5),
                                                spreadRadius: 2,
                                                blurRadius: 4,
                                                offset: const Offset(4, 4),
                                              ),
                                            ],
                                          ),
                                          child: ListTile(
                                              title: Text(
                                                  snapshot.data![index].message,
                                                  style: const TextStyle(
                                                      color: Colors.white))),
                                        ),
                                      ]),
                                ),
                                const SizedBox(width: 10),
                              ]),
                              const SizedBox(height: 5),
                              Text("${snapshot.data![index].sender}   "),
                            ],
                          )
                        ]);
                      } else {
                        return Column(children: [
                          const SizedBox(
                            height: 10,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            color: Colors.grey,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.grey
                                                    .withOpacity(0.5),
                                                spreadRadius: 2,
                                                blurRadius: 4,
                                                offset: const Offset(-4, 4),
                                              ),
                                            ],
                                          ),
                                          child: ListTile(
                                              title: Text(
                                                  snapshot.data![index].message,
                                                  style: const TextStyle(
                                                      color: Colors.white))),
                                        ),
                                      ]),
                                ),
                                const SizedBox(width: 10),
                                getProfileHeader(snapshot.data![index].sender),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                      getFormattedTime(
                                          snapshot.data![index].timestamp),
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 10)),
                                ),
                              ]),
                              const SizedBox(height: 5),
                              Text("   ${snapshot.data![index].sender}"),
                            ],
                          )
                        ]);
                      }
                    },
                  );
                } else {
                  // Loading indicator
                  return const CircularProgressIndicator();
                }
              },
            ),
          ),
          const SizedBox(height: 15),
          // Text input and send button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // Send message
                  widget.onSendMessage(_messageController.text);
                  // Clear the input field
                  _messageController.clear();
                },
                child: const Text('Send'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }

  Container getProfileHeader(String name) {
    String imageUrl = widget.profilePics[name] ?? "";
    return Container(
      child: Column(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundImage: NetworkImage(imageUrl),
          ),
          //Text(name),
        ],
      ),
    );
  }

  DateTime getDateTime(int timestamp) {
    // Assuming 'timestamp' is a server timestamp
    return DateTime.fromMillisecondsSinceEpoch(timestamp ?? 0);
  }

  String getFormattedTime(int timestamp) {
    final dateTime = getDateTime(timestamp);
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    final formattedTime =
        "$hour:${dateTime.minute.toString().padLeft(2, '0')} $period";
    return formattedTime;
  }
}