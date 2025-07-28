import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated({'auto-width': 125.76953125, 'auto-height': 20})
class ListItem extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const ListItem({this.el = '', super.key});

  final String? el;

  @override
  State<ListItem> createState() {
    return _ListItemState();
  }
}

@NowaGenerated()
class _ListItemState extends State<ListItem> {
  String? itemName = 'A name ;)';

  String? uuid = '';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (true) {}
      },
      trackpadScrollToScaleFactor: const Offset(0, 0),
      child: const Wrap(
        direction: Axis.horizontal,
        children: [],
      ),
    );
  }
}
