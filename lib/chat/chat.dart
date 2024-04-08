import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:chat_tunify/bloc/chat_bloc.dart';
import 'package:chat_tunify/bloc/message_send_bloc.dart';
import 'package:chat_tunify/bloc/profile_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chat_tunify/chat/message_class.dart';
import 'package:chat_tunify/bloc/message_receive_bloc.dart';
import 'package:chat_tunify/bloc/chat_action_log_bloc.dart';

class ChatRoomPage extends StatefulWidget {
  //const ChatRoomPage({super.key});
  //email을 인자로 받아서 채팅방을 생성한다.
  final String email;
  final String name;
  final String uid;
  const ChatRoomPage(
      {super.key, required this.name, required this.email, required this.uid});

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final Map<String, bool> _originalMessageVisibility = {};
  bool _isRecommendMessageWidgetVisible = false;

  int _previousMessageCount = 0; // 메시지 목록의 이전 길이를 저장하는 변수

  //** 모드 관련 변수 실험군에 맞춰서 변경 **//
  bool originalMessageCheckMode = false; //원본 메시지확인 버튼 활성화 모드
  bool isConvertMessageCheckMode = false; //변환된 메시지인지 확인할 수 있는 모드
  //** */

  double keyboardHeight = 0;

  final TextEditingController _textEditingController = TextEditingController();
  final FocusNode textFieldFocusNode = FocusNode();
  //스크롤 컨트롤러
  final ScrollController _scrollController = ScrollController();

