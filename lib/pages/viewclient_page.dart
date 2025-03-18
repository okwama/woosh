// View Client Page
import 'package:flutter/material.dart';

class ViewClientPage extends StatelessWidget {
  const ViewClientPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View Client'),
      ),
      body: Center(
        child: Text('View Client Page Content'),
      ),
    );
  }
}
