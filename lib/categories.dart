import 'package:flutter/material.dart';

class ExpenseCategory {
  const ExpenseCategory(this.id, this.label, this.icon, this.keywords);

  final String id;
  final String label;
  final IconData icon;
  final List<String> keywords;
}

const expenseCategories = [
  ExpenseCategory('food', 'Food', Icons.restaurant_rounded, [
    'dinner',
    'lunch',
    'breakfast',
    'food',
    'cafe',
    'coffee',
    'tea',
    'pizza',
    'burger',
    'biryani',
    'restaurant',
    'snack',
    'drinks',
    'beer',
    'swiggy',
    'zomato',
  ]),
  ExpenseCategory('groceries', 'Groceries', Icons.shopping_basket_rounded, [
    'grocery',
    'groceries',
    'vegetable',
    'milk',
    'bigbasket',
    'blinkit',
    'zepto',
    'supermarket',
  ]),
  ExpenseCategory('travel', 'Travel', Icons.directions_car_rounded, [
    'uber',
    'ola',
    'cab',
    'taxi',
    'fuel',
    'petrol',
    'diesel',
    'flight',
    'train',
    'bus',
    'toll',
    'metro',
    'auto',
  ]),
  ExpenseCategory('stay', 'Stay', Icons.hotel_rounded, [
    'hotel',
    'hostel',
    'airbnb',
    'resort',
    'stay',
    'room',
  ]),
  ExpenseCategory('rent', 'Rent', Icons.home_rounded, ['rent', 'maintenance']),
  ExpenseCategory('bills', 'Bills', Icons.bolt_rounded, [
    'electricity',
    'wifi',
    'internet',
    'recharge',
    'bill',
    'water',
    'gas',
    'subscription',
    'netflix',
    'spotify',
  ]),
  ExpenseCategory('shopping', 'Shopping', Icons.shopping_bag_rounded, [
    'shopping',
    'clothes',
    'amazon',
    'flipkart',
    'gift',
  ]),
  ExpenseCategory('fun', 'Fun', Icons.movie_rounded, [
    'movie',
    'cinema',
    'game',
    'party',
    'concert',
    'trip',
    'club',
  ]),
  ExpenseCategory('health', 'Health', Icons.local_hospital_rounded, [
    'doctor',
    'medicine',
    'pharmacy',
    'hospital',
  ]),
  ExpenseCategory('other', 'Other', Icons.more_horiz_rounded, []),
];

ExpenseCategory categoryOf(String id) => expenseCategories.firstWhere(
  (c) => c.id == id,
  orElse: () => expenseCategories.last,
);

String guessCategory(String title) {
  final words = title.toLowerCase().split(RegExp(r'[^a-z0-9]+'));
  for (final category in expenseCategories) {
    for (final keyword in category.keywords) {
      if (words.contains(keyword)) return category.id;
    }
  }
  return 'other';
}
