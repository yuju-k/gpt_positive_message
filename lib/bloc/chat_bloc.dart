import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class ChatRoomEvent {
  final String friendEmail;
  ChatRoomEvent(this.friendEmail);
}

class CheckChatRoomExist extends ChatRoomEvent {
  CheckChatRoomExist(String friendEmail) : super(friendEmail);
}

class LoadChatRoom extends ChatRoomEvent {
  final String roomId;
  LoadChatRoom(this.roomId, String friendEmail) : super(friendEmail);
}

class CreateChatRoom extends ChatRoomEvent {
  CreateChatRoom(String friendEmail) : super(friendEmail);
}

abstract class ChatRoomState {}

class ChatRoomInitial extends ChatRoomState {}

class ChatRoomLoading extends ChatRoomState {}

class ChatRoomExist extends ChatRoomState {
  final String roomId;
  ChatRoomExist(this.roomId);
}

class ChatRoomNotExist extends ChatRoomState {}

class ChatRoomLoaded extends ChatRoomState {
  final List<Map<String, dynamic>> messages;
  ChatRoomLoaded(this.messages);
}

class ChatRoomLoadedFail extends ChatRoomState {}

class ChatRoomCreated extends ChatRoomState {
  final String roomId;
  ChatRoomCreated(this.roomId);
}

class ChatRoomBloc extends Bloc<ChatRoomEvent, ChatRoomState> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final DatabaseReference databaseRef = FirebaseDatabase.instance.ref();
  final String userEmail = FirebaseAuth.instance.currentUser!.email!;

  ChatRoomBloc() : super(ChatRoomInitial()) {
    on<CheckChatRoomExist>(_onCheckChatRoomExist);
    on<LoadChatRoom>(_onLoadChatRoom);
    on<CreateChatRoom>(_onCreateChatRoom);
  }

  Future<void> _onCheckChatRoomExist(
      CheckChatRoomExist event, Emitter<ChatRoomState> emit) async {
    emit(ChatRoomLoading());

    DocumentSnapshot currentUserChatRoomsSnapshot =
        await firestore.collection('user_chat_rooms').doc(userEmail).get();

    DocumentSnapshot friendChatRoomsSnapshot = await firestore
        .collection('user_chat_rooms')
        .doc(event.friendEmail)
        .get();

    String? chatRoomId;
    if (currentUserChatRoomsSnapshot.exists && friendChatRoomsSnapshot.exists) {
      Map<String, dynamic> currentUserChatRooms =
          currentUserChatRoomsSnapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> friendChatRooms =
          friendChatRoomsSnapshot.data() as Map<String, dynamic>;

      for (String roomId in currentUserChatRooms.keys) {
        if (friendChatRooms.containsKey(roomId)) {
          chatRoomId = roomId;
          break;
        }
      }
    }

    if (chatRoomId != null) {
      emit(ChatRoomExist(chatRoomId));
    } else {
      emit(ChatRoomNotExist());
    }
  }

  Future<void> _onLoadChatRoom(
      LoadChatRoom event, Emitter<ChatRoomState> emit) async {
    emit(ChatRoomLoading());

    final messagesRef = databaseRef.child('messages/${event.roomId}');
    final snapshot = await messagesRef.once();
    if (snapshot.snapshot.exists) {
      List<Map<String, dynamic>> messages = [];
      for (var message in snapshot.snapshot.children) {
        messages.add(Map<String, dynamic>.from(message.value as Map));
      }
      emit(ChatRoomLoaded(messages));
    } else {
      emit(ChatRoomLoadedFail());
    }
  }

  Future<void> _onCreateChatRoom(
      CreateChatRoom event, Emitter<ChatRoomState> emit) async {
    emit(ChatRoomLoading());

    DatabaseReference newChatRoomRef = databaseRef.child('chat_rooms').push();
    String chatRoomId = newChatRoomRef.key!;

    await newChatRoomRef.set({
      'userEmails': [userEmail, event.friendEmail],
      'last_message': '',
      'last_message_timestamp': ServerValue.timestamp,
      'create_chat_room_timestamp': ServerValue.timestamp,
    });

    await firestore.collection('user_chat_rooms').doc(userEmail).set({
      chatRoomId: true,
    }, SetOptions(merge: true));

    await firestore.collection('user_chat_rooms').doc(event.friendEmail).set({
      chatRoomId: true,
    }, SetOptions(merge: true));

    emit(ChatRoomCreated(chatRoomId));
  }
}