  //스크롤러 맨 아래로 내리는 함수
  void scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  //스크롤러 맨 아래로 내리기, 애니메이션 없이
  void scrollToBottomWithoutAnimation() {
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  String roomId = '';

  // 프로필 정보를 저장할 변수
  String myName = '';
  String myImageUrl = '';
  String myUid = '';
  String friendName = '';
  String friendImageUrl = '';
  String friendUid = '';

  String recommandMessage = '추천메시지..';
  String sensibility = '';

  @override
  void initState() {
    super.initState();
    final chatRoomBloc = context.read<ChatRoomBloc>();

    // Checking if chat room exists with friend's email
    chatRoomBloc.add(CheckChatRoomExist(widget.uid));

    // 텍스트 컨트롤러 값 변경되면 _isRecommendMessageWidgetVisible를 false로 변경
    _textEditingController.addListener(() {
      if (_textEditingController.text.isNotEmpty) {
        setState(() {
          scrollToBottom();
        });
      }
    });

    // profile_bloc을 이용해서 나와 상대방의 프로필을 불러옴
    final profileBloc = context.read<ProfileBloc>();
    profileBloc.add(ProfileLoadRequested(widget.email)); // 상대방 프로필
    profileBloc.add(ProfileLoadRequested(
        FirebaseAuth.instance.currentUser!.email!)); // 나의 프로필
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    textFieldFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
            onLongPress: () {
              //modeOnOff(); 위젯을 모달로 열기
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  return modeOnOff(); // No callbacks needed here
                },
              );
            },
            child: Text(widget.name)),
        centerTitle: false,
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<ProfileBloc, ProfileState>(
            listener: (context, state) {
              if (state is ProfileLoaded) {
                if (state.email == FirebaseAuth.instance.currentUser!.email) {
                  // 나의 프로필 정보 로드됨
                  setState(() {
                    myName = state.name;
                    myImageUrl = state.imageUrl;
                    myUid = state.uid;
                  });
                  //print('My name: $myName / $myUid');
                } else if (state.email == widget.email) {
                  // 상대방의 프로필 정보 로드됨
                  setState(() {
                    friendName = state.name;
                    friendImageUrl = state.imageUrl;
                    friendUid = state.uid;
                  });
                  //print('Friend name: $friendName / $friendUid');
                }
              }
            },
          ),
          BlocListener<ChatRoomBloc, ChatRoomState>(
            listener: (context, state) {
              if (state is ChatRoomExist) {
                //room이 존재하면 roomId불러옴
                //print('Chat room exists with ID: ${state.roomId}');
                roomId = state.roomId;
                context
                    .read<MessageReceiveBloc>()
                    .add(ListenForMessages(roomId: roomId));
              }
              if (state is ChatRoomNotExist) {
                // Trigger the creation of a new chat room
                context.read<ChatRoomBloc>().add(CreateChatRoom(widget.uid));
              }
              if (state is ChatRoomLoaded) {
                scrollToBottomWithoutAnimation();
              }
              if (state is ChatRoomCreated) {
                //print('Chat room created with ID: ${state.roomId}');
                roomId = state.roomId;
                context
                    .read<MessageReceiveBloc>()
                    .add(ListenForMessages(roomId: roomId));
              }
            },
          ),
          BlocListener<MessageSendBloc, MessageSendState>(
            listener: (context, state) {
              if (state is AzureSentimentAnalysisSuccessState) {
                if (state.analysisResult == 'negative') {
                  sensibility = state.analysisResult;

                  //추천 메시지 ChatGPT Recommend Message Event
                  context.read<MessageSendBloc>().add(
                      ChatGptRecommendMessageEvent(
                          _textEditingController.text));
                } else {
                  //mixed, neutral, positive 일 때
                  //Firebase에 메시지 저장
                  context.read<MessageSendBloc>().add(FirebaseMessageSaveEvent(
                      roomId: roomId,
                      senderName: myName,
                      senderUID: myUid,
                      originalMessageContent: _textEditingController.text,
                      convertMessageContent: '',
                      timestamp: DateTime.now().toString(),
                      isConvertMessage: false,
                      sentiment: state.analysisResult));
                  //텍스트 필드 비우기
                  _textEditingController.clear();
                }
              }
              if (state is ChatGptRecommendMessageState) {
                //print('GPT 추천 메시지: ${state.chatGptRecommendResponse}');
                setState(() {
                  recommandMessage = state.chatGptRecommendResponse;
                  _isRecommendMessageWidgetVisible = true;
                });
              }
              if (state is ChatGPTSendMessageSendErrorState) {
                // Handle the error
                //print('Error: ${state.error}');
              }
            },
          ),
        ],
        child: totalWidet(),
      ),
    );
  }

  Widget modeOnOff() {
    // No changes needed to your method signature
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('원본 메시지 확인'),
                Switch(
                  value: originalMessageCheckMode,
                  onChanged: (value) {
                    setModalState(() {
                      originalMessageCheckMode = value;
                    });
                    // You can still call the main setState if you need to update the main page
                    setState(() {});
                  },
                  activeTrackColor: Colors.lightGreenAccent,
                  activeColor: Colors.green,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('변환된 메시지 확인'),
                Switch(
                  value: isConvertMessageCheckMode,
                  onChanged: (value) {
                    setModalState(() {
                      isConvertMessageCheckMode = value;
                    });
                    // Same here for the main page update if necessary
                    setState(() {});
                  },
                  activeTrackColor: Colors.lightGreenAccent,
                  activeColor: Colors.green,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget totalWidet() {
    return Column(
      children: [
        Expanded(
          child: BlocBuilder<MessageReceiveBloc, MessageReceiveState>(
            builder: (context, state) {
              if (state is MessagesUpdated) {
                if (_previousMessageCount != state.messages.length) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      scrollToBottom();
                    }
                  });
                  _previousMessageCount = state.messages.length;
                }

                return messagingWidget(state.messages);
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
        ),
        Form(
          child: Stack(
            children: [
              Column(
                children: [
                  recommendMessageWidget(),
                  typingMessageWidget(),
                  KeyboardVisibilityBuilder(
                      builder: (context, isKeyboardVisible) {
                    return Visibility(
                      visible: !isKeyboardVisible &&
                          !_isRecommendMessageWidgetVisible,
                      child: const Column(
                        children: [
                          Divider(
                            height: 1,
                            thickness: 1,
                          ),
                          SizedBox(
                            height: 25,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget messagingWidget(List<Message> messages) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        Message message = messages[index];
        bool isSender = message.senderUID == myUid;
        return messageContainer(message, isSender: isSender);
      },
    );
  }

  Widget messageContainer(Message message, {required bool isSender}) {
    String messageKey = '${message.senderUID}_${message.timestamp}';
    bool isOriginalVisible = _originalMessageVisibility[messageKey] ?? false;
    final bool isConvertMessage = message.isConvertMessage;

    return Column(
      children: [
        Container(
          color: isSender ? Colors.white : Colors.grey[100],
          child: ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: isSender
                  ? (myImageUrl == ''
                      ? const AssetImage('assets/images/default_profile.png')
                      : NetworkImage(myImageUrl) as ImageProvider)
                  : (friendImageUrl == ''
                      ? const AssetImage('assets/images/default_profile_2.jpg')
                      : NetworkImage(friendImageUrl) as ImageProvider),
            ),
            title: Row(
              children: [
                Text(
                  message.senderName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  //timestamp값은 24-01-10 19:50 까지만 표시
                  message.timestamp.substring(2, 16),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Visibility(
                          child: isConvertMessageCheckMode && isConvertMessage
                              ? const Icon(Icons.published_with_changes_rounded,
                                  size: 20, color: Colors.blueAccent)
                              : const SizedBox(width: 5)),
                    ],
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConvertMessage
                      ? message.convertMessageContent
                      : message.originalMessageContent,
                  style: const TextStyle(fontSize: 14),
                ),
                Visibility(
                  visible: isOriginalVisible && originalMessageCheckMode,
                  child: Text(message.originalMessageContent,
                      style: const TextStyle(fontSize: 14, color: Colors.blue)),
                ),
                Visibility(
                  visible: isConvertMessage && originalMessageCheckMode,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _originalMessageVisibility[messageKey] =
                                !isOriginalVisible;
                          });
                          if (_originalMessageVisibility[messageKey] == true) {
                            //원본메시지 확인버튼 클릭시 로그 기록
                            context.read<ChatActionLogBloc>().add(
                                ChatActionLogEvent(
                                    ChatAction.viewOriginalMessage,
                                    roomId,
                                    myName));
                          } else {
                            //원본메시지 숨기기 버튼 클릭시 로그 기록
                            context.read<ChatActionLogBloc>().add(
                                ChatActionLogEvent(
                                    ChatAction.viewOriginalMessageClose,
                                    roomId,
                                    myName));
                          }
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                                !isOriginalVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                size: 20,
                                color: Colors.grey),
                            const SizedBox(width: 5),
                            Text(
                              isOriginalVisible ? '원본 메시지 숨기기' : '원본 메시지 확인',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1),
      ],
    );
  }

  Widget typingMessageWidget() {
    return Padding(
      padding: const EdgeInsets.only(left: 15, bottom: 5),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _textEditingController,
              focusNode: textFieldFocusNode, // Attach the focus node here
              decoration: const InputDecoration(
                hintText: '메시지를 입력하세요',
                border: UnderlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
          ),
          BlocBuilder<MessageSendBloc, MessageSendState>(
            builder: (context, state) {
              if (state is ChatGPTSendMessageSendingState) {
                // Show loading indicator when message is being sent
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: CircularProgressIndicator(),
                );
              } else {
                // Show send button when not sending a message
                return Visibility(
                  visible: !_isRecommendMessageWidgetVisible,
                  child: IconButton(
                    onPressed: () {
                      // Only allow message send if text field has content
                      if (_textEditingController.text.isNotEmpty) {
                        context.read<MessageSendBloc>().add(
                            AzureSentimentAnalysisEvent(
                                _textEditingController.text));

                        //메시지 전송 로그 기록
                        context.read<ChatActionLogBloc>().add(
                            ChatActionLogEvent(
                                ChatAction.send, roomId, myName));
                      }
                    },
                    icon: const Icon(Icons.send),
                  ),
                );
              }
            },
          ),
          Visibility(
            // 새로고침버튼
            visible: _isRecommendMessageWidgetVisible,
            child: IconButton(
                onPressed: () {
                  if (_textEditingController.text.isNotEmpty) {
                    context.read<MessageSendBloc>().add(
                        ChatGptRecommendMessageEvent(
                            _textEditingController.text));
                    //새로고침 로그 기록
                    context.read<ChatActionLogBloc>().add(
                        ChatActionLogEvent(ChatAction.refresh, roomId, myName));
                  }
                },
                icon: const Icon(Icons.refresh, color: Colors.blueAccent)),
          ),
          Visibility(
            visible: _isRecommendMessageWidgetVisible,
            child: IconButton(
              onPressed: () {
                //recommandMessageWidget Toggle
                setState(() {
                  _isRecommendMessageWidgetVisible = false;
                });

                //Firebase에 메시지 저장
                context.read<MessageSendBloc>().add(FirebaseMessageSaveEvent(
                    roomId: roomId,
                    senderName: myName,
                    senderUID: myUid,
                    originalMessageContent: _textEditingController.text,
                    convertMessageContent: recommandMessage,
                    timestamp: DateTime.now().toString(),
                    isConvertMessage: false,
                    sentiment: sensibility));

                //추천메시지 상태에서 메시지 전송 로그 기록
                context.read<ChatActionLogBloc>().add(
                    ChatActionLogEvent(ChatAction.arrowUpward, roomId, myName));

                _textEditingController.clear();
              },
              icon: const Icon(Icons.arrow_upward, color: Colors.blueAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget recommendMessageWidget() {
    return Visibility(
      visible: _isRecommendMessageWidgetVisible,
      child: Container(
        width: double.infinity,
        color: Colors.lime[100],
        child: Stack(
          children: [
            recommandMessageCard(),
            // Close button
            Positioned(
              right: 0,
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _isRecommendMessageWidgetVisible = false;
                  });
                },
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget recommandMessageCard() {
    return InkWell(
      child: Card(
        margin: const EdgeInsets.fromLTRB(10, 10, 40, 10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
          child: Text(
            recommandMessage,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
      onTap: () {
        setState(() {
          _isRecommendMessageWidgetVisible = false;

          //Firebase에 메시지 저장
          context.read<MessageSendBloc>().add(FirebaseMessageSaveEvent(
              roomId: roomId,
              senderName: myName,
              senderUID: myUid,
              originalMessageContent: _textEditingController.text,
              convertMessageContent: recommandMessage,
              timestamp: DateTime.now().toString(),
              isConvertMessage: true,
              sentiment: sensibility));

          //추천메시지 카드 클릭시 로그 기록
          context.read<ChatActionLogBloc>().add(ChatActionLogEvent(
              ChatAction.recommandMessageCard, roomId, myName));

          _textEditingController.clear();
        });
      },
    );
  }
}
