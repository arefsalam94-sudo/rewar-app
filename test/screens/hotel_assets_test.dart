import 'package:flutter_test/flutter_test.dart';
import 'package:kurdistan_paradise_travel_guide/screens/hotel_assets.dart';

void main() {
  test('the complete hotel flow reuses the approved local background', () {
    expect(hotelBackgroundAsset, 'assets/images/hotel background.webp');
  });
}
