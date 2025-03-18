import 'package:whoosh/models/journeyPlan_model.dart';
import 'package:whoosh/models/order_model.dart';
import 'package:whoosh/models/token_model.dart';

class User {
  final int id;
  final String name;
  final String email;
  final String password; // Hashed password
  final List<Order> orders;
  final List<JourneyPlan> journeyPlans;
  final List<Token> tokens;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.orders,
    required this.journeyPlans,
    required this.tokens,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      password: json['password'],
      orders: (json['orders'] as List).map((order) => Order.fromJson(order)).toList(),
      journeyPlans: (json['journeyPlans'] as List)
          .map((journeyPlan) => JourneyPlan.fromJson(journeyPlan))
          .toList(),
      tokens: (json['tokens'] as List).map((token) => Token.fromJson(token)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'orders': orders.map((order) => order.toJson()).toList(),
      'journeyPlans': journeyPlans.map((journeyPlan) => journeyPlan.toJson()).toList(),
      'tokens': tokens.map((token) => token.toJson()).toList(),
    };
  }
}