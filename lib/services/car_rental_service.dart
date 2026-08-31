import '../models/car_rental.dart';

abstract interface class CarRentalService {
  Future<List<RentalVehicle>> trendingCars();

  Future<List<RentalVehicle>> searchCars(CarRentalSearchCriteria criteria);

  Future<List<RentalLocation>> searchLocations(String query);
}

/// Typed design-review data used until a rental provider is connected.
///
/// **Everything below is MOCK DATA.** None of it is written to Firestore,
/// fetched from a supplier, or presented as live inventory: the vehicles,
/// companies, branches, coordinates and prices are invented for visual review
/// of the Car Rental and Car Rental Results screens. Vehicle names are real
/// makes/models purely so the screens read naturally during review — they are
/// not offers, and nothing here implies a relationship with those makers.
///
/// Replacing this with a real provider means writing a second
/// [CarRentalService] implementation and passing it to the screens; no widget
/// or model change is required.
class PreviewCarRentalService implements CarRentalService {
  const PreviewCarRentalService();

  /// Shared development placeholder. Real per-vehicle photography replaces
  /// these paths when a supplier feed is connected; the path lives in the mock
  /// data only, never in a widget.
  static const _image = 'assets/images/journey-car.png';

  /// Stand-in gallery. The project ships exactly one car photograph, so the
  /// same asset is listed five times purely so the details carousel's swipe
  /// and page dots can be exercised during review. A supplier feed replaces
  /// this with real per-angle photography — front, rear, side, interior,
  /// dashboard — and the carousel renders however many arrive, since nothing
  /// in the widget layer assumes a count.
  static const _gallery = <String>[_image, _image, _image, _image, _image];

  /// Review add-ons. Prices are invented for visual review, exactly like the
  /// daily rates above, and are replaced wholesale by supplier data. They live
  /// on each vehicle (see [RentalVehicle.extras]) rather than in a global
  /// catalogue, so two companies can price the same add-on differently.
  static const _extras = <RentalExtra>[
    RentalExtra(
      id: 'preview-extra-mini-damage',
      name: RentalText(
        en: 'Mini Damage Protection',
        ku: 'پاراستنی زیانی بچووک',
        ar: 'حماية الأضرار الصغيرة',
      ),
      pricePerDay: 10,
    ),
    RentalExtra(
      id: 'preview-extra-super-damage',
      name: RentalText(
        en: 'Super Damage Protection',
        ku: 'پاراستنی زیانی تەواو',
        ar: 'حماية الأضرار الشاملة',
      ),
      pricePerDay: 17,
    ),
    RentalExtra(
      id: 'preview-extra-additional-driver',
      name: RentalText(
        en: 'Additional Driver',
        ku: 'شۆفێری زیادە',
        ar: 'سائق إضافي',
      ),
      pricePerDay: 6,
      selection: RentalExtraSelection.quantity,
      maxQuantity: 2,
    ),
    RentalExtra(
      id: 'preview-extra-baby-seat',
      name: RentalText(en: 'Baby Seat', ku: 'کورسی منداڵ', ar: 'مقعد أطفال'),
      pricePerDay: 5,
      selection: RentalExtraSelection.quantity,
      maxQuantity: 3,
    ),
    RentalExtra(
      id: 'preview-extra-gps',
      name: RentalText(
        en: 'GPS Navigation',
        ku: 'ڕێنیشاندەری GPS',
        ar: 'ملاحة GPS',
      ),
      pricePerDay: 4,
    ),
    RentalExtra(
      id: 'preview-extra-fuel-waiver',
      name: RentalText(
        en: 'Full Tank Return Waiver',
        ku: 'لێبوردنی گەڕاندنەوەی تانکی پڕ',
        ar: 'إعفاء إعادة الخزان ممتلئًا',
      ),
      pricePerDay: 13,
    ),
  ];

