import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:badges/badges.dart' as badges;
import 'package:diemchat/Screens/filter_group.dart';
import 'package:diemchat/Screens/user_gifts.dart';
import 'package:diemchat/Screens/widgets/create_group.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dashed_circle/dashed_circle.dart';
import 'package:diemchat/Screens/widgets/get_credits.dart';
import 'package:diemchat/Screens/widgets/groopLength.dart';
import 'package:diemchat/Screens/widgets/user_preview.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:diemchat/constatnt/Constant.dart';
import 'package:diemchat/constatnt/global.dart';
import 'package:diemchat/helper/sizeconfig.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'chat.dart';

import 'dart:math' as math;

class ListUsers extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return ListUsersState();
  }
}

class ListUsersState extends State<ListUsers>
    with SingleTickerProviderStateMixin {
  List<DocumentSnapshot> usersList = [];
  bool isLoading = true;
  List<DocumentSnapshot> searchList = [];
  List<DocumentSnapshot> groopList = [];
  @override
  void initState() {
    // addUsers();
    // deleteUsers();
    _controller = TabController(length: 2, vsync: this);
    _controller.addListener(() {
      setState(() {});
    });
    getUsers();
    super.initState();
  }

  Future deleteUsers() async {
    await FirebaseFirestore.instance.collection("users").get().then((value) {
      value.docs.forEach((element) {
        element.reference.delete();
      });
    });
  }

  Future addUsers() async {
    for (var i = 0; i < 15; i++) {
      Random random = Random();
      final response = await http.get(Uri.parse('https://randomuser.me/api/'));
      if (response.statusCode == 200) {
        String photo =
            jsonDecode(response.body)["results"][0]["picture"]["medium"];
        String name = jsonDecode(response.body)["results"][0]["name"]["first"] +
            " " +
            jsonDecode(response.body)["results"][0]["name"]["last"];
        String email = jsonDecode(response.body)["results"][0]["email"];
        await FirebaseFirestore.instance.collection("users").add({
          "email": email,
          "nick": name,
          "photo": photo,
          "status": DateTime.now()
              .subtract(Duration(minutes: random.nextInt(30)))
              .millisecondsSinceEpoch
              .toString(),
          "bio": email,
          "token": "token"
        });
        print("eklendi");
      } else {
        // If the server did not return a 200 OK response,
        // then throw an exception.
        throw Exception('Failed to load album');
      }
    }
  }

  FirebaseAuth _auth = FirebaseAuth.instance;

  int onlineCekilecekKullanici = 8;
  int cekilecekKullaniciSayisi = 20;

  Future getOfflineUsers() async {
    await FirebaseFirestore.instance
        .collection("users")
        .where("status",
            isGreaterThan: DateTime.now().subtract(Duration(days: 1)))
        .orderBy("status", descending: true)
        .limit(20)
        .get()
        .then((offlineUsers) async {
      if (cekilecekKullaniciSayisi < 8) {
        for (var i = 0; i < 8; i++) {
          if (offlineUsers.docs[i].id != _auth.currentUser!.uid &&
              cekilecekKullaniciSayisi > 0) {
            if (offlineUsers.docs[i].data().containsKey('banned')) {
              if (!offlineUsers.docs[i]['banned']) {
                usersList.add(offlineUsers.docs[i]);
              }
            } else {
              usersList.add(offlineUsers.docs[i]);
            }
          }
          cekilecekKullaniciSayisi--;
        }
      } else {
        for (var i = 0; i < offlineUsers.docs.length; i++) {
          if (offlineUsers.docs[i].id != _auth.currentUser.uid &&
              cekilecekKullaniciSayisi > 0) {
            if (offlineUsers.docs[i].data().containsKey('banned')) {
              if (!offlineUsers.docs[i]['banned']) {
                usersList.add(offlineUsers.docs[i]);
              }
            } else {
              usersList.add(offlineUsers.docs[i]);
            }
          }
          cekilecekKullaniciSayisi--;
        }
      }
    });
  }

  List boostedUserIds = [];
  Future getBoostedUsers() async {
    await FirebaseFirestore.instance
        .collection("purchasedUsers")
        .where("boostDate", isGreaterThan: DateTime.now())
        .get()
        .then((boostedUsers) async {
      if (boostedUsers.docs.length > 0) {
        print("Boosted Users: " + boostedUsers.docs.length.toString());
        if (boostedUsers.docs.length > 4) {
          for (var i = 0; i < 4; i++) {
            await FirebaseFirestore.instance
                .collection("users")
                .doc(boostedUsers.docs[i].id)
                .get()
                .then((value) {
              if (boostedUsers.docs[i].id != _auth.currentUser.uid) {
                usersList.add(value);
                boostedUserIds.add(boostedUsers.docs[i].id);
              }
            });
            cekilecekKullaniciSayisi--;
          }
        } else {
          for (var i = 0; i < boostedUsers.docs.length; i++) {
            await FirebaseFirestore.instance
                .collection("users")
                .doc(boostedUsers.docs[i].id)
                .get()
                .then((value) {
              if (boostedUsers.docs[i].id != _auth.currentUser.uid) {
                usersList.add(value);
                boostedUserIds.add(boostedUsers.docs[i].id);
              }
            });
            cekilecekKullaniciSayisi--;
          }
        }
      }
    });
  }

  Future getUsers() async {
    cekilecekKullaniciSayisi = 20;
    onlineCekilecekKullanici = 8;
    usersList.clear();
    getBoostedUsers()
        .then((value) => getOfflineUsers().then((value) => setState(() {
              usersList.shuffle();
              isLoading = false;
            })));
  }

  void showUserDialog(BuildContext context, name, image, phone, id,
      {GetCredits Function(dynamic context)? builder}) {
    showGeneralDialog(
      barrierDismissible: true,
      barrierLabel: "Barrier",
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: Duration(milliseconds: 700),
      context: context,
      pageBuilder: (_, __, ___) {
        return UserPreviewDialog(
          userId: id,
          userImage: image,
          userName: name,
          userPhone: phone,
          userToken: '',
        );
      },
      transitionBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween(begin: Offset(0, 1), end: Offset(0, 0)).animate(anim),
          child: child,
        );
      },
    );
  }

  late TabController _controller;
  RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  void _onRefresh() async {
    // monitor network fetch
    await getUsers();

    // if failed,use refreshFailed()

    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    // monitor network fetch
    await Future.delayed(Duration(milliseconds: 1000));

    // if failed,use loadFailed(),if no data return,use LoadNodata()
    // items.add((items.length+1).toString());

    _refreshController.loadComplete();
  }

  searchUser() {
    searchList.clear();
    allUsers.forEach((element) {
      if (element.id != _auth.currentUser!.uid) {
        if (element["nick"].toLowerCase().contains(searchQuery.toLowerCase()) ||
            element["bio"].toLowerCase().contains(searchQuery.toLowerCase())) {
          setState(() {
            searchList.add(element);
            searchLoading = false;
          });
        } else {
          setState(() {
            searchLoading = false;
          });
        }
      }
    });
  }

  bool first = true;
  bool searchLoading = false;
  String searchQuery = '';
  List<DocumentSnapshot> allUsers = [];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _controller.index == 0
          ? null
          : FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: () {
                showGeneralDialog(
                    context: context,
                    barrierDismissible: true,
                    barrierLabel: MaterialLocalizations.of(context)
                        .modalBarrierDismissLabel,
                    barrierColor: Colors.black45,
                    transitionDuration: const Duration(milliseconds: 200),
                    pageBuilder: (BuildContext buildContext,
                        Animation animation, Animation secondaryAnimation) {
                      return CreateGroup();
                    });
              },
              child: IconButton(
                icon: ImageIcon(
                  AssetImage("assets/images/addGroop.png"),
                  size: 30,
                  color: appColorBlue,
                ),
                onPressed: () {
                  showGeneralDialog(
                      context: context,
                      barrierDismissible: true,
                      barrierLabel: MaterialLocalizations.of(context)
                          .modalBarrierDismissLabel,
                      barrierColor: Colors.black45,
                      transitionDuration: const Duration(milliseconds: 200),
                      pageBuilder: (BuildContext buildContext,
                          Animation animation, Animation secondaryAnimation) {
                        return CreateGroup();
                      });
                },
              ),
            ),
      backgroundColor: bgcolor,
      body: Container(
        color: bgcolor,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: Container(
                height: 50,
                padding: EdgeInsets.symmetric(
                  horizontal: 10,
                ),
                margin: EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15)),
                child: Center(
                  child: TextField(
                      onTap: () async {
                        await FirebaseFirestore.instance
                            .collection("users")
                            .get()
                            .then((value) {
                          value.docs.forEach((element) {
                            allUsers.add(element);
                          });
                          first = false;
                        });
                      },
                      onChanged: (query) async {
                        setState(() {
                          searchLoading = true;
                        });
                        searchQuery = query;
                        if (_controller.index == 0) {
                          searchUser();
                        } else {
                          await FirebaseFirestore.instance
                              .collection("groop")
                              .get()
                              .then((value) {
                            setState(() {
                              groopList.clear();
                              value.docs.forEach((element) {
                                if (element["groupName"]
                                    .toLowerCase()
                                    .contains(query.toLowerCase())) {
                                  searchLoading = false;
                                  groopList.add(element);
                                }
                              });
                            });
                          });
                        }
                      },
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.only(top: 13.5),
                        hintText: _controller.index == 0
                            ? "Kullanıcı adı veya Biografi ile ara"
                            : "Groop Ara",
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                      )),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 15, right: 15, top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => FilterGroup(
                                      type: 0,
                                    )));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        margin: EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.green.withOpacity(0.2)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/chats.png',
                              height: 45,
                              width: 45,
                            ),
                            SizedBox(
                              height: 8,
                            ),
                            Text(
                              'Yazılı Sohbet',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => FilterGroup(
                                      type: 2,
                                    )));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        margin: EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: appColor.withOpacity(0.2)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/videoChat.png',
                              height: 45,
                              width: 45,
                            ),
                            SizedBox(
                              height: 8,
                            ),
                            Text(
                              'Video Sohbet',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => FilterGroup(
                                      type: 1,
                                    )));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        margin: EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color:
                                Colors.amberAccent.shade700.withOpacity(0.2)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/voiceChat.png',
                              height: 45,
                              width: 45,
                            ),
                            SizedBox(
                              height: 8,
                            ),
                            Text(
                              'Sesli Sohbet',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 50,
              child: TabBar(
                controller: _controller,
                unselectedLabelColor: Colors.grey,
                labelColor: Colors.black,
                labelStyle: TextStyle(
                    fontSize: SizeConfig.blockSizeHorizontal * 4.1,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorColor: Colors.black,
                // indicator: BoxDecoration(
                //   borderRadius: BorderRadius.circular(10),
                //   gradient: LinearGradient(
                //       colors: [
                //         Constants.SecondColor,
                //         Constants.FirstColor
                //       ],
                //       begin: Alignment.bottomCenter,
                //       end: Alignment.topCenter),
                // ),
                tabs: [
                  Tab(
                    text: "SHUFFLE",
                  ),
                  Tab(
                    text: "Groop",
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 5,
            ),
            Expanded(
              child: TabBarView(controller: _controller, children: [
                // first tab bar view widget
                SmartRefresher(
                    enablePullDown: true,
                    header: WaterDropHeader(
                      complete: Container(),
                    ),
                    footer: CustomFooter(
                      builder: (BuildContext context, LoadStatus? mode) {
                        Widget body;
                        if (mode == LoadStatus.idle) {
                          body = Text("pull up load");
                        } else if (mode == LoadStatus.loading) {
                          body = CupertinoActivityIndicator();
                        } else if (mode == LoadStatus.failed) {
                          body = Text("Load Failed!Click retry!");
                        } else if (mode == LoadStatus.canLoading) {
                          body = Text("release to load more");
                        } else {
                          body = Text("No more Data");
                        }
                        return Container(
                          height: 55.0,
                          child: Center(child: body),
                        );
                      },
                    ),
                    controller: _refreshController,
                    onRefresh: _onRefresh,
                    onLoading: _onLoading,
                    child: isLoading
                        ? Center(
                            child: CircularProgressIndicator(),
                          )
                        : searchQuery == null || searchQuery == ""
                            ? GridView.count(
                                padding: EdgeInsets.all(10),
                                primary: false,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                crossAxisCount: 2,
                                childAspectRatio: 11 / 11,
                                children: usersList.map<Widget>((doc) {
                                  // bool boosted = false;
                                  // boostedUserIds.forEach((element) {
                                  //   if (element == doc.id) {
                                  //     boosted = true;
                                  //   }
                                  // });
                                  return Container(
                                    child: Stack(
                                      fit: StackFit.passthrough,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) => Chat(
                                                          peerID: doc.id,
                                                          peerName: doc["nick"],
                                                          currentUserId: _auth
                                                              .currentUser!.uid,
                                                        )));
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(),
                                            child: Card(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceEvenly,
                                                children: [
                                                  Stack(
                                                    alignment:
                                                        Alignment.bottomRight,
                                                    children: [
                                                      InkWell(
                                                        onTap: () {
                                                          showUserDialog(
                                                            context,
                                                            doc["nick"],
                                                            doc["photo"],
                                                            doc["bio"],
                                                            doc.id,
                                                          );
                                                        },
                                                        child: DashedCircle(
                                                          gapSize: 40,
                                                          dashes: 20,
                                                          strokeWidth: 20,
                                                          color: Colors.red,
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(1.0),
                                                            child: CircleAvatar(
                                                              radius: 30,
                                                              foregroundColor:
                                                                  Theme.of(
                                                                          context)
                                                                      .primaryColor,
                                                              backgroundColor:
                                                                  Colors.grey,
                                                              backgroundImage:
                                                                  new NetworkImage(
                                                                doc["photo"],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      doc["status"] == "Online"
                                                          ? Container(
                                                              width: 20,
                                                              height: 20,
                                                              decoration:
                                                                  BoxDecoration(
                                                                border: Border.all(
                                                                    color: Colors
                                                                        .white,
                                                                    width: 1),
                                                                shape: BoxShape
                                                                    .circle,
                                                                color: Colors
                                                                    .greenAccent
                                                                    .shade400,
                                                              ),
                                                            )
                                                          : DateTime.now()
                                                                      .difference(
                                                                          doc["status"]
                                                                              .toDate())
                                                                      .inMinutes >
                                                                  1
                                                              ? Container(
                                                                  width: 20,
                                                                  height: 20,
                                                                  padding:
                                                                      EdgeInsets
                                                                          .all(
                                                                              1),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    border: Border.all(
                                                                        color: Colors
                                                                            .white,
                                                                        width:
                                                                            1),
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    color: Colors
                                                                        .grey,
                                                                  ),
                                                                  child: Center(
                                                                    child:
                                                                        AutoSizeText(
                                                                      DateTime.now().difference(doc["status"].toDate()).inHours >
                                                                              24
                                                                          ? DateTime.now().difference(doc["status"].toDate()).inDays.toString() +
                                                                              "g"
                                                                          : DateTime.now().difference(doc["status"].toDate()).inMinutes > 60
                                                                              ? DateTime.now().difference(doc["status"].toDate()).inHours.toString() + "s"
                                                                              : DateTime.now().difference(doc["status"].toDate()).inMinutes.toString() + "d",
                                                                      minFontSize:
                                                                          4,
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .white,
                                                                          fontSize:
                                                                              9,
                                                                          fontWeight:
                                                                              FontWeight.bold),
                                                                    ),
                                                                  ),
                                                                )
                                                              : Container(
                                                                  width: 20,
                                                                  height: 20,
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    border: Border.all(
                                                                        color: Colors
                                                                            .white,
                                                                        width:
                                                                            1),
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    color: Colors
                                                                        .greenAccent
                                                                        .shade400,
                                                                  ),
                                                                )
                                                    ],
                                                  ),
                                                  Text(
                                                    doc["nick"],
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  Container(
                                                    margin: EdgeInsets.only(
                                                        bottom: 5),
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 10),
                                                    child: Text(
                                                      doc["bio"],
                                                      textAlign:
                                                          TextAlign.center,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 2,
                                                      style: TextStyle(
                                                          color: Colors
                                                              .grey.shade600,
                                                          fontSize: 12),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          alignment: Alignment.bottomRight,
                                          child: Padding(
                                            padding: const EdgeInsets.all(0.0),
                                            child: IconButton(
                                                onPressed: () {
                                                  showDialog(
                                                      context: context,
                                                      builder: (context) {
                                                        return GetCredits(
                                                          peerToken:
                                                              doc["token"],
                                                          userId: doc.id,
                                                          userName: doc["nick"],
                                                        );
                                                      });
                                                },
                                                icon: Image.asset(
                                                  'assets/stickers/gift.png',
                                                  color: appcolor,
                                                  width: 20,
                                                  height: 20,
                                                )),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList())
                            : searchLoading
                                ? Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : GridView.count(
                                    padding: EdgeInsets.all(10),
                                    primary: false,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    crossAxisCount: 2,
                                    childAspectRatio: 11 / 11,
                                    children: searchList.map<Widget>((doc) {
                                      return Container(
                                        child: Stack(
                                          children: [
                                            InkWell(
                                              onTap: () {
                                                Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            Chat(
                                                              peerID: doc.id,
                                                              peerName:
                                                                  doc["nick"],
                                                              currentUserId: _auth
                                                                  .currentUser!
                                                                  .uid,
                                                            )));
                                              },
                                              child: Card(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceEvenly,
                                                  children: [
                                                    Stack(
                                                      alignment:
                                                          Alignment.bottomRight,
                                                      children: [
                                                        InkWell(
                                                          onTap: () {
                                                            showUserDialog(
                                                              context,
                                                              doc["nick"],
                                                              doc["photo"],
                                                              doc["bio"],
                                                              doc.id,
                                                            );
                                                          },
                                                          child: DashedCircle(
                                                            gapSize: 40,
                                                            dashes: 20,
                                                            strokeWidth: 20,
                                                            color: Colors.red,
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(1.0),
                                                              child:
                                                                  CircleAvatar(
                                                                radius: 30,
                                                                foregroundColor:
                                                                    Theme.of(
                                                                            context)
                                                                        .primaryColor,
                                                                backgroundColor:
                                                                    Colors.grey,
                                                                backgroundImage:
                                                                    new NetworkImage(
                                                                  doc["photo"],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        doc["status"] ==
                                                                "Online"
                                                            ? Container(
                                                                width: 20,
                                                                height: 20,
                                                                decoration:
                                                                    BoxDecoration(
                                                                  border: Border.all(
                                                                      color: Colors
                                                                          .white,
                                                                      width: 1),
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  color: Colors
                                                                      .greenAccent
                                                                      .shade400,
                                                                ),
                                                              )
                                                            : DateTime.now()
                                                                        .difference(
                                                                            doc["status"].toDate())
                                                                        .inMinutes >
                                                                    1
                                                                ? Container(
                                                                    width: 20,
                                                                    height: 20,
                                                                    padding:
                                                                        EdgeInsets
                                                                            .all(1),
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      border: Border.all(
                                                                          color: Colors
                                                                              .white,
                                                                          width:
                                                                              1),
                                                                      shape: BoxShape
                                                                          .circle,
                                                                      color: Colors
                                                                          .grey,
                                                                    ),
                                                                    child:
                                                                        Center(
                                                                      child:
                                                                          AutoSizeText(
                                                                        DateTime.now().difference(doc["status"].toDate()).inHours >
                                                                                24
                                                                            ? DateTime.now().difference(doc["status"].toDate()).inDays.toString() +
                                                                                "g"
                                                                            : DateTime.now().difference(doc["status"].toDate()).inMinutes > 60
                                                                                ? DateTime.now().difference(doc["status"].toDate()).inHours.toString() + "s"
                                                                                : DateTime.now().difference(doc["status"].toDate()).inMinutes.toString() + "d",
                                                                        minFontSize:
                                                                            4,
                                                                        style: TextStyle(
                                                                            color: Colors
                                                                                .white,
                                                                            fontSize:
                                                                                9,
                                                                            fontWeight:
                                                                                FontWeight.bold),
                                                                      ),
                                                                    ),
                                                                  )
                                                                : Container(
                                                                    width: 20,
                                                                    height: 20,
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      border: Border.all(
                                                                          color: Colors
                                                                              .white,
                                                                          width:
                                                                              1),
                                                                      shape: BoxShape
                                                                          .circle,
                                                                      color: Colors
                                                                          .greenAccent
                                                                          .shade400,
                                                                    ),
                                                                  )
                                                      ],
                                                    ),
                                                    Text(
                                                      doc["nick"],
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 10),
                                                      child: Text(
                                                        doc["bio"],
                                                        textAlign:
                                                            TextAlign.center,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        maxLines: 2,
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey.shade600,
                                                            fontSize: 12),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                                onPressed: () {},
                                                icon: Image.asset(
                                                    'assets/stickers/gift.png')),
                                          ],
                                        ),
                                      );
                                    }).toList())),
                groopList.length > 0
                    ? ListView.builder(
                        itemCount: groopList.length,
                        shrinkWrap: true,
                        itemBuilder: (context, int index) {
                          DocumentSnapshot doc = groopList[index];
                          return Container(
                            child: InkWell(
                              onTap: () {
                                if (doc['type'] == 0) {
                                  Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                          builder: (context) => GroupChat(
                                                joins: doc['joins'],
                                                joined: doc["joins"].contains(
                                                    _auth.currentUser!.uid),
                                                currentuser:
                                                    _auth.currentUser!.uid,
                                                currentusername: globalName,
                                                currentuserimage: globalImage,
                                                peerID: doc.id,
                                                peerUrl: doc['groupImage'],
                                                peerName: doc['groupName'],
                                                archive: false,
                                                mute: false,
                                                muteds: doc['muteds'],
                                                pins: doc['pins'],
                                              )));
                                } else if (doc['type'] == 2) {
                                  Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                          builder: (context) => GroupVideoCall(
                                              groupImage: doc['groupImage'],
                                              groupName: doc['groupName'],
                                              kisiler: doc['joins'],
                                              joined: doc['joins'].contains(
                                                  _auth.currentUser!.uid),
                                              documentId: doc.id)));
                                } else if (doc['type'] == 1) {
                                  Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                          builder: (context) => GroupVoiceCall(
                                              groupImage: doc['groupImage'],
                                              groupName: doc['groupName'],
                                              kisiler: doc['joins'],
                                              joined: doc['joins'].contains(
                                                  _auth.currentUser!.uid),
                                              documentId: doc.id)));
                                }
                              },
                              child: Column(
                                children: [
                                  Divider(height: 1, color: Colors.black12),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 5, horizontal: 15),
                                    color: Colors.white,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            SizedBox(
                                              width: 5,
                                            ),
                                            Container(
                                                margin:
                                                    EdgeInsets.only(top: 10),
                                                height: 50,
                                                width: 50,
                                                child: doc["groupImage"]
                                                            .toString()
                                                            .length >
                                                        3
                                                    ? Container(
                                                        height: 50,
                                                        width: 50,
                                                        child: DashedCircle(
                                                          gapSize: 20,
                                                          dashes: 20,
                                                          color:
                                                              getRandomColor(),
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(0.75),
                                                            child: CircleAvatar(
                                                              //radius: 60,
                                                              foregroundColor:
                                                                  Theme.of(
                                                                          context)
                                                                      .primaryColor,
                                                              backgroundColor:
                                                                  Colors.grey,
                                                              backgroundImage:
                                                                  new NetworkImage(
                                                                      doc['groupImage']),
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    : Container(
                                                        height: 50,
                                                        width: 50,
                                                        decoration:
                                                            BoxDecoration(
                                                                color: Colors
                                                                    .grey[400],
                                                                shape: BoxShape
                                                                    .circle),
                                                        child: DashedCircle(
                                                          gapSize: 20,
                                                          dashes: 20,
                                                          color:
                                                              getRandomColor(),
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(0.75),
                                                            child: Image.asset(
                                                              "assets/images/${doc['groupImage']}.png",
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        ))),
                                            SizedBox(
                                              width: 8,
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                SizedBox(
                                                  height: 8,
                                                ),
                                                Container(
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width /
                                                      1.5,
                                                  child: Text(
                                                    doc["groupName"] ?? "",
                                                    style: new TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                        color: appColorBlack),
                                                  ),
                                                ),
                                                SizedBox(
                                                  height: 8,
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 0),
                                                  child: msgTypeWidget(
                                                      doc['type'],
                                                      doc['content']),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                          height: 5,
                                        ),
                                        Row(
                                          children: [
                                            doc['type'] < 1
                                                ? Container()
                                                : Container(
                                                    width: 50,
                                                    margin: EdgeInsets.only(
                                                        top: 12, right: 15),
                                                    child: StreamBuilder<Event>(
                                                        stream: FirebaseDatabase
                                                            .instance
                                                            .reference()
                                                            .child('groopCall')
                                                            .child(doc.id)
                                                            .onValue,
                                                        builder: (context,
                                                            snapshot) {
                                                          if (snapshot
                                                              .hasError) {
                                                            return Text(
                                                              '',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .green),
                                                            );
                                                          }
                                                          if (snapshot
                                                              .hasData) {
                                                            return snapshot
                                                                    .data
                                                                    .snapshot
                                                                    .exists
                                                                ? Badge(
                                                                    shape: BadgeShape
                                                                        .square,
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(5),
                                                                    badgeColor:
                                                                        appColor,
                                                                    position: badges
                                                                            .BadgePosition
                                                                        .topEnd(
                                                                            top:
                                                                                -12,
                                                                            end:
                                                                                -4),
                                                                    padding: EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            5,
                                                                        vertical:
                                                                            3),
                                                                    badgeContent:
                                                                        Text(
                                                                      snapshot
                                                                          .data
                                                                          .snapshot
                                                                          .value
                                                                          .length
                                                                          .toString(),
                                                                      style: TextStyle(
                                                                          color: Colors
                                                                              .white,
                                                                          fontSize:
                                                                              12,
                                                                          fontWeight:
                                                                              FontWeight.bold),
                                                                    ),
                                                                    child: Icon(
                                                                      Icons
                                                                          .group,
                                                                      size: 30,
                                                                      color:
                                                                          appColor,
                                                                    ),
                                                                  )
                                                                : Container();
                                                          }
                                                          return Container();
                                                        }),
                                                  ),
                                            doc["joins"].length == 0
                                                ? Container()
                                                : Container(
                                                    height: 42,
                                                    padding: EdgeInsets.only(
                                                        left: doc['type'] < 1
                                                            ? 65
                                                            : 0),
                                                    child: ListView.builder(
                                                        itemCount:
                                                            doc["joins"].length,
                                                        scrollDirection:
                                                            Axis.horizontal,
                                                        shrinkWrap: true,
                                                        itemBuilder: (context,
                                                            int index) {
                                                          return GroopLength(
                                                            type: 0,
                                                            userId: doc["joins"]
                                                                [index],
                                                          );
                                                        }),
                                                  ),
                                          ],
                                        ),
                                        SizedBox(
                                          height: 5,
                                        )
                                      ],
                                    ),
                                  ),
                                  Divider(height: 1, color: Colors.black45),
                                ],
                              ),
                            ),
                          );
                        })
                    : StreamBuilder(
                        stream: FirebaseFirestore.instance
                            .collection("groop")
                            .orderBy("created", descending: true)
                            .where("created",
                                isGreaterThan:
                                    DateTime.now().subtract(Duration(days: 1)))
                            .snapshots(),
                        builder:
                            (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                          if (snapshot.hasData) {
                            return Container(
                              width: MediaQuery.of(context).size.width,
                              child: snapshot.data!.docs.length > 0
                                  ? ListView.builder(
                                      itemCount: snapshot.data!.docs.length,
                                      shrinkWrap: true,
                                      itemBuilder: (context, int index) {
                                        DocumentSnapshot doc =
                                            snapshot.data.docs[index];
                                        return Container(
                                          child: InkWell(
                                            onTap: () {
                                              if (doc['type'] == 0) {
                                                Navigator.push(
                                                    context,
                                                    CupertinoPageRoute(
                                                        builder: (context) =>
                                                            GroupChat(
                                                              joins:
                                                                  doc['joins'],
                                                              joined: doc[
                                                                      "joins"]
                                                                  .contains(_auth
                                                                      .currentUser
                                                                      .uid),
                                                              currentuser: _auth
                                                                  .currentUser
                                                                  .uid,
                                                              currentusername:
                                                                  globalName,
                                                              currentuserimage:
                                                                  globalImage,
                                                              peerID: doc.id,
                                                              peerUrl: doc[
                                                                  'groupImage'],
                                                              peerName: doc[
                                                                  'groupName'],
                                                              archive: false,
                                                              mute: false,
                                                              muteds:
                                                                  doc['muteds'],
                                                              pins: doc['pins'],
                                                            )));
                                              } else if (doc['type'] == 2) {
                                                Navigator.push(
                                                    context,
                                                    CupertinoPageRoute(
                                                        builder: (context) => GroupVideoCall(
                                                            groupImage: doc[
                                                                'groupImage'],
                                                            groupName: doc[
                                                                'groupName'],
                                                            kisiler:
                                                                doc['joins'],
                                                            joined: doc['joins']
                                                                .contains(_auth
                                                                    .currentUser
                                                                    .uid),
                                                            documentId:
                                                                doc.id)));
                                              } else if (doc['type'] == 1) {
                                                Navigator.push(
                                                    context,
                                                    CupertinoPageRoute(
                                                        builder: (context) => GroupVoiceCall(
                                                            groupImage: doc[
                                                                'groupImage'],
                                                            groupName: doc[
                                                                'groupName'],
                                                            kisiler:
                                                                doc['joins'],
                                                            joined: doc['joins']
                                                                .contains(_auth
                                                                    .currentUser
                                                                    .uid),
                                                            documentId:
                                                                doc.id)));
                                              }
                                            },
                                            child: Column(
                                              children: [
                                                Divider(
                                                    height: 1,
                                                    color: Colors.black12),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 5,
                                                      horizontal: 15),
                                                  color: Colors.white,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          SizedBox(
                                                            width: 5,
                                                          ),
                                                          Container(
                                                              margin: EdgeInsets
                                                                  .only(
                                                                      top: 10),
                                                              height: 50,
                                                              width: 50,
                                                              child: doc["groupImage"]
                                                                          .toString()
                                                                          .length >
                                                                      3
                                                                  ? Container(
                                                                      height:
                                                                          50,
                                                                      width: 50,
                                                                      child:
                                                                          DashedCircle(
                                                                        gapSize:
                                                                            20,
                                                                        dashes:
                                                                            20,
                                                                        color:
                                                                            getRandomColor(),
                                                                        child:
                                                                            Padding(
                                                                          padding: const EdgeInsets
                                                                              .all(
                                                                              0.75),
                                                                          child:
                                                                              CircleAvatar(
                                                                            //radius: 60,
                                                                            foregroundColor:
                                                                                Theme.of(context).primaryColor,
                                                                            backgroundColor:
                                                                                Colors.grey,
                                                                            backgroundImage:
                                                                                new NetworkImage(doc['groupImage']),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    )
                                                                  : Container(
                                                                      height:
                                                                          50,
                                                                      width: 50,
                                                                      decoration: BoxDecoration(
                                                                          color: Colors.grey[
                                                                              400],
                                                                          shape: BoxShape
                                                                              .circle),
                                                                      child:
                                                                          DashedCircle(
                                                                        gapSize:
                                                                            20,
                                                                        dashes:
                                                                            20,
                                                                        color:
                                                                            getRandomColor(),
                                                                        child:
                                                                            Padding(
                                                                          padding: const EdgeInsets
                                                                              .all(
                                                                              0.75),
                                                                          child:
                                                                              Image.asset(
                                                                            "assets/images/${doc['groupImage']}.png",
                                                                            fit:
                                                                                BoxFit.cover,
                                                                          ),
                                                                        ),
                                                                      ))),
                                                          SizedBox(
                                                            width: 8,
                                                          ),
                                                          Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              SizedBox(
                                                                height: 8,
                                                              ),
                                                              Container(
                                                                width: MediaQuery.of(
                                                                            context)
                                                                        .size
                                                                        .width /
                                                                    1.5,
                                                                child: Text(
                                                                  doc["groupName"] ??
                                                                      "",
                                                                  style: new TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          14,
                                                                      color:
                                                                          appColorBlack),
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                height: 8,
                                                              ),
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            0),
                                                                child: msgTypeWidget(
                                                                    doc['type'],
                                                                    doc['content']),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(
                                                        height: 5,
                                                      ),
                                                      Row(
                                                        children: [
                                                          doc['type'] < 1
                                                              ? Container()
                                                              : Container(
                                                                  width: 50,
                                                                  margin: EdgeInsets
                                                                      .only(
                                                                          top:
                                                                              12,
                                                                          right:
                                                                              15),
                                                                  child: StreamBuilder<
                                                                          Event>(
                                                                      stream: FirebaseDatabase
                                                                          .instance
                                                                          .reference()
                                                                          .child(
                                                                              'groopCall')
                                                                          .child(doc
                                                                              .id)
                                                                          .onValue,
                                                                      builder:
                                                                          (context,
                                                                              snapshot) {
                                                                        if (snapshot
                                                                            .hasError) {
                                                                          return Text(
                                                                            '',
                                                                            style:
                                                                                TextStyle(color: Colors.green),
                                                                          );
                                                                        }
                                                                        if (snapshot
                                                                            .hasData) {
                                                                          return snapshot.data.snapshot.exists
                                                                              ? badges.Badge(
                                                                                  badgeStyle: badges.BadgeStyle(
                                                                                    shape: badges.BadgeShape.square,
                                                                                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                                                                    borderSide: BorderSide(color: Colors.white, width: 1),
                                                                                    badgeRadius: 5,
                                                                                    badgeColor: appColor,
                                                                                  ),
                                                                                  position: badges.BadgePosition.topEnd(top: -12, end: -4),
                                                                                  badgeContent: Text(
                                                                                    snapshot.data.snapshot.value.length.toString(),
                                                                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                                                  ),
                                                                                  child: Icon(
                                                                                    Icons.group,
                                                                                    size: 30,
                                                                                    color: appColor,
                                                                                  ),
                                                                                )
                                                                              : Container();
                                                                        }
                                                                        return Container();
                                                                      }),
                                                                ),
                                                          doc["joins"].length ==
                                                                  0
                                                              ? Container()
                                                              : Container(
                                                                  width: doc['type'] <
                                                                          1
                                                                      ? MediaQuery.of(context)
                                                                              .size
                                                                              .width /
                                                                          1.1
                                                                      : MediaQuery.of(context)
                                                                              .size
                                                                              .width /
                                                                          1.6,
                                                                  height: 47,
                                                                  padding: EdgeInsets.only(
                                                                      right: 0,
                                                                      left: doc['type'] <
                                                                              1
                                                                          ? 65
                                                                          : 0),
                                                                  child: ListView
                                                                      .builder(
                                                                          itemCount: doc["joins"]
                                                                              .length,
                                                                          scrollDirection: Axis
                                                                              .horizontal,
                                                                          padding: EdgeInsets.all(
                                                                              3),
                                                                          shrinkWrap:
                                                                              true,
                                                                          itemBuilder:
                                                                              (context, int index) {
                                                                            return GroopLength(
                                                                              type: null,
                                                                              userId: doc["joins"][index],
                                                                            );
                                                                          }),
                                                                ),
                                                        ],
                                                      ),
                                                      SizedBox(
                                                        height: 5,
                                                      )
                                                    ],
                                                  ),
                                                ),
                                                Divider(
                                                    height: 1,
                                                    color: Colors.black45),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Center(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Padding(
                                            padding:
                                                EdgeInsets.only(bottom: 15),
                                            child: CustomText(
                                              text: "Sohbet Listen Boş",
                                              alignment: Alignment.center,
                                              fontSize: SizeConfig
                                                      .blockSizeHorizontal *
                                                  5,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: "MontserratBold",
                                              color: appColorBlack,
                                            ),
                                          ),
                                          Image.asset(
                                            "assets/images/noimage.jpeg",
                                            width: 200,
                                          ),
                                          SizedBox(
                                            height: 15,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 40),
                                            child: Text(
                                              "Sohbet listende kimse yok mesajlaşman için shuffle listesine göz at",
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            );
                          }
                          return Container(
                            height: MediaQuery.of(context).size.height,
                            width: MediaQuery.of(context).size.width,
                            alignment: Alignment.center,
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: <Widget>[
                                  CupertinoActivityIndicator(),
                                ]),
                          );
                        },
                      )
              ]),
            ),
          ],
        ),
      ),
    );
  }

  getRandomColor() {
    return Color.fromRGBO(math.Random().nextInt(200),
        math.Random().nextInt(200), math.Random().nextInt(200), 1);
  }

  Widget msgTypeWidget(int type, String content) {
    return new Container(
      padding: const EdgeInsets.only(top: 0),
      width: MediaQuery.of(context).size.width / 1.4,
      child: type == 1
          ? Row(
              children: [
                Icon(
                  Icons.camera_alt,
                  color: Colors.grey,
                  size: 17,
                ),
                Text(
                  "  Photo",
                  maxLines: 2,
                  style: new TextStyle(
                      color: Colors.deepPurple.shade900,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w700),
                ),
              ],
            )
          : type == 4
              ? Row(
                  children: [
                    Icon(
                      Icons.video_call,
                      color: Colors.grey,
                      size: 17,
                    ),
                    Text(
                      "  Video",
                      maxLines: 2,
                      style: new TextStyle(
                          color: Colors.deepPurple.shade900,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                )
              : type == 5
                  ? Row(
                      children: [
                        Icon(
                          Icons.note,
                          color: Colors.grey,
                          size: 17,
                        ),
                        Text(
                          "  File",
                          maxLines: 2,
                          style: new TextStyle(
                              color: Colors.deepPurple.shade900,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    )
                  : type == 6
                      ? Row(
                          children: [
                            Icon(
                              Icons.audiotrack,
                              color: Colors.grey,
                              size: 17,
                            ),
                            Text(
                              "  Audio",
                              maxLines: 2,
                              style: new TextStyle(
                                  color: Colors.deepPurple.shade900,
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        )
                      : Text(
                          content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: new TextStyle(
                              color: Colors.deepPurple.shade900,
                              fontSize: 12.0,
                              fontWeight: FontWeight.w700),
                        ),
    );
  }
}
