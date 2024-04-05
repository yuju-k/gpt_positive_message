import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class ChatRoomEvent {
  final String friendUID;
  final String friendEmail;
  ChatRoomEvent(this.friendUID, this.friendEmail);
}

class CheckChatRoomExist extends ChatRoomEvent {
  CheckChatRoomExist(
    String friendUID,
    String friendEmail,
  ) : super(friendUID, friendEmail);
}

class LoadChatRoom extends ChatRoomEvent {
  LoadChatRoom(
    String friendUID,
    String friendEmail,
  ) : super(friendUID, friendEmail);
}

class CreateChatRoom extends ChatRoomEvent {
  CreateChatRoom(
    String friendUID,
    String friendEmail,
  ) : super(friendUID, friendEmail);
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
  final DatabaseReference databaseRef = FirebaseDatabase.instance.ref();
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  ChatRoomBloc() : super(ChatRoomInitial()) {
    on<CheckChatRoomExist>(_onCheckChatRoomExist);
    on<LoadChatRoom>(_onLoadChatRoom);
    on<CreateChatRoom>(_onCreateChatRoom);
  }

  Future<void> _onCheckChatRoomExist(
      CheckChatRoomExist event, Emitter<ChatRoomState> emit) async {
    emit(ChatRoomLoading());

    // Query chat rooms by friend's UID, and my uid
    Query userRoomsRef = databaseRef
        .child('chat_rooms')
        .orderByChild('participants/$userId')
        .equalTo(true);

    DatabaseEvent userRoomsEvent = await userRoomsRef.once();

    if (userRoomsEvent.snapshot.exists) {
      bool roomFound = false;
      String roomId = '';

      for (var child in userRoomsEvent.snapshot.children) {
        if (child.child('participants/${event.friendUID}').exists) {
          roomFound = true;
          roomId = child.key!;
          break;
        }
      }

      if (roomFound) {
        // Chat room with both users exists
        emit(ChatRoomExist(roomId));
      } else {
        // Chat room does not exist with both users
        emit(ChatRoomNotExist());
      }
    } else {
      // No chat rooms exist for the current user
      emit(ChatRoomNotExist());
    }
  }

  Future<void> _onLoadChatRoom(
      LoadChatRoom event, Emitter<ChatRoomState> emit) async {
    emit(ChatRoomLoading());

    // Load chat room messages
    final messagesRef =
        databaseRef.child('chat_rooms/${event.friendUID}/messages');
    final snapshot = await messagesRef.once();
    if (snapshot.snapshot.exists) {
      // Extract messages
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

    // Create a new chat room entry
    DatabaseReference newChatRoomRef = databaseRef.child('chat_rooms').push();

    // Setting up participants for the chat room
    Map<String, bool> participants = {
      userId: true,
      event.friendUID: true,
    };

    Map<String, String> emails = {
      userId: FirebaseAuth.instance.currentUser!.email!,
      event.friendUID: event.friendEmail,
    };

    await newChatRoomRef.set({
      'participants': participants,
      'email': emails,
    });

    // Emitting the state with the new room ID
    emit(ChatRoomCreated(newChatRoomRef.key!));
  }
}
