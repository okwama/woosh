import 'package:flutter/material.dart';
import 'package:woosh/services/api_service.dart';
import 'package:woosh/models/noticeboard_model.dart';
import 'package:intl/intl.dart';
import 'package:woosh/utils/app_theme.dart';
import 'package:woosh/widgets/gradient_app_bar.dart'; // Import for date formatting

class NoticeBoardPage extends StatefulWidget {
  const NoticeBoardPage({super.key});

  @override
  State<NoticeBoardPage> createState() => _NoticeBoardPageState();
}

class _NoticeBoardPageState extends State<NoticeBoardPage> {
  late Future<List<NoticeBoard>> _noticesFuture;

  @override
  void initState() {
    super.initState();
    _noticesFuture = _loadNotices();
  }

  Future<List<NoticeBoard>> _loadNotices() async {
    try {
      return await ApiService.getNotice();
    } catch (e) {
      _showErrorSnackBar('Failed to load data');
      return [];
    }
  }

  Future<void> _refreshNotices() async {
    setState(() {
      _noticesFuture = _loadNotices();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing notices...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildNoticeCard(NoticeBoard notice) {
    String formattedDate =
        DateFormat('yyyy-MM-dd HH:mm').format(notice.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 120,
        maxHeight: 200,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: () {
            // Show full notice in a dialog
            showDialog(
              context: context,
              builder: (context) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notice.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        child: Text(
                          notice.content,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Posted on: $formattedDate',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.notifications_active,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        notice.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Text(
                    notice.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Tap to read more',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
      return Scaffold(
      backgroundColor: appBackground,
      appBar: GradientAppBar(
        title: 'Notice Board',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshNotices,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Notices List
            Expanded(
              child: FutureBuilder<List<NoticeBoard>>(
                future: _noticesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  } else if (snapshot.hasError || snapshot.data == null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load notices',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notices available',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return RefreshIndicator(
                      onRefresh: () async {
                        setState(() {
                          _noticesFuture = _loadNotices();
                        });
                      },
                      child: ListView.builder(
                        key: const PageStorageKey('notices_list'),
                        padding: const EdgeInsets.all(16.0),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final notice = snapshot.data![index];
                          return Card(
                            key: ValueKey('notice_${notice.id}_$index'),
                            child: _buildNoticeCard(notice),
                          );
                        },
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