  static const erbilAirport = RentalLocation(
    id: 'preview-erbil-airport',
    name: RentalText(
      en: 'Erbil International Airport',
      ku: 'فڕۆکەخانەی نێودەوڵەتی هەولێر',
      ar: 'مطار أربيل الدولي',
    ),
    city: RentalText(en: 'Erbil', ku: 'هەولێر', ar: 'أربيل'),
    country: RentalText(en: 'Iraq', ku: 'عێراق', ar: 'العراق'),
    airportCode: 'EBL',
    latitude: 36.2376,
    longitude: 43.9632,
  );

  static const sulaymaniyahAirport = RentalLocation(
    id: 'preview-sulaymaniyah-airport',
    name: RentalText(
      en: 'Sulaimaniyah International Airport',
      ku: 'فڕۆکەخانەی نێودەوڵەتی سلێمانی',
      ar: 'مطار السليمانية الدولي',
    ),
    city: RentalText(en: 'Sulaimaniyah', ku: 'سلێمانی', ar: 'السليمانية'),
    country: RentalText(en: 'Iraq', ku: 'عێراق', ar: 'العراق'),
    airportCode: 'ISU',
    latitude: 35.5617,
    longitude: 45.3167,
  );

  static const duhokCenter = RentalLocation(
    id: 'preview-duhok-center',
    name: RentalText(
      en: 'Duhok City Centre',
      ku: 'ناوەندی شاری دهۆک',
      ar: 'وسط مدينة دهوك',
    ),
    city: RentalText(en: 'Duhok', ku: 'دهۆک', ar: 'دهوك'),
    country: RentalText(en: 'Iraq', ku: 'عێراق', ar: 'العراق'),
    latitude: 36.8612,
    longitude: 42.9998,
  );

  // Branch locations — invented addresses used only for review.
  static const wavyAvenue = RentalLocation(
    id: 'preview-wavy-avenue',
    name: RentalText(
      en: 'Wavy Avenue, near Empire Pearl',
      ku: 'شەقامی ویڤی، نزیک ئیمپایەر پێرل',
      ar: 'شارع ويفي، قرب إمباير بيرل',
    ),
    city: RentalText(en: 'Erbil', ku: 'هەولێر', ar: 'أربيل'),
    country: RentalText(en: 'Iraq', ku: 'عێراق', ar: 'العراق'),
    latitude: 36.2088,
    longitude: 43.9891,
  );

  static const dreamCity = RentalLocation(
    id: 'preview-dream-city',
    name: RentalText(
      en: 'Dream City, near 99 Grill',
      ku: 'دریم سیتی، نزیک ٩٩ گرێل',
      ar: 'دريم سيتي، قرب 99 غريل',
    ),
    city: RentalText(en: 'Erbil', ku: 'هەولێر', ar: 'أربيل'),
    country: RentalText(en: 'Iraq', ku: 'عێراق', ar: 'العراق'),
    latitude: 36.2172,
    longitude: 44.0128,
  );

  static const gulanStreet = RentalLocation(
    id: 'preview-gulan-street',
    name: RentalText(
      en: 'Gulan Street, near Sami Abdulrahman Park',
      ku: 'شەقامی گوڵان، نزیک پارکی سامی عەبدولڕەحمان',
      ar: 'شارع كولان، قرب حديقة سامي عبد الرحمن',
    ),
    city: RentalText(en: 'Erbil', ku: 'هەولێر', ar: 'أربيل'),
    country: RentalText(en: 'Iraq', ku: 'عێراق', ar: 'العراق'),
    latitude: 36.1938,
    longitude: 43.9861,
  );

  static const _abcCars = RentalCompany(
    id: 'preview-abc-cars',
    name: RentalText(
      en: 'ABC Cars',
      ku: 'ئەی بی سی کارز',
      ar: 'إيه بي سي كارز',
    ),
  );

  static const _paradiseRentACar = RentalCompany(
    id: 'preview-paradise-rent-a-car',
    name: RentalText(
      en: 'Paradise Rent A Car',
      ku: 'پەرادایس ڕێنت ئە کار',
      ar: 'باراديس رينت آ كار',
    ),
  );

