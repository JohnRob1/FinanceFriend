import 'dart:async';
import 'package:financefriend/ff_appbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_http_request.dart';
import 'package:intl/intl.dart';
import 'home.dart';
import 'package:table_calendar/table_calendar.dart';

final firebaseApp = Firebase.app();
final database = FirebaseDatabase.instanceFor(
  app: firebaseApp,
  databaseURL: "https://financefriend-41da9-default-rtdb.firebaseio.com/",
);
final reference = database.ref();
final currentUser = FirebaseAuth.instance.currentUser;

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController billTitleController = TextEditingController();
  final TextEditingController billAmountController = TextEditingController();
  final TextEditingController billNoteController = TextEditingController();
  final TextEditingController billDateController = TextEditingController();

  // Calendar info
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<String>> _events = {};

  DateTime _parseDate(String date) {
    String year = date.substring(6);
    String month = date.substring(0, 2);
    String day = date.substring(3, 5);
    String reformattedDate = year + '-' + month + '-' + day;
    return DateTime.parse(reformattedDate);
  }

  Future<bool> _billNotifsOn() async {
    DatabaseReference settingsRef =
        reference.child('users/${currentUser?.uid}').child('settings');
    DataSnapshot settings = await settingsRef.get();
    if (!settings.hasChild('allNotifs')) {
      settingsRef.child('allNotifs').set(true);
    } else if (!(settings.child('allNotifs').value as bool)) {
      return false;
    }
    if (!settings.hasChild('billNotifs')) {
      settingsRef.child('billNotifs').set(true);
      return true;
    } else {
      return (settings.child('billNotifs').value as bool);
    }
  }

  void _writeNotif(String billTitle, String dueDate) {
    String title = billTitle + ' is due soon!';
    String note = 'This bill is due on ' + dueDate;
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
      print('Error writing bill notification: $error');
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      if (_selectedDay != null) {
        _openNotificationsDialog();
      }
    }
  }

  bool _validBillInput() {
    String title = billTitleController.text;
    if (title.isEmpty) return false;
    String amount = billAmountController.text;
    if (amount.isEmpty) return false;
    if (amount.contains(RegExp(r'[A-Za-z]'))) return false;
    String duedate = billDateController.text;
    if (duedate.isEmpty) return false;
    if (duedate.length != 10) return false;
    if (duedate.contains(RegExp(r'[A-Za-z]'))) return false;
    if (duedate[2] != '/' || duedate[5] != '/') return false;
    return true;
  }

  void _writeBill() async {
    try {
      String title = billTitleController.text.trim();
      String amount = billAmountController.text.trim();
      String note = billNoteController.text.trim();
      String duedate = billDateController.text.trim();
      DatabaseReference newBill =
          reference.child('users/${currentUser?.uid}/bills').push();
      newBill.set({
        'title': title,
        'amount': amount,
        'note': note,
        'duedate': duedate,
      });
      if (await _billNotifsOn()) {
        DateTime parsedDueDate = _parseDate(duedate);
        if (parsedDueDate.isAfter(DateTime.now()) &&
            parsedDueDate.difference(DateTime.now()).inDays <= 7) {
          _writeNotif(title, duedate);
        }
        setState(() {});
      }
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Bill added successfully! Refresh to update page.'),
      //   ),
      // );
    } catch (error) {
      print('Error adding bill: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add bill.'),
        ),
      );
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[day] ?? [];
  }

  void _deleteBill(String id) {
    try {
      DatabaseReference billsRef =
          reference.child('users/${currentUser?.uid}/bills');
      billsRef.child(id).remove();
      setState(() {});
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //     content: Text('Bill deleted successfully! Refresh to update page.'),
      //   ),
      // );
    } catch (error) {
      print(error);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete bill.'),
        ),
      );
    }
  }

  void _navigateToHomePage(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => HomePage(),
    ));
  }

  List<Map<String, String>> results = [];
  DataRow _getDataRow(index, data) {
    return DataRow(
      cells: <DataCell>[
        DataCell(Text(data['title'])),
        DataCell(Text("\$" + data['amount'])),
        DataCell(Text(data['note'])),
        DataCell(Text(data['duedate'])),
        DataCell(IconButton(
          icon: Image.asset('images/DeleteButton.png'),
          onPressed: () => _deleteBill(data['id']),
        )),
      ],
    );
  }

  double billTotal = 0.0;
  Future _fetchBills() async {
    billTotal = 0.0;
    DatabaseReference userRef = reference.child('users/${currentUser?.uid}');

    DataSnapshot user = await userRef.get();
    if (!user.hasChild('bills')) {
      return;
    }

    DataSnapshot bills = await userRef.child('bills').get();
    Map<String, dynamic> billsMap = bills.value as Map<String, dynamic>;
    results = [];
    billsMap.forEach((key, value) {
      var amount = value['amount'] != null ? value['amount'].toString() : '0';
      results.add({
        'id': key.toString(),
        'title': value['title'].toString(),
        'amount': amount,
        'note': value['note'].toString(),
        'duedate': value['duedate'].toString()
      });
      billTotal += double.parse(amount);
    });

    return results;
  }

  void _addBillToCalendar(String dueDate, String title) {
    final DateTime parsedDueDate = DateTime.parse(dueDate);
    if (_events.containsKey(parsedDueDate)) {
      _events[parsedDueDate]!.add(title);
    } else {
      _events[parsedDueDate] = [title];
    }
  }

  void _removeBillFromCalendar(String dueDate) {
    final DateTime parsedDueDate = DateTime.parse(dueDate);
    if (_events.containsKey(parsedDueDate)) {
      _events.remove(parsedDueDate);
    }
  }

  void _openAddBillDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Stack(
          children: <Widget>[
            Positioned(
              right: -40,
              top: -40,
              child: InkResponse(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: const CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Icon(Icons.close),
                ),
              ),
            ),
            Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Please input bill data that you would like us to keep track of.',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        const Text('Title: ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              hintText: 'Enter a title to identify the bill',
                            ),
                            controller: billTitleController,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        const Text('Amount: ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              hintText: "Enter the amount owed for the bill",
                            ),
                            controller: billAmountController,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        const Text('Notes: ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              hintText:
                                  "OPTIONAL: Enter any notes relating to the bill",
                            ),
                            controller: billNoteController,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        const Text('Due Date: ',
                            style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              hintText: 'MM/DD/YYYY',
                            ),
                            controller: billDateController,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          child: const Text('Submit'),
                          onPressed: () {
                            if (_validBillInput()) {
                              _writeBill();
                              Navigator.of(context).pop();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Failed to add bill. Please ensure that all required fields are formatted correctly.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        ElevatedButton(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNotificationsDialog() async {
    if (_selectedDay == null) return;

    final selectedDayFormatted = DateFormat('MM/dd/yyyy').format(_selectedDay!);

    final matchingBills = results
        .where(
          (bill) => bill['duedate'] == selectedDayFormatted,
        )
        .toList();

    if (matchingBills.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: Stack(
            children: <Widget>[
              Positioned(
                right: -40,
                top: -40,
                child: InkResponse(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: const CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Icon(Icons.close),
                  ),
                ),
              ),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Bill Information',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                    for (var bill in matchingBills)
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Text('Title: ', style: TextStyle(fontSize: 14)),
                                Text(bill['title']!,
                                    style: TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Text('Amount: ',
                                    style: TextStyle(fontSize: 14)),
                                Text(bill['amount']!,
                                    style: TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Text('Notes: ', style: TextStyle(fontSize: 14)),
                                Text(bill['note']!,
                                    style: TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Text('Due Date: ',
                                    style: TextStyle(fontSize: 14)),
                                Text(bill['duedate']!,
                                    style: TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            child: const Text('Add New Bill'),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _openAddBillDialog();
                            },
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
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FFAppBar(),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            width: 600,
            height: 900,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  // Calendar Start
                  Card(
                    margin: const EdgeInsets.all(10),
                    elevation: 10,
                    color: Colors.green,
                    child: TableCalendar(
                      headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold)),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.bold),
                        weekendStyle: TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.bold),
                      ),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      onDaySelected: _onDaySelected,
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2025),
                      eventLoader: _getEventsForDay,
                      calendarStyle: const CalendarStyle(
                        todayDecoration: BoxDecoration(
                            color: Colors.grey, shape: BoxShape.circle),
                        selectedDecoration: BoxDecoration(
                            color: Colors.blueGrey, shape: BoxShape.circle),
                        defaultTextStyle: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        weekendTextStyle: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        outsideTextStyle: TextStyle(
                            color: Color(0xFFBBBBBB),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // Calendar End
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      width: 1750,
                      height: 2,
                      color: Colors.green,
                    ),
                  ),
                  const Text('Bills',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  RefreshIndicator(
                    onRefresh: () async {
                      return await _fetchBills();
                    },
                    child: FutureBuilder(
                      future: _fetchBills(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          results = snapshot.data;
                          if (snapshot.data.length != 0) {
                            return Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  child: DataTable(
                                    headingRowColor:
                                        MaterialStateColor.resolveWith(
                                      (states) => Colors.green,
                                    ),
                                    columnSpacing: 50,
                                    columns: [
                                      DataColumn(label: Text('Title')),
                                      DataColumn(label: Text('Amount')),
                                      DataColumn(label: Text('Notes')),
                                      DataColumn(label: Text('Due Date')),
                                      DataColumn(label: Text('Delete')),
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
                                ),
                                Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                      'Total Owed: \$' +
                                          billTotal.toStringAsFixed(2),
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    )),
                              ],
                            );
                          } else {
                            return const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text(
                                      'You have no saved bills. Try adding one!'),
                                ),
                              ],
                            );
                          }
                        } else {
                          return const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Padding(
                                padding: EdgeInsets.all(40),
                                child: Text(
                                    'You have no saved bills. Try adding one!'),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _openAddBillDialog,
                    child: const Text('Add Bill'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
