import 'dart:async';

import 'package:bbb_app/src/connect/meeting/main_websocket/chat/chat.dart';
import 'package:bbb_app/src/connect/meeting/main_websocket/chat/group.dart';
import 'package:bbb_app/src/connect/meeting/main_websocket/main_websocket.dart';
import 'package:bbb_app/src/connect/meeting/meeting_info.dart';
import 'package:bbb_app/src/connect/meeting/model/user_model.dart';
import 'package:bbb_app/src/locale/app_localizations.dart';
import 'package:bbb_app/src/view/chat/chat_view.dart';
import 'package:flutter/material.dart';

/// Widget showing the meeting participants and chat (or a link to the chat).
class MeetingInfoView extends StatefulWidget {
  MeetingInfo _meetingInfo;

  /// The meetings main websocket connection.
  MainWebSocket _mainWebSocket;

  MeetingInfoView(this._meetingInfo, this._mainWebSocket);

  @override
  State<StatefulWidget> createState() => _MeetingInfoViewState();
}

/// State of the meeting info view.
class _MeetingInfoViewState extends State<MeetingInfoView> {
  /// Map of users currently in the meeting.
  Map<String, UserModel> _userMap = {};

  /// Available chat groups.
  List<ChatGroup> _chatGroups = [];

  /// Unread message counters for each open chat group.
  Map<String, int> _unreadMessageCounters = {};

  /// Subscription to user changes.
  StreamSubscription _userChangesStreamSubscription;

  /// Subscription to chat group changes.
  StreamSubscription _chatGroupsStreamSubscription;

  /// Subscription to unread message counters of the open chats.
  StreamSubscription _unreadMessageCounterStreamSubscription;

  @override
  void initState() {
    super.initState();

    _userMap = widget._mainWebSocket.userModule.userMap;
    _userChangesStreamSubscription =
        widget._mainWebSocket.userModule.changes.listen((userMap) {
      setState(
          () => _userMap = Map.of(widget._mainWebSocket.userModule.userMap));
    });

    _chatGroups.addAll(widget._mainWebSocket.chatModule.activeChatGroups);
    _chatGroupsStreamSubscription = widget
        ._mainWebSocket.chatModule.chatGroupStream
        .listen((chatGroupEvent) {
      setState(() {
        if (chatGroupEvent.added) {
          _chatGroups.add(chatGroupEvent.target);
        } else {
          _chatGroups.remove(chatGroupEvent.target);
        }
      });
    });

    _unreadMessageCounters =
        Map.of(widget._mainWebSocket.chatModule.unreadMessageCounters);
    _unreadMessageCounterStreamSubscription = widget
        ._mainWebSocket.chatModule.unreadMessageCounterStream
        .listen((event) {
      setState(() {
        _unreadMessageCounters[event.chatID] = event.counter;
      });
    });
  }

  @override
  void dispose() {
    _userChangesStreamSubscription.cancel();
    _chatGroupsStreamSubscription.cancel();
    _unreadMessageCounterStreamSubscription.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<UserModel> users = createUserList();

    return Scaffold(
      appBar: _buildAppBar(),
      body: ListView(
        children: <Widget>[
          _buildSectionHeader(
              AppLocalizations.of(context).get("meeting-info.messages")),
          _buildChatList(),
          _buildSectionHeader(
              "${AppLocalizations.of(context).get("meeting-info.participants")} (${users.length})"),
          _buildUsers(context, users),
        ],
      ),
    );
  }

