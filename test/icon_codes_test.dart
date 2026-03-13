import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Print Icon Codes', () {
    print('Food: ${Icons.restaurant_rounded.codePoint}');
    print('Fuel: ${Icons.local_gas_station_rounded.codePoint}');
    print('Salary: ${Icons.payments_rounded.codePoint}');
    print('Bills: ${Icons.receipt_long_rounded.codePoint}');
    print('Shopping: ${Icons.shopping_bag_rounded.codePoint}');
    print('Other: ${Icons.more_horiz_rounded.codePoint}');
    print('Rent: ${Icons.home_rounded.codePoint}');
    print('Utilities: ${Icons.lightbulb_rounded.codePoint}');
    print('Entertainment: ${Icons.movie_rounded.codePoint}');
    print('Health: ${Icons.medical_services_rounded.codePoint}');
    print('Transport: ${Icons.directions_car_rounded.codePoint}');
  });
}
