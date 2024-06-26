import 'package:financefriend/budget_tracking_widgets/budget.dart';
import 'package:financefriend/budget_tracking_widgets/wishlist.dart';
//import 'package:financefriend/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:pie_chart/pie_chart.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:financefriend/budget_tracking_widgets/budget_db_utils.dart';
import 'budget_tracking_widgets/budget_creation.dart';
import 'budget_tracking_widgets/expense_tracking.dart';
import 'budget_tracking_widgets/usage_table.dart';
import 'budget_tracking_widgets/budget_category.dart';
import 'budget_tracking_widgets/budget_colors.dart';

class BudgetTracking extends StatefulWidget {
  @override
  _BudgetTrackingState createState() => _BudgetTrackingState();
}

class _BudgetTrackingState extends State<BudgetTracking> {
  late TextEditingController controller;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  TextEditingController newBudgetNameController =
      TextEditingController(); // Step 1: Create the controller

  String actualCategory = "";
  bool values_added = false;

  String selectedCategory = "Select Category";
  bool isFormValid = false;
  bool budgetCreated = false;

  List<Expense> expenseList = <Expense>[];
  List<Color> colorList = <Color>[];

  Map<String, double> budgetMap = {};

  double budgetAmount = 0;
  String budgetName = "";

  List<String> budgetList = [];
  List<WishListItem> wishlistLoaded = [];

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    loadBudgetListFromDB();
    getBudgetListFromFirebase(); // Fetch the list of budget names
    loadWishlistFromDB();
  }

  Future<void> loadWishlistFromDB() async {
    if (currentUser == null) {
      return;
    }

    List<WishListItem> tempWishList = await getWishlistFromDB();
    setState(() {
      wishlistLoaded = tempWishList;
    });
  }

  Future<void> loadBudgetListFromDB() async {}

  Future<void> getBudgetListFromFirebase() async {
    if (currentUser == null) {
      return;
    }

    try {
      final budgetsRef = reference.child('users/${currentUser?.uid}/budgets');

      DatabaseEvent event = await budgetsRef.once();
      DataSnapshot snapshot = event.snapshot;

      if (snapshot.value != null) {
        Map<String, dynamic> budgetData =
            snapshot.value as Map<String, dynamic>;

        // Extract the list of budget keys
        List<String> budgetKeys = budgetData.keys.toList();

        setState(() {
          budgetList = budgetKeys;
        });
      }
    } catch (error) {
      print("Error fetching budget list from Firebase: $error");
    }
  }

  // Function to open a specific budget based on the selected budget name
  void openBudget(String selectedBudgetName) {
    setState(() {
      budgetName = selectedBudgetName;
      budgetMap = {}; // Clear the current budget map
      budgetCreated = false; // Reset budgetCreated to indicate loading
      colorList = greenColorList;
    });

    // Fetch the selected budget data and update your UI
    getBudgetFromFirebaseByName(selectedBudgetName).then((selectedBudget) {
      if (selectedBudget != null) {
        setState(() {
          budgetMap = selectedBudget.budgetMap;
          expenseList = selectedBudget.expenses;
          budgetName = selectedBudget.budgetName;
          colorList = selectedBudget.colorList;
          budgetCreated = true; // Set budgetCreated to true when data is loaded
          // Load other budget-related data as needed
        });
      } else {
        // Handle the case where the budget data could not be retrieved
        print("Error loading budget data.");
        // You can show an error message to the user if needed.
      }
    }).catchError((error) {
      print("Error fetching budget data: $error");
      // Handle the error. You might want to show an error message to the user.
    });

    getWishlistFromDB().then((wishlist) {
      if (wishlist != null) {
        setState(() {
          wishlistLoaded = wishlist;
        });
      } else {
        print("Error locating wishlist");
      }
    }).catchError((error) {
      print("Error locating error: $error");
    });
  }

  // Build the list of budget buttons
  Widget buildBudgetButtons() {
    if (budgetList.isEmpty) {
      return const Text("");
    }

    return Container(
      width: 300,
      child: Card(
        margin: const EdgeInsets.all(16),
        color: Colors.green,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Existing Budgets:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white),
                      ),
                    ],
                  ),
                  Container(
                    width: 200, // Set a fixed width for the divider
                    child: const Divider(
                      color: Colors.white, // Change the color as needed
                      thickness: 1.0, // Adjust the thickness as needed
                    ),
                  ),
                ],
              ),
            ),
            ...budgetList.map((budgetName) {
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      openBudget(budgetName);
                    },
                    child: Text("Open Budget: $budgetName"),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  final Color color =
      Color(int.parse("#248712".substring(1, 7), radix: 16) + 0xFF0000000);

  List<String> dropdownItems = [
    "Select Category",
    "Housing",
    "Utilities",
    "Food",
    "Transportation",
    "Entertainment",
    "Investments",
    "Debt Payments",
    "Custom",
  ];

  var options = ["Option 1", "Option 2", "Option 3"];

  TextEditingController customCategoryController = TextEditingController();
  bool isOtherSelected = false;
  bool afterBudgetAmt = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          leading: IconButton(
            icon: Image.asset('images/FFLogo.png'),
            onPressed: () {
              // if (seeTransitions) {
              //   Navigator.push(
              //     context,
              //     PageRouteBuilder(
              //       pageBuilder: (context, animation, secondaryAnimation) {
              //         return HomePage(); // Replace with your actual page widget
              //       },
              //       transitionsBuilder:
              //           (context, animation, secondaryAnimation, child) {
              //         const begin = 0.0;
              //         const end = 1.0;
              //         const curve = Curves.easeInOut;
              //         const duration =
              //             Duration(milliseconds: 2000); // Adjust the duration here

              //         var tween = Tween(begin: begin, end: end)
              //             .chain(CurveTween(curve: curve));

              //         var opacityAnimation = animation.drive(tween);

              //         return FadeTransition(
              //           opacity: opacityAnimation,
              //           child: child,
              //         );
              //       },
              //       transitionDuration: const Duration(
              //           milliseconds: 2000), // Adjust the duration here
              //     ),
              //   );
              // } else {
              // If seeTransitions is false, simply navigate to the home page
              Navigator.pop(
                context,
                //MaterialPageRoute(builder: (context) => HomePage()),
              );
              //}
            },
          ),
          title: const Text(
            'Finance Friend',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 44,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          actions: <Widget>[
            IconButton(
              icon: Image.asset('images/Settings.png'),
              onPressed: () {}, //=> _openSettings(context),
            ),
          ],
        ),
        body: Row(
          children: [
            AnimatedContainer(
                duration: Duration(seconds: 2),
                width: 300,
                color: Colors.white,
                child: Column(
                  children: [
                    const SizedBox(
                      height: 20,
                    ),
                    Column(children: [
                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return BudgetCreationPopup(onBudgetCreated:
                                  (Map<String, double> budgetMap,
                                      String budgetName,
                                      List<Color> colorListRecieved) {
                                // Step 1: Create the budget in Firebase

                                createBudgetInFirebase(Budget(
                                        budgetName: budgetName,
                                        budgetMap: budgetMap,
                                        expenses: [],
                                        colorList: colorListRecieved))
                                    .then((result) {
                                  if (result == true) {
                                    // Step 2: Update local state after Firebase operation is successful
                                    setState(() {
                                      this.budgetMap = budgetMap;
                                      this.budgetName = budgetName;
                                      budgetCreated = true;
                                      this.budgetList.add(budgetName);
                                      this.colorList = colorListRecieved;
                                    });
                                  } else {
                                    // Handle error or show an error message
                                  }
                                });
                              });
                            },
                          );
                        },
                        child: const Text("Create New Budget"),
                      ),
                    ]),
                    const SizedBox(
                      height: 15,
                    ),
                    buildBudgetButtons(),
                  ],
                )),
            const VerticalDivider(
              color: Colors.black,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  clipBehavior: Clip.none,
                  child: Center(
                    child: Column(children: <Widget>[
                      Visibility(
                        visible: budgetMap.isNotEmpty,
                        child: Column(
                          children: <Widget>[
                            Visibility(
                              visible: budgetMap.isNotEmpty,
                              child: Center(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Budget: $budgetName",
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () {
                                            editBudgetName();
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 35),
                                    Builder(
                                      builder: (BuildContext context) {
                                        return ElevatedButton(
                                          onPressed: () async {
                                            final resp =
                                                await openAddToBudget();
                                            if (resp == null || resp.isEmpty) {
                                              return;
                                            }

                                            setState(() {
                                              if (!dropdownItems
                                                  .contains(actualCategory)) {
                                                dropdownItems.insert(
                                                    dropdownItems.length - 1,
                                                    actualCategory);
                                              }

                                              // Check if the category already exists in the budgetMap
                                              if (budgetMap.containsKey(
                                                  actualCategory)) {
                                                // If it exists, update the existing value
                                                double currentValue =
                                                    budgetMap[actualCategory] ??
                                                        0.0;
                                                double newValue =
                                                    double.parse(resp);
                                                budgetMap[actualCategory] =
                                                    currentValue + newValue;
                                              } else {
                                                // If it doesn't exist, add a new entry
                                                budgetMap[actualCategory] =
                                                    double.parse(resp);
                                              }
                                              values_added = true;
                                            });
                                          },
                                          child: const Text(
                                              "Add Spending Category",
                                              style: TextStyle()),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 35),
                                    Visibility(
                                      visible: budgetMap.isNotEmpty,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Column(
                                            children: <Widget>[
                                              const SizedBox(height: 35),
                                              BudgetPieChart(
                                                budgetMap: budgetMap,
                                                valuesAdded:
                                                    budgetMap.isNotEmpty,
                                                colorList: colorList,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(
                                            width: 30,
                                          ),
                                          Container(
                                            width: 2,
                                            height: 500,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(
                                            width: 30,
                                          ),
                                          Column(
                                            children: [
                                              BudgetUsageTable(
                                                budget: Budget(
                                                    budgetMap: budgetMap,
                                                    budgetName: budgetName,
                                                    expenses: expenseList,
                                                    colorList: colorList),
                                                expensesList: expenseList,
                                              )
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 35),
                                    Center(
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            ElevatedButton(
                                              onPressed: () {
                                                openColorChoice((newColorList) {
                                                  setState(() {
                                                    colorList = newColorList;
                                                  });
                                                });
                                              },
                                              child:
                                                  Text("Change Chart Colors"),
                                            ),
                                            SizedBox(
                                              width: 10,
                                            ),
                                            ElevatedButton(
                                              onPressed: openBudgetTable,
                                              child: const Text(
                                                  "View/Edit Current Budget",
                                                  style: TextStyle()),
                                            ),
                                          ]),
                                    ),
                                    const SizedBox(height: 35),
                                  ],
                                ),
                              ),
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(width: 20),
                                  Column(
                                    children: [
                                      ExpenseTracking(
                                        budget: Budget(
                                            budgetMap: budgetMap,
                                            expenses: expenseList,
                                            budgetName: budgetName,
                                            colorList: colorList),
                                        dropdownItems: dropdownItems,
                                        onExpensesListChanged:
                                            (updatedExpensesList) {
                                          setState(() {
                                            expenseList = updatedExpensesList;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 20),
                                ],
                              ),
                            ),
                            const SizedBox(
                              height: 35,
                            ),
                            WishList(
                              budget: Budget(
                                  budgetMap: budgetMap,
                                  budgetName: budgetName,
                                  expenses: expenseList,
                                  colorList: colorList),
                              wishlist: wishlistLoaded,
                            ),
                            const SizedBox(
                              height: 35,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  // Exports the current budget to a downloadable CSV file
                                  child: const Text(
                                    "Export Budget",
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                  onPressed: () {
                                    exportBudget();
                                  },
                                ),
                                const SizedBox(
                                  width: 20,
                                ),
                                ElevatedButton(
                                  // Add a button to delete the budget
                                  child: const Text(
                                    "Delete Budget",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  onPressed: () {
                                    deleteBudget();
                                    setState(() {
                                      budgetList.remove(this.budgetName);
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 35,
                            )
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ));
  }

  void exportBudget() {
    List<List<dynamic>> csvList = [
      ['Category', 'Amount']
    ];
    budgetMap.forEach((category, amount) {
      csvList.add([category, amount]);
    });

    String csv = const ListToCsvConverter().convert(csvList);
    String filename = budgetName.trim().replaceAll(' ', '_') + '.csv';

    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void deleteBudget() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Budget"),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  "Are you sure you want to delete the budget? This action cannot be undone."),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                // Delete the budget from the database and reset the local state
                deleteBudgetFromFirebase(budgetName).then((success) {
                  if (success) {
                    setState(() {
                      budgetMap = {};
                      budgetName = "";
                    });
                  }
                });
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  void editBudgetName() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Budget Name"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newBudgetNameController,
                decoration: const InputDecoration(labelText: "New Budget Name"),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                String newBudgetName = newBudgetNameController.text;
                updateBudgetNameInFirebase(budgetName, newBudgetName)
                    .then((success) {
                  if (success) {
                    setState(() {
                      budgetList.remove(budgetName);
                      budgetList.add(newBudgetName);
                      budgetName = newBudgetName;
                    });
                  }
                });
                newBudgetNameController.clear();
                Navigator.of(context).pop();
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<String?> openAddToBudget() => showDialog<String>(
        context: scaffoldKey.currentContext!,
        builder: (context) {
          bool isCustomColorSelected =
              false; // Track if custom color is selected
          Color customColor = Colors.green; // Initialize with a default color

          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text("Enter New Category:", style: TextStyle()),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      items: dropdownItems.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: const TextStyle(),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedCategory = newValue!;
                          isFormValid =
                              newValue != "Select Category" && !isOtherSelected;
                          // Check if "Custom" is selected
                          isOtherSelected = newValue == "Custom";
                        });
                      },
                    ),
                    // Show a text field if "Other" is selected
                    if (isOtherSelected)
                      TextField(
                        controller: customCategoryController,
                        decoration: const InputDecoration(
                          hintText: 'Enter a custom category',
                        ),
                      ),
                    const SizedBox(height: 10), // Add some spacing
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Enter your expense amount (i.e. \$25)',
                        hintStyle: TextStyle(),
                      ),
                      controller: controller,
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: isCustomColorSelected,
                          onChanged: (bool? newValue) {
                            setState(() {
                              isCustomColorSelected = newValue ?? false;
                            });
                          },
                        ),
                        Text("Custom Color"),
                        SizedBox(width: 28),
                        if (isCustomColorSelected)
                          ElevatedButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  Color selectedColor = customColor;
                                  return AlertDialog(
                                    title: Text("Select Custom Color"),
                                    content: SingleChildScrollView(
                                      child: ColorPicker(
                                        pickerColor: selectedColor,
                                        onColorChanged: (color) {
                                          selectedColor = color;
                                        },
                                      ),
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text("Cancel"),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                      TextButton(
                                        child: Text("Apply"),
                                        onPressed: () {
                                          setState(() {
                                            customColor = selectedColor;
                                          });
                                          colorList.insert(
                                              budgetMap.length, selectedColor);
                                          saveColorListToFirebase(
                                              budgetName, colorList);
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: Text("Pick Color"),
                          ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      submit();
                      setState(() {
                        values_added = true;
                      });
                      Navigator.of(context).pop();
                    },
                    child: const Text("Submit", style: TextStyle()),
                  ),
                ],
              );
            },
          );
        },
      );

  Future<void> openBudgetTable() async {
    await showDialog(
      context: scaffoldKey.currentContext!,
      builder: (context) {
        return Visibility(
            visible: budgetMap.isNotEmpty,
            child: BudgetCategoryTable(
              budget: Budget(
                  budgetMap: budgetMap,
                  budgetName: budgetName,
                  expenses: expenseList,
                  colorList: colorList),
              onBudgetUpdate: (updatedBudgetMap) async {
                bool updateResult =
                    await updateBudgetInFirebase(budgetName, updatedBudgetMap);

                if (updateResult) {
                  // If the update was successful, update the local state
                  setState(() {
                    budgetMap = updatedBudgetMap;
                  });
                } else {
                  // Handle the case where the update in Firebase failed
                  // You can show an error message or take appropriate action here
                }
              },
            ));
      },
    );
  }

  String colorChoice = "Custom";

  final Map<String, List<Color>> colorMap = {
    "Custom": customColorList,
    "Green": greenColorList,
    "Blue": blueColorList,
    "Orange": orangeColorList,
    "Purple": purpleColorList,
    "Black": blackColorList,
  };

  List<String> colorOptions = [
    "Custom",
    "Green",
    "Blue",
    "Orange",
    "Purple",
    "Black"
  ];

  void openColorChoice(void Function(List<Color>) updateColorList) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Choose A Color Scheme"),
            content: Column(
              children: [
                SizedBox(height: 10),
                Column(
                  children: budgetMap.keys.map((category) {
                    final colorIndex =
                        budgetMap.keys.toList().indexOf(category);
                    final color = colorIndex != -1
                        ? colorList[colorIndex]
                        : Colors
                            .black; // Replace 'defaultColor' with your default color
                    return Column(
                      children: <Widget>[
                        CategoryColorWidget(
                          budgetName: budgetName,
                          category: category,
                          colorList: colorList,
                          index: colorIndex,
                          color: color,
                          onSelect: () {},
                        ),
                        SizedBox(
                            height:
                                10), // Adds spacing between CategoryColorWidgets
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Perform actions based on the selected category and colorChoice
                  Navigator.of(context).pop(); // Close the dialog
                  List<Color> currList =
                      await getColorListFromFirebase(budgetName);
                  setState(() {
                    updateColorList(currList);
                  });
                },
                child: const Text("Submit"),
              ),
            ],
          );
        });
      },
    );
  }

  void submit() {
    actualCategory = selectedCategory;
    if (isOtherSelected) {
      // Use the custom category name if "Other" is selected
      actualCategory = customCategoryController.text;
    }
    if (actualCategory != "Select Category") {
      setState(() {
        if (budgetMap.containsKey(actualCategory)) {
          budgetMap[actualCategory] =
              (budgetMap[actualCategory]! + double.parse(controller.text))!;
        } else {
          budgetMap[actualCategory.toString()] = double.parse(controller.text);
          if (!dropdownItems.contains(actualCategory)) {
            dropdownItems.insert(dropdownItems.length - 1, actualCategory);
          }
        }
      });
      selectedCategory = "Select Category";
    }
    controller.clear();
    customCategoryController.clear();
    isOtherSelected = false;
    updateBudgetInFirebase(budgetName, budgetMap);
  }

  double getTotalBudget(Map<String, double> budgetMap) {
    double total = budgetMap.values.fold(0, (previousValue, currentValue) {
      return previousValue + currentValue;
    });

    return double.parse(total.toStringAsFixed(2));
  }
}

class BudgetPieChart extends StatelessWidget {
  final Map<String, double> budgetMap;
  final bool valuesAdded;
  final List<Color> colorList;

  BudgetPieChart({
    required this.budgetMap,
    required this.valuesAdded,
    required this.colorList,
  });

  @override
  Widget build(BuildContext context) {
    final totalBudget = getTotalBudget(budgetMap);
    final formattedTotalBudget = NumberFormat.currency(
      symbol: '\$', // Use "$" as the currency symbol
      decimalDigits: 0, // No decimal places
    ).format(totalBudget);

    final filteredLegendItems = budgetMap.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toList();

    return PieChart(
      key: UniqueKey(),
      dataMap: budgetMap,
      animationDuration: const Duration(milliseconds: 800),
      chartLegendSpacing: 80,
      chartRadius: 300,
      initialAngleInDegree: 0,
      chartType: ChartType.ring,
      ringStrokeWidth: 35,
      centerText: formattedTotalBudget,
      centerTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 40,
      ),
      chartValuesOptions: ChartValuesOptions(
        showChartValues: valuesAdded,
        showChartValuesInPercentage: true,
        showChartValueBackground: false,
        decimalPlaces: 0,
        chartValueStyle: const TextStyle(fontSize: 20),
      ),
      // legendLabels: ,
      //legendLabels: budgetMap.entries.where((element) => ),
      legendOptions: valuesAdded
          ? const LegendOptions(
              showLegends: true,
              legendPosition: LegendPosition.right,
              legendTextStyle: TextStyle(
                fontSize: 14,
              ),
              legendShape: BoxShape.circle)
          : const LegendOptions(
              showLegends: false,
            ),
      baseChartColor: Colors.white,
      colorList: colorList,
    );
  }

  double getTotalBudget(Map<String, double> budgetMap) {
    double total = budgetMap.values.fold(0, (previousValue, currentValue) {
      return previousValue + currentValue;
    });

    return double.parse(total.toStringAsFixed(2));
  }
}

class CategoryColorWidget extends StatefulWidget {
  final String category;
  Color color;
  final VoidCallback onSelect;
  int index;
  List<Color> colorList;
  String budgetName;

  CategoryColorWidget({
    required this.category,
    required this.color,
    required this.onSelect,
    required this.index,
    required this.colorList,
    required this.budgetName,
  });

  @override
  _CategoryColorWidgetState createState() => _CategoryColorWidgetState();
}

class _CategoryColorWidgetState extends State<CategoryColorWidget> {
  void changeColor(Color newColor) {
    setState(() {
      widget.color = newColor;
      widget.colorList[widget.index] = newColor;
      saveColorListToFirebase(widget.budgetName, widget.colorList);
      widget.onSelect;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Pick a color'),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: widget.color,
                  onColorChanged: changeColor,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(widget.category),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }
}
