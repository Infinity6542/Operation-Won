import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@NowaGenerated()
class GlobalState extends ChangeNotifier {
  GlobalState();

  factory GlobalState.of(BuildContext context, {bool listen = true}) {
    return Provider.of<GlobalState>(context, listen: listen);
  }

  List<String>? events = [];

  final List<String>? param = [];
}
