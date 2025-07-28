import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@NowaGenerated()
class CommsState extends ChangeNotifier {
  CommsState();

  factory CommsState.of(BuildContext context, {bool listen = true}) {
    return Provider.of<CommsState>(context, listen: listen);
  }

  bool? isLoading = false;

  void createEvent() {}

  void createChannel() {}

  void getChannels() {}

  void getEvents() {}
}
