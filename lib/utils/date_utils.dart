import 'package:intl/intl.dart';

class DateFormatter {
  // Format for displaying date and time in readable format
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    
    final formatter = DateFormat('MMM dd, yyyy hh:mm a');
    try {
      return formatter.format(dateTime.toLocal());
    } catch (e) {
      print('Error formatting date: $e');
      return 'Invalid Date';
    }
  }
  
  // Format for displaying just the date
  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    
    final formatter = DateFormat('MMM dd, yyyy');
    try {
      return formatter.format(dateTime.toLocal());
    } catch (e) {
      print('Error formatting date: $e');
      return 'Invalid Date';
    }
  }
  
  // Format for displaying just the time
  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    
    final formatter = DateFormat('hh:mm a');
    try {
      return formatter.format(dateTime.toLocal());
    } catch (e) {
      print('Error formatting time: $e');
      return 'Invalid Time';
    }
  }
} 