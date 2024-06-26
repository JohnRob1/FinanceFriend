import 'package:flutter/material.dart';
import 'package:financefriend/ff_appbar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'location_card_widget.dart';

final firebaseApp = Firebase.app();
final database = FirebaseDatabase.instanceFor(
  app: firebaseApp,
  databaseURL: "https://financefriend-41da9-default-rtdb.firebaseio.com/",
);
final reference = database.ref();
final currentUser = FirebaseAuth.instance.currentUser;

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  void _writeNotif(String title, String note) {
    try {
      DatabaseReference notifRef =
          reference.child('users/${currentUser?.uid}/notifications');
      DatabaseReference newNotif = notifRef.push();
      newNotif.set({
        'title': title,
        'note': note,
      });
      notifRef.child('state').set(1);
    } catch (error) {
      print(error);
    }
  }

  void _silenceNotifs() {
    try {
      DatabaseReference notifRef =
          reference.child('users/${currentUser?.uid}/notifications');
      notifRef.child('state').set(0);
    } catch (error) {
      print(error);
    }
  }

  void _deleteNotif(String id) async {
    try {
      DatabaseReference notifRef =
          reference.child('users/${currentUser?.uid}/notifications');
      notifRef.child(id).remove();
      DataSnapshot notifs = await notifRef.get();
      if (notifs.children.length <= 1) {
        notifRef.child('state').set(0);
      }
      setState(() {});
    } catch (error) {
      print(error);
    }
  }

  void _acceptRequest(String note, String id) async {
    try {
      String userName =
          note.substring(note.indexOf(' friend ') + 8, note.indexOf(' would '));
      String typeS = note.substring(note.indexOf(' would '));
      String type = '';
      if (typeS.contains('bill')) {
        type = 'calendar';
      } else if (typeS.contains('budget')) {
        type = 'budgets';
      }
      DatabaseReference settingsRef =
          reference.child('users/${currentUser?.uid}/settings');
      DataSnapshot settings = await settingsRef.get();
      if (!settings.hasChild('permissions') ||
          !(settings.child('permissions').hasChild(userName) &&
              settings.child('permissions').child(userName).child(type).value ==
                  true)) {
        settingsRef.child('permissions').child(userName).child(type).set(true);
      }
    } catch (error) {
      print(error);
    }
    _deleteNotif(id);
  }

  List<Map<String, String>> results = [];
  Future _fetchNotifs() async {
    DatabaseReference userRef = reference.child('users/${currentUser?.uid}');

    DataSnapshot user = await userRef.get();
    if (!user.hasChild('notifications')) {
      return;
    }

    DataSnapshot notifs = await userRef.child('notifications').get();
    Map<String, dynamic> notifsMap = notifs.value as Map<String, dynamic>;
    results = [];
    notifsMap.forEach((key, value) {
      if (key != 'state' && key != 'notifTime') {
        results.add({
          'id': key.toString(),
          'title': value['title'].toString(),
          'note': value['note'].toString(),
        });
      }
    });

    return results;
  }

  DataRow _getDataRow(index, data) {
    if (data['title'].split(': ')[0] == "Location") {
      return DataRow(
        cells: <DataCell>[
          DataCell(Text(data['title'])),
          DataCell(Text(data['note'])),
          DataCell(
              /*TextField(
            decoration: const InputDecoration(labelText: 'Enter a number'),
            onSubmitted: (value) {
              
            },
          )*/
              LocationInput(
            date: data['note'].split(': ')[0],
            locationAddress: data['note'].split(': ')[1],
            locationName: data['title'].split(': ')[1],
            deleteNotif: () => _deleteNotif(data['id']),
          )),
        ],
      );
    } else if (data['title'].contains('Request to View ')) {
      return DataRow(cells: <DataCell>[
        DataCell(Text(data['title'])),
        DataCell(Text(data['note'])),
        DataCell(Row(children: [
          ElevatedButton(
            child: const Text('Accept'),
            onPressed: () => _acceptRequest(data['note'], data['id']),
          ),
          ElevatedButton(
            child: const Text('Deny'),
            onPressed: () => _deleteNotif(data['id']),
          ),
        ])),
      ]);
    } else {
      return DataRow(
        cells: <DataCell>[
          DataCell(Text(data['title'])),
          DataCell(Text(data['note'])),
          DataCell(IconButton(
            icon: Image.asset('images/DeleteButton.png'),
            onPressed: () => _deleteNotif(data['id']),
          )),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FFAppBar(),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            alignment: Alignment.center,
            child: const Text('Notifications', style: TextStyle(fontSize: 32)),
          ),
          FutureBuilder(
              future: _fetchNotifs(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  results = snapshot.data;
                  if (snapshot.data.length != 0) {
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                      ),
                      child: DataTable(
                        headingRowColor: MaterialStateColor.resolveWith(
                          (states) => Colors.green,
                        ),
                        columnSpacing: 30,
                        columns: [
                          DataColumn(
                              label: Text('Title',
                                  style: TextStyle(color: Colors.white))),
                          DataColumn(
                              label: Text('Note',
                                  style: TextStyle(color: Colors.white))),
                          DataColumn(
                              label: Text('Actions',
                                  style: TextStyle(color: Colors.white))),
                        ],
                        rows: List.generate(
                          results.length,
                          (index) => _getDataRow(
                            index,
                            results[index],
                          ),
                        ),
                        showBottomBorder: true,
                      ),
                    );
                  } else {
                    return const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.all(40),
                          child: Text('You have no notifications'),
                        ),
                      ],
                    );
                  }
                } else {
                  return const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(),
                      ),
                      Padding(
                        padding: EdgeInsets.all(40),
                        child: Text('No Data Found...'),
                      ),
                    ],
                  );
                }
              }),
          ElevatedButton(
            onPressed: _silenceNotifs,
            child: const Text('Mark Notifications As Read'),
          ),
        ]),
      ),
    );
  }
}
