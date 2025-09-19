import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import 'package:test_chat/services/matrix_service.dart';
import 'package:test_chat/screens/chat_screen.dart';

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MatrixService>();
    final rooms = service.joinedRooms;
    final selectedRoom =
        service.selectedRoom ?? (rooms.isNotEmpty ? rooms.first : null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;
        if (isWide) {
          return Scaffold(
            appBar: AppBar(
              title: Text(selectedRoom != null
                  ? _roomTitle(selectedRoom)
                  : 'Matrix Chat'),
              actions: [
                IconButton(
                  onPressed: () =>
                      context.read<MatrixService>().refreshSelectedRoom(),
                  icon: const Icon(Icons.refresh),
                  tooltip: '重新整理',
                ),
                IconButton(
                  onPressed: () => context.read<MatrixService>().logout(),
                  icon: const Icon(Icons.logout),
                  tooltip: '登出',
                ),
              ],
            ),
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex:
                      selectedRoom != null ? rooms.indexOf(selectedRoom) : -1,
                  onDestinationSelected: (index) {
                    unawaited(
                      context.read<MatrixService>().selectRoom(rooms[index]),
                    );
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: rooms
                      .map(
                        (room) => NavigationRailDestination(
                          icon: const Icon(Icons.chat_bubble_outline),
                          selectedIcon: const Icon(Icons.chat_bubble),
                          label: Text(
                            _roomTitle(room),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: ChatScreen(room: selectedRoom),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(selectedRoom != null
                ? _roomTitle(selectedRoom)
                : 'Matrix Chat'),
            actions: [
              IconButton(
                onPressed: () =>
                    context.read<MatrixService>().refreshSelectedRoom(),
                icon: const Icon(Icons.refresh),
                tooltip: '重新整理',
              ),
              IconButton(
                onPressed: () => context.read<MatrixService>().logout(),
                icon: const Icon(Icons.logout),
                tooltip: '登出',
              ),
            ],
          ),
          drawer: Drawer(
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '聊天室',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: rooms.isEmpty
                        ? const Center(child: Text('尚未加入任何聊天室'))
                        : ListView.builder(
                            itemCount: rooms.length,
                            itemBuilder: (context, index) {
                              final room = rooms[index];
                              final isSelected = room == selectedRoom;
                              return ListTile(
                                selected: isSelected,
                                leading: const Icon(Icons.forum_outlined),
                                title: Text(
                                  _roomTitle(room),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  unawaited(
                                    context
                                        .read<MatrixService>()
                                        .selectRoom(room),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          body: ChatScreen(room: selectedRoom),
        );
      },
    );
  }

  String _roomTitle(Room room) {
    final displayName = room.getLocalizedDisplayname();
    if (displayName.isNotEmpty) {
      return displayName;
    }
    if (room.name.isNotEmpty) {
      return room.name;
    }
    return room.id;
  }
}
