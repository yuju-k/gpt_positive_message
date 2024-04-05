import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Events
abstract class ContactsEvent {}

class LoadContacts extends ContactsEvent {}

class SearchContacts extends ContactsEvent {
  final String query;
  SearchContacts(this.query);
}

// States
abstract class ContactsState {}

class ContactsLoading extends ContactsState {}

class ContactsLoaded extends ContactsState {
  final List<Map<String, dynamic>> contacts;

  ContactsLoaded({required this.contacts});
}

class ContactsSearchResults extends ContactsState {
  final List<Map<String, dynamic>> searchResults;

  ContactsSearchResults({required this.searchResults});
}

class ContactsFailure extends ContactsState {
  final String error;

  ContactsFailure({required this.error});
}

//** 사용자 추가 */
class AddUser extends ContactsEvent {
  final String userEmail;
  AddUser(this.userEmail);
}

// 로딩중
class AddUserLoading extends ContactsState {}

class AddUserSuccess extends ContactsState {
  final String userEmail;
  AddUserSuccess(this.userEmail);
}

class AddUserFailure extends ContactsState {
  final String error;
  AddUserFailure(this.error);
}

// Bloc
class ContactsBloc extends Bloc<ContactsEvent, ContactsState> {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Use List<Map<String, dynamic>> to match the ContactsLoaded state
  List<Map<String, dynamic>> allContacts = [];

  ContactsBloc({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        super(ContactsLoading()) {
    on<LoadContacts>(_loadContacts);
    on<SearchContacts>(_searchContacts);
    on<AddUser>(_addUser);
  }

  Future<void> _addUser(AddUser event, Emitter<ContactsState> emit) async {
    emit(AddUserLoading());
    try {
      var user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Check if the user is trying to add themselves
      if (user.email == event.userEmail) {
        throw Exception('You cannot add yourself as a friend');
      }

      DocumentSnapshot friendProfileDoc =
          await _firestore.doc('user_profile/${event.userEmail}').get();

      if (friendProfileDoc.exists) {
        Map<String, dynamic> friendData =
            friendProfileDoc.data()! as Map<String, dynamic>;
        allContacts.add({
          'name': friendData['name'],
          'email': friendData['email'],
          'imageUrl': friendData['imageUrl'],
          'statusMessage': friendData['statusMessage'],
        });

        // Add friend to user's friends collection
        await _firestore
            .collection('user_profile')
            .doc('${user.email}')
            .collection('friends')
            .add({
          'profile_ref': 'user_profile/${event.userEmail}',
        });
      } else {
        throw Exception('User not found');
      }

      emit(AddUserSuccess(event.userEmail));
      // Also trigger loading of updated contacts
      // add(LoadContacts());
    } catch (e) {
      emit(AddUserFailure(e.toString()));
    }
  }

  Future<void> _loadContacts(
      LoadContacts event, Emitter<ContactsState> emit) async {
    emit(ContactsLoading());
    try {
      var user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      QuerySnapshot friendsSnapshot = await _firestore
          .collection('user_profile')
          .doc('${user.email}')
          .collection('friends')
          .get();

      //allContacts.clear();
      allContacts = [];

      for (var doc in friendsSnapshot.docs) {
        var data = doc.data();
        if (data is Map<String, dynamic>) {
          // Now that we have a Map, we can safely use the [] operator.
          String profileRef = data['profile_ref'] as String;
          DocumentSnapshot friendProfileDoc =
              await _firestore.doc(profileRef).get();

          if (friendProfileDoc.exists) {
            Map<String, dynamic> friendData =
                friendProfileDoc.data()! as Map<String, dynamic>;
            allContacts.add({
              'name': friendData['name'],
              'email': friendData['email'],
              'imageUrl': friendData['imageUrl'],
              'statusMessage': friendData['statusMessage'],
              'uid': friendData['uid'],
            });
          }
        }
      }

      emit(ContactsLoaded(contacts: allContacts));
    } catch (e) {
      emit(ContactsFailure(error: e.toString()));
    }
  }

  Future<void> _searchContacts(
      SearchContacts event, Emitter<ContactsState> emit) async {
    if (event.query.isEmpty) {
      emit(ContactsLoaded(contacts: allContacts));
    } else {
      final searchResults = allContacts.where((contact) {
        // Safely handle null values
        final nameLower = (contact['name'] as String? ?? '').toLowerCase();
        final queryLower = event.query.toLowerCase();
        return nameLower.contains(queryLower);
      }).toList();
      emit(ContactsSearchResults(searchResults: searchResults));
    }
  }
}
