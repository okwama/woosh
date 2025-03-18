// Notice Board Page
import 'package:flutter/material.dart';

class NoticeBoardPage extends StatelessWidget {
  const NoticeBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notice Board'),
      ),
      body: Center(
        child: Text('Notice Board Page Content'),
      ),
    );
  }
}
