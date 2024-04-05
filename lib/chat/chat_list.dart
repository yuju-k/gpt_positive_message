import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_tunify/chat/chat.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final rtdb.DatabaseReference databaseRef =
      rtdb.FirebaseDatabase.instance.ref();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  List<Map<String, dynamic>> chatList = [];

  bool isLoading = false; // Add a new state variable for loading status

  @override
  void initState() {
    super.initState();
    loadChatList();
  }

  void loadChatList() async {
    try {
      setState(() {
        isLoading = true; // Set loading to true when the fetch starts
      });

      // Query chat rooms where the current user is a participant
      rtdb.Query chatRoomsQuery = databaseRef
          .child('chat_rooms')
          .orderByChild('participants/$userId')
          .equalTo(true);

      rtdb.DatabaseEvent event = await chatRoomsQuery.once();

      List<Map<String, dynamic>> loadedChatList = [];
      for (var room in event.snapshot.children) {
        try {
          // Get chat room data as a Map
          Map<String, dynamic> chatRoomData =
              Map<String, dynamic>.from(room.value as Map);

          // 현재 사용자의 UID를 가져옵니다.

          // 현재 사용자를 제외한 다른 참가자의 이메일을 찾습니다.
          String? friendEmail;
          for (String email in chatRoomData['email'].values) {
            if (email != FirebaseAuth.instance.currentUser!.email) {
              friendEmail = email;
              break; // 다른 참가자를 찾으면 반복문을 중단합니다.
            }
          }

          if (friendEmail == null) {
            continue; // 친구 이메일을 찾지 못한 경우, 다음 채팅방으로 넘어갑니다.
          }

          // Initialize lastMessage with a default value
          String lastMessage = '';
          if (chatRoomData['last_message'] != null) {
            Map<String, dynamic> lastMessageData =
                Map<String, dynamic>.from(chatRoomData['last_message'] as Map);
            lastMessage = lastMessageData['last_message'] ?? '';
          }

          // Firestore에서 친구의 이메일로 사용자 프로필을 조회합니다.
          var userProfiles = await firestore
              .collection('user_profile')
              .where('email', isEqualTo: friendEmail)
              .get();

          if (userProfiles.docs.isNotEmpty) {
            var userProfile = userProfiles.docs.first.data();
            String friendName = userProfile['name'] ?? 'Unknown';
            String friendImageUrl = userProfile['imageUrl'] ?? '';
            String friendUid = userProfile['uid'] ?? '';

            // Add to the list of chat rooms with the friend's name, profile image URL, and last message
            loadedChatList.add({
              'roomId': room.key,
              'roomName': friendName,
              'friendEmail': friendEmail,
              'friendImageUrl': friendImageUrl,
              'friendUID': friendUid,
              'lastMessage': lastMessage,
            });
          }
        } catch (e) {
          // Handle exceptions for each chat room processing
          //print('Error processing a chat room: $e');
        }
      }

      setState(() {
        chatList =
            loadedChatList; // Update the chatList with the loadedChatList
        isLoading = false; // Set loading to false after processing is complete
      });
    } catch (e) {
      // Handle exceptions for the entire chat list loading process
      //print('Error loading chat list: $e');
      setState(() {
        isLoading = false; // Ensure loading is set to false in case of an error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('대화목록'),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : chatList.isNotEmpty
              ? ListView.builder(
                  itemCount: chatList.length,
                  itemBuilder: (context, index) {
                    var chatRoom = chatList[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: chatRoom['friendImageUrl'] != null &&
                                chatRoom['friendImageUrl'].isNotEmpty
                            ? NetworkImage(chatRoom['friendImageUrl'])
                                as ImageProvider<Object>?
                            : const AssetImage(
                                'assets/images/default_profile.png'),
                      ),
                      title: Text(chatRoom['roomName'] ?? 'No name'),
                      subtitle:
                          //chatRoom['lastMessage'] 를 20자로 자르고 ...을 붙여줌
                          RichText(
                        text: TextSpan(
                          text: chatRoom['lastMessage'].length > 20
                              ? chatRoom['lastMessage'].substring(0, 20) + '...'
                              : chatRoom['lastMessage'],
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      //Text(chatRoom['lastMessage']),
                      onTap: () {
                        // 채팅방으로 이동
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatRoomPage(
                                name: chatRoom['roomName'],
                                email: chatRoom['friendEmail'],
                                uid: chatRoom['friendUID'],
                              ),
                            ));
                      },
                    );
                  },
                )
              : const Center(
                  child: Text('대화방이 없습니다.'),
                ),
    );
  }
}