  /// The five review vehicles. Test data only — not real rental offers.
  static const vehicles = <RentalVehicle>[
    RentalVehicle(
      id: 'preview-car-tesla-model-3',
      name: RentalText(
        en: 'Tesla Model 3',
        ku: 'تێسلا مۆدێل ٣',
        ar: 'تسلا موديل 3',
      ),
      modelYear: 2026,
      company: _abcCars,
      images: _gallery,
      passengers: 4,
      bags: 2,
      powertrain: RentalPowertrain.electric,
      transmission: RentalTransmission.automatic,
      airConditioning: true,
      paymentOption: RentalPaymentOption.payAtPickup,
      location: wavyAvenue,
      dailyPrice: 56,
      currencyCode: 'USD',
      extras: _extras,
      featured: true,
    ),
    RentalVehicle(
      id: 'preview-car-ford-mustang',
      name: RentalText(
        en: 'Ford Mustang',
        ku: 'فۆرد مەستانگ',
        ar: 'فورد موستانغ',
      ),
      modelYear: 2023,
      company: _abcCars,
      images: _gallery,
      passengers: 2,
      bags: 2,
      powertrain: RentalPowertrain.petrol,
      transmission: RentalTransmission.manual,
      airConditioning: true,
      paymentOption: RentalPaymentOption.payNow,
      location: dreamCity,
      dailyPrice: 44,
      currencyCode: 'USD',
      extras: _extras,
      featured: true,
    ),
    RentalVehicle(
      id: 'preview-car-toyota-corolla',
      name: RentalText(
        en: 'Toyota Corolla',
        ku: 'تۆیۆتا کۆرۆلا',
        ar: 'تويوتا كورولا',
      ),
      modelYear: 2024,
      company: _abcCars,
      images: _gallery,
      passengers: 4,
      bags: 4,
      powertrain: RentalPowertrain.hybrid,
      transmission: RentalTransmission.automatic,
      airConditioning: true,
      paymentOption: RentalPaymentOption.payAtPickup,
      location: wavyAvenue,
      dailyPrice: 30,
      currencyCode: 'USD',
      extras: _extras,
      featured: false,
    ),
    RentalVehicle(
      id: 'preview-car-range-rover',
      name: RentalText(en: 'Range Rover', ku: 'ڕەینج ڕۆڤەر', ar: 'رينج روفر'),
      modelYear: 2026,
      company: _abcCars,
      images: _gallery,
      passengers: 5,
      bags: 2,
      powertrain: RentalPowertrain.petrol,
      transmission: RentalTransmission.automatic,
      airConditioning: true,
      paymentOption: RentalPaymentOption.payAtPickup,
      location: wavyAvenue,
      dailyPrice: 110,
      currencyCode: 'USD',
      extras: _extras,
      featured: false,
    ),
    RentalVehicle(
      id: 'preview-car-bmw-x5',
      name: RentalText(
        en: 'BMW X5',
        ku: 'بی ئێم دەبلیو ئێکس٥',
        ar: 'بي إم دبليو إكس5',
      ),
      modelYear: 2025,
      company: _paradiseRentACar,
      images: _gallery,
      passengers: 5,
      bags: 3,
      powertrain: RentalPowertrain.hybrid,
      transmission: RentalTransmission.automatic,
      airConditioning: true,
      paymentOption: RentalPaymentOption.payNow,
      location: gulanStreet,
      dailyPrice: 82,
      currencyCode: 'USD',
      extras: _extras,
      featured: true,
    ),
  ];

  static const locations = <RentalLocation>[
    erbilAirport,
    sulaymaniyahAirport,
    duhokCenter,
    wavyAvenue,
    dreamCity,
    gulanStreet,
  ];

  @override
  Future<List<RentalVehicle>> trendingCars() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return vehicles;
  }

  @override
  Future<List<RentalVehicle>> searchCars(
    CarRentalSearchCriteria criteria,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    return vehicles;
  }

  @override
  Future<List<RentalLocation>> searchLocations(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) return const [];
    return locations
        .where((location) {
          final values = [
            location.name.en,
            location.name.ku,
            location.name.ar,
            location.city.en,
            location.city.ku,
            location.city.ar,
            location.country.en,
            location.airportCode ?? '',
          ].join(' ').toLowerCase();
          return values.contains(normalized);
        })
        .toList(growable: false);
  }
}