  /// Build a section header text.
  Widget _buildSectionHeader(String text) => Container(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        margin: EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 1.0,
              color:
                  Theme.of(context).textTheme.bodyText1.color.withOpacity(0.3),
            ),
          ),
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  /// Build the available chats list.
  Widget _buildChatList() => ListView.builder(
        scrollDirection: Axis.vertical,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _chatGroups.length,
        itemBuilder: (BuildContext context, int index) {
          ChatGroup group = _chatGroups[index];

          return Column(
            children: [
              _buildChatListItem(group),
              Divider(
                indent: 15,
                endIndent: 15,
              )
            ],
          );
        },
      );

  /// Build a chat list item.
  Widget _buildChatListItem(ChatGroup group) => new ListTile(
        contentPadding:
            const EdgeInsets.only(left: 15.0, top: 0.0, bottom: 0.0),
        leading: Container(
          constraints: BoxConstraints(minWidth: 50, maxWidth: 50),
          width: 50,
          height: 40,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Stack(
              children: [
                Icon(Icons.chat),
                if (_unreadMessageCounters.containsKey(group.id) &&
                    _unreadMessageCounters[group.id] > 0)
                  Container(
                    margin: EdgeInsets.only(top: 12, left: 15),
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).errorColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${_unreadMessageCounters[group.id]}",
                      style: TextStyle(
                          color: Theme.of(context)
                              .primaryTextTheme
                              .bodyText1
                              .color),
                    ),
                  ),
              ],
            ),
          ),
        ),
        title: Text(group.id == ChatModule.defaultChatID
            ? AppLocalizations.of(context).get("chat.public")
            : group.name),
        trailing: group.id != ChatModule.defaultChatID
            ? IconButton(
                icon: Icon(Icons.delete_forever),
                onPressed: () =>
                    widget._mainWebSocket.chatModule.removeGroupChat(group),
              )
            : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ChatView(
                      group,
                      widget._meetingInfo,
                      widget._mainWebSocket,
                    )),
          );
        },
      );

  List<UserModel> createUserList() {
    List<UserModel> currentUser = [];
    _userMap.values.forEach((u) {
      if (u.internalId == widget._meetingInfo.internalUserID) {
        currentUser.add(u);
      }
    });

    List<UserModel> moderators = [];
    _userMap.values.forEach((u) {
      if (u.role == UserModel.ROLE_MODERATOR &&
          u.internalId != widget._meetingInfo.internalUserID) {
        moderators.add(u);
      }
    });

    List<UserModel> nonModerators = [];
    _userMap.values.forEach((u) {
      if (u.role != UserModel.ROLE_MODERATOR &&
          u.internalId != widget._meetingInfo.internalUserID) {
        nonModerators.add(u);
      }
    });

    moderators.sort((a, b) => a.sortName.compareTo(b.sortName));
    nonModerators.sort((a, b) => a.sortName.compareTo(b.sortName));

    List<UserModel> allUsers = currentUser + moderators + nonModerators;

    allUsers.removeWhere(
        (u) => u.connectionStatus != UserModel.CONNECTIONSTATUS_ONLINE);

    return allUsers;
  }

  Widget _buildUsers(BuildContext context, List<UserModel> users) {
    return ListView.builder(
        scrollDirection: Axis.vertical,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: users.length,
        itemBuilder: (BuildContext context, int index) {
          UserModel user = users[index];
          return Column(
            children: [
              _buildUserEntry(user, context),
              Divider(
                indent: 15,
                endIndent: 15,
              )
            ],
          );
        });
  }

  Widget _buildUserEntry(UserModel user, BuildContext context) {
    final bool isCurrentUser =
        user.internalId == widget._meetingInfo.internalUserID;

    final Widget bubble = Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: user.role == UserModel.ROLE_MODERATOR
            ? BorderRadius.circular(10)
            : BorderRadius.circular(99999),
        color: isCurrentUser
            ? Theme.of(context).disabledColor
            : Theme.of(context).accentColor,
      ),
      child: Center(
        child: Text(
          user.name.length > 2 ? user.name.substring(0, 2) : user.name,
          style: TextStyle(
              color: isCurrentUser
                  ? Theme.of(context).textTheme.bodyText1.color
                  : Theme.of(context).accentTextTheme.bodyText1.color),
        ),
      ),
    );

    return ListTile(
      leading: bubble,
      contentPadding: const EdgeInsets.only(left: 15.0, top: 0.0, bottom: 0.0),
      title: Row(
        children: [
          if (user.isPresenter)
            Container(
                margin: const EdgeInsets.only(right: 15.0),
                child: Icon(
                  Icons.desktop_windows,
                  size: 20.0,
                )),
          Text(user.name),
          if (isCurrentUser)
            Text(" (" +
                AppLocalizations.of(context).get("meeting-info.you") +
                ")"),
        ],
      ),
      trailing: !isCurrentUser ? _createItemPopupMenu(user) : null,
    );
  }

  /// Create popup menu for a user item.
  Widget _createItemPopupMenu(UserModel user) => PopupMenuButton<String>(
        onSelected: (result) {
          if (result == "createPrivateChat") {
            widget._mainWebSocket.chatModule.createGroupChat(user);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: "createPrivateChat",
            child: Text(AppLocalizations.of(context)
                .get("meeting-info.create-private-chat")),
          ),
        ],
      );

  /// Build the views application bar.
  Widget _buildAppBar() => AppBar(
      title: Text(AppLocalizations.of(context).get("meeting-info.title")),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios),
        tooltip: AppLocalizations.of(context).get("back"),
        onPressed: () {
          Navigator.pop(context);
        },
      ));
}
