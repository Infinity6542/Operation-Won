import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated({'auto-width': 279, 'auto-height': 282})
class ChannelList extends StatelessWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const ChannelList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        height: 100,
        width: 100,
        decoration: const BoxDecoration(
            color: Color(0x66ffe1b0),
            border:
                Border(bottom: BorderSide(color: Color(0xffc4c4c4), width: 1))),
        child: const Center(
          child: Text(
            'Placeholder',
          ),
        ),
      ),
    );
  }
}
