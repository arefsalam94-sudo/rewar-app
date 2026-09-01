import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import '../models/booking.dart';
import '../models/help_topic.dart';
import '../models/nature_detail.dart';
import '../models/nature_filters.dart';
import '../models/policy_topic.dart';
import '../models/tour.dart';
import '../models/tour_filters.dart';

/// App localization for English, Kurdish (Sorani) and Arabic.
///
/// Hand-written (rather than generated) so it stays robust across Flutter
/// versions and gives full control over the Kurdish locale, which Flutter's
/// built-in localizations don't cover (handled via the fallback delegates
/// below — Kurdish reuses Arabic's Material/RTL localizations).
///
/// Access with `AppLocalizations.of(context)`.
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ku'), // Kurdish (Sorani)
    Locale('ar'),
  ];

  /// The full delegate list for [MaterialApp] (and tests). Kurdish fallback
  /// delegates come first so they win for `ku`; everything else is handled by
  /// the standard global delegates.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        _KurdishMaterialDelegate(),
        _KurdishCupertinoDelegate(),
        _KurdishWidgetsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ];

  static const Map<String, Map<String, String>>
  _values = <String, Map<String, String>>{
    'en': <String, String>{
      'chooseYourLanguage': 'Choose Your Language',
      'selectLanguageToContinue': 'Select a language to continue',
      'logIn': 'Log In',
      'email': 'Email',
      'password': 'Password',
      'forgetPassword': 'Forget Password',
      'orLabel': 'Or',
      'dontHaveAccount': "Don't have an account? ",
      'registerNow': 'Register Now',
      'continueAsGuest': 'Continue as Guest',
      'emailRequired': 'Please enter your email',
      'emailInvalid': 'Enter a valid email address',
      'passwordRequired': 'Please enter your password',
      'forgetPasswordSubtitle':
          'Please select your contact details and we will send a '
          'verification code to reset your password.',
      'phoneNumber': 'Phone number',
      'emailAddress': 'Email address',
      'sendCode': 'Send Code',
      'selectContactMethod': 'Choose phone or email first',
      'verificationCode': 'Verification Code',
      // {dest} is replaced with the masked phone/email, rendered in bold.
      'verificationSubtitle':
          'Enter the 6-digit code we just sent to {dest} to reset your '
          'password.',
      'didntReceiveCode': "Didn't receive the code? ",
      'resendNow': 'Resend now',
      'resendIn': 'Resend in {seconds}s',
      'verify': 'Verify',
      'codeIncomplete': 'Enter all 6 digits of the code',
      'codeIncorrect': 'That code is not correct. Please try again.',
      'codeExpired': 'This code has expired. Request a new one.',
      'tooManyAttempts': 'Too many attempts. Please wait before trying again.',
      'codeResentPhone': 'A new code has been sent by SMS',
      'codeResentEmail': 'A new code has been sent to your email',
      'sendCodeFailed': "We couldn't send the code. Please try again.",
      'networkError': 'No connection. Check your network and try again.',
      'resetPassword': 'Reset Password',
      'resetPasswordSubtitle':
          'At least 8 characters, with uppercase, lowercase and special '
          'character.',
      'newPassword': 'New Password',
      'confirmPassword': 'Confirm Password',
      'updatePassword': 'Update Password',
      'passwordTooShort': 'Use at least 8 characters',
      'passwordNeedsUppercase': 'Add at least one uppercase letter',
      'passwordNeedsLowercase': 'Add at least one lowercase letter',
      'passwordNeedsSpecial': 'Add at least one special character',
      'confirmPasswordRequired': 'Please re-enter the new password',
      'passwordsDontMatch': 'The two passwords do not match',
      'passwordUpdated': 'Password updated. Please log in.',
      'passwordUpdateFailed':
          "We couldn't update your password. Please try again.",
      'passwordTooWeak': 'Please choose a stronger password',
      'sessionExpired': 'Your session expired. Please start again.',
      // --- Register screen ---
      'register': 'Register',
      'fullName': 'Full Name',
      'age': 'Age',
      'gender': 'Gender',
      'genderMale': 'Male',
      'genderFemale': 'Female',
      'genderOther': 'Other',
      'genderOptional': 'Gender (optional)',
      'alreadyHaveAccount': 'Already have an Account? ',
      'logInHere': 'Log In here',
      'passwordHint':
          'At least 8 characters, with uppercase, lowercase and special '
          'character.',
      'acceptTerms': 'I agree to the Terms of Service and Privacy Policy',
      'termsRequired': 'Please accept the Terms and Privacy Policy',
      'fullNameRequired': 'Please enter your full name',
      'fullNameTooShort': 'Please enter your full name',
      'dateOfBirthRequired': 'Please choose your date of birth',
      'mustBe18': 'You must be at least 18 to create an account',
      'phoneRequired': 'Please enter your phone number',
      'phoneInvalid': 'Enter a valid phone number',
      'selectCountryCode': 'Country code',
      'accountCreated': 'Account created. Please log in.',
      'registerFailed': "We couldn't create your account. Please try again.",
      'emailInUse': 'An account already exists with this email',
      'phoneInUse': 'An account already exists with this phone number',
      'verifyNumberSubtitle':
          'Enter the 6-digit code we just sent to {dest} to verify your '
          'number.',
      'verifyEmailTitle': 'Verify your email',
      'verifyEmailSubtitle':
          'Enter the 6-digit code we just sent to {dest} to confirm your '
          'email address.',
      'emailVerified': 'Your email is verified.',
      // --- Terms of Service screen ---
      'termsOfService': 'Terms of Service',
      'termsAgreeCheckbox':
          'I have read and agree to the Terms of Service and Privacy Policy.',
      'continueLabel': 'Continue',
      'lastUpdated': 'Last updated: {date}',
      'termsLoadFailed': "We couldn't load the Terms. Please try again.",
      'tryAgain': 'Try again',
      'termsNotReviewed':
          'Draft wording — pending legal review. Not for release.',
      // --- Account Setup screen ---
      'accountSetup': 'Account Setup',
      'accountSetupSubtitle':
          'Finish your account setup by uploading profile picture and set '
          'your username.',
      'username': 'Username',
      'createAccount': 'Create Account',
      'chooseFromGallery': 'Choose from gallery',
      'takePhoto': 'Take a photo',
      'removePhoto': 'Remove photo',
      'usernameRequired': 'Please enter a username',
      'usernameTooShort': 'Use at least 2 characters',
      'imageTooLarge': 'That picture is too large. Choose one under 5 MB.',
      'imagePickFailed': "We couldn't open that picture. Please try again.",
      'profileSaveFailed': "We couldn't save your profile. Please try again.",
      'cameraPermissionDenied':
          'Camera access is off. Turn it on in Settings to take a photo.',
      'galleryPermissionDenied':
          'Photo access is off. Turn it on in Settings to choose a picture.',
      // --- Register Complete screen ---
      'registerComplete': 'Register Complete!',
      'registerCompleteSubtitle':
          'You have successfully created your account. Welcome!',
      'explore': 'Explore',
      // --- Onboarding (3-slide intro) ---
      // The title is two separate lines because each uses a different font:
      // line 1 Corbel Regular, line 2 Unbounded Medium.
      'onboardingTitleLine1': 'Discover',
      'onboardingTitleLine2': 'Kurdistan',
      // The only hard line break is before the closing sentence; the rest is
      // left to wrap naturally so longer translations don't break the layout.
      'onboardingBody1':
          'Explore beautiful valleys, rivers, and mountain trails that few '
          'travelers ever reach.\nAll in one app.',
      // Slide 2. One sentence with no hard break — it wraps to two lines on
      // its own, as the reference shows.
      'onboardingTitle2Line1': 'Fly to',
      'onboardingTitle2Line2': 'Kurdistan',
      'onboardingBody2':
          'Compare flights, pick your dates and book your ticket in minutes.',
      // Slide 3.
      'onboardingTitle3Line1': 'Your Ride',
      'onboardingTitle3Line2': 'Is Ready !',
      'onboardingBody3':
          'Rent a car and reach every corner of Kurdistan on your own '
          'schedule.',
      'onboardingNext': 'Next',
      // --- Home screen ---
      'goodMorning': 'Good morning',
      'goodAfternoon': 'Good afternoon',
      'goodEvening': 'Good evening',
      'dearUser': 'Dear User',
      'whereWouldYouLikeToGo': 'Where would you like to go?',
      'planYourJourney': 'Plan your journey',
      'exploreNature': 'Explore Nature',
      'exploreNatureHint': 'Trails, lakes & breathtaking parks.',
      'whereToStay': 'Where to Stay',
      'whereToStayHint': 'Hotels, cabins & unique stays',
      'hotelLocation': 'Location',
      'hotelLocationHint': 'Where do you want to stay?',
      'hotelRecentSearches': 'Recent Searches',
      'hotelDate': 'Date',
      'hotelCheckIn': 'Check-In',
      'hotelCheckOut': 'Check-Out',
      'hotelGuests': 'Guests',
      'hotelAdult': 'Adult',
      'hotelChild': 'Child',
      'hotelRoom': 'Room',
      'hotelBed': 'Bed',
      'hotelOptions': 'Options',
      'hotelNoOptions': 'No options selected',
      'hotelOneOption': '1 option selected',
      'hotelManyOptions': '{count} options selected',
      'hotelPool': 'Pool',
      'hotelBar': 'Bar',
      'hotelRestaurant': 'Restaurant',
      'hotelGym': 'Gym',
      'hotelParking': 'Parking',
      'hotelFreeWifi': 'Free WiFi',
      'hotelBeach': 'Beach',
      'hotelMoreOptions': 'More Options',
      'hotelSearch': 'Search',
      'hotelTrending': 'Trending Accommodations',
      'hotelPerNight': 'Per Night',
      'hotelDistanceFromCenter': '{distance} km from city center',
      'hotelAdultsBeds': '{adults} adults, {beds} beds',
      'hotelGuestSummary':
          '{adults} adults, {children} children, {rooms} rooms, {beds} beds',
      'hotelAdultCountOne': '{count} adult',
      'hotelAdultCountMany': '{count} adults',
      'hotelChildCountOne': '{count} child',
      'hotelChildCountMany': '{count} children',
      'hotelRoomCountOne': '{count} room',
      'hotelRoomCountMany': '{count} rooms',
      'hotelBedCountOne': '{count} bed',
      'hotelBedCountMany': '{count} beds',
      'hotelDestinationRequired': 'Please choose a location',
      'hotelInvalidDates': 'Check-out must be after check-in',
      'hotelPreviewData': 'Preview stays – live availability is not connected',
      'hotelCarouselPosition': 'Featured hotel {current} of {total}',
      'hotelStarClassification': '{count}-star hotel',
      'hotelReviewScore': 'Review score {score} out of 10',
      'hotelIncrease': 'Increase {name}',
      'hotelDecrease': 'Decrease {name}',
      // --- Hotel Details page ---
      'hotelDetails': 'Hotel Details',
      'hotelDetailNotFound': 'This hotel is no longer available.',
      'hotelDetailLoadFailed': 'We could not load this hotel.',
      'hotelGalleryPosition': '{current} / {total}',
      'hotelGalleryImage': 'Hotel photo {current} of {total}',
      'hotelChange': 'Change',
      'hotelUpdateStay': 'Update your stay',
      'hotelUpdateStayApply': 'Apply changes',
      'hotelStayUpdated': 'Your stay has been updated',
      'hotelFacilities': 'Facilities',
      'hotelAllFacilities': 'All facilities',
      'hotelNoFacilities': 'No facilities listed yet',
      'hotelSeeAll': 'See all',
      'hotelReviews': 'Reviews',
      'hotelReviewCountOne': '{count} review',
      'hotelReviewCountMany': '{count} reviews',
      'hotelCleanliness': 'Cleanliness',
      'hotelComfort': 'Comfort',
      'hotelService': 'Service',
      'hotelStaff': 'Staff',
      'hotelValue': 'Value',
      'hotelMap': 'Location',
      'hotelMapUnavailable': 'Map is unavailable',
      'hotelNearby': 'Nearby',
      'hotelNearbyEmpty': 'No nearby places listed yet',
      'hotelNearbyAll': 'Nearby places',
      'hotelNearbyDistance': '{distance} km',
      'hotelNearbyDistanceWithTime': '{minutes} min ({distance} km)',
      'hotelRatingsAndComments': 'Ratings & Comments',
      'hotelSelectRoom': 'Select Room',
      'hotelChooseRoom': 'Choose Your Room',
      'hotelMockNotice':
          'Preview data — availability and payments are not live.',
      'hotelNoRooms': 'No rooms are available for these dates.',
      'hotelChangeDates': 'Change dates',
      'hotelBackToHotel': 'Back to hotel',
      'hotelSeeRoomDetails': 'See room details',
      'hotelMaximumGuests': 'Maximum {count} guests',
      'hotelReserve': 'Reserve',
      'hotelPriceForNights': 'Price for {count} night(s)',
      'hotelRechecking': 'Rechecking price and availability…',
      'hotelCompleteBooking': 'Complete Your Booking',
      'hotelGuestDetails': 'Guest details',
      'hotelSpecialRequestsHint':
          'Optional requests are subject to hotel availability',
      'hotelStripePreview': 'Stripe — preview only',
      'hotelFibPreview': 'FIB — preview only',
      'hotelMockPaymentNotice':
          'No payment will be sent. This checkout creates a local preview reservation only.',
      'hotelRoomSubtotal': 'Room subtotal',
      'hotelBookingConsent':
          'I agree to the displayed rate and cancellation conditions.',
      'hotelConfirmMockBooking': 'Confirm preview booking',
      'hotelMockBookingComplete': 'Preview Booking Complete',
      'hotelMockBookingCompleteBody':
          'No room was held with a hotel and no payment was charged.',
      'hotelViewReservations': 'View Your Reservations',
      'hotelGuestRequired': 'Please complete the required guest details.',
      'hotelConsentRequired': 'Please accept the booking conditions.',
      'hotelRateUnavailable':
          'This rate is no longer available. Choose another option.',
      'hotelPropertyPolicies': 'Property policies',
      'hotelPolicyCheckInFrom': 'Check-in from',
      'hotelPolicyCheckOutUntil': 'Check-out until',
      'hotelPolicyChildren': 'Children',
      'hotelPolicyCribs': 'Cribs',
      'hotelPolicyExtraBeds': 'Extra beds',
      'hotelPolicyAgeRestriction': 'Age restriction',
      'hotelPolicyMinimumAge': 'The minimum check-in age is {age}',
      'hotelPolicyPets': 'Pets',
      'hotelPolicySmoking': 'Smoking',
      'hotelPolicyPayment': 'Accepted payment methods',
      'hotelPolicySpecialRequests': 'Special requests',
      'hotelPolicySpecialRequestsYes':
          'Special requests can be added to your booking.',
      'hotelPolicySpecialRequestsNo': 'Special requests cannot be accepted.',
      'hotelPolicyAccessibility': 'Accessibility',
      'hotelFacilityGeneral': 'General',
      'hotelFacilityInternet': 'Internet',
      'hotelFacilityParking': 'Parking',
      'hotelFacilityFoodAndDrink': 'Food & Drink',
      'hotelFacilityWellness': 'Wellness',
      'hotelFacilityPool': 'Pool',
      'hotelFacilityTransportation': 'Transportation',
      'hotelFacilityRoom': 'Room facilities',
      'hotelFacilityFamily': 'Family',
      'hotelFacilityAccessibility': 'Accessibility',
      'hotelFacilityBusiness': 'Business',
      'hotelFacilitySafety': 'Safety',
      'hotelBedSingle': 'Single bed',
      'hotelBedTwin': 'Twin bed',
      'hotelBedDouble': 'Double bed',
      'hotelBedQueen': 'Queen bed',
      'hotelBedKing': 'King bed',
      'hotelBedSofa': 'Sofa bed',
      'hotelBedBunk': 'Bunk bed',
      'hotelBedCount': '{count} × {bed}',
      'hotelBreakfastIncluded': 'Breakfast included',
      'hotelBreakfastExtra': 'Breakfast available for an extra charge',
      'hotelBreakfastUnavailable': 'Breakfast not available',
      'hotelTaxesAndFees': 'Taxes and fees',
      'hotelTaxesIncluded': 'Taxes and fees included',
      'hotelTaxesExcluded': 'Taxes and fees are not included',
      'hotelFreeCancellation': 'Free cancellation',
      'hotelPartiallyRefundable': 'Partially refundable',
      'hotelNonRefundable': 'Non-refundable',
      'hotelPayNow': 'Pay now',
      'hotelPayLater': 'Pay later',
      'hotelPayAtProperty': 'Pay at property',
      'hotelPrepaymentRequired': 'Prepayment required',
      'hotelPartialPrepayment': 'Partial prepayment required',
      'hotelNoPrepayment': 'No prepayment needed',
      'hotelRoomsLeftOne': 'Only {count} room left',
      'hotelRoomsLeftMany': 'Only {count} rooms left',
      'bestPrice': 'Best Price',
      'carRental': 'Car Rental',
      'carRentalHint': 'Find the perfect car for your adventure',
      'findACar': 'Find a Car',
      'carPickupDropOffLocation': 'Pick-up – Drop-off Location',
      'carPickup': 'Pick-up',
      'carDropOff': 'Drop-off',
      'carPickupLocation': 'Pick-up location',
      'carDropOffLocation': 'Drop-off location',
      'carDifferentDropOff': 'Drop off in a different location',
      'carSelectDate': 'Select date',
      'carSelectTime': 'Select time',
      'carSearch': 'Search',
      'carSearching': 'Searching…',
      'carTrending': 'Trending Cars',
      'carAvailable': 'Available Cars',
      'carNoAvailable': 'No cars available for these dates',
      'carSearchLocations': 'Search rental location',
      'carLocationSearchHint': 'City, airport, code, or branch',
      'carLocationStartTyping': 'Enter at least 2 characters',
      'carNoLocations': 'No rental locations found',
      'carLocationsFailed': 'Unable to load rental locations',
      'carPickupLocationRequired': 'Please choose a pick-up location',
      'carDropOffLocationRequired': 'Please choose a drop-off location',
      'carPickupDateRequired': 'Please choose a pick-up date',
      'carPickupTimeRequired': 'Please choose a pick-up time',
      'carDropOffDateRequired': 'Please choose a drop-off date',
      'carDropOffTimeRequired': 'Please choose a drop-off time',
      'carPickupFuture': 'Pick-up must be in the future',
      'carDropOffAfterPickup': 'Drop-off must be after pick-up',
      'carSearchFailed': "Couldn't load available cars",
      'carPersons': '{count} persons',
      'carBags': '{count} bags',
      'carAirConditioning': 'AC',
      'carHybrid': 'Hybrid',
      'carElectric': 'Electric',
      'carPetrol': 'Petrol',
      'carDiesel': 'Diesel',
      'carPayAtPickup': 'Pay at pickup',
      'carPayNow': 'Pay now',
      'carModelYear': 'Model {year}',
      'carPricePerDay': '{price}/day',
      'carPreviewData': 'Preview cars – live availability is not connected',
      'carCarouselPosition': 'Featured car {current} of {total}',
      'carResultsOne': '1 Result',
      'carResultsMany': '{count} Results',
      'carResultsEmptyTitle': 'No cars found',
      'carResultsEmptyBody':
          'No cars found for your selected dates and location.',
      'carModifySearch': 'Modify Search',
      'carResultsLoading': 'Loading available cars',
      'carResultsListLabel': 'Car rental search results',
      'carDetails': 'Car details',
      'carPickupDropOffDetails': 'Pick-Up / Drop Off Details',
      'carLocation': 'Location',
      'carAdditionalOptions': 'Additional Options',
      'carApply': 'Apply',
      'carAutomatic': 'Automatic',
      'carManual': 'Manual',
      'carPhotoPosition': 'Photo {current} of {total}',
      'carGalleryLabel': '{name} photos',
      'carDecreaseQuantity': 'Fewer {name}',
      'carIncreaseQuantity': 'More {name}',
      'carExtraTimesQuantity': '{price} × {count}',
      'carPriceSummary': 'Price Summary',
      'carBaseRental': 'Base rental',
      'carExtrasTotal': 'Extras',
      'carEstimatedTotal': 'Estimated total',
      'carRentalDayOne': '1 rental day',
      'carRentalDaysMany': '{count} rental days',
      'carEstimateNote':
          'Estimate only — taxes and supplier fees are not included.',
      'carRentalConditions': 'Rental Conditions',
      'carFuelPolicy': 'Fuel policy',
      'carFuelFullToFull': 'Full to full',
      'carFuelFullToEmpty': 'Full to empty',
      'carFuelSameToSame': 'Same to same',
      'carMileage': 'Mileage',
      'carMileageUnlimited': 'Unlimited',
      'carMileagePerDay': '{count} km per day',
      'carMileageExtra': '{price} per extra km',
      'carDeposit': 'Security deposit',
      'carDamageExcess': 'Damage excess',
      'carFreeCancellation': 'Free cancellation until',
      'carMinimumAge': 'Minimum driver age',
      'carMinimumAgeValue': '{age} years',
      'carRequiredDocuments': 'Required documents',
      'carOrSimilar': 'This model or a similar vehicle',
      'flightTicketing': 'Flight Ticketing',
      'flightTicketingHint': 'Cheap flights, easy booking, secure payments',
      'findFlight': 'Find Flight',
      'flightOneWay': 'One-way',
      'flightRoundTrip': 'Round trip',
      'flightFrom': 'From',
      'flightTo': 'To',
      'flightSearchAirport': 'Search airport',
      'flightAirportSearchHint': 'City, airport, IATA code, or country',
      'flightAirportStartTyping': 'Enter at least 2 characters',
      'flightNoAirportsFound': 'No airports found',
      'flightAirportLoadFailed': 'Unable to load airports',
      'flightDepartureDate': 'Departure',
      'flightReturnDate': 'Return',
      'flightPassengers': 'Passengers',
      'flightAdults': 'Adults (12+)',
      'flightChildren': 'Children (2–11)',
      'flightInfants': 'Infants (under 2)',
      'flightCabinClass': 'Cabin class',
      'flightCabinEconomy': 'Economy',
      'flightCabinPremiumEconomy': 'Premium Economy',
      'flightCabinBusiness': 'Business',
      'flightCabinFirst': 'First Class',
      'flightDirectOnly': 'Direct flights only',
      'flightSearch': 'Search flights',
      'flightSearching': 'Searching…',
      'done': 'Done',
      'flightOriginRequired': 'Please enter where you are flying from',
      'flightDestinationRequired': 'Please enter where you are flying to',
      'flightDifferentAirports': 'Origin and destination must be different',
      'flightDepartureRequired': 'Please choose a departure date',
      'flightReturnRequired': 'Please choose a return date',
      'flightSearchReady': 'Your flight search is ready for the results page',
      'flightPassengerSummary':
          '{adults} adult · {children} child · {infants} infant',
      'flightResultsOne': '1 flight found',
      'flightResultsMany': '{count} flights found',
      'flightSortBest': 'Best',
      'flightSortCheapest': 'Cheapest',
      'flightSortFastest': 'Fastest',
      'flightSelect': 'Select',
      'flightDirect': 'Direct',
      'flightOneStop': '1 stop',
      'flightManyStops': '{count} stops',
      'flightOutbound': 'Outbound',
      'flightReturn': 'Return',
      'flightTotalPrice': 'Total price',
      'flightPerTraveler': 'Per traveler',
      'flightResultsLoadFailed': "Couldn't load flights",
      'flightResultsEmptyTitle': 'No flights found',
      'flightResultsEmptyBody':
          'Try another date or change your search filters.',
      'flightRetry': 'Retry',
      'flightPreviousDate': 'Previous date',
      'flightNextDate': 'Next date',
      'flightOfferSelected': 'Flight selected for the next booking step',
      'exploreToursTitle': 'Explore Tours',
      'exploreToursHint': 'Local experiences, hidden gems & expert guides',
      'findTours': 'Find Tours',
      'placesCount': '{count}+ places',
      'navHome': 'Home',
      'navTrips': 'Trips',
      'navMap': 'Map',
      'navSaved': 'Saved',
      'featuredLoadFailed': "Couldn't load featured destinations",
      'featuredEmpty': 'Nothing is featured yet',
      'signInToSave': 'Sign in to save favourites',
      'signInToSaveBody':
          'Create an account or log in to keep your favourite places.',
      'notNow': 'Not now',
      'addedToFavorites': 'Added to your favourites',
      'removedFromFavorites': 'Removed from your favourites',
      'favoriteFailed': "Couldn't update your favourites",
      'comingSoon': 'Coming soon',
      'mapOpenFailed': "Couldn't open the maps app",
      'menu': 'Menu',
      'changeLanguage': 'Change language',
      // --- Home screen side drawer ---
      'close': 'Close',
      'services': 'Services',
      'myBookings': 'My Bookings',
      'billingPayments': 'Billing/Payments',
      'billingPaymentTitle': 'Billing & Payments',
      'currentPaymentMethod': 'Current Payment Method',
      'addPaymentMethod': 'Add a payment method',
      'addPaymentMethodDescription':
          'Save your debit or credit card to pay for hotels, flights, car rentals, and tours.',
      'paymentInformationEncrypted':
          'Your payment information is securely encrypted.',
      'addCard': 'Add Card',
      'debitOrCreditCard': 'Debit or Credit Card',
      'secureCheckout': 'Secure checkout',
      'secureCardSetupUnavailable': 'Secure card setup is coming soon.',
      'paymentMethodAlreadyAdded':
          'A payment method is already linked to your account.',
      'newCard': 'New Card',
      'newCardDescription':
          'Add a card for faster checkout on future bookings.',
      'cardDetails': 'Card Details',
      'cardholderName': 'Cardholder Name',
      'cardNumber': 'Card Number',
      'expiryDate': 'Expiry Date',
      'expiryHint': 'MM/YY',
      'cvv': 'CVV',
      'country': 'Country',
      'yourCountry': 'Your country',
      'zipCode': 'ZIP Code',
      'optional': 'Optional',
      'saveCardForFutureBookings': 'Save this card for future bookings',
      'editPaymentMethodLater':
          'You can edit or remove this payment method later from Billing & Payment.',
      'requiredField': 'This field is required.',
      'invalidCardNumber': 'Enter a valid card number.',
      'invalidExpiryDate': 'Enter a valid future date.',
      'invalidCvv': 'Enter a valid CVV.',
      'editProfile': 'Edit Profile',
      'editProfileSubtitle': 'Update your photo and full name.',
      'firstAndLastName': 'First and last name',
      'firstName': 'First name',
      'lastName': 'Last name',
      'firstAndLastNameRequired': 'Enter both your first and last name.',
      'saveChanges': 'Save Changes',
      'profileUpdated': 'Your profile was updated.',
      'settingsUpdateFailed': 'Could not update this setting. Try again.',
      'changeEmail': 'Change Email',
      'changeEmailSubtitle':
          'Confirm your password, then verify the new email address.',
      'confirmEmailIdentitySubtitle':
          'Enter your current account email and app password to confirm your identity.',
      'currentEmail': 'Current email',
      'newEmail': 'New email',
      'newEmailVerificationSubtitle':
          'Enter the new email and the 6-digit verification code we send there.',
      'emailUpdated': 'Your email was updated.',
      'currentPassword': 'Current password',
      'enterValidEmail': 'Enter a valid email address.',
      'sendVerificationLink': 'Send Verification Link',
      'emailVerificationSent':
          'Verification sent. Your email changes after you approve the link.',
      'reauthenticationFailed': 'Your current password could not be verified.',
      'changePhoneNumber': 'Change Phone Number',
      'changePhoneSubtitle': 'We will send an SMS code to verify this number.',
      'newPhoneNumber': 'New phone number',
      'phoneInternationalFormat': 'Use international format, such as +964…',
      'verificationCodeSent': 'Verification code sent.',
      // 'verificationCode' and 'sendCode' already exist earlier in this map.
      'verifyAndSave': 'Verify & Save',
      'invalidVerificationCode': 'The verification code is invalid.',
      'passwordChangeRules':
          'Use at least 8 characters, one uppercase letter, and one symbol.',
      'kilometers': 'Kilometers (km)',
      'miles': 'Miles (mi)',
      'milesShort': 'mi',
      'defaultPayment': 'Default',
      'debitCard': 'Debit Card',
      'creditCard': 'Credit Card',
      'kurdistanInternationalBank': 'Kurdistan International Bank',
      'firstIraqiBank': 'First Iraqi Bank',
      'newlyAddedCard': 'Newly added card',
      'savedCard': 'Saved card',
      'add': 'Add',
      'change': 'Change',
      'delete': 'Delete',
      'cancel': 'Cancel',
      'setDefaultCard': 'Set default card',
      'setDefaultCardBody': 'This card will be used for new bookings.',
      'defaultCardUpdated': 'Default card updated',
      'deleteCardTitle': 'Delete this card?',
      'deleteCardBody':
          'The card ending {last4} will be removed from your saved payment '
          'methods. You can add it again at any time.',
      'cardDeleted': 'Card removed',
      'cardAdded': 'Card added',
      'billingSignInTitle': 'Sign in to manage payment',
      'billingSignInBody':
          'Your saved cards are tied to your account, so we need you signed in '
          'to show them.',
      'photoSignInTitle': 'Sign in to add a photo',
      'photoSignInBody':
          'Your profile picture is saved to your account, so we need you '
          'signed in to change it.',
      'paymentHistory': 'Payment History',
      'paid': 'Paid',
      'pending': 'Pending',
      'viewReceipt': 'View Receipt',
      'hotel': 'Hotel',
      'flight': 'Flight',
      'car': 'Car',
      'tour': 'Tour',
      'mountainViewResort': 'Mountain View Resort',
      'erbilToIstanbul': 'Erbil → Istanbul',
      'suvRental': 'SUV Rental',
      'rawanduzCanyonAdventure': 'Rawanduz Canyon Adventure',
      'paymentDateMay24': 'May 24, 2025',
      'paymentDateMay23': 'May 23, 2025',
      'paymentDateMay25': 'May 25, 2025',
      'paymentDateMay26': 'May 26, 2025',
      'settings': 'Settings',
      'settingsAccount': 'Account',
      'settingsChangePassword': 'Change password',
      'settingsPreferences': 'Preferences',
      'settingsNotifications': 'Notifications',
      'settingsTheme': 'Theme',
      'settingsLanguage': 'Language',
      'settingsUnits': 'Units',
      'settingsSecurityLegal': 'Security & legal',
      'settingsSecurityPrivacy': 'Security & privacy',
      'settingsDeleteAccount': 'Delete account',
      'notificationsPermissionDenied':
          'Notification permission was not granted.',
      'notificationsUpdateFailed':
          "We couldn't update notifications. Please try again.",
      'languageEnglish': 'English',
      'languageKurdish': 'Kurdish',
      'languageArabic': 'Arabic',
      'kilometersShort': 'Km',
      'currency': 'Currency',
      'policy': 'Policy',
      'helpSupport': 'Help/Support',
      'aboutUs': 'About Us',
      'contactWay': 'Contact Way',
      'logOut': 'Log Out',
      'guestUser': 'Guest',
      'guestDrawerPrompt': 'Sign in to see your profile',
      'signInRequired': 'Please sign in first',
      'selectCurrency': 'Select Currency',
      'currencyUSD': 'US Dollar (USD)',
      'currencyIQD': 'Iraqi Dinar (IQD)',
      'currencyEUR': 'Euro (EUR)',
      'currencyUpdated': 'Currency updated',
      'currencyUpdateFailed':
          "We couldn't update your currency. Please try again.",
      'logOutFailed': "We couldn't log you out. Please try again.",
      'profilePhotoUpdated': 'Profile photo updated',
      // --- Explore Nature screen ---
      'filterHiking': 'Hiking',
      'filterBeach': 'Beach',
      'filterSunsetView': 'Sunset View',
      'filterCustomize': 'Customize',
      'locationLabel': 'Location:',
      'distanceLabel': 'Distance:',
      'distanceFromCurrentLocation': '{distance} from current location',
      'natureSpotsLoadFailed': "Couldn't load places. Please try again.",
      'natureSpotsEmpty': 'No places match these filters yet',
      'highlightedEmpty': 'Nothing is highlighted yet',
      'clearFilters': 'Clear filters',
      'aboutThisPlace': 'About this place',
      'placeNameLabel': 'Name:',
      'placeDistanceLabel': 'Distance:',
      'suggestedStaysNearby': 'Suggested stays nearby',
      'stayDistanceAway': '{distance} km away',
      'weather': 'Weather',
      'weatherUnavailable': 'Weather is unavailable right now',
      'sunny': 'Sunny',
      'partlyCloudy': 'Partly cloudy',
      'cloudy': 'Cloudy',
      'rainy': 'Rainy',
      'snowy': 'Snowy',
      'ratingsAndReviews': 'Ratings & Reviews',
      'basedOnReviews': 'Based on {count} reviews',
      'writeReviewPrompt': 'Visited this place?',
      'writeReviewHint': 'Tap here to rate your visit and write a comment',
      'reviewsLoadFailed': "Couldn't load visitor reviews",
      'noReviewsYet': 'No reviews yet. Be the first to share your visit.',
      'seeAllReviews': 'See all reviews',
      'openPlaceMap': 'Open place map',
      'reviewsCount': '{count} reviews',
      // --- Reviews & Ratings screen ---
      'reviewsAndRatings': 'Reviews & Ratings',
      'averageRating': 'Average Rating',
      'outOfTen': '/ 10',
      'allReviews': 'All Reviews',
      'sortMostRecent': 'Most Recent',
      'sortHighestRated': 'Highest Rated',
      'sortLowestRated': 'Lowest Rated',
      'sortMostHelpful': 'Most Helpful',
      'sortReviewsBy': 'Sort reviews by',
      'oneReview': '1 review',
      'noRatingsYet': 'Not rated yet',
      'addYourReview': 'Add your review',
      'yourRating': 'Your rating',
      'reviewCommentHint': 'Tell others about your experience…',
      'postReview': 'Post Review',
      'updateReview': 'Update Review',
      'reviewPosted': 'Thanks — your review is live',
      'reviewUpdated': 'Your review has been updated',
      'reviewPostFailed': "We couldn't post your review. Please try again.",
      'reviewRatingRequired': 'Choose a star rating first',
      'reviewCommentTooShort': 'Write at least 3 characters',
      'reviewCommentTooLong': 'Keep your review under 1000 characters',
      'reviewSignInTitle': 'Sign in to write a review',
      'reviewSignInBody':
          'Reviews are tied to your account, so everyone can see who visited.',
      'yourReviewLabel': 'Your review',
      'editYourReview': 'Edit your review',
      'helpfulVote': 'Mark this review as helpful',
      'helpfulVoteRemove': 'Remove your helpful vote',
      'helpfulSignInBody': 'Sign in to tell others a review was helpful.',
      'helpfulFailed': "We couldn't save your vote. Please try again.",
      'loadMoreReviews': 'Show more reviews',
      'reviewJustNow': 'Just now',
      'reviewHoursAgo': '{count} hours ago',
      'reviewOneHourAgo': '1 hour ago',
      'reviewDaysAgo': '{count} days ago',
      'reviewOneDayAgo': '1 day ago',
      'reviewWeeksAgo': '{count} weeks ago',
      'reviewOneWeekAgo': '1 week ago',
      'reviewMonthsAgo': '{count} months ago',
      'reviewOneMonthAgo': '1 month ago',
      'reviewYearsAgo': '{count} years ago',
      'reviewOneYearAgo': '1 year ago',
      // --- Customize Filters screen ---
      'customizeFilters': 'Customize Filters',
      'customizeFiltersSubtitle': 'Find places that match your trip',
      'filtersSelected': '{count} Filters selected',
      'oneFilterSelected': '1 Filter selected',
      'noFiltersSelected': 'No filters selected',
      'resetAll': 'Reset All',
      'placeType': 'Place Type',
      'facilitiesAmenities': 'Facilities & Amenities',
      'showPlaces': 'Show {count} Places',
      'showOnePlace': 'Show 1 Place',
      'showNoPlaces': 'No places match',
      'placeTypeForest': 'Forest',
      'placeTypeMountain': 'Mountain',
      'placeTypeCanyon': 'Canyon',
      'placeTypePark': 'Park',
      'placeTypeLake': 'Lake',
      'placeTypeWaterfall': 'Waterfall',
      'placeTypeRiver': 'River',
      'placeTypeMuseum': 'Museum',
      'amenityParking': 'Parking',
      'amenityRestrooms': 'Restrooms',
      'amenityRestaurants': 'Restaurants',
      'amenityCafes': 'Cafes',
      'amenityMobileSignal': 'Mobile signal',
      'amenityLodgingNearby': 'Lodging nearby',
      'amenityAtmNearby': 'ATM nearby',
      // --- Policy screen ---
      'policyOfApp': 'Policy of App',
      'policyOfAppSubtitle':
          'Read our guidelines and policies to learn how we protect you.',
      'policyPrivacyTitle': 'Privacy Policy',
      'policyPrivacySubtitle': 'How we handle your data',
      'policyTermsTitle': 'Terms & Conditions',
      'policyTermsSubtitle': 'Rules for using the app',
      'policyCancellationTitle': 'Cancellation & Refunds',
      'policyCancellationSubtitle': 'Changing or cancelling bookings',
      'policyPaymentTitle': 'Payment Policy',
      'policyPaymentSubtitle': 'Methods, currency & charges',
      'policyLiabilityTitle': 'Liability & Disclaimer',
      'policyLiabilitySubtitle': 'Limits of our responsibility',
      'policyContactTitle': 'Contact & Complaints',
      'policyContactSubtitle': 'Reach support',
      'policyAccountDeletionTitle': 'Account & Data Deletion',
      'policyAccountDeletionSubtitle': 'Delete your account and your data',
      'policyLoadFailed': "We couldn't load this policy. Please try again.",
      // --- Help & Support screen ---
      'helpAndSupport': 'Help & Support',
      'helpAccountTitle': 'Account & Sign-in',
      'helpAccountPreview': 'How do I change my email or ...',
      'helpBookingsTitle': 'Bookings & Confirmation',
      'helpBookingsPreview': 'What is my booking reference ...',
      'helpPaymentsTitle': 'Payments & Refunds',
      'helpPaymentsPreview': 'My payment failed but I ...',
      'helpCancellationTitle': 'Cancellation & Changes',
      'helpCancellationPreview': 'Can I change my booking instead ...',
      'helpFlightsTitle': 'Flights',
      'helpFlightsPreview': 'What is the baggage allowance ...',
      'helpStaysTitle': 'Where to Stay (Hotels)',
      'helpStaysPreview': 'What are the check-in and ...',
      'helpCarRentalTitle': 'Car Rental',
      'helpCarRentalPreview': 'What documents do I need to ...',
      'helpToursTitle': 'Tours & Nature (Explore)',
      'helpToursPreview': 'What happens if the weather ...',
      'helpSafetyTitle': 'Safety & Travel Info',
      'helpSafetyPreview': 'What are the emergency numbers in ...',
      'helpContactTitle': 'Still need help? Contact us',
      'helpContactPreview': 'Get in touch with our support team ...',
      // --- My Bookings screen ---
      'bookingsFilterAll': 'All',
      'bookingsFilterHotels': 'Hotels',
      'bookingsFilterCars': 'Cars',
      'bookingsFilterFlights': 'Flights',
      'bookingsFilterTours': 'Tours',
      'bookingsSegmentUpcoming': 'Upcoming',
      'bookingsSegmentPast': 'Past',
      'bookingsSegmentCancelled': 'Cancelled',
      'bookingTypeHotel': 'HOTEL',
      'bookingTypeCar': 'CAR RENTAL',
      'bookingTypeFlight': 'FLIGHT',
      'bookingTypeTour': 'TOUR',
      'bookingStatusConfirmed': 'CONFIRMED',
      'bookingStatusPending': 'PENDING',
      'bookingStatusCancelled': 'CANCELLED',
      'bookingStatusCompleted': 'COMPLETED',
      'bookingStatusUpcoming': 'UPCOMING',
      'cabinEconomy': 'ECONOMY',
      'cabinPremiumEconomy': 'PREMIUM',
      'cabinBusiness': 'BUSINESS',
      'cabinFirst': 'FIRST',
      'bookingCheckIn': 'Check-in',
      'bookingCheckOut': 'Check-out',
      'bookingGuests': 'Guests',
      'bookingTravelers': 'Travelers',
      'bookingDriver': 'Driver',
      'bookingTraveler': 'Traveler',
      'bookingSeat': 'Seat',
      'bookingDuration': 'Duration',
      'bookingId': 'Booking ID',
      'bookingPickup': 'Pick-up',
      'bookingDropoff': 'Drop-off',
      'bookingTotalPaid': 'Total paid',
      'bookingActionCheckIn': 'Check In',
      'bookingActionOpenTicket': 'Open Ticket',
      'bookingActionPickupInfo': 'Pickup Info',
      'bookingActionTourDetails': 'Tour Details',
      'bookingActionViewDetails': 'View Details',
      'bookingAdultsCount': '{count} Adults',
      'bookingAdultCount': '{count} Adult',
      'bookingHours': '{count} Hours',
      'bookingsLoadFailed': "Couldn't load your bookings",
      'bookingsEmptyTitle': 'No bookings yet',
      'bookingsEmptyBody':
          'When you book a hotel, flight, car or tour, it will appear here.',
      'bookingsEmptyUpcoming': 'No upcoming bookings',
      'bookingsEmptyPast': 'No past bookings',
      'bookingsEmptyCancelled': 'No cancelled bookings',
      'bookingsEmptyFiltered':
          'Nothing matches this filter. Try another category.',
      'bookingsSignInTitle': 'Sign in to see your bookings',
      'bookingsSignInBody':
          'Your bookings are tied to your account, so we need you signed in to show them.',
      'bookingsStartExploring': 'Start exploring',
      // Month names and meridiems, for the booking date/time rows. Written out
      // here rather than taken from `intl`, which has no Kurdish (`ku`) locale.
      'month1': 'January',
      'month2': 'February',
      'month3': 'March',
      'month4': 'April',
      'month5': 'May',
      'month6': 'June',
      'month7': 'July',
      'month8': 'August',
      'month9': 'September',
      'month10': 'October',
      'month11': 'November',
      'month12': 'December',
      'timeAm': 'AM',
      'timePm': 'PM',
      // Abbreviated months, used only by the Explore Tours date range where a
      // full month name would wrap the price column off the card. Deliberately
      // **English only**: Kurdish and Arabic have no conventional three-letter
      // month abbreviation, and inventing one is worse than printing the full
      // name, so `_monthLabel` falls back to `monthName` for those two.
      'monthShort1': 'Jan',
      'monthShort2': 'Feb',
      'monthShort3': 'Mar',
      'monthShort4': 'Apr',
      'monthShort5': 'May',
      'monthShort6': 'Jun',
      'monthShort7': 'Jul',
      'monthShort8': 'Aug',
      'monthShort9': 'Sep',
      'monthShort10': 'Oct',
      'monthShort11': 'Nov',
      'monthShort12': 'Dec',
      // --- Explore Tours screen ---
      'toursSearchHint': 'Search for a tour or location',
      'toursDateHint': 'Date of the tour',
      'toursApply': 'Apply',
      'clearDate': 'Clear date',
      'clearSearch': 'Clear search',
      'trendingTours': 'Trending Tours',
      'toursLoadFailed': "Couldn't load tours",
      'toursEmpty': 'No tours match your search',
      'toursHighlightedEmpty': 'No tours are highlighted yet',
      'tourDayTravel': '{count} Day travel',
      'tourDaysTravel': '{count} Days travel',
      'tourPerPerson': 'per person',
      // Title-cased twin of the line above, for the price badge on a tour card:
      // the reference stacks it as "Per / Person" beside the figure, while
      // `tourPerPerson` still reads inside a sentence on the detail screen.
      'tourPerPersonBadge': 'Per Person',
      'tourFeatureCamping': 'Camping',
      'tourFeatureHiking': 'Hiking',
      'tourFeatureGuide': 'Guide',
      'tourFeatureFood': 'Food',
      'tourFeatureSwimming': 'Swimming',
      'tourFeatureCampfire': 'Campfire',
      'tourFeatureTransport': 'Transport',
      'tourFeaturePhotography': 'Photography',
      'tourFeatureActivity': 'Activity',
      'tourFeatureWifi': 'Wifi',
      'tourFeatureElectricity': 'Electricity',
      'tourFeatureTent': 'Tent',
      'tourReviewCount': '{count} reviews',
      'tourReviewCountOne': '1 review',
      'tourNoReviews': 'No reviews yet',
      'tourSpotsLeft': 'Only {count} spots left',
      'tourSpotsLeftOne': 'Only 1 spot left',
      'tourTravellers': 'Travellers',
      'tourTravellerCount': '{count} travellers',
      'tourTravellerCountOne': '1 traveller',
      'tourTotalFor': 'Total {price}',
      'tourCancelFree24h': 'Free cancellation until 24h before',
      'tourCancelFree48h': 'Free cancellation until 48h before',
      'tourCancelFree7d': 'Free cancellation until 7 days before',
      'tourCancelNonRefundable': 'Non-refundable',
      'tourGuideLanguages': 'Guide speaks',
      'tourLanguageEnglish': 'English',
      'tourLanguageKurdish': 'Kurdish',
      'tourLanguageArabic': 'Arabic',
      'tourLanguageTurkish': 'Turkish',
      'tourLanguagePersian': 'Persian',
      'toursSortLabel': 'Sort',
      'toursSortSoonest': 'Soonest',
      'toursSortPriceLow': 'Price: low to high',
      'toursSortPriceHigh': 'Price: high to low',
      'toursSortTopRated': 'Top rated',
      'toursSortNearest': 'Nearest to me',
      'toursRefine': 'Refine',
      'toursIncludes': 'Includes',
      'toursDateRangeHint': 'Dates of the tour',
      'toursPriceApprox':
          'Prices are converted at an indicative rate and shown as approximate. '
          'You are charged in the operator’s own currency.',
      'toursClearAll': 'Clear all',
      'tourDetails': 'Tour Details',
      'tourFacilities': 'Facilities',
      'tourMap': 'Map',
      'tourCheckout': 'Check Out',
      'tourPerson': 'Person',
      'tourTransportationBus': 'Transportation Bus',
      'tourOptional': 'Optional',
      'tourTotalPrice': 'Total Price',
      'tourReserveInsight': 'Reserve Insight',
      'tourTransportUnavailable':
          'Bus transport is not available for this tour',
      'tourWeatherUnavailable': 'Weather is unavailable',
      'tourMapUnavailable': 'Map is unavailable',
      'tourWriteReviewPrompt': 'Joined this tour?',
      'tourNoReviewsYet': 'No reviews yet. Be the first to share your tour.',
      'tourReviewSignInBody':
          'Tour reviews are tied to your account, so travellers can trust who joined.',
      'bookingStepTravelerInfo': 'Traveler Info',
      'bookingStepPayment': 'Payment',
      'bookingStepConfirmation': 'Confirmation',
      'travelerInformation': 'Traveler Information',
      'travelerInformationHint': 'Please enter the details of all travelers',
      'contactPerson': 'Contact Person',
      'travelersLabel': 'Travelers',
      'travelerNumbered': 'Traveler',
      'dateOfBirthHint': 'Date of birth',
      'leadTraveler': 'Lead traveler',
      'leadTravelerHint': 'The booking is issued to this traveler',
      'informationSecure': 'Your information is secure and encrypted',
      'continueToPayment': 'Continue to Payment',
      'selectDialCode': 'Select country code',
      'travelerInfoIncomplete':
          'Please complete every traveler\u2019s name and date of birth.',
      'contactIncomplete':
          'Please enter a valid name, email address and phone number.',
      'travelerTooYoung': 'Every traveler on this tour must be {age} or older.',
      'travelerFutureBirthDate': 'A date of birth cannot be in the future.',
      'noPlacesLeft': 'This departure is sold out.',
      'onlyPlacesLeft': 'Only {count} places left on this departure.',
      'reserveSignInTitle': 'Sign in to reserve',
      'reserveSignInBody':
          'A booking is tied to your account, so you can find it later and we know who to contact.',
      'paymentDetails': 'Payment Details',
      'paymentDetailsHint': 'Complete your payment to confirm the booking',
      'bookingSummary': 'Booking Summary',
      'paymentMethodLabel': 'Payment Method',
      'mastercardVisa': 'Mastercard / Visa',
      'totalLabel': 'Total',
      'selectPaymentMethod': 'Choose how you want to pay',
      'cardEntryNotLive':
          'Card payments are not connected yet. Your card details were not sent or saved.',
      'paymentIncompleteCard':
          'Please enter the card number, expiry date and CVV.',
      'paymentNoMethod': 'Please choose a payment method.',
      'useSavedCard': 'Use this card',
      // --- Checkout step 3 (Review & Confirm) ---
      'reviewConfirmTitle': 'Review & Confirm',
      'reviewConfirmHint':
          'Please review your booking details before confirmation.',
      'travelersInformation': 'Travelers Information',
      'priceBreakdown': 'Price Breakdown',
      'travelerFee': 'Traveler Fee',
      // "2 × $55" — the arithmetic behind a line, shown so nobody has to
      // trust the total blindly. Digits stay Western in all three languages.
      'priceEachTimes': '{count} × {price}',
      'reviewAgreeTerms': 'I agree to the {terms} and {policy}.',
      'reviewTermsLink': 'Terms of Service',
      'reviewPolicyLink': 'Policy of App',
      'reviewMustAgree':
          'Please agree to the Terms of Service and Policy of App to continue.',
      'confirmAndPay': 'Confirm & Pay {price}',
      'confirmPayNotLive':
          'Payments are not connected yet, so nothing was charged and no '
          'booking was created.',
    },
    'ku': <String, String>{
      'chooseYourLanguage': 'زمانەکەت هەڵبژێرە',
      'selectLanguageToContinue': 'زمانێک هەڵبژێرە بۆ بەردەوامبوون',
      'logIn': 'چوونەژوورەوە',
      'email': 'ئیمەیڵ',
      'password': 'وشەی نهێنی',
      'forgetPassword': 'وشەی نهێنیت لەبیرچووە؟',
      'orLabel': 'یان',
      'dontHaveAccount': 'هەژمارت نییە؟ ',
      'registerNow': 'خۆت تۆمار بکە',
      'continueAsGuest': 'وەک میوان بەردەوام بە',
      'emailRequired': 'تکایە ئیمەیڵەکەت بنووسە',
      'emailInvalid': 'ئیمەیڵێکی دروست بنووسە',
      'passwordRequired': 'تکایە وشەی نهێنییەکەت بنووسە',
      'forgetPasswordSubtitle':
          'تکایە زانیارییەکانی پەیوەندیت هەڵبژێرە و ئێمە کۆدێکی '
          'پشتڕاستکردنەوەت بۆ دەنێرین بۆ ڕێکخستنەوەی وشەی نهێنی.',
      'phoneNumber': 'ژمارەی مۆبایل',
      'emailAddress': 'ناونیشانی ئیمەیڵ',
      'sendCode': 'کۆد بنێرە',
      'selectContactMethod': 'سەرەتا مۆبایل یان ئیمەیڵ هەڵبژێرە',
      'verificationCode': 'کۆدی پشتڕاستکردنەوە',
      'verificationSubtitle':
          'ئەو کۆدە ٦ ژمارەییە بنووسە کە ئێستا ناردمان بۆ {dest} بۆ '
          'ڕێکخستنەوەی وشەی نهێنییەکەت.',
      'didntReceiveCode': 'کۆدەکەت پێنەگەیشت؟ ',
      'resendNow': 'دووبارە بینێرە',
      'resendIn': 'دووبارە ناردن لە {seconds} چرکەدا',
      'verify': 'پشتڕاستکردنەوە',
      'codeIncomplete': 'هەر ٦ ژمارەکەی کۆدەکە بنووسە',
      'codeIncorrect': 'ئەم کۆدە دروست نییە. تکایە دووبارە هەوڵ بدەوە.',
      'codeExpired': 'ئەم کۆدە بەسەرچووە. کۆدێکی نوێ بخوازە.',
      'tooManyAttempts':
          'هەوڵی زۆر درا. تکایە پێش هەوڵدانەوە کەمێک چاوەڕێ بکە.',
      'codeResentPhone': 'کۆدێکی نوێ بە نامەی کورت نێردرا',
      'codeResentEmail': 'کۆدێکی نوێ بۆ ئیمەیڵەکەت نێردرا',
      'sendCodeFailed': 'نەمانتوانی کۆدەکە بنێرین. تکایە دووبارە هەوڵ بدەوە.',
      'networkError':
          'پەیوەندی نییە. تکایە ئینتەرنێتەکەت بپشکنە و دووبارە هەوڵ بدەوە.',
      'resetPassword': 'ڕێکخستنەوەی وشەی نهێنی',
      'resetPasswordSubtitle':
          'لانیکەم ٨ پیت، بە پیتی گەورە و پیتی بچووک و هێمایەکی تایبەت.',
      'newPassword': 'وشەی نهێنی نوێ',
      'confirmPassword': 'دووبارەکردنەوەی وشەی نهێنی',
      'updatePassword': 'نوێکردنەوەی وشەی نهێنی',
      'passwordTooShort': 'لانیکەم ٨ پیت بەکاربهێنە',
      'passwordNeedsUppercase': 'لانیکەم یەک پیتی گەورە زیاد بکە',
      'passwordNeedsLowercase': 'لانیکەم یەک پیتی بچووک زیاد بکە',
      'passwordNeedsSpecial': 'لانیکەم یەک هێمای تایبەت زیاد بکە',
      'confirmPasswordRequired': 'تکایە وشەی نهێنییە نوێیەکە دووبارە بنووسە',
      'passwordsDontMatch': 'هەردوو وشەی نهێنییەکە وەک یەک نین',
      'passwordUpdated': 'وشەی نهێنی نوێکرایەوە. تکایە بچۆرە ژوورەوە.',
      'passwordUpdateFailed':
          'نەمانتوانی وشەی نهێنییەکەت نوێ بکەینەوە. تکایە دووبارە هەوڵ بدەوە.',
      'passwordTooWeak': 'تکایە وشەیەکی نهێنی بەهێزتر هەڵبژێرە',
      'sessionExpired':
          'دانیشتنەکەت بەسەرچوو. تکایە لە سەرەتاوە دەست پێ بکەوە.',
      // --- Register screen ---
      'register': 'تۆمارکردن',
      'fullName': 'ناوی تەواو',
      'age': 'تەمەن',
      'gender': 'ڕەگەز',
      'genderMale': 'نێر',
      'genderFemale': 'مێ',
      'genderOther': 'هیتر',
      'genderOptional': 'ڕەگەز (ئارەزوومەندانە)',
      'alreadyHaveAccount': 'پێشتر هەژمارت هەیە؟ ',
      'logInHere': 'لێرە بچۆرە ژوورەوە',
      'passwordHint':
          'لانیکەم ٨ پیت، بە پیتی گەورە و پیتی بچووک و هێمایەکی تایبەت.',
      'acceptTerms': 'ڕازیم بە مەرجەکانی بەکارهێنان و سیاسەتی تایبەتمەندی',
      'termsRequired': 'تکایە ڕەزامەندی بدە بە مەرجەکان و سیاسەتی تایبەتمەندی',
      'fullNameRequired': 'تکایە ناوی تەواوت بنووسە',
      'fullNameTooShort': 'تکایە ناوی تەواوت بنووسە',
      'dateOfBirthRequired': 'تکایە بەرواری لەدایکبوونت هەڵبژێرە',
      'mustBe18': 'دەبێت لانیکەم تەمەنت ١٨ ساڵ بێت بۆ دروستکردنی هەژمار',
      'phoneRequired': 'تکایە ژمارەی مۆبایلەکەت بنووسە',
      'phoneInvalid': 'ژمارەیەکی مۆبایلی دروست بنووسە',
      'selectCountryCode': 'کۆدی وڵات',
      'accountCreated': 'هەژمارەکە دروستکرا. تکایە بچۆرە ژوورەوە.',
      'registerFailed':
          'نەمانتوانی هەژمارەکەت دروست بکەین. تکایە دووبارە هەوڵ بدەوە.',
      'emailInUse': 'هەژمارێک بەم ئیمەیڵە هەیە',
      'phoneInUse': 'هەژمارێک بەم ژمارە مۆبایلە هەیە',
      'verifyNumberSubtitle':
          'ئەو کۆدە ٦ ژمارەییە بنووسە کە ئێستا ناردمان بۆ {dest} بۆ '
          'پشتڕاستکردنەوەی ژمارەکەت.',
      'verifyEmailTitle': 'ئیمەیڵەکەت پشتڕاست بکەرەوە',
      'verifyEmailSubtitle':
          'ئەو کۆدە ٦ ژمارەییە بنووسە کە ئێستا ناردمان بۆ {dest} بۆ '
          'پشتڕاستکردنەوەی ئیمەیڵەکەت.',
      'emailVerified': 'ئیمەیڵەکەت پشتڕاست کرایەوە.',
      // --- Terms of Service screen ---
      'termsOfService': 'مەرجەکانی بەکارهێنان',
      'termsAgreeCheckbox':
          'خوێندمەوە و ڕازیم بە مەرجەکانی بەکارهێنان و سیاسەتی تایبەتمەندی.',
      'continueLabel': 'بەردەوامبوون',
      'lastUpdated': 'دوایین نوێکردنەوە: {date}',
      'termsLoadFailed':
          'نەمانتوانی مەرجەکان باربکەین. تکایە دووبارە هەوڵ بدەوە.',
      'tryAgain': 'دووبارە هەوڵ بدەوە',
      'termsNotReviewed':
          'دەقی سەرەتایی — چاوەڕوانی پێداچوونەوەی یاسایی. بۆ بڵاوکردنەوە نییە.',
      // --- Account Setup screen ---
      'accountSetup': 'ڕێکخستنی هەژمار',
      'accountSetupSubtitle':
          'ڕێکخستنی هەژمارەکەت تەواو بکە بە بارکردنی وێنەی پرۆفایل و '
          'دیارکردنی ناوی بەکارهێنەر.',
      'username': 'ناوی بەکارهێنەر',
      'createAccount': 'دروستکردنی هەژمار',
      'chooseFromGallery': 'لە گەلەری هەڵبژێرە',
      'takePhoto': 'وێنەیەک بگرە',
      'removePhoto': 'وێنەکە لاببە',
      'usernameRequired': 'تکایە ناوی بەکارهێنەر بنووسە',
      'usernameTooShort': 'لانیکەم ٢ پیت بەکاربهێنە',
      'imageTooLarge':
          'ئەم وێنەیە زۆر گەورەیە. یەکێک هەڵبژێرە کە لە ٥ مێگابایت کەمتر بێت.',
      'imagePickFailed':
          'نەمانتوانی ئەم وێنەیە بکەینەوە. تکایە دووبارە هەوڵ بدەوە.',
      'profileSaveFailed':
          'نەمانتوانی پرۆفایلەکەت پاشەکەوت بکەین. تکایە دووبارە هەوڵ بدەوە.',
      'cameraPermissionDenied':
          'دەستڕاگەیشتن بە کامێرا کوژاوەتەوە. لە ڕێکخستنەکان بیکەوە.',
      'galleryPermissionDenied':
          'دەستڕاگەیشتن بە وێنەکان کوژاوەتەوە. لە ڕێکخستنەکان بیکەوە.',
      // --- Register Complete screen ---
      'registerComplete': 'تۆمارکردن تەواو بوو!',
      'registerCompleteSubtitle':
          'بە سەرکەوتوویی هەژمارەکەت دروستکرا. بەخێربێیت!',
      'explore': 'گەڕان',
      // --- Onboarding (3-slide intro) ---
      'onboardingTitleLine1': 'کوردستان',
      'onboardingTitleLine2': 'بدۆزەرەوە',
      'onboardingBody1':
          'بگەڕێ بەناو دۆڵە جوانەکان و ڕووبارەکان و ڕێڕەوە شاخاوییەکاندا کە '
          'کەم گەشتیار پێیان دەگات.\nهەمووی لە یەک ئەپدا.',
      'onboardingTitle2Line1': 'بفڕە بۆ',
      'onboardingTitle2Line2': 'کوردستان',
      'onboardingBody2':
          'بەراوردی فڕینەکان بکە، بەرواری خۆت هەڵبژێرە و لە چەند خولەکێکدا '
          'بلیتەکەت تۆمار بکە.',
      'onboardingTitle3Line1': 'ئۆتۆمبێلەکەت',
      'onboardingTitle3Line2': 'ئامادەیە !',
      'onboardingBody3':
          'ئۆتۆمبێلێک بەکرێ بگرە و بەپێی پلانی خۆت بگە بە هەموو گۆشەیەکی '
          'کوردستان.',
      'onboardingNext': 'دواتر',
      // --- Home screen ---
      'goodMorning': 'بەیانیت باش',
      'goodAfternoon': 'نیوەڕۆت باش',
      'goodEvening': 'ئێوارەت باش',
      'dearUser': 'بەکارهێنەری خۆشەویست',
      'whereWouldYouLikeToGo': 'دەتەوێت بۆ کوێ بچیت؟',
      'planYourJourney': 'پلان بۆ گەشتەکەت دابنێ',
      'exploreNature': 'گەڕان بە سروشتدا',
      'exploreNatureHint': 'ڕێڕەوەکان، دەریاچەکان و پارکە سەرنجڕاکێشەکان.',
      'whereToStay': 'شوێنی مانەوە',
      'whereToStayHint': 'هوتێل، کوخ و شوێنی مانەوەی تایبەت',
      'hotelLocation': 'ناونیشان',
      'hotelLocationHint': 'دەتەوێت لە کوێ بمێنیتەوە؟',
      'hotelRecentSearches': 'گەڕانەکانی پێشوو',
      'hotelDate': 'بەروار',
      'hotelCheckIn': 'چوونە ژوورەوە',
      'hotelCheckOut': 'چوونە دەرەوە',
      'hotelGuests': 'مێوانەکان',
      'hotelAdult': 'پێگەیشتوو',
      'hotelChild': 'ساوا',
      'hotelRoom': 'ژوور',
      'hotelBed': 'جێگا',
      'hotelOptions': 'هەڵبژاردەکان',
      'hotelNoOptions': 'هیچ هەڵبژاردەیەک دیاری نەکراوە',
      'hotelOneOption': '١ هەڵبژاردە دیاری کراوە',
      'hotelManyOptions': '{count} هەڵبژاردە دیاری کراوە',
      'hotelPool': 'مەلەوانگە',
      'hotelBar': 'بار',
      'hotelRestaurant': 'چێشتخانە',
      'hotelGym': 'هۆڵی وەرزش',
      'hotelParking': 'گەراج',
      'hotelFreeWifi': 'وایفای بەخۆڕایی',
      'hotelBeach': 'کەناراو',
      'hotelMoreOptions': 'هەڵبژاردەی زیاتر',
      'hotelSearch': 'گەڕان',
      'hotelTrending': 'شوێنە بەناوبانگەکانی مانەوە',
      'hotelPerNight': 'بۆ هەر شەوێک',
      'hotelDistanceFromCenter': '{distance} کم لە ناوەندی شارەوە',
      'hotelAdultsBeds': '{adults} پێگەیشتوو، {beds} جێگا',
      'hotelGuestSummary':
          '{adults} پێگەیشتوو، {children} ساوا، {rooms} ژوور، {beds} جێگا',
      'hotelAdultCountOne': '{count} پێگەیشتوو',
      'hotelAdultCountMany': '{count} پێگەیشتوو',
      'hotelChildCountOne': '{count} ساوا',
      'hotelChildCountMany': '{count} ساوا',
      'hotelRoomCountOne': '{count} ژوور',
      'hotelRoomCountMany': '{count} ژوور',
      'hotelBedCountOne': '{count} جێگا',
      'hotelBedCountMany': '{count} جێگا',
      'hotelDestinationRequired': 'تکایە شوێنێک هەڵبژێرە',
      'hotelInvalidDates': 'چوونە دەرەوە دەبێت دوای چوونە ژوورەوە بێت',
      'hotelPreviewData': 'شوێنی تاقیکردنەوە – بەردەستی ڕاستەوخۆ پەیوەست نییە',
      'hotelCarouselPosition': 'هوتێلی دیاریکراوی {current} لە {total}',
      'hotelStarClassification': 'هوتێلی {count} ئەستێرە',
      'hotelReviewScore': 'نمرەی هەڵسەنگاندن {score} لە ١٠',
      'hotelIncrease': 'زیادکردنی {name}',
      'hotelDecrease': 'کەمکردنی {name}',
      // --- Hotel Details page ---
      'hotelDetails': 'زانیاری هوتێل',
      'hotelDetailNotFound': 'ئەم هوتێلە چیتر بەردەست نییە.',
      'hotelDetailLoadFailed': 'نەمانتوانی ئەم هوتێلە باربکەین.',
      'hotelGalleryPosition': '{current} / {total}',
      'hotelGalleryImage': 'وێنەی هوتێل {current} لە {total}',
      'hotelChange': 'گۆڕین',
      'hotelUpdateStay': 'نوێکردنەوەی مانەوەکەت',
      'hotelUpdateStayApply': 'جێبەجێکردنی گۆڕانکاری',
      'hotelStayUpdated': 'مانەوەکەت نوێ کرایەوە',
      'hotelFacilities': 'ئاسانکاریەکان',
      'hotelAllFacilities': 'هەموو ئاسانکاریەکان',
      'hotelNoFacilities': 'هێشتا هیچ ئاسانکارییەک تۆمار نەکراوە',
      'hotelSeeAll': 'بینینی هەموو',
      'hotelReviews': 'بۆچوونەکان',
      'hotelReviewCountOne': '{count} بۆچوون',
      'hotelReviewCountMany': '{count} بۆچوون',
      'hotelCleanliness': 'پاکوخاوێنی',
      'hotelComfort': 'ئاسوودەیی',
      'hotelService': 'خزمەتگوزاری',
      'hotelStaff': 'ستاف',
      'hotelValue': 'نرخ بەرامبەر بەها',
      'hotelMap': 'ناونیشان',
      'hotelMapUnavailable': 'نەخشە بەردەست نییە',
      'hotelNearby': 'نزیک لێرەوە',
      'hotelNearbyEmpty': 'هێشتا هیچ شوێنێکی نزیک تۆمار نەکراوە',
      'hotelNearbyAll': 'شوێنە نزیکەکان',
      'hotelNearbyDistance': '{distance} کم',
      'hotelNearbyDistanceWithTime': '{minutes} خولەک ({distance} کم)',
      'hotelRatingsAndComments': 'هەڵسەنگاندن و لێدوانەکان',
      'hotelSelectRoom': 'هەڵبژاردنی ژوور',
      'hotelChooseRoom': 'ژوورەکەت هەڵبژێرە',
      'hotelMockNotice': 'داتای پێشبینین — بەردەستبوون و پارەدان ڕاستەوخۆ نین.',
      'hotelNoRooms': 'هیچ ژوورێک بۆ ئەم بەروارانە بەردەست نییە.',
      'hotelChangeDates': 'گۆڕینی بەروارەکان',
      'hotelBackToHotel': 'گەڕانەوە بۆ هوتێل',
      'hotelSeeRoomDetails': 'وردەکاری ژوور ببینە',
      'hotelMaximumGuests': 'زۆرترین {count} میوان',
      'hotelReserve': 'حجزکردن',
      'hotelPriceForNights': 'نرخ بۆ {count} شەو',
      'hotelRechecking': 'پشکنینەوەی نرخ و بەردەستبوون…',
      'hotelCompleteBooking': 'حجزەکەت تەواو بکە',
      'hotelGuestDetails': 'وردەکاری میوان',
      'hotelSpecialRequestsHint':
          'داواکارییە ئارەزوومەندانەکان بە بەردەستبوونی هوتێل بەستراونەتەوە',
      'hotelStripePreview': 'Stripe — تەنها پێشبینین',
      'hotelFibPreview': 'FIB — تەنها پێشبینین',
      'hotelMockPaymentNotice':
          'هیچ پارەدانێک نانێردرێت. ئەم پشکنینە تەنها حجزێکی پێشبینینی ناوخۆیی دروست دەکات.',
      'hotelRoomSubtotal': 'کۆی ژوور',
      'hotelBookingConsent':
          'ڕازیم بە نرخ و مەرجەکانی هەڵوەشاندنەوەی پیشاندراو.',
      'hotelConfirmMockBooking': 'پشتڕاستکردنەوەی حجزی پێشبینین',
      'hotelMockBookingComplete': 'حجزی پێشبینین تەواو بوو',
      'hotelMockBookingCompleteBody':
          'هیچ ژوورێک لە هوتێل نەگیرا و هیچ پارەیەک وەرنەگیرا.',
      'hotelViewReservations': 'حجزەکانت ببینە',
      'hotelGuestRequired': 'تکایە وردەکارییە پێویستەکانی میوان تەواو بکە.',
      'hotelConsentRequired': 'تکایە مەرجەکانی حجز قبوڵ بکە.',
      'hotelRateUnavailable':
          'ئەم نرخە چیتر بەردەست نییە. هەڵبژاردەیەکی تر هەڵبژێرە.',
      'hotelPropertyPolicies': 'ڕێساکانی هوتێل',
      'hotelPolicyCheckInFrom': 'چوونە ژوورەوە لە',
      'hotelPolicyCheckOutUntil': 'چوونە دەرەوە تا',
      'hotelPolicyChildren': 'ساوا',
      'hotelPolicyCribs': 'لانکە',
      'hotelPolicyExtraBeds': 'جێگای زیادە',
      'hotelPolicyAgeRestriction': 'سنووری تەمەن',
      'hotelPolicyMinimumAge': 'کەمترین تەمەن بۆ چوونەژوورەوە {age} ساڵە',
      'hotelPolicyPets': 'ئاژەڵی ماڵی',
      'hotelPolicySmoking': 'جگەرەکێشان',
      'hotelPolicyPayment': 'شێوازە پەسەندکراوەکانی پارەدان',
      'hotelPolicySpecialRequests': 'داواکاری تایبەت',
      'hotelPolicySpecialRequestsYes':
          'دەتوانرێت داواکاری تایبەت بۆ حجزەکەت زیاد بکرێت.',
      'hotelPolicySpecialRequestsNo': 'داواکاری تایبەت وەرناگیرێت.',
      'hotelPolicyAccessibility': 'دەستڕاگەیشتن',
      'hotelFacilityGeneral': 'گشتی',
      'hotelFacilityInternet': 'ئینتەرنێت',
      'hotelFacilityParking': 'گەراج',
      'hotelFacilityFoodAndDrink': 'خواردن و خواردنەوە',
      'hotelFacilityWellness': 'تەندروستی',
      'hotelFacilityPool': 'مەلەوانگە',
      'hotelFacilityTransportation': 'گواستنەوە',
      'hotelFacilityRoom': 'ئاسانکاری ژوور',
      'hotelFacilityFamily': 'خێزانی',
      'hotelFacilityAccessibility': 'دەستڕاگەیشتن',
      'hotelFacilityBusiness': 'بازرگانی',
      'hotelFacilitySafety': 'سەلامەتی',
      'hotelBedSingle': 'جێگای تاک',
      'hotelBedTwin': 'دوو جێگای تاک',
      'hotelBedDouble': 'جێگای دووکەسی',
      'hotelBedQueen': 'جێگای کوین',
      'hotelBedKing': 'جێگای کینگ',
      'hotelBedSofa': 'قەنەفەی جێگا',
      'hotelBedBunk': 'جێگای چینچین',
      'hotelBedCount': '{count} × {bed}',
      'hotelBreakfastIncluded': 'نانی بەیانی لەگەڵدایە',
      'hotelBreakfastExtra': 'نانی بەیانی بە تێچووی زیادە بەردەستە',
      'hotelBreakfastUnavailable': 'نانی بەیانی بەردەست نییە',
      'hotelTaxesAndFees': 'باج و کرێکان',
      'hotelTaxesIncluded': 'باج و کرێکان لەگەڵدان',
      'hotelTaxesExcluded': 'باج و کرێکان لەگەڵدا نین',
      'hotelFreeCancellation': 'هەڵوەشاندنەوەی بەخۆڕایی',
      'hotelPartiallyRefundable': 'بەشێکی دەگەڕێتەوە',
      'hotelNonRefundable': 'ناگەڕێتەوە',
      'hotelPayNow': 'ئێستا پارە بدە',
      'hotelPayLater': 'دواتر پارە بدە',
      'hotelPayAtProperty': 'لە هوتێل پارە بدە',
      'hotelPrepaymentRequired': 'پارەدانی پێشەکی پێویستە',
      'hotelPartialPrepayment': 'بەشێکی پارەی پێشەکی پێویستە',
      'hotelNoPrepayment': 'پارەدانی پێشەکی پێویست نییە',
      'hotelRoomsLeftOne': 'تەنها {count} ژوور ماوە',
      'hotelRoomsLeftMany': 'تەنها {count} ژوور ماوە',
      'bestPrice': 'باشترین نرخ',
      'carRental': 'بەکرێ وەرگرتنی ئۆتۆمبێل',
      'carRentalHint': 'ئۆتۆمبێلی گونجاو بۆ سەرکێشییەکەت بدۆزەرەوە',
      'findACar': 'ئۆتۆمبێل بدۆزەرەوە',
      'carPickupDropOffLocation': 'شوێنی وەرگرتن – گەڕاندنەوە',
      'carPickup': 'وەرگرتن',
      'carDropOff': 'گەڕاندنەوە',
      'carPickupLocation': 'شوێنی وەرگرتن',
      'carDropOffLocation': 'شوێنی گەڕاندنەوە',
      'carDifferentDropOff': 'گەڕاندنەوە لە شوێنێکی جیاواز',
      'carSelectDate': 'بەروار هەڵبژێرە',
      'carSelectTime': 'کات هەڵبژێرە',
      'carSearch': 'گەڕان',
      'carSearching': 'گەڕان…',
      'carTrending': 'ئۆتۆمبێلە بەناوبانگەکان',
      'carAvailable': 'ئۆتۆمبێلە بەردەستەکان',
      'carNoAvailable': 'هیچ ئۆتۆمبێلێک بۆ ئەم بەروارانە بەردەست نییە',
      'carSearchLocations': 'گەڕان بەدوای شوێنی بەکرێگرتندا',
      'carLocationSearchHint': 'شار، فڕۆکەخانە، کۆد یان لق',
      'carLocationStartTyping': 'لانیکەم ٢ پیت بنووسە',
      'carNoLocations': 'هیچ شوێنێکی بەکرێگرتن نەدۆزرایەوە',
      'carLocationsFailed': 'نەتوانرا شوێنەکان باربکرێن',
      'carPickupLocationRequired': 'تکایە شوێنی وەرگرتن هەڵبژێرە',
      'carDropOffLocationRequired': 'تکایە شوێنی گەڕاندنەوە هەڵبژێرە',
      'carPickupDateRequired': 'تکایە بەرواری وەرگرتن هەڵبژێرە',
      'carPickupTimeRequired': 'تکایە کاتی وەرگرتن هەڵبژێرە',
      'carDropOffDateRequired': 'تکایە بەرواری گەڕاندنەوە هەڵبژێرە',
      'carDropOffTimeRequired': 'تکایە کاتی گەڕاندنەوە هەڵبژێرە',
      'carPickupFuture': 'کاتی وەرگرتن دەبێت لە داهاتوودا بێت',
      'carDropOffAfterPickup': 'گەڕاندنەوە دەبێت دوای وەرگرتن بێت',
      'carSearchFailed': 'نەتوانرا ئۆتۆمبێلە بەردەستەکان باربکرێن',
      'carPersons': '{count} کەس',
      'carBags': '{count} جانتا',
      'carAirConditioning': 'ساردکەرەوە',
      'carHybrid': 'هایبرید',
      'carElectric': 'کارەبایی',
      'carPetrol': 'بەنزین',
      'carDiesel': 'دیزل',
      'carPayAtPickup': 'پارەدان لە کاتی وەرگرتن',
      'carPayNow': 'ئێستا پارە بدە',
      'carModelYear': 'مۆدێلی {year}',
      'carPricePerDay': '{price}/ڕۆژ',
      'carPreviewData': 'ئۆتۆمبێلی پیشاندان – بەردەستی ڕاستەقینە پەیوەست نییە',
      'carCarouselPosition': 'ئۆتۆمبێلی هەڵبژێردراوی {current} لە {total}',
      'carResultsOne': '١ ئەنجام',
      'carResultsMany': '{count} ئەنجام',
      'carResultsEmptyTitle': 'هیچ ئۆتۆمبێلێک نەدۆزرایەوە',
      'carResultsEmptyBody':
          'بۆ بەروار و شوێنی هەڵبژێردراوت هیچ ئۆتۆمبێلێک نەدۆزرایەوە.',
      'carModifySearch': 'گۆڕینی گەڕان',
      'carResultsLoading': 'باربوونی ئۆتۆمبێلە بەردەستەکان',
      'carResultsListLabel': 'ئەنجامەکانی گەڕانی بەکرێدانی ئۆتۆمبێل',
      'carDetails': 'زانیاری ئۆتۆمبێل',
      'carPickupDropOffDetails': 'زانیاری وەرگرتن / گەڕاندنەوە',
      'carLocation': 'ناونیشان',
      'carAdditionalOptions': 'هەڵبژاردنی زیادە',
      'carApply': 'جێبەجێکردن',
      'carAutomatic': 'ئۆتۆماتیک',
      'carManual': 'دەستی',
      'carPhotoPosition': 'وێنەی {current} لە {total}',
      'carGalleryLabel': 'وێنەکانی {name}',
      'carDecreaseQuantity': 'کەمکردنی {name}',
      'carIncreaseQuantity': 'زیادکردنی {name}',
      'carExtraTimesQuantity': '{price} × {count}',
      'carPriceSummary': 'کورتەی نرخ',
      'carBaseRental': 'کرێی بنەڕەتی',
      'carExtrasTotal': 'زیادەکان',
      'carEstimatedTotal': 'کۆی خەمڵێنراو',
      'carRentalDayOne': '١ ڕۆژی کرێ',
      'carRentalDaysMany': 'کرێی {count} ڕۆژان',
      'carEstimateNote': 'تەنها خەمڵاندنە — باج و کرێی دابینکەر لەخۆ ناگرێت.',
      'carRentalConditions': 'مەرجەکانی کرێ',
      'carFuelPolicy': 'سیاسەتی سووتەمەنی',
      'carFuelFullToFull': 'پڕ بۆ پڕ',
      'carFuelFullToEmpty': 'پڕ بۆ بەتاڵ',
      'carFuelSameToSame': 'وەک خۆی بۆ وەک خۆی',
      'carMileage': 'مەودای ڕۆیشتن',
      'carMileageUnlimited': 'بێ سنوور',
      'carMileagePerDay': '{count} کم لە ڕۆژێکدا',
      'carMileageExtra': '{price} بۆ هەر کیلۆمەترێکی زیادە',
      'carDeposit': 'بارمتەی دڵنیایی',
      'carDamageExcess': 'بەشی زیانی لەسەر خۆت',
      'carFreeCancellation': 'هەڵوەشاندنەوەی بێبەرامبەر تا',
      'carMinimumAge': 'کەمترین تەمەنی شۆفێر',
      'carMinimumAgeValue': '{age} ساڵ',
      'carRequiredDocuments': 'بەڵگەنامە پێویستەکان',
      'carOrSimilar': 'ئەم مۆدێلە یان ئۆتۆمبێلێکی هاوشێوە',
      'flightTicketing': 'بلیتی فڕۆکە',
      'flightTicketingHint':
          'فڕینی هەرزان، تۆمارکردنی ئاسان، پارەدانی پارێزراو',
      'findFlight': 'فڕین بدۆزەرەوە',
      'flightOneWay': 'یەک ئاراستە',
      'flightRoundTrip': 'چوون و گەڕانەوە',
      'flightFrom': 'لە کوێوە',
      'flightTo': 'بۆ کوێ',
      'flightSearchAirport': 'گەڕان بەدوای فڕۆکەخانەدا',
      'flightAirportSearchHint': 'شار، فڕۆکەخانە، کۆدی IATA یان وڵات',
      'flightAirportStartTyping': 'لانیکەم ٢ پیت بنووسە',
      'flightNoAirportsFound': 'هیچ فڕۆکەخانەیەک نەدۆزرایەوە',
      'flightAirportLoadFailed': 'نەتوانرا فڕۆکەخانەکان باربکرێن',
      'flightDepartureDate': 'بەرواری ڕۆیشتن',
      'flightReturnDate': 'بەرواری گەڕانەوە',
      'flightPassengers': 'گەشتیاران',
      'flightAdults': 'پێگەیشتوو (١٢+)',
      'flightChildren': 'ساوا (٢–١١)',
      'flightInfants': 'ساواکان (خوار ٢ ساڵ)',
      'flightCabinClass': 'پۆلی کابین',
      'flightCabinEconomy': 'ئابووری',
      'flightCabinPremiumEconomy': 'ئابووری تایبەت',
      'flightCabinBusiness': 'بازرگانی',
      'flightCabinFirst': 'پۆلی یەکەم',
      'flightDirectOnly': 'تەنها فڕینی ڕاستەوخۆ',
      'flightSearch': 'گەڕان بەدوای فڕیندا',
      'flightSearching': 'گەڕان…',
      'done': 'تەواو',
      'flightOriginRequired': 'تکایە شوێنی دەستپێکی فڕین بنووسە',
      'flightDestinationRequired': 'تکایە شوێنی مەبەستی فڕین بنووسە',
      'flightDifferentAirports': 'شوێنی دەستپێک و مەبەست دەبێت جیاواز بن',
      'flightDepartureRequired': 'تکایە بەرواری ڕۆیشتن هەڵبژێرە',
      'flightReturnRequired': 'تکایە بەرواری گەڕانەوە هەڵبژێرە',
      'flightSearchReady': 'گەڕانەکەت ئامادەیە بۆ پەڕەی ئەنجامەکان',
      'flightPassengerSummary':
          '{adults} پێگەیشتوو · {children} ساوا · {infants} ساوا',
      'flightResultsOne': '١ فڕین دۆزرایەوە',
      'flightResultsMany': '{count} فڕین دۆزرایەوە',
      'flightSortBest': 'باشترین',
      'flightSortCheapest': 'هەرزانترین',
      'flightSortFastest': 'خێراترین',
      'flightSelect': 'هەڵبژاردن',
      'flightDirect': 'ڕاستەوخۆ',
      'flightOneStop': '١ وەستان',
      'flightManyStops': '{count} وەستان',
      'flightOutbound': 'ڕۆیشتن',
      'flightReturn': 'گەڕانەوە',
      'flightTotalPrice': 'نرخی گشتی',
      'flightPerTraveler': 'بۆ هەر گەشتیارێک',
      'flightResultsLoadFailed': 'نەتوانرا فڕینەکان باربکرێن',
      'flightResultsEmptyTitle': 'هیچ فڕینێک نەدۆزرایەوە',
      'flightResultsEmptyBody': 'بەروارێکی تر یان فلتەرەکان بگۆڕە.',
      'flightRetry': 'دووبارە هەوڵبدەوە',
      'flightPreviousDate': 'بەرواری پێشوو',
      'flightNextDate': 'بەرواری دواتر',
      'flightOfferSelected': 'فڕینەکە بۆ هەنگاوی داهاتووی حیجز هەڵبژێردرا',
      'exploreToursTitle': 'گەڕان بە گەشتەکاندا',
      'exploreToursHint': 'ئەزموونی ناوخۆیی، شوێنە شاراوەکان و ڕێبەری شارەزا',
      'findTours': 'گەشت بدۆزەرەوە',
      'placesCount': '{count}+ شوێن',
      'navHome': 'سەرەکی',
      'navTrips': 'گەشتەکان',
      'navMap': 'نەخشە',
      'navSaved': 'دڵخوازەکانم',
      'featuredLoadFailed': 'نەتوانرا شوێنە هەڵبژێردراوەکان باربکرێن',
      'featuredEmpty': 'هێشتا هیچ شوێنێکی هەڵبژێردراو نییە',
      'signInToSave': 'بچۆ ژوورەوە بۆ پاشەکەوتکردن',
      'signInToSaveBody':
          'هەژمارێک دروست بکە یان بچۆ ژوورەوە بۆ هێشتنەوەی شوێنە '
          'دڵخوازەکانت.',
      'notNow': 'ئێستا نا',
      'addedToFavorites': 'زیادکرا بۆ دڵخوازەکانت',
      'removedFromFavorites': 'لابرا لە دڵخوازەکانت',
      'favoriteFailed': 'نەتوانرا دڵخوازەکانت نوێ بکرێنەوە',
      'comingSoon': 'بەم زووانە',
      'mapOpenFailed': 'نەتوانرا ئەپی نەخشە بکرێتەوە',
      'menu': 'لیستە',
      'changeLanguage': 'گۆڕینی زمان',
      // --- Home screen side drawer ---
      'close': 'داخستن',
      'services': 'خزمەتگوزارییەکان',
      'myBookings': 'داواکاریەکانم',
      'billingPayments': 'پارەدان',
      'billingPaymentTitle': 'پسوڵە و پارەدانەکان',
      'currentPaymentMethod': 'شێوازی پارەدانی ئێستا',
      'addPaymentMethod': 'شێوازێکی پارەدان زیاد بکە',
      'addPaymentMethodDescription':
          'کارتی دێبیت یان کرێدیتەکەت هەڵبگرە بۆ پارەدانی هوتێل، فڕین، بەکرێگرتنی ئۆتۆمبێل و گەشتەکان.',
      'paymentInformationEncrypted':
          'زانیارییەکانی پارەدانت بە شێوەیەکی پارێزراو نهێنیکراون.',
      'addCard': 'کارت زیاد بکە',
      'debitOrCreditCard': 'کارتی دێبیت یان کرێدیت',
      'secureCheckout': 'پارەدانی پارێزراو',
      'secureCardSetupUnavailable':
          'ڕێکخستنی پارێزراوی کارت بەم زووانە بەردەست دەبێت.',
      'paymentMethodAlreadyAdded':
          'پێشتر شێوازێکی پارەدانت بە هەژمارەکەتەوە بەستووە.',
      'newCard': 'کارتی نوێ',
      'newCardDescription':
          'کارتێک زیاد بکە بۆ پارەدانی خێراتر لە حجزەکانی داهاتوو.',
      'cardDetails': 'وردەکارییەکانی کارت',
      'cardholderName': 'ناوی خاوەنی کارت',
      'cardNumber': 'ژمارەی کارت',
      'expiryDate': 'بەرواری بەسەرچوون',
      'expiryHint': 'MM/YY',
      'cvv': 'CVV',
      'country': 'وڵات',
      'yourCountry': 'وڵاتەکەت',
      'zipCode': 'کۆدی پۆستە',
      'optional': 'ئارەزوومەندانە',
      'saveCardForFutureBookings': 'ئەم کارتە بۆ حجزەکانی داهاتوو هەڵبگرە',
      'editPaymentMethodLater':
          'دەتوانیت دواتر لە پارەدان ئەم شێوازی پارەدانە دەستکاری یان بسڕیتەوە.',
      'requiredField': 'ئەم خانەیە پێویستە.',
      'invalidCardNumber': 'ژمارەی کارتێکی دروست بنووسە.',
      'invalidExpiryDate': 'بەروارێکی دروستی داهاتوو بنووسە.',
      'invalidCvv': 'CVV ـێکی دروست بنووسە.',
      'editProfile': 'دەستکاریکردنی پرۆفایل',
      'editProfileSubtitle': 'وێنە و ناوی تەواوت نوێ بکەرەوە.',
      'firstAndLastName': 'ناوی یەکەم و کۆتایی',
      'firstName': 'ناوی یەکەم',
      'lastName': 'ناوی کۆتایی',
      'firstAndLastNameRequired': 'ناوی یەکەم و کۆتایی بنووسە.',
      'saveChanges': 'پاشەکەوتکردنی گۆڕانکارییەکان',
      'profileUpdated': 'پرۆفایلەکەت نوێ کرایەوە.',
      'settingsUpdateFailed': 'نوێکردنەوە سەرکەوتوو نەبوو. دووبارە هەوڵ بدە.',
      'changeEmail': 'گۆڕینی ئیمەیڵ',
      'changeEmailSubtitle':
          'وشەی نهێنی پشتڕاست بکەرەوە، پاشان ئیمەیڵی نوێ بسەلمێنە.',
      'confirmEmailIdentitySubtitle':
          'ئیمەیڵ و وشەی نهێنی هەژمارەکەت بنووسە بۆ پشتڕاستکردنەوەی ناسنامەت.',
      'currentEmail': 'ئیمەیڵی ئێستا',
      'newEmail': 'ئیمەیڵی نوێ',
      'newEmailVerificationSubtitle':
          'ئیمەیڵە نوێیەکە و کۆدی ٦ ژمارەیی بنووسە کە بۆی دەنێرین.',
      'emailUpdated': 'ئیمەیڵەکەت نوێکرایەوە.',
      'currentPassword': 'وشەی نهێنی ئێستا',
      'enterValidEmail': 'ئیمەیڵێکی دروست بنووسە.',
      'sendVerificationLink': 'ناردنی بەستەری پشتڕاستکردنەوە',
      'emailVerificationSent': 'بەستەری پشتڕاستکردنەوە نێردرا.',
      'reauthenticationFailed': 'وشەی نهێنی ئێستا پشتڕاست نەکرایەوە.',
      'changePhoneNumber': 'گۆڕینی ژمارەی مۆبایل',
      'changePhoneSubtitle': 'کۆدی SMS بۆ پشتڕاستکردنەوە دەنێرین.',
      'newPhoneNumber': 'ژمارەی مۆبایلی نوێ',
      'phoneInternationalFormat': 'فۆرماتی نێودەوڵەتی بەکاربهێنە، وەک +964…',
      'verificationCodeSent': 'کۆدی پشتڕاستکردنەوە نێردرا.',
      // 'verificationCode' and 'sendCode' already exist earlier in this map.
      'verifyAndSave': 'پشتڕاستکردنەوە و پاشەکەوتکردن',
      'invalidVerificationCode': 'کۆدی پشتڕاستکردنەوە هەڵەیە.',
      'passwordChangeRules':
          'لانیکەم ٨ پیت، پیتێکی گەورە و هێمایەک بەکاربهێنە.',
      'kilometers': 'کیلۆمەتر (km)',
      'miles': 'مایل (mi)',
      'milesShort': 'mi',
      'defaultPayment': 'بنەڕەتی',
      'debitCard': 'کارتی دێبیت',
      'creditCard': 'کارتی کرێدیت',
      'kurdistanInternationalBank': 'بانکی نێودەوڵەتی کوردستان',
      'firstIraqiBank': 'بانکی یەکەمی عێراق',
      'newlyAddedCard': 'کارتی تازە زیادکراو',
      'savedCard': 'کارتی پاشەکەوتکراو',
      'add': 'زیادکردن',
      'change': 'گۆڕین',
      'delete': 'سڕینەوە',
      'cancel': 'پاشگەزبوونەوە',
      'setDefaultCard': 'دیاریکردنی کارتی بنەڕەتی',
      'setDefaultCardBody': 'ئەم کارتە بۆ حیجزە نوێیەکان بەکاردەهێنرێت.',
      'defaultCardUpdated': 'کارتی بنەڕەتی نوێکرایەوە',
      'deleteCardTitle': 'ئەم کارتە بسڕدرێتەوە؟',
      'deleteCardBody':
          'کارتەکە کە بە {last4} کۆتایی دێت لە شێوازە پاشەکەوتکراوەکانی پارەدانت '
          'لادەبرێت. لە هەر کاتێکدا دەتوانیت دووبارە زیادی بکەیتەوە.',
      'cardDeleted': 'کارتەکە لابرا',
      'cardAdded': 'کارتەکە زیادکرا',
      'billingSignInTitle': 'بچۆ ژوورەوە بۆ بەڕێوەبردنی پارەدان',
      'billingSignInBody':
          'کارتە پاشەکەوتکراوەکانت بە هەژمارەکەتەوە بەستراون، بۆیە پێویستە بچیتە '
          'ژوورەوە بۆ پیشاندانیان.',
      'photoSignInTitle': 'بچۆ ژوورەوە بۆ زیادکردنی وێنە',
      'photoSignInBody':
          'وێنەی پرۆفایلەکەت لە هەژمارەکەتدا پاشەکەوت دەکرێت، بۆیە پێویستە بچیتە '
          'ژوورەوە بۆ گۆڕینی.',
      'paymentHistory': 'مێژووی پارەدان',
      'paid': 'پارەدراو',
      'pending': 'چاوەڕوان',
      'viewReceipt': 'بینینی پسوڵە',
      'hotel': 'هوتێل',
      'flight': 'فڕین',
      'car': 'ئۆتۆمبێل',
      'tour': 'گەشت',
      'mountainViewResort': 'پشوودانی دیمەنی چیا',
      'erbilToIstanbul': 'هەولێر ← ئیستانبوڵ',
      'suvRental': 'بەکرێگرتنی SUV',
      'rawanduzCanyonAdventure': 'سەرکێشی دۆڵی ڕەواندز',
      'paymentDateMay24': '٢٤ی ئایاری ٢٠٢٥',
      'paymentDateMay23': '٢٣ی ئایاری ٢٠٢٥',
      'paymentDateMay25': '٢٥ی ئایاری ٢٠٢٥',
      'paymentDateMay26': '٢٦ی ئایاری ٢٠٢٥',
      'settings': 'ڕێکخستنەکان',
      'settingsAccount': 'هەژمار',
      'settingsChangePassword': 'گۆڕینی وشەی نهێنی',
      'settingsPreferences': 'هەڵبژاردەکان',
      'settingsNotifications': 'ئاگادارکردنەوەکان',
      'settingsTheme': 'ڕووکار',
      'settingsLanguage': 'زمان',
      'settingsUnits': 'یەکەکان',
      'settingsSecurityLegal': 'ئاسایش و یاسایی',
      'settingsSecurityPrivacy': 'ئاسایش و تایبەتمەندی',
      'settingsDeleteAccount': 'سڕینەوەی هەژمار',
      'notificationsPermissionDenied': 'مۆڵەتی ئاگادارکردنەوە نەدرا.',
      'notificationsUpdateFailed':
          'نەمانتوانی ئاگادارکردنەوەکان نوێ بکەینەوە. دووبارە هەوڵ بدەوە.',
      'languageEnglish': 'ئینگلیزی',
      'languageKurdish': 'کوردی',
      'languageArabic': 'عەرەبی',
      'kilometersShort': 'کم',
      'currency': 'دراو',
      'policy': 'سیاسەت',
      'helpSupport': 'یارمەتی',
      'aboutUs': 'دەربارەمان',
      'contactWay': 'ڕێگای پەیوەندی',
      'logOut': 'دەرچوون',
      'guestUser': 'میوان',
      'guestDrawerPrompt': 'بۆ بینینی پرۆفایلەکەت بچۆرە ژوورەوە',
      'signInRequired': 'تکایە سەرەتا بچۆرە ژوورەوە',
      'selectCurrency': 'دراو هەڵبژێرە',
      'currencyUSD': 'دۆلاری ئەمریکی (USD)',
      'currencyIQD': 'دیناری عێراقی (IQD)',
      'currencyEUR': 'یۆرۆ (EUR)',
      'currencyUpdated': 'دراوەکە نوێکرایەوە',
      'currencyUpdateFailed':
          'نەمانتوانی دراوەکەت نوێ بکەینەوە. تکایە دووبارە هەوڵ بدەوە.',
      'logOutFailed': 'نەمانتوانی دەرتبکەین. تکایە دووبارە هەوڵ بدەوە.',
      'profilePhotoUpdated': 'وێنەی پرۆفایل نوێکرایەوە',
      // --- Explore Nature screen ---
      'filterHiking': 'ڕێپێوان',
      'filterBeach': 'کەنارئاو',
      'filterSunsetView': 'دیمەنی خۆرئاوابوون',
      'filterCustomize': 'ڕێکخستنی خۆت',
      'locationLabel': 'ناونیشان:',
      'distanceLabel': 'دووری:',
      'distanceFromCurrentLocation': '{distance} لە شوێنی ئێستاتەوە',
      'natureSpotsLoadFailed':
          'نەمانتوانی شوێنەکان باربکەین. تکایە دووبارە هەوڵ بدەوە.',
      'natureSpotsEmpty': 'هیچ شوێنێک لەگەڵ ئەم پاڵاوتنانەدا نەگونجا',
      'highlightedEmpty': 'هێشتا هیچ شوێنێکی هەڵبژێردراو نییە',
      'clearFilters': 'پاڵاوتنەکان بسڕەوە',
      'aboutThisPlace': 'دەربارەی ئەم شوێنە',
      'placeNameLabel': 'ناو:',
      'placeDistanceLabel': 'دووری:',
      'suggestedStaysNearby': 'شوێنی مانەوەی پێشنیارکراو لە نزیکەوە',
      'stayDistanceAway': '{distance} کم دوورە',
      'weather': 'کەشوهەوا',
      'weatherUnavailable': 'کەشوهەوا ئێستا بەردەست نییە',
      'sunny': 'خۆرەتاو',
      'partlyCloudy': 'هەورێکی کەم',
      'cloudy': 'هەوراوی',
      'rainy': 'باراناوی',
      'snowy': 'بەفراوی',
      'ratingsAndReviews': 'هەڵسەنگاندن و بۆچوونەکان',
      'basedOnReviews': 'لەسەر بنەمای {count} بۆچوون',
      'writeReviewPrompt': 'سەردانی ئەم شوێنەت کردووە؟',
      'writeReviewHint': 'کلیک لێرە بکە بۆ هەڵسەنگاندن و نووسینی بۆچوون',
      'reviewsLoadFailed': 'نەتوانرا بۆچوونەکانی سەردانکەران باربکرێن',
      'noReviewsYet': 'هێشتا هیچ بۆچوونێک نییە. یەکەم کەس بە بۆچوونەکەت.',
      'seeAllReviews': 'هەموو بۆچوونەکان ببینە',
      'openPlaceMap': 'نەخشەی شوێنەکە بکەرەوە',
      'reviewsCount': '{count} پێداچوونەوە',
      // --- Reviews & Ratings screen ---
      'reviewsAndRatings': 'بۆچوون و هەڵسەنگاندن',
      'averageRating': 'ناوەندی هەڵسەنگاندن',
      'outOfTen': '/ ١٠',
      'allReviews': 'هەموو بۆچوونەکان',
      'sortMostRecent': 'نوێترین',
      'sortHighestRated': 'بەرزترین هەڵسەنگاندن',
      'sortLowestRated': 'نزمترین هەڵسەنگاندن',
      'sortMostHelpful': 'سوودبەخشترین',
      'sortReviewsBy': 'ڕیزکردنی بۆچوونەکان بەپێی',
      'oneReview': '١ بۆچوون',
      'noRatingsYet': 'هێشتا هەڵنەسەنگێنراوە',
      'addYourReview': 'بۆچوونەکەت زیاد بکە',
      'yourRating': 'هەڵسەنگاندنی تۆ',
      'reviewCommentHint': 'باسی ئەزموونەکەت بۆ ئەوانی تر بکە…',
      'postReview': 'ناردنی بۆچوون',
      'updateReview': 'نوێکردنەوەی بۆچوون',
      'reviewPosted': 'سوپاس — بۆچوونەکەت بڵاوکرایەوە',
      'reviewUpdated': 'بۆچوونەکەت نوێکرایەوە',
      'reviewPostFailed':
          'نەتوانرا بۆچوونەکەت بنێردرێت. تکایە دووبارە هەوڵ بدە.',
      'reviewRatingRequired': 'سەرەتا ژمارەی ئەستێرە هەڵبژێرە',
      'reviewCommentTooShort': 'لانیکەم ٣ پیت بنووسە',
      'reviewCommentTooLong': 'بۆچوونەکەت کەمتر لە ١٠٠٠ پیت بێت',
      'reviewSignInTitle': 'بۆ نووسینی بۆچوون بچۆ ژوورەوە',
      'reviewSignInBody':
          'بۆچوونەکان بە هەژمارەکەتەوە بەستراون، بۆیە هەمووان دەزانن کێ سەردانی کردووە.',
      'yourReviewLabel': 'بۆچوونی تۆ',
      'editYourReview': 'دەستکاری بۆچوونەکەت بکە',
      'helpfulVote': 'ئەم بۆچوونە بە سوودبەخش نیشان بدە',
      'helpfulVoteRemove': 'دەنگی سوودبەخشی لاببە',
      'helpfulSignInBody':
          'بچۆ ژوورەوە بۆ ئەوەی بڵێیت ئەم بۆچوونە سوودبەخش بوو.',
      'helpfulFailed': 'نەتوانرا دەنگەکەت پاشەکەوت بکرێت. دووبارە هەوڵ بدە.',
      'loadMoreReviews': 'بۆچوونی زیاتر پیشان بدە',
      'reviewJustNow': 'هەر ئێستا',
      'reviewHoursAgo': 'لەمەوبەر {count} کاتژمێر',
      'reviewOneHourAgo': 'لەمەوبەر ١ کاتژمێر',
      'reviewDaysAgo': 'لەمەوبەر {count} ڕۆژان',
      'reviewOneDayAgo': 'لەمەوبەر ١ ڕۆژ',
      'reviewWeeksAgo': 'لەمەوبەر {count} هەفتە',
      'reviewOneWeekAgo': 'لەمەوبەر ١ هەفتە',
      'reviewMonthsAgo': 'لەمەوبەر {count} مانگەکان',
      'reviewOneMonthAgo': 'لەمەوبەر ١ مانگ',
      'reviewYearsAgo': 'لەمەوبەر {count} ساڵ',
      'reviewOneYearAgo': 'لەمەوبەر ١ ساڵ',
      // --- Customize Filters screen ---
      'customizeFilters': 'ڕێکخستنی پاڵاوتنەکان',
      'customizeFiltersSubtitle':
          'ئەو شوێنانە بدۆزەرەوە کە لەگەڵ گەشتەکەت دەگونجێن',
      'filtersSelected': '{count} پاڵاوتن هەڵبژێردراوە',
      'oneFilterSelected': '١ پاڵاوتن هەڵبژێردراوە',
      'noFiltersSelected': 'هیچ پاڵاوتنێک هەڵنەبژێردراوە',
      'resetAll': 'هەمووی بسڕەوە',
      'placeType': 'جۆری شوێن',
      'facilitiesAmenities': 'ئاسانکاری و خزمەتگوزاری',
      'showPlaces': '{count} شوێن پیشان بدە',
      'showOnePlace': '١ شوێن پیشان بدە',
      'showNoPlaces': 'هیچ شوێنێک نەگونجا',
      'placeTypeForest': 'دارستان',
      'placeTypeMountain': 'شاخ',
      'placeTypeCanyon': 'دەربەند',
      'placeTypePark': 'پارک',
      'placeTypeLake': 'دەریاچە',
      'placeTypeWaterfall': 'ئاوشار',
      'placeTypeRiver': 'ڕووبار',
      'placeTypeMuseum': 'مۆزەخانە',
      'amenityParking': 'گەراج',
      'amenityRestrooms': 'ئاودەست',
      'amenityRestaurants': 'چێشتخانە',
      'amenityCafes': 'کافێ',
      'amenityMobileSignal': 'ئاماژەی مۆبایل',
      'amenityLodgingNearby': 'شوێنی مانەوەی نزیک',
      'amenityAtmNearby': 'ئەی تی ئێمی نزیک',
      // --- Policy screen ---
      'policyOfApp': 'سیاسەتی ئەپ',
      'policyOfAppSubtitle':
          'ڕێنمایی و سیاسەتەکانمان بخوێنەوە بۆ ئەوەی بزانیت چۆن '
          'پارێزگاریت لێ دەکەین.',
      'policyPrivacyTitle': 'سیاسەتی تایبەتمەندێتی',
      'policyPrivacySubtitle': 'چۆن مامەڵە لەگەڵ زانیارییەکانت دەکەین',
      'policyTermsTitle': 'مەرج و ڕێساکان',
      'policyTermsSubtitle': 'ڕێساکانی بەکارهێنانی ئەپەکە',
      'policyCancellationTitle': 'هەڵوەشاندنەوە و گەڕاندنەوەی پارە',
      'policyCancellationSubtitle': 'گۆڕین یان هەڵوەشاندنەوەی حجزەکان',
      'policyPaymentTitle': 'سیاسەتی پارەدان',
      'policyPaymentSubtitle': 'ڕێگاکان، دراو و کرێیەکان',
      'policyLiabilityTitle': 'بەرپرسیارێتی و ڕوونکردنەوە',
      'policyLiabilitySubtitle': 'سنووری بەرپرسیارێتیمان',
      'policyContactTitle': 'پەیوەندی و سکاڵا',
      'policyContactSubtitle': 'پەیوەندی بە پشتگیرییەوە بکە',
      'policyAccountDeletionTitle': 'سڕینەوەی هەژمار و زانیاری',
      'policyAccountDeletionSubtitle': 'هەژمار و زانیارییەکانت بسڕەوە',
      'policyLoadFailed':
          'نەمانتوانی ئەم سیاسەتە باربکەین. تکایە دووبارە هەوڵ بدەوە.',
      // --- Help & Support screen ---
      'helpAndSupport': 'یارمەتی و پشتگیری',
      'helpAccountTitle': 'هەژمار و چوونەژوورەوە',
      'helpAccountPreview': 'چۆن ئیمەیڵەکەم بگۆڕم یان ...',
      'helpBookingsTitle': 'حجز و پشتڕاستکردنەوە',
      'helpBookingsPreview': 'ژمارەی ئاماژەی حجزەکەم چییە ...',
      'helpPaymentsTitle': 'پارەدان و گەڕاندنەوەی پارە',
      'helpPaymentsPreview': 'پارەدانەکەم سەرکەوتوو نەبوو بەڵام ...',
      'helpCancellationTitle': 'هەڵوەشاندنەوە و گۆڕانکاری',
      'helpCancellationPreview': 'دەتوانم لەبری ئەوە حجزەکەم بگۆڕم ...',
      'helpFlightsTitle': 'فڕینەکان',
      'helpFlightsPreview': 'ڕێژەی بارهەڵگرتن چەندە ...',
      'helpStaysTitle': 'شوێنی مانەوە (هۆتێلەکان)',
      'helpStaysPreview': 'کاتی چوونەژوورەوە و ... چییە',
      'helpCarRentalTitle': 'بەکرێگرتنی ئۆتۆمبێل',
      'helpCarRentalPreview': 'چ بەڵگەنامەیەکم پێویستە بۆ ...',
      'helpToursTitle': 'گەشت و سروشت (گەڕان)',
      'helpToursPreview': 'ئەگەر کەشوهەوا ... چی ڕوودەدات',
      'helpSafetyTitle': 'سەلامەتی و زانیاری گەشت',
      'helpSafetyPreview': 'ژمارەکانی فریاگوزاری لە ... چین',
      'helpContactTitle': 'هێشتا یارمەتیت دەوێت؟ پەیوەندیمان پێوە بکە',
      'helpContactPreview': 'پەیوەندی بە تیمی پشتگیریمانەوە بکە ...',
      // --- My Bookings screen ---
      'bookingsFilterAll': 'هەموو',
      'bookingsFilterHotels': 'هوتێلەکان',
      'bookingsFilterCars': 'ئۆتۆمبێلەکان',
      'bookingsFilterFlights': 'فڕینەکان',
      'bookingsFilterTours': 'گەشتەکان',
      'bookingsSegmentUpcoming': 'داهاتوو',
      'bookingsSegmentPast': 'ڕابردوو',
      'bookingsSegmentCancelled': 'هەڵوەشێنراوە',
      'bookingTypeHotel': 'هوتێل',
      'bookingTypeCar': 'بەکرێگرتنی ئۆتۆمبێل',
      'bookingTypeFlight': 'فڕین',
      'bookingTypeTour': 'گەشت',
      'bookingStatusConfirmed': 'پشتڕاستکراوە',
      'bookingStatusPending': 'چاوەڕوانە',
      'bookingStatusCancelled': 'هەڵوەشێنراوە',
      'bookingStatusCompleted': 'تەواوبوو',
      'bookingStatusUpcoming': 'داهاتوو',
      'cabinEconomy': 'ئابووری',
      'cabinPremiumEconomy': 'ئابووری تایبەت',
      'cabinBusiness': 'بازرگانی',
      'cabinFirst': 'پۆلی یەکەم',
      'bookingCheckIn': 'چوونەژوورەوە',
      'bookingCheckOut': 'دەرچوون',
      'bookingGuests': 'میوانەکان',
      'bookingTravelers': 'گەشتیارەکان',
      'bookingDriver': 'شۆفێر',
      'bookingTraveler': 'گەشتیار',
      'bookingSeat': 'کورسی',
      'bookingDuration': 'ماوە',
      'bookingId': 'ژمارەی حیجز',
      'bookingPickup': 'وەرگرتن',
      'bookingDropoff': 'گەڕاندنەوە',
      'bookingTotalPaid': 'کۆی دراو',
      'bookingActionCheckIn': 'چوونەژوورەوە',
      'bookingActionOpenTicket': 'کردنەوەی بلیت',
      'bookingActionPickupInfo': 'زانیاری وەرگرتن',
      'bookingActionTourDetails': 'وردەکاری گەشت',
      'bookingActionViewDetails': 'بینینی وردەکاری',
      'bookingAdultsCount': '{count} پێگەیشتوو',
      'bookingAdultCount': '{count} پێگەیشتوو',
      'bookingHours': '{count} کاتژمێر',
      'bookingsLoadFailed': 'نەتوانرا حیجزەکانت باربکرێن',
      'bookingsEmptyTitle': 'هێشتا هیچ حیجزێک نییە',
      'bookingsEmptyBody':
          'کاتێک هوتێل، فڕین، ئۆتۆمبێل یان گەشتێک حیجز دەکەیت، لێرە دەردەکەوێت.',
      'bookingsEmptyUpcoming': 'هیچ حیجزێکی داهاتوو نییە',
      'bookingsEmptyPast': 'هیچ حیجزێکی ڕابردوو نییە',
      'bookingsEmptyCancelled': 'هیچ حیجزێکی هەڵوەشێنراوە نییە',
      'bookingsEmptyFiltered':
          'هیچ شتێک لەگەڵ ئەم پاڵێوەرەدا ناگونجێت. جۆرێکی تر تاقی بکەرەوە.',
      'bookingsSignInTitle': 'بچۆ ژوورەوە بۆ بینینی حیجزەکانت',
      'bookingsSignInBody':
          'حیجزەکانت بە هەژمارەکەتەوە بەستراون، بۆیە پێویستە بچیتە ژوورەوە بۆ پیشاندانیان.',
      'bookingsStartExploring': 'دەست بە گەڕان بکە',
      'month1': 'کانوونی دووەم',
      'month2': 'شوبات',
      'month3': 'ئازار',
      'month4': 'نیسان',
      'month5': 'ئایار',
      'month6': 'حوزەیران',
      'month7': 'تەمموز',
      'month8': 'ئاب',
      'month9': 'ئەیلوول',
      'month10': 'تشرینی یەکەم',
      'month11': 'تشرینی دووەم',
      'month12': 'کانوونی یەکەم',
      'timeAm': 'ب.ن',
      'timePm': 'د.ن',
      // --- Explore Tours screen ---
      'toursSearchHint': 'گەڕان بۆ گەشت یان شوێن',
      'toursDateHint': 'ڕێکەوتی گەشتەکە',
      'toursApply': 'جێبەجێکردن',
      'clearDate': 'ڕێکەوت بسڕەوە',
      'clearSearch': 'گەڕان بسڕەوە',
      'trendingTours': 'گەشتە بەناوبانگەکان',
      'toursLoadFailed': 'نەتوانرا گەشتەکان بهێنرێن',
      'toursEmpty': 'هیچ گەشتێک لەگەڵ گەڕانەکەت ناگونجێت',
      'toursHighlightedEmpty': 'هێشتا هیچ گەشتێک دیاری نەکراوە',
      'tourDayTravel': 'گەشتی {count} ڕۆژ',
      'tourDaysTravel': 'گەشتی {count} ڕۆژان',
      'tourPerPerson': 'بۆ هەر کەسێک',
      'tourPerPersonBadge': 'بۆ هەر کەسێک',
      'tourFeatureCamping': 'خێوەتگە',
      'tourFeatureHiking': 'پیاسەی چیا',
      'tourFeatureGuide': 'ڕێبەر',
      'tourFeatureFood': 'خواردن',
      'tourFeatureSwimming': 'مەلەکردن',
      'tourFeatureCampfire': 'ئاگری خێوەتگە',
      'tourFeatureTransport': 'گواستنەوە',
      'tourFeaturePhotography': 'وێنەگرتن',
      'tourFeatureActivity': 'چالاکی',
      'tourFeatureWifi': 'وایفای',
      'tourFeatureElectricity': 'کارەبا',
      'tourFeatureTent': 'خێمە',
      'tourReviewCount': '{count} پێداچوونەوە',
      // Digits stay Western in all three languages, matching every other
      // number in the app (see `bookingDate`).
      'tourReviewCountOne': '1 پێداچوونەوە',
      'tourNoReviews': 'هێشتا پێداچوونەوە نییە',
      'tourSpotsLeft': 'تەنها {count} شوێن ماوە',
      'tourSpotsLeftOne': 'تەنها 1 شوێن ماوە',
      'tourTravellers': 'گەشتیارەکان',
      'tourTravellerCount': '{count} گەشتیار',
      'tourTravellerCountOne': '1 گەشتیار',
      'tourTotalFor': 'کۆی گشتی {price}',
      'tourCancelFree24h': 'هەڵوەشاندنەوەی بێبەرامبەر تا 24 کاتژمێر پێشتر',
      'tourCancelFree48h': 'هەڵوەشاندنەوەی بێبەرامبەر تا 48 کاتژمێر پێشتر',
      'tourCancelFree7d': 'هەڵوەشاندنەوەی بێبەرامبەر تا 7 ڕۆژان پێشتر',
      'tourCancelNonRefundable': 'پارە ناگەڕێتەوە',
      'tourGuideLanguages': 'ڕێبەر قسە دەکات بە',
      'tourLanguageEnglish': 'ئینگلیزی',
      'tourLanguageKurdish': 'کوردی',
      'tourLanguageArabic': 'عەرەبی',
      'tourLanguageTurkish': 'تورکی',
      'tourLanguagePersian': 'فارسی',
      'toursSortLabel': 'ڕیزکردن',
      'toursSortSoonest': 'نزیکترین کات',
      'toursSortPriceLow': 'نرخ: لە کەمەوە بۆ زۆر',
      'toursSortPriceHigh': 'نرخ: لە زۆرەوە بۆ کەم',
      'toursSortTopRated': 'باشترین هەڵسەنگاندن',
      'toursSortNearest': 'نزیکترین بۆ من',
      'toursRefine': 'ورد کردنەوە',
      'toursIncludes': 'لەخۆدەگرێت',
      'toursDateRangeHint': 'ڕێکەوتەکانی گەشت',
      'toursPriceApprox':
          'نرخەکان بە ڕێژەیەکی نزیکەیی گۆڕدراون و وەک نزیکەیی پیشان دەدرێن. '
          'پارەکە بە دراوی خودی کۆمپانیاکە وەردەگیرێت.',
      'toursClearAll': 'هەمووی بسڕەوە',
      'tourDetails': 'زانیارییەکانی گەشت',
      'tourFacilities': 'خزمەتگوزارییەکان',
      'tourMap': 'نەخشە',
      'tourCheckout': 'پوختەی نرخ',
      'tourPerson': 'کەس',
      'tourTransportationBus': 'گواستنەوە بە پاس',
      'tourOptional': 'ئارەزوومەندانە',
      'tourTotalPrice': 'کۆی نرخ',
      'tourReserveInsight': 'تۆمارکردنی گەشت',
      'tourTransportUnavailable': 'گواستنەوە بە پاس بۆ ئەم گەشتە بەردەست نییە',
      'tourWeatherUnavailable': 'زانیاری کەشوهەوا بەردەست نییە',
      'tourMapUnavailable': 'نەخشە بەردەست نییە',
      'tourWriteReviewPrompt': 'بەشداری ئەم گەشتەت کردووە؟',
      'tourNoReviewsYet':
          'هێشتا بۆچوون نییە. یەکەم کەس بە کە ئەزموونی گەشتەکەت باس دەکات.',
      'tourReviewSignInBody':
          'بۆچوونەکانی گەشت بە هەژمارەکەتەوە بەستراونەتەوە بۆ ئەوەی گەشتیاران متمانەیان پێ بکەن.',
      'bookingStepTravelerInfo': 'زانیاری گەشتیار',
      'bookingStepPayment': 'پارەدان',
      'bookingStepConfirmation': 'پشتڕاستکردنەوە',
      'travelerInformation': 'زانیاری گەشتیار',
      'travelerInformationHint': 'تکایە زانیاری هەموو گەشتیارەکان بنووسە',
      'contactPerson': 'کەسی پەیوەندی',
      'travelersLabel': 'گەشتیاران',
      'travelerNumbered': 'گەشتیار',
      'dateOfBirthHint': 'بەرواری لەدایکبوون',
      'leadTraveler': 'گەشتیاری سەرەکی',
      'leadTravelerHint': 'تۆمارەکە بە ناوی ئەم گەشتیارە دەردەچێت',
      'informationSecure': 'زانیارییەکانت پارێزراو و کۆدکراون',
      'continueToPayment': 'بەردەوامبە بۆ پارەدان',
      'selectDialCode': 'کۆدی وڵات هەڵبژێرە',
      'travelerInfoIncomplete':
          'تکایە ناو و بەرواری لەدایکبوونی هەموو گەشتیارەکان تەواو بکە.',
      'contactIncomplete': 'تکایە ناو، ئیمەیڵ و ژمارەی مۆبایلی دروست بنووسە.',
      'travelerTooYoung':
          'هەموو گەشتیارێکی ئەم گەشتە دەبێت تەمەنی {age} یان زیاتر بێت.',
      'travelerFutureBirthDate':
          'بەرواری لەدایکبوون ناتوانێت لە داهاتوودا بێت.',
      'noPlacesLeft': 'ئەم گەشتە هیچ شوێنێکی بەتاڵی نەماوە.',
      'onlyPlacesLeft': 'تەنها {count} شوێن لەم گەشتەدا ماوە.',
      'reserveSignInTitle': 'بۆ تۆمارکردن بچۆ ژوورەوە',
      'reserveSignInBody':
          'تۆمارکردن بە هەژمارەکەتەوە بەستراوەتەوە، بۆ ئەوەی دواتر بیدۆزیتەوە و بزانین پەیوەندی بە کێوە بکەین.',
      'paymentDetails': 'وردەکاری پارەدان',
      'paymentDetailsHint': 'پارەدانەکە تەواو بکە بۆ پشتڕاستکردنەوەی تۆمارەکە',
      'bookingSummary': 'کورتەی تۆمارکردن',
      'paymentMethodLabel': 'شێوازی پارەدان',
      'mastercardVisa': 'ماستەرکارد / ڤیزا',
      'totalLabel': 'کۆی گشتی',
      'selectPaymentMethod': 'شێوازی پارەدانەکەت هەڵبژێرە',
      'cardEntryNotLive':
          'پارەدان بە کارت هێشتا پەیوەست نەکراوە. زانیاری کارتەکەت نەنێردرا و پاشەکەوت نەکرا.',
      'paymentIncompleteCard':
          'تکایە ژمارەی کارت، بەرواری بەسەرچوون و CVV بنووسە.',
      'paymentNoMethod': 'تکایە شێوازی پارەدان هەڵبژێرە.',
      // --- Checkout step 3 (Review & Confirm) ---
      'reviewConfirmTitle': 'پێداچوونەوە و پشتڕاستکردنەوە',
      'reviewConfirmHint':
          'تکایە پێش پشتڕاستکردنەوە وردەکارییەکانی تۆمارکردنەکەت بپشکنە.',
      'travelersInformation': 'زانیاری گەشتیارەکان',
      'priceBreakdown': 'وردەکاری نرخ',
      'travelerFee': 'کرێی گەشتیار',
      'priceEachTimes': '{count} × {price}',
      'reviewAgreeTerms': 'ڕازیم بە {terms} و {policy}.',
      'reviewTermsLink': 'مەرجەکانی خزمەتگوزاری',
      'reviewPolicyLink': 'ڕێساکانی ئەپ',
      'reviewMustAgree':
          'تکایە ڕازیبە بە مەرجەکانی خزمەتگوزاری و ڕێساکانی ئەپ بۆ بەردەوامبوون.',
      'confirmAndPay': 'پشتڕاستکردنەوە و پارەدانی {price}',
      'confirmPayNotLive':
          'پارەدان هێشتا بەستراوە نییە، بۆیە هیچ پارەیەک وەرنەگیرا و هیچ '
          'تۆمارکردنێک دروست نەکرا.',
      'useSavedCard': 'ئەم کارتە بەکاربهێنە',
    },
    'ar': <String, String>{
      'chooseYourLanguage': 'اختر لغتك',
      'selectLanguageToContinue': 'اختر لغة للمتابعة',
      'logIn': 'تسجيل الدخول',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'forgetPassword': 'نسيت كلمة المرور؟',
      'orLabel': 'أو',
      'dontHaveAccount': 'ليس لديك حساب؟ ',
      'registerNow': 'سجّل الآن',
      'continueAsGuest': 'المتابعة كضيف',
      'emailRequired': 'الرجاء إدخال بريدك الإلكتروني',
      'emailInvalid': 'أدخل بريدًا إلكترونيًا صالحًا',
      'passwordRequired': 'الرجاء إدخال كلمة المرور',
      'forgetPasswordSubtitle':
          'يرجى اختيار بيانات الاتصال الخاصة بك وسنرسل إليك رمز تحقق '
          'لإعادة تعيين كلمة المرور.',
      'phoneNumber': 'رقم الهاتف',
      'emailAddress': 'البريد الإلكتروني',
      'sendCode': 'إرسال الرمز',
      'selectContactMethod': 'اختر الهاتف أو البريد الإلكتروني أولاً',
      'verificationCode': 'رمز التحقق',
      'verificationSubtitle':
          'أدخل الرمز المكوّن من ٦ أرقام الذي أرسلناه للتو إلى {dest} '
          'لإعادة تعيين كلمة المرور.',
      'didntReceiveCode': 'لم تستلم الرمز؟ ',
      'resendNow': 'إعادة الإرسال',
      'resendIn': 'إعادة الإرسال خلال {seconds} ثانية',
      'verify': 'تحقّق',
      'codeIncomplete': 'أدخل أرقام الرمز الستة كاملة',
      'codeIncorrect': 'هذا الرمز غير صحيح. يرجى المحاولة مرة أخرى.',
      'codeExpired': 'انتهت صلاحية هذا الرمز. اطلب رمزًا جديدًا.',
      'tooManyAttempts':
          'محاولات كثيرة جدًا. يرجى الانتظار قبل المحاولة مرة أخرى.',
      'codeResentPhone': 'تم إرسال رمز جديد عبر رسالة نصية',
      'codeResentEmail': 'تم إرسال رمز جديد إلى بريدك الإلكتروني',
      'sendCodeFailed': 'تعذّر إرسال الرمز. يرجى المحاولة مرة أخرى.',
      'networkError': 'لا يوجد اتصال. تحقّق من شبكتك ثم حاول مرة أخرى.',
      'resetPassword': 'إعادة تعيين كلمة المرور',
      'resetPasswordSubtitle':
          '٨ أحرف على الأقل، مع حرف كبير وحرف صغير ورمز خاص.',
      'newPassword': 'كلمة المرور الجديدة',
      'confirmPassword': 'تأكيد كلمة المرور',
      'updatePassword': 'تحديث كلمة المرور',
      'passwordTooShort': 'استخدم ٨ أحرف على الأقل',
      'passwordNeedsUppercase': 'أضف حرفًا كبيرًا واحدًا على الأقل',
      'passwordNeedsLowercase': 'أضف حرفًا صغيرًا واحدًا على الأقل',
      'passwordNeedsSpecial': 'أضف رمزًا خاصًا واحدًا على الأقل',
      'confirmPasswordRequired': 'يرجى إعادة إدخال كلمة المرور الجديدة',
      'passwordsDontMatch': 'كلمتا المرور غير متطابقتين',
      'passwordUpdated': 'تم تحديث كلمة المرور. يرجى تسجيل الدخول.',
      'passwordUpdateFailed':
          'تعذّر تحديث كلمة المرور. يرجى المحاولة مرة أخرى.',
      'passwordTooWeak': 'يرجى اختيار كلمة مرور أقوى',
      'sessionExpired': 'انتهت جلستك. يرجى البدء من جديد.',
      // --- Register screen ---
      'register': 'إنشاء حساب',
      'fullName': 'الاسم الكامل',
      'age': 'العمر',
      'gender': 'الجنس',
      'genderMale': 'ذكر',
      'genderFemale': 'أنثى',
      'genderOther': 'آخر',
      'genderOptional': 'الجنس (اختياري)',
      'alreadyHaveAccount': 'لديك حساب بالفعل؟ ',
      'logInHere': 'سجّل الدخول من هنا',
      'passwordHint': '٨ أحرف على الأقل، مع حرف كبير وحرف صغير ورمز خاص.',
      'acceptTerms': 'أوافق على شروط الخدمة وسياسة الخصوصية',
      'termsRequired': 'يرجى الموافقة على الشروط وسياسة الخصوصية',
      'fullNameRequired': 'يرجى إدخال اسمك الكامل',
      'fullNameTooShort': 'يرجى إدخال اسمك الكامل',
      'dateOfBirthRequired': 'يرجى اختيار تاريخ ميلادك',
      'mustBe18': 'يجب أن يكون عمرك ١٨ عامًا على الأقل لإنشاء حساب',
      'phoneRequired': 'يرجى إدخال رقم هاتفك',
      'phoneInvalid': 'أدخل رقم هاتف صالح',
      'selectCountryCode': 'رمز الدولة',
      'accountCreated': 'تم إنشاء الحساب. يرجى تسجيل الدخول.',
      'registerFailed': 'تعذّر إنشاء حسابك. يرجى المحاولة مرة أخرى.',
      'emailInUse': 'يوجد حساب بهذا البريد الإلكتروني بالفعل',
      'phoneInUse': 'يوجد حساب بهذا الرقم بالفعل',
      'verifyNumberSubtitle':
          'أدخل الرمز المكوّن من ٦ أرقام الذي أرسلناه للتو إلى {dest} '
          'للتحقق من رقمك.',
      'verifyEmailTitle': 'تحقّق من بريدك الإلكتروني',
      'verifyEmailSubtitle':
          'أدخل الرمز المكوّن من ٦ أرقام الذي أرسلناه للتو إلى {dest} '
          'لتأكيد بريدك الإلكتروني.',
      'emailVerified': 'تم التحقق من بريدك الإلكتروني.',
      // --- Terms of Service screen ---
      'termsOfService': 'شروط الخدمة',
      'termsAgreeCheckbox':
          'لقد قرأت شروط الخدمة وسياسة الخصوصية وأوافق عليها.',
      'continueLabel': 'متابعة',
      'lastUpdated': 'آخر تحديث: {date}',
      'termsLoadFailed': 'تعذّر تحميل الشروط. يرجى المحاولة مرة أخرى.',
      'tryAgain': 'حاول مرة أخرى',
      'termsNotReviewed':
          'صيغة مبدئية — بانتظار المراجعة القانونية. غير مخصّصة للإصدار.',
      // --- Account Setup screen ---
      'accountSetup': 'إعداد الحساب',
      'accountSetupSubtitle':
          'أكمل إعداد حسابك برفع صورة الملف الشخصي وتحديد اسم المستخدم.',
      'username': 'اسم المستخدم',
      'createAccount': 'إنشاء الحساب',
      'chooseFromGallery': 'اختر من المعرض',
      'takePhoto': 'التقط صورة',
      'removePhoto': 'إزالة الصورة',
      'usernameRequired': 'يرجى إدخال اسم المستخدم',
      'usernameTooShort': 'استخدم حرفين على الأقل',
      'imageTooLarge': 'هذه الصورة كبيرة جدًا. اختر صورة أقل من ٥ ميغابايت.',
      'imagePickFailed': 'تعذّر فتح هذه الصورة. يرجى المحاولة مرة أخرى.',
      'profileSaveFailed': 'تعذّر حفظ ملفك الشخصي. يرجى المحاولة مرة أخرى.',
      'cameraPermissionDenied':
          'الوصول إلى الكاميرا مُعطّل. فعّله من الإعدادات لالتقاط صورة.',
      'galleryPermissionDenied':
          'الوصول إلى الصور مُعطّل. فعّله من الإعدادات لاختيار صورة.',
      // --- Register Complete screen ---
      'registerComplete': 'اكتمل التسجيل!',
      'registerCompleteSubtitle': 'تم إنشاء حسابك بنجاح. أهلًا بك!',
      'explore': 'استكشف',
      // --- Onboarding (3-slide intro) ---
      'onboardingTitleLine1': 'اكتشف',
      'onboardingTitleLine2': 'كردستان',
      'onboardingBody1':
          'استكشف الوديان الجميلة والأنهار ودروب الجبال التي لا يصل إليها '
          'سوى قليل من المسافرين.\nكل ذلك في تطبيق واحد.',
      'onboardingTitle2Line1': 'طر إلى',
      'onboardingTitle2Line2': 'كردستان',
      'onboardingBody2': 'قارن الرحلات واختر تواريخك واحجز تذكرتك في دقائق.',
      'onboardingTitle3Line1': 'سيارتك',
      'onboardingTitle3Line2': 'جاهزة !',
      'onboardingBody3':
          'استأجر سيارة وتنقّل إلى كل ركن في كردستان وفق جدولك الخاص.',
      'onboardingNext': 'التالي',
      // --- Home screen ---
      'goodMorning': 'صباح الخير',
      'goodAfternoon': 'طاب نهارك',
      'goodEvening': 'مساء الخير',
      'dearUser': 'عزيزي المستخدم',
      'whereWouldYouLikeToGo': 'إلى أين تودّ الذهاب؟',
      'planYourJourney': 'خطّط لرحلتك',
      'exploreNature': 'استكشف الطبيعة',
      'exploreNatureHint': 'مسارات وبحيرات وحدائق خلّابة.',
      'whereToStay': 'أين تقيم',
      'whereToStayHint': 'فنادق وأكواخ وأماكن إقامة مميّزة',
      'hotelLocation': 'الموقع',
      'hotelLocationHint': 'أين تريد الإقامة؟',
      'hotelRecentSearches': 'عمليات البحث الأخيرة',
      'hotelDate': 'التاريخ',
      'hotelCheckIn': 'تسجيل الوصول',
      'hotelCheckOut': 'تسجيل المغادرة',
      'hotelGuests': 'الضيوف',
      'hotelAdult': 'بالغ',
      'hotelChild': 'طفل',
      'hotelRoom': 'غرفة',
      'hotelBed': 'سرير',
      'hotelOptions': 'الخيارات',
      'hotelNoOptions': 'لم يتم تحديد خيارات',
      'hotelOneOption': 'تم تحديد خيار واحد',
      'hotelManyOptions': 'تم تحديد {count} خيارات',
      'hotelPool': 'مسبح',
      'hotelBar': 'بار',
      'hotelRestaurant': 'مطعم',
      'hotelGym': 'نادي رياضي',
      'hotelParking': 'موقف سيارات',
      'hotelFreeWifi': 'واي فاي مجاني',
      'hotelBeach': 'شاطئ',
      'hotelMoreOptions': 'المزيد من الخيارات',
      'hotelSearch': 'بحث',
      'hotelTrending': 'أماكن الإقامة الرائجة',
      'hotelPerNight': 'لليلة',
      'hotelDistanceFromCenter': '{distance} كم من وسط المدينة',
      'hotelAdultsBeds': '{adults} بالغين، {beds} أسرّة',
      'hotelGuestSummary':
          '{adults} بالغين، {children} أطفال، {rooms} غرف، {beds} أسرّة',
      'hotelAdultCountOne': '{count} بالغ',
      'hotelAdultCountMany': '{count} بالغين',
      'hotelChildCountOne': '{count} طفل',
      'hotelChildCountMany': '{count} أطفال',
      'hotelRoomCountOne': '{count} غرفة',
      'hotelRoomCountMany': '{count} غرف',
      'hotelBedCountOne': '{count} سرير',
      'hotelBedCountMany': '{count} أسرّة',
      'hotelDestinationRequired': 'يرجى اختيار موقع',
      'hotelInvalidDates': 'يجب أن تكون المغادرة بعد الوصول',
      'hotelPreviewData': 'إقامات تجريبية – التوفر المباشر غير متصل',
      'hotelCarouselPosition': 'الفندق المميز {current} من {total}',
      'hotelStarClassification': 'فندق {count} نجوم',
      'hotelReviewScore': 'درجة التقييم {score} من 10',
      'hotelIncrease': 'زيادة {name}',
      'hotelDecrease': 'تقليل {name}',
      // --- Hotel Details page ---
      'hotelDetails': 'تفاصيل الفندق',
      'hotelDetailNotFound': 'لم يعد هذا الفندق متاحاً.',
      'hotelDetailLoadFailed': 'تعذر تحميل هذا الفندق.',
      'hotelGalleryPosition': '{current} / {total}',
      'hotelGalleryImage': 'صورة الفندق {current} من {total}',
      'hotelChange': 'تغيير',
      'hotelUpdateStay': 'تحديث إقامتك',
      'hotelUpdateStayApply': 'تطبيق التغييرات',
      'hotelStayUpdated': 'تم تحديث إقامتك',
      'hotelFacilities': 'المرافق',
      'hotelAllFacilities': 'كل المرافق',
      'hotelNoFacilities': 'لا توجد مرافق مدرجة بعد',
      'hotelSeeAll': 'عرض الكل',
      'hotelReviews': 'المراجعات',
      'hotelReviewCountOne': 'مراجعة واحدة',
      'hotelReviewCountMany': '{count} مراجعة',
      'hotelCleanliness': 'النظافة',
      'hotelComfort': 'الراحة',
      'hotelService': 'الخدمة',
      'hotelStaff': 'الطاقم',
      'hotelValue': 'القيمة مقابل السعر',
      'hotelMap': 'الموقع',
      'hotelMapUnavailable': 'الخريطة غير متاحة',
      'hotelNearby': 'أماكن قريبة',
      'hotelNearbyEmpty': 'لا توجد أماكن قريبة مدرجة بعد',
      'hotelNearbyAll': 'الأماكن القريبة',
      'hotelNearbyDistance': '{distance} كم',
      'hotelNearbyDistanceWithTime': '{minutes} دقيقة ({distance} كم)',
      'hotelRatingsAndComments': 'التقييمات والتعليقات',
      'hotelSelectRoom': 'اختيار الغرفة',
      'hotelChooseRoom': 'اختر غرفتك',
      'hotelMockNotice': 'بيانات معاينة — التوفر والدفع غير متصلين فعلياً.',
      'hotelNoRooms': 'لا توجد غرف متاحة لهذه التواريخ.',
      'hotelChangeDates': 'تغيير التواريخ',
      'hotelBackToHotel': 'العودة إلى الفندق',
      'hotelSeeRoomDetails': 'عرض تفاصيل الغرفة',
      'hotelMaximumGuests': 'الحد الأقصى {count} ضيوف',
      'hotelReserve': 'احجز',
      'hotelPriceForNights': 'السعر لمدة {count} ليلة',
      'hotelRechecking': 'جارٍ إعادة التحقق من السعر والتوفر…',
      'hotelCompleteBooking': 'أكمل حجزك',
      'hotelGuestDetails': 'بيانات الضيف',
      'hotelSpecialRequestsHint': 'الطلبات الاختيارية تخضع لتوفر الفندق',
      'hotelStripePreview': 'Stripe — معاينة فقط',
      'hotelFibPreview': 'FIB — معاينة فقط',
      'hotelMockPaymentNotice':
          'لن يتم إرسال أي دفعة. ينشئ هذا الدفع حجز معاينة محلياً فقط.',
      'hotelRoomSubtotal': 'المجموع الفرعي للغرفة',
      'hotelBookingConsent': 'أوافق على السعر وشروط الإلغاء المعروضة.',
      'hotelConfirmMockBooking': 'تأكيد حجز المعاينة',
      'hotelMockBookingComplete': 'اكتمل حجز المعاينة',
      'hotelMockBookingCompleteBody':
          'لم يتم حجز غرفة لدى الفندق ولم يتم تحصيل أي مبلغ.',
      'hotelViewReservations': 'عرض حجوزاتك',
      'hotelGuestRequired': 'يرجى إكمال بيانات الضيف المطلوبة.',
      'hotelConsentRequired': 'يرجى الموافقة على شروط الحجز.',
      'hotelRateUnavailable': 'لم يعد هذا السعر متاحاً. اختر خياراً آخر.',
      'hotelPropertyPolicies': 'سياسات الفندق',
      'hotelPolicyCheckInFrom': 'تسجيل الوصول من',
      'hotelPolicyCheckOutUntil': 'تسجيل المغادرة حتى',
      'hotelPolicyChildren': 'الأطفال',
      'hotelPolicyCribs': 'أسرة الأطفال',
      'hotelPolicyExtraBeds': 'أسرة إضافية',
      'hotelPolicyAgeRestriction': 'قيود العمر',
      'hotelPolicyMinimumAge': 'الحد الأدنى لسن تسجيل الوصول هو {age}',
      'hotelPolicyPets': 'الحيوانات الأليفة',
      'hotelPolicySmoking': 'التدخين',
      'hotelPolicyPayment': 'طرق الدفع المقبولة',
      'hotelPolicySpecialRequests': 'الطلبات الخاصة',
      'hotelPolicySpecialRequestsYes': 'يمكن إضافة طلبات خاصة إلى حجزك.',
      'hotelPolicySpecialRequestsNo': 'لا يمكن قبول الطلبات الخاصة.',
      'hotelPolicyAccessibility': 'إمكانية الوصول',
      'hotelFacilityGeneral': 'عام',
      'hotelFacilityInternet': 'إنترنت',
      'hotelFacilityParking': 'مواقف السيارات',
      'hotelFacilityFoodAndDrink': 'الطعام والشراب',
      'hotelFacilityWellness': 'الصحة والاستجمام',
      'hotelFacilityPool': 'المسبح',
      'hotelFacilityTransportation': 'المواصلات',
      'hotelFacilityRoom': 'مرافق الغرفة',
      'hotelFacilityFamily': 'العائلة',
      'hotelFacilityAccessibility': 'إمكانية الوصول',
      'hotelFacilityBusiness': 'الأعمال',
      'hotelFacilitySafety': 'السلامة',
      'hotelBedSingle': 'سرير فردي',
      'hotelBedTwin': 'سريران فرديان',
      'hotelBedDouble': 'سرير مزدوج',
      'hotelBedQueen': 'سرير كوين',
      'hotelBedKing': 'سرير كينغ',
      'hotelBedSofa': 'أريكة سرير',
      'hotelBedBunk': 'سرير بطابقين',
      'hotelBedCount': '{count} × {bed}',
      'hotelBreakfastIncluded': 'الفطور مشمول',
      'hotelBreakfastExtra': 'الفطور متاح مقابل رسوم إضافية',
      'hotelBreakfastUnavailable': 'الفطور غير متاح',
      'hotelTaxesAndFees': 'الضرائب والرسوم',
      'hotelTaxesIncluded': 'الضرائب والرسوم مشمولة',
      'hotelTaxesExcluded': 'الضرائب والرسوم غير مشمولة',
      'hotelFreeCancellation': 'إلغاء مجاني',
      'hotelPartiallyRefundable': 'قابل للاسترداد جزئياً',
      'hotelNonRefundable': 'غير قابل للاسترداد',
      'hotelPayNow': 'ادفع الآن',
      'hotelPayLater': 'ادفع لاحقاً',
      'hotelPayAtProperty': 'ادفع في الفندق',
      'hotelPrepaymentRequired': 'الدفع المسبق مطلوب',
      'hotelPartialPrepayment': 'مطلوب دفع مسبق جزئي',
      'hotelNoPrepayment': 'لا حاجة للدفع المسبق',
      'hotelRoomsLeftOne': 'بقيت غرفة واحدة فقط',
      'hotelRoomsLeftMany': 'بقيت {count} غرف فقط',
      'bestPrice': 'أفضل سعر',
      'carRental': 'تأجير السيارات',
      'carRentalHint': 'اعثر على السيارة المثالية لمغامرتك',
      'findACar': 'ابحث عن سيارة',
      'carPickupDropOffLocation': 'موقع الاستلام – التسليم',
      'carPickup': 'الاستلام',
      'carDropOff': 'التسليم',
      'carPickupLocation': 'موقع الاستلام',
      'carDropOffLocation': 'موقع التسليم',
      'carDifferentDropOff': 'التسليم في موقع مختلف',
      'carSelectDate': 'اختر التاريخ',
      'carSelectTime': 'اختر الوقت',
      'carSearch': 'بحث',
      'carSearching': 'جارٍ البحث…',
      'carTrending': 'السيارات الرائجة',
      'carAvailable': 'السيارات المتاحة',
      'carNoAvailable': 'لا توجد سيارات متاحة لهذه التواريخ',
      'carSearchLocations': 'البحث عن موقع تأجير',
      'carLocationSearchHint': 'مدينة أو مطار أو رمز أو فرع',
      'carLocationStartTyping': 'أدخل حرفين على الأقل',
      'carNoLocations': 'لم يتم العثور على مواقع تأجير',
      'carLocationsFailed': 'تعذّر تحميل مواقع التأجير',
      'carPickupLocationRequired': 'يرجى اختيار موقع الاستلام',
      'carDropOffLocationRequired': 'يرجى اختيار موقع التسليم',
      'carPickupDateRequired': 'يرجى اختيار تاريخ الاستلام',
      'carPickupTimeRequired': 'يرجى اختيار وقت الاستلام',
      'carDropOffDateRequired': 'يرجى اختيار تاريخ التسليم',
      'carDropOffTimeRequired': 'يرجى اختيار وقت التسليم',
      'carPickupFuture': 'يجب أن يكون الاستلام في المستقبل',
      'carDropOffAfterPickup': 'يجب أن يكون التسليم بعد الاستلام',
      'carSearchFailed': 'تعذّر تحميل السيارات المتاحة',
      'carPersons': '{count} أشخاص',
      'carBags': '{count} حقائب',
      'carAirConditioning': 'تكييف',
      'carHybrid': 'هجين',
      'carElectric': 'كهربائية',
      'carPetrol': 'بنزين',
      'carDiesel': 'ديزل',
      'carPayAtPickup': 'الدفع عند الاستلام',
      'carPayNow': 'ادفع الآن',
      'carModelYear': 'موديل {year}',
      'carPricePerDay': '{price}/يوم',
      'carPreviewData': 'سيارات تجريبية – التوفر المباشر غير متصل',
      'carCarouselPosition': 'السيارة المميزة {current} من {total}',
      'carResultsOne': 'نتيجة واحدة',
      'carResultsMany': '{count} نتائج',
      'carResultsEmptyTitle': 'لم يتم العثور على سيارات',
      'carResultsEmptyBody':
          'لم يتم العثور على سيارات للتواريخ والموقع المحددين.',
      'carModifySearch': 'تعديل البحث',
      'carResultsLoading': 'جارٍ تحميل السيارات المتاحة',
      'carResultsListLabel': 'نتائج البحث عن تأجير السيارات',
      'carDetails': 'تفاصيل السيارة',
      'carPickupDropOffDetails': 'تفاصيل الاستلام / التسليم',
      'carLocation': 'الموقع',
      'carAdditionalOptions': 'خيارات إضافية',
      'carApply': 'تطبيق',
      'carAutomatic': 'أوتوماتيك',
      'carManual': 'يدوي',
      'carPhotoPosition': 'الصورة {current} من {total}',
      'carGalleryLabel': 'صور {name}',
      'carDecreaseQuantity': 'إنقاص {name}',
      'carIncreaseQuantity': 'زيادة {name}',
      'carExtraTimesQuantity': '{price} × {count}',
      'carPriceSummary': 'ملخص السعر',
      'carBaseRental': 'الإيجار الأساسي',
      'carExtrasTotal': 'الإضافات',
      'carEstimatedTotal': 'الإجمالي التقديري',
      'carRentalDayOne': 'يوم إيجار واحد',
      'carRentalDaysMany': '{count} أيام إيجار',
      'carEstimateNote': 'تقدير فقط — الضرائب ورسوم المورّد غير مشمولة.',
      'carRentalConditions': 'شروط الإيجار',
      'carFuelPolicy': 'سياسة الوقود',
      'carFuelFullToFull': 'ممتلئ إلى ممتلئ',
      'carFuelFullToEmpty': 'ممتلئ إلى فارغ',
      'carFuelSameToSame': 'كما هو إلى كما هو',
      'carMileage': 'المسافة المقطوعة',
      'carMileageUnlimited': 'غير محدودة',
      'carMileagePerDay': '{count} كم في اليوم',
      'carMileageExtra': '{price} لكل كم إضافي',
      'carDeposit': 'مبلغ التأمين',
      'carDamageExcess': 'مبلغ التحمّل',
      'carFreeCancellation': 'إلغاء مجاني حتى',
      'carMinimumAge': 'الحد الأدنى لعمر السائق',
      'carMinimumAgeValue': '{age} سنة',
      'carRequiredDocuments': 'المستندات المطلوبة',
      'carOrSimilar': 'هذا الطراز أو مركبة مماثلة',
      'flightTicketing': 'حجز الطيران',
      'flightTicketingHint': 'رحلات رخيصة، حجز سهل، دفع آمن',
      'findFlight': 'ابحث عن رحلة',
      'flightOneWay': 'ذهاب فقط',
      'flightRoundTrip': 'ذهاب وعودة',
      'flightFrom': 'من',
      'flightTo': 'إلى',
      'flightSearchAirport': 'البحث عن مطار',
      'flightAirportSearchHint': 'المدينة أو المطار أو رمز IATA أو الدولة',
      'flightAirportStartTyping': 'أدخل حرفين على الأقل',
      'flightNoAirportsFound': 'لم يتم العثور على مطارات',
      'flightAirportLoadFailed': 'تعذّر تحميل المطارات',
      'flightDepartureDate': 'المغادرة',
      'flightReturnDate': 'العودة',
      'flightPassengers': 'المسافرون',
      'flightAdults': 'البالغون (12+)',
      'flightChildren': 'الأطفال (2–11)',
      'flightInfants': 'الرُضّع (أقل من سنتين)',
      'flightCabinClass': 'درجة السفر',
      'flightCabinEconomy': 'الدرجة الاقتصادية',
      'flightCabinPremiumEconomy': 'الاقتصادية المميزة',
      'flightCabinBusiness': 'درجة رجال الأعمال',
      'flightCabinFirst': 'الدرجة الأولى',
      'flightDirectOnly': 'رحلات مباشرة فقط',
      'flightSearch': 'البحث عن رحلات',
      'flightSearching': 'جارٍ البحث…',
      'done': 'تم',
      'flightOriginRequired': 'يرجى إدخال مكان المغادرة',
      'flightDestinationRequired': 'يرجى إدخال الوجهة',
      'flightDifferentAirports': 'يجب أن تختلف المغادرة عن الوجهة',
      'flightDepartureRequired': 'يرجى اختيار تاريخ المغادرة',
      'flightReturnRequired': 'يرجى اختيار تاريخ العودة',
      'flightSearchReady': 'بحثك جاهز لصفحة النتائج',
      'flightPassengerSummary':
          '{adults} بالغ · {children} طفل · {infants} رضيع',
      'flightResultsOne': 'تم العثور على رحلة واحدة',
      'flightResultsMany': 'تم العثور على {count} رحلات',
      'flightSortBest': 'الأفضل',
      'flightSortCheapest': 'الأرخص',
      'flightSortFastest': 'الأسرع',
      'flightSelect': 'اختيار',
      'flightDirect': 'مباشرة',
      'flightOneStop': 'توقف واحد',
      'flightManyStops': '{count} توقفات',
      'flightOutbound': 'الذهاب',
      'flightReturn': 'العودة',
      'flightTotalPrice': 'السعر الإجمالي',
      'flightPerTraveler': 'لكل مسافر',
      'flightResultsLoadFailed': 'تعذّر تحميل الرحلات',
      'flightResultsEmptyTitle': 'لم يتم العثور على رحلات',
      'flightResultsEmptyBody': 'جرّب تاريخًا آخر أو غيّر عوامل البحث.',
      'flightRetry': 'إعادة المحاولة',
      'flightPreviousDate': 'التاريخ السابق',
      'flightNextDate': 'التاريخ التالي',
      'flightOfferSelected': 'تم اختيار الرحلة لخطوة الحجز التالية',
      'exploreToursTitle': 'استكشف الجولات',
      'exploreToursHint': 'تجارب محلية وأماكن مخفية ومرشدون خبراء',
      'findTours': 'ابحث عن جولة',
      'placesCount': '{count}+ مكان',
      'navHome': 'الرئيسية',
      'navTrips': 'رحلاتي',
      'navMap': 'الخريطة',
      'navSaved': 'المحفوظات',
      'featuredLoadFailed': 'تعذّر تحميل الوجهات المميّزة',
      'featuredEmpty': 'لا توجد وجهات مميّزة بعد',
      'signInToSave': 'سجّل الدخول لحفظ المفضّلة',
      'signInToSaveBody':
          'أنشئ حسابًا أو سجّل الدخول للاحتفاظ بأماكنك المفضّلة.',
      'notNow': 'ليس الآن',
      'addedToFavorites': 'أُضيف إلى مفضّلتك',
      'removedFromFavorites': 'أُزيل من مفضّلتك',
      'favoriteFailed': 'تعذّر تحديث مفضّلتك',
      'comingSoon': 'قريبًا',
      'mapOpenFailed': 'تعذّر فتح تطبيق الخرائط',
      'menu': 'القائمة',
      'changeLanguage': 'تغيير اللغة',
      // --- Home screen side drawer ---
      'close': 'إغلاق',
      'services': 'الخدمات',
      'myBookings': 'حجوزاتي',
      'billingPayments': 'الفواتير/الدفع',
      'billingPaymentTitle': 'الفوترة والمدفوعات',
      'currentPaymentMethod': 'طريقة الدفع الحالية',
      'addPaymentMethod': 'إضافة طريقة دفع',
      'addPaymentMethodDescription':
          'احفظ بطاقة الخصم أو الائتمان للدفع مقابل الفنادق والرحلات الجوية وتأجير السيارات والجولات.',
      'paymentInformationEncrypted': 'معلومات الدفع الخاصة بك مشفّرة بأمان.',
      'addCard': 'إضافة بطاقة',
      'debitOrCreditCard': 'بطاقة خصم أو ائتمان',
      'secureCheckout': 'دفع آمن',
      'secureCardSetupUnavailable': 'إعداد البطاقة الآمن سيتوفر قريبًا.',
      'paymentMethodAlreadyAdded': 'هناك طريقة دفع مرتبطة بحسابك بالفعل.',
      'newCard': 'بطاقة جديدة',
      'newCardDescription': 'أضف بطاقة لإتمام حجوزاتك المستقبلية بشكل أسرع.',
      'cardDetails': 'تفاصيل البطاقة',
      'cardholderName': 'اسم حامل البطاقة',
      'cardNumber': 'رقم البطاقة',
      'expiryDate': 'تاريخ الانتهاء',
      'expiryHint': 'MM/YY',
      'cvv': 'CVV',
      'country': 'البلد',
      'yourCountry': 'بلدك',
      'zipCode': 'الرمز البريدي',
      'optional': 'اختياري',
      'saveCardForFutureBookings': 'احفظ هذه البطاقة للحجوزات المستقبلية',
      'editPaymentMethodLater':
          'يمكنك تعديل طريقة الدفع هذه أو إزالتها لاحقًا من الفوترة والدفع.',
      'requiredField': 'هذا الحقل مطلوب.',
      'invalidCardNumber': 'أدخل رقم بطاقة صالحًا.',
      'invalidExpiryDate': 'أدخل تاريخًا مستقبليًا صالحًا.',
      'invalidCvv': 'أدخل رمز CVV صالحًا.',
      'editProfile': 'تعديل الملف الشخصي',
      'editProfileSubtitle': 'حدّث صورتك واسمك الكامل.',
      'firstAndLastName': 'الاسم الأول واسم العائلة',
      'firstName': 'الاسم الأول',
      'lastName': 'اسم العائلة',
      'firstAndLastNameRequired': 'أدخل الاسم الأول واسم العائلة.',
      'saveChanges': 'حفظ التغييرات',
      'profileUpdated': 'تم تحديث ملفك الشخصي.',
      'settingsUpdateFailed': 'تعذّر تحديث هذا الإعداد. حاول مجددًا.',
      'changeEmail': 'تغيير البريد الإلكتروني',
      'changeEmailSubtitle': 'أكد كلمة مرورك ثم تحقق من البريد الجديد.',
      'confirmEmailIdentitySubtitle':
          'أدخل بريد حسابك الحالي وكلمة مرور التطبيق لتأكيد هويتك.',
      'currentEmail': 'البريد الإلكتروني الحالي',
      'newEmail': 'البريد الإلكتروني الجديد',
      'newEmailVerificationSubtitle':
          'أدخل البريد الجديد ورمز التحقق المكون من 6 أرقام الذي نرسله إليه.',
      'emailUpdated': 'تم تحديث بريدك الإلكتروني.',
      'currentPassword': 'كلمة المرور الحالية',
      'enterValidEmail': 'أدخل بريدًا إلكترونيًا صالحًا.',
      'sendVerificationLink': 'إرسال رابط التحقق',
      'emailVerificationSent':
          'تم إرسال رابط التحقق. يتغير البريد بعد الموافقة عليه.',
      'reauthenticationFailed': 'تعذّر التحقق من كلمة المرور الحالية.',
      'changePhoneNumber': 'تغيير رقم الهاتف',
      'changePhoneSubtitle': 'سنرسل رمز SMS للتحقق من الرقم.',
      'newPhoneNumber': 'رقم الهاتف الجديد',
      'phoneInternationalFormat': 'استخدم الصيغة الدولية، مثل +964…',
      'verificationCodeSent': 'تم إرسال رمز التحقق.',
      // 'verificationCode' and 'sendCode' already exist earlier in this map.
      'verifyAndSave': 'تحقق واحفظ',
      'invalidVerificationCode': 'رمز التحقق غير صالح.',
      'passwordChangeRules': 'استخدم 8 أحرف على الأقل وحرفًا كبيرًا ورمزًا.',
      'kilometers': 'كيلومترات (km)',
      'miles': 'أميال (mi)',
      'milesShort': 'mi',
      'defaultPayment': 'افتراضية',
      'debitCard': 'بطاقة خصم',
      'creditCard': 'بطاقة ائتمان',
      'kurdistanInternationalBank': 'مصرف كوردستان الدولي',
      'firstIraqiBank': 'المصرف العراقي الأول',
      'newlyAddedCard': 'البطاقة المضافة حديثًا',
      'savedCard': 'بطاقة محفوظة',
      'add': 'إضافة',
      'change': 'تغيير',
      'delete': 'حذف',
      'cancel': 'إلغاء',
      'setDefaultCard': 'تعيين البطاقة الافتراضية',
      'setDefaultCardBody': 'ستُستخدم هذه البطاقة للحجوزات الجديدة.',
      'defaultCardUpdated': 'تم تحديث البطاقة الافتراضية',
      'deleteCardTitle': 'حذف هذه البطاقة؟',
      'deleteCardBody':
          'ستتم إزالة البطاقة المنتهية بـ {last4} من طرق الدفع المحفوظة لديك. '
          'يمكنك إضافتها مرة أخرى في أي وقت.',
      'cardDeleted': 'تمت إزالة البطاقة',
      'cardAdded': 'تمت إضافة البطاقة',
      'billingSignInTitle': 'سجّل الدخول لإدارة الدفع',
      'billingSignInBody':
          'بطاقاتك المحفوظة مرتبطة بحسابك، لذا نحتاج إلى تسجيل دخولك لعرضها.',
      'photoSignInTitle': 'سجّل الدخول لإضافة صورة',
      'photoSignInBody':
          'تُحفظ صورة ملفك الشخصي في حسابك، لذا نحتاج إلى تسجيل دخولك لتغييرها.',
      'paymentHistory': 'سجل المدفوعات',
      'paid': 'مدفوع',
      'pending': 'قيد الانتظار',
      'viewReceipt': 'عرض الإيصال',
      'hotel': 'فندق',
      'flight': 'رحلة جوية',
      'car': 'سيارة',
      'tour': 'جولة',
      'mountainViewResort': 'منتجع إطلالة الجبل',
      'erbilToIstanbul': 'أربيل ← إسطنبول',
      'suvRental': 'تأجير سيارة SUV',
      'rawanduzCanyonAdventure': 'مغامرة وادي رواندز',
      'paymentDateMay24': '٢٤ مايو ٢٠٢٥',
      'paymentDateMay23': '٢٣ مايو ٢٠٢٥',
      'paymentDateMay25': '٢٥ مايو ٢٠٢٥',
      'paymentDateMay26': '٢٦ مايو ٢٠٢٥',
      'settings': 'الإعدادات',
      'settingsAccount': 'الحساب',
      'settingsChangePassword': 'تغيير كلمة المرور',
      'settingsPreferences': 'التفضيلات',
      'settingsNotifications': 'الإشعارات',
      'settingsTheme': 'المظهر',
      'settingsLanguage': 'اللغة',
      'settingsUnits': 'الوحدات',
      'settingsSecurityLegal': 'الأمان والشؤون القانونية',
      'settingsSecurityPrivacy': 'الأمان والخصوصية',
      'settingsDeleteAccount': 'حذف الحساب',
      'notificationsPermissionDenied': 'لم يتم منح إذن الإشعارات.',
      'notificationsUpdateFailed':
          'تعذّر تحديث الإشعارات. يرجى المحاولة مرة أخرى.',
      'languageEnglish': 'الإنجليزية',
      'languageKurdish': 'الكردية',
      'languageArabic': 'العربية',
      'kilometersShort': 'كم',
      'currency': 'العملة',
      'policy': 'السياسة',
      'helpSupport': 'المساعدة والدعم',
      'aboutUs': 'من نحن',
      'contactWay': 'طرق التواصل',
      'logOut': 'تسجيل الخروج',
      'guestUser': 'ضيف',
      'guestDrawerPrompt': 'سجّل الدخول لعرض ملفك الشخصي',
      'signInRequired': 'يرجى تسجيل الدخول أولاً',
      'selectCurrency': 'اختر العملة',
      'currencyUSD': 'دولار أمريكي (USD)',
      'currencyIQD': 'دينار عراقي (IQD)',
      'currencyEUR': 'يورو (EUR)',
      'currencyUpdated': 'تم تحديث العملة',
      'currencyUpdateFailed': 'تعذّر تحديث العملة. يرجى المحاولة مرة أخرى.',
      'logOutFailed': 'تعذّر تسجيل خروجك. يرجى المحاولة مرة أخرى.',
      'profilePhotoUpdated': 'تم تحديث صورة الملف الشخصي',
      // --- Explore Nature screen ---
      'filterHiking': 'المشي الجبلي',
      'filterBeach': 'الشاطئ',
      'filterSunsetView': 'منظر الغروب',
      'filterCustomize': 'تخصيص',
      'locationLabel': 'الموقع:',
      'distanceLabel': 'المسافة:',
      'distanceFromCurrentLocation': '{distance} من موقعك الحالي',
      'natureSpotsLoadFailed': 'تعذّر تحميل الأماكن. يرجى المحاولة مرة أخرى.',
      'natureSpotsEmpty': 'لا توجد أماكن تطابق هذه الفلاتر بعد',
      'highlightedEmpty': 'لا توجد أماكن مميّزة بعد',
      'clearFilters': 'مسح الفلاتر',
      'aboutThisPlace': 'حول هذا المكان',
      'placeNameLabel': 'الاسم:',
      'placeDistanceLabel': 'المسافة:',
      'suggestedStaysNearby': 'أماكن إقامة مقترحة قريبة',
      'stayDistanceAway': 'يبعد {distance} كم',
      'weather': 'الطقس',
      'weatherUnavailable': 'الطقس غير متاح الآن',
      'sunny': 'مشمس',
      'partlyCloudy': 'غائم جزئياً',
      'cloudy': 'غائم',
      'rainy': 'ممطر',
      'snowy': 'مثلج',
      'ratingsAndReviews': 'التقييمات والمراجعات',
      'basedOnReviews': 'بناءً على {count} مراجعة',
      'writeReviewPrompt': 'هل زرت هذا المكان؟',
      'writeReviewHint': 'اضغط هنا لتقييم زيارتك وكتابة تعليق',
      'reviewsLoadFailed': 'تعذّر تحميل مراجعات الزوار',
      'noReviewsYet': 'لا توجد مراجعات بعد. كن أول من يشارك زيارته.',
      'seeAllReviews': 'عرض كل المراجعات',
      'openPlaceMap': 'فتح خريطة المكان',
      'reviewsCount': '{count} تقييم',
      // --- Reviews & Ratings screen ---
      'reviewsAndRatings': 'المراجعات والتقييمات',
      'averageRating': 'متوسط التقييم',
      'outOfTen': '/ ١٠',
      'allReviews': 'كل المراجعات',
      'sortMostRecent': 'الأحدث',
      'sortHighestRated': 'الأعلى تقييماً',
      'sortLowestRated': 'الأقل تقييماً',
      'sortMostHelpful': 'الأكثر إفادة',
      'sortReviewsBy': 'ترتيب المراجعات حسب',
      'oneReview': 'مراجعة واحدة',
      'noRatingsYet': 'لم يُقيَّم بعد',
      'addYourReview': 'أضف مراجعتك',
      'yourRating': 'تقييمك',
      'reviewCommentHint': 'أخبر الآخرين عن تجربتك…',
      'postReview': 'نشر المراجعة',
      'updateReview': 'تحديث المراجعة',
      'reviewPosted': 'شكراً — تم نشر مراجعتك',
      'reviewUpdated': 'تم تحديث مراجعتك',
      'reviewPostFailed': 'تعذّر نشر مراجعتك. يرجى المحاولة مرة أخرى.',
      'reviewRatingRequired': 'اختر عدد النجوم أولاً',
      'reviewCommentTooShort': 'اكتب 3 أحرف على الأقل',
      'reviewCommentTooLong': 'اجعل مراجعتك أقل من 1000 حرف',
      'reviewSignInTitle': 'سجّل الدخول لكتابة مراجعة',
      'reviewSignInBody':
          'ترتبط المراجعات بحسابك، ليعرف الجميع من قام بالزيارة.',
      'yourReviewLabel': 'مراجعتك',
      'editYourReview': 'تعديل مراجعتك',
      'helpfulVote': 'وسم هذه المراجعة بأنها مفيدة',
      'helpfulVoteRemove': 'إزالة تصويتك بأنها مفيدة',
      'helpfulSignInBody': 'سجّل الدخول لتخبر الآخرين أن المراجعة كانت مفيدة.',
      'helpfulFailed': 'تعذّر حفظ تصويتك. يرجى المحاولة مرة أخرى.',
      'loadMoreReviews': 'عرض مراجعات أكثر',
      'reviewJustNow': 'الآن',
      'reviewHoursAgo': 'قبل {count} ساعات',
      'reviewOneHourAgo': 'قبل ساعة',
      'reviewDaysAgo': 'قبل {count} أيام',
      'reviewOneDayAgo': 'قبل يوم',
      'reviewWeeksAgo': 'قبل {count} أسابيع',
      'reviewOneWeekAgo': 'قبل أسبوع',
      'reviewMonthsAgo': 'قبل {count} أشهر',
      'reviewOneMonthAgo': 'قبل شهر',
      'reviewYearsAgo': 'قبل {count} سنوات',
      'reviewOneYearAgo': 'قبل سنة',
      // --- Customize Filters screen ---
      'customizeFilters': 'تخصيص الفلاتر',
      'customizeFiltersSubtitle': 'اعثر على أماكن تناسب رحلتك',
      'filtersSelected': 'تم اختيار {count} فلاتر',
      'oneFilterSelected': 'تم اختيار فلتر واحد',
      'noFiltersSelected': 'لم يتم اختيار أي فلتر',
      'resetAll': 'إعادة تعيين الكل',
      'placeType': 'نوع المكان',
      'facilitiesAmenities': 'المرافق والخدمات',
      'showPlaces': 'عرض {count} مكان',
      'showOnePlace': 'عرض مكان واحد',
      'showNoPlaces': 'لا توجد أماكن مطابقة',
      'placeTypeForest': 'غابة',
      'placeTypeMountain': 'جبل',
      'placeTypeCanyon': 'وادٍ',
      'placeTypePark': 'حديقة',
      'placeTypeLake': 'بحيرة',
      'placeTypeWaterfall': 'شلال',
      'placeTypeRiver': 'نهر',
      'placeTypeMuseum': 'متحف',
      'amenityParking': 'موقف سيارات',
      'amenityRestrooms': 'دورات مياه',
      'amenityRestaurants': 'مطاعم',
      'amenityCafes': 'مقاهٍ',
      'amenityMobileSignal': 'تغطية الهاتف',
      'amenityLodgingNearby': 'إقامة قريبة',
      'amenityAtmNearby': 'صرّاف آلي قريب',
      // --- Policy screen ---
      'policyOfApp': 'سياسة التطبيق',
      'policyOfAppSubtitle': 'اطّلع على إرشاداتنا وسياساتنا لتعرف كيف نحميك.',
      'policyPrivacyTitle': 'سياسة الخصوصية',
      'policyPrivacySubtitle': 'كيف نتعامل مع بياناتك',
      'policyTermsTitle': 'الشروط والأحكام',
      'policyTermsSubtitle': 'قواعد استخدام التطبيق',
      'policyCancellationTitle': 'الإلغاء واسترداد الأموال',
      'policyCancellationSubtitle': 'تغيير الحجوزات أو إلغاؤها',
      'policyPaymentTitle': 'سياسة الدفع',
      'policyPaymentSubtitle': 'الطرق والعملة والرسوم',
      'policyLiabilityTitle': 'المسؤولية وإخلاء المسؤولية',
      'policyLiabilitySubtitle': 'حدود مسؤوليتنا',
      'policyContactTitle': 'التواصل والشكاوى',
      'policyContactSubtitle': 'تواصل مع الدعم',
      'policyAccountDeletionTitle': 'حذف الحساب والبيانات',
      'policyAccountDeletionSubtitle': 'احذف حسابك وبياناتك',
      'policyLoadFailed': 'تعذّر تحميل هذه السياسة. يرجى المحاولة مرة أخرى.',
      // --- Help & Support screen ---
      'helpAndSupport': 'المساعدة والدعم',
      'helpAccountTitle': 'الحساب وتسجيل الدخول',
      'helpAccountPreview': 'كيف أغيّر بريدي الإلكتروني أو ...',
      'helpBookingsTitle': 'الحجوزات والتأكيد',
      'helpBookingsPreview': 'ما هو الرقم المرجعي لحجزي ...',
      'helpPaymentsTitle': 'المدفوعات والاسترداد',
      'helpPaymentsPreview': 'فشلت عملية الدفع لكنني ...',
      'helpCancellationTitle': 'الإلغاء والتعديلات',
      'helpCancellationPreview': 'هل يمكنني تعديل حجزي بدلًا من ...',
      'helpFlightsTitle': 'الرحلات الجوية',
      'helpFlightsPreview': 'ما هو وزن الأمتعة المسموح ...',
      'helpStaysTitle': 'أماكن الإقامة (الفنادق)',
      'helpStaysPreview': 'ما هي مواعيد تسجيل الدخول و ...',
      'helpCarRentalTitle': 'تأجير السيارات',
      'helpCarRentalPreview': 'ما المستندات التي أحتاجها لـ ...',
      'helpToursTitle': 'الجولات والطبيعة (استكشاف)',
      'helpToursPreview': 'ماذا يحدث إذا كان الطقس ...',
      'helpSafetyTitle': 'السلامة ومعلومات السفر',
      'helpSafetyPreview': 'ما هي أرقام الطوارئ في ...',
      'helpContactTitle': 'ما زلت بحاجة إلى مساعدة؟ تواصل معنا',
      'helpContactPreview': 'تواصل مع فريق الدعم لدينا ...',
      // --- My Bookings screen ---
      'bookingsFilterAll': 'الكل',
      'bookingsFilterHotels': 'الفنادق',
      'bookingsFilterCars': 'السيارات',
      'bookingsFilterFlights': 'الرحلات',
      'bookingsFilterTours': 'الجولات',
      'bookingsSegmentUpcoming': 'القادمة',
      'bookingsSegmentPast': 'السابقة',
      'bookingsSegmentCancelled': 'الملغاة',
      'bookingTypeHotel': 'فندق',
      'bookingTypeCar': 'تأجير سيارة',
      'bookingTypeFlight': 'رحلة',
      'bookingTypeTour': 'جولة',
      'bookingStatusConfirmed': 'مؤكد',
      'bookingStatusPending': 'قيد الانتظار',
      'bookingStatusCancelled': 'ملغى',
      'bookingStatusCompleted': 'مكتمل',
      'bookingStatusUpcoming': 'قادم',
      'cabinEconomy': 'اقتصادية',
      'cabinPremiumEconomy': 'اقتصادية مميزة',
      'cabinBusiness': 'رجال الأعمال',
      'cabinFirst': 'الأولى',
      'bookingCheckIn': 'تسجيل الدخول',
      'bookingCheckOut': 'تسجيل الخروج',
      'bookingGuests': 'الضيوف',
      'bookingTravelers': 'المسافرون',
      'bookingDriver': 'السائق',
      'bookingTraveler': 'مسافر',
      'bookingSeat': 'المقعد',
      'bookingDuration': 'المدة',
      'bookingId': 'رقم الحجز',
      'bookingPickup': 'الاستلام',
      'bookingDropoff': 'التسليم',
      'bookingTotalPaid': 'إجمالي المدفوع',
      'bookingActionCheckIn': 'تسجيل الدخول',
      'bookingActionOpenTicket': 'فتح التذكرة',
      'bookingActionPickupInfo': 'معلومات الاستلام',
      'bookingActionTourDetails': 'تفاصيل الجولة',
      'bookingActionViewDetails': 'عرض التفاصيل',
      'bookingAdultsCount': '{count} بالغين',
      'bookingAdultCount': '{count} بالغ',
      'bookingHours': '{count} ساعات',
      'bookingsLoadFailed': 'تعذر تحميل حجوزاتك',
      'bookingsEmptyTitle': 'لا توجد حجوزات بعد',
      'bookingsEmptyBody': 'عند حجز فندق أو رحلة أو سيارة أو جولة، ستظهر هنا.',
      'bookingsEmptyUpcoming': 'لا توجد حجوزات قادمة',
      'bookingsEmptyPast': 'لا توجد حجوزات سابقة',
      'bookingsEmptyCancelled': 'لا توجد حجوزات ملغاة',
      'bookingsEmptyFiltered': 'لا شيء يطابق هذا الفلتر. جرّب فئة أخرى.',
      'bookingsSignInTitle': 'سجّل الدخول لعرض حجوزاتك',
      'bookingsSignInBody':
          'حجوزاتك مرتبطة بحسابك، لذا نحتاج إلى تسجيل دخولك لعرضها.',
      'bookingsStartExploring': 'ابدأ الاستكشاف',
      'month1': 'يناير',
      'month2': 'فبراير',
      'month3': 'مارس',
      'month4': 'أبريل',
      'month5': 'مايو',
      'month6': 'يونيو',
      'month7': 'يوليو',
      'month8': 'أغسطس',
      'month9': 'سبتمبر',
      'month10': 'أكتوبر',
      'month11': 'نوفمبر',
      'month12': 'ديسمبر',
      'timeAm': 'ص',
      'timePm': 'م',
      // --- Explore Tours screen ---
      'toursSearchHint': 'ابحث عن جولة أو موقع',
      'toursDateHint': 'تاريخ الجولة',
      'toursApply': 'تطبيق',
      'clearDate': 'مسح التاريخ',
      'clearSearch': 'مسح البحث',
      'trendingTours': 'الجولات الرائجة',
      'toursLoadFailed': 'تعذر تحميل الجولات',
      'toursEmpty': 'لا توجد جولات تطابق بحثك',
      'toursHighlightedEmpty': 'لا توجد جولات مميزة بعد',
      'tourDayTravel': 'رحلة {count} يوم',
      'tourDaysTravel': 'رحلة {count} أيام',
      'tourPerPerson': 'للشخص الواحد',
      'tourPerPersonBadge': 'للشخص الواحد',
      'tourFeatureCamping': 'تخييم',
      'tourFeatureHiking': 'المشي الجبلي',
      'tourFeatureGuide': 'مرشد',
      'tourFeatureFood': 'طعام',
      'tourFeatureSwimming': 'سباحة',
      'tourFeatureCampfire': 'نار المخيم',
      'tourFeatureTransport': 'نقل',
      'tourFeaturePhotography': 'تصوير',
      'tourFeatureActivity': 'أنشطة',
      'tourFeatureWifi': 'واي فاي',
      'tourFeatureElectricity': 'كهرباء',
      'tourFeatureTent': 'خيمة',
      'tourReviewCount': '{count} تقييمات',
      'tourReviewCountOne': 'تقييم واحد',
      'tourNoReviews': 'لا توجد تقييمات بعد',
      'tourSpotsLeft': 'بقي {count} مقاعد فقط',
      'tourSpotsLeftOne': 'بقي مقعد واحد فقط',
      'tourTravellers': 'المسافرون',
      'tourTravellerCount': '{count} مسافرين',
      'tourTravellerCountOne': 'مسافر واحد',
      'tourTotalFor': 'الإجمالي {price}',
      'tourCancelFree24h': 'إلغاء مجاني حتى 24 ساعة قبل الموعد',
      'tourCancelFree48h': 'إلغاء مجاني حتى 48 ساعة قبل الموعد',
      'tourCancelFree7d': 'إلغاء مجاني حتى 7 أيام قبل الموعد',
      'tourCancelNonRefundable': 'غير قابل للاسترداد',
      'tourGuideLanguages': 'لغات المرشد',
      'tourLanguageEnglish': 'الإنجليزية',
      'tourLanguageKurdish': 'الكردية',
      'tourLanguageArabic': 'العربية',
      'tourLanguageTurkish': 'التركية',
      'tourLanguagePersian': 'الفارسية',
      'toursSortLabel': 'الترتيب',
      'toursSortSoonest': 'الأقرب موعداً',
      'toursSortPriceLow': 'السعر: من الأقل للأعلى',
      'toursSortPriceHigh': 'السعر: من الأعلى للأقل',
      'toursSortTopRated': 'الأعلى تقييماً',
      'toursSortNearest': 'الأقرب إليّ',
      'toursRefine': 'تصفية',
      'toursIncludes': 'يشمل',
      'toursDateRangeHint': 'تواريخ الجولة',
      'toursPriceApprox':
          'يتم تحويل الأسعار بسعر صرف إرشادي وتظهر تقريبية. '
          'يتم تحصيل المبلغ بعملة المشغّل نفسها.',
      'toursClearAll': 'مسح الكل',
      'tourDetails': 'تفاصيل الجولة',
      'tourFacilities': 'المرافق',
      'tourMap': 'الخريطة',
      'tourCheckout': 'ملخص السعر',
      'tourPerson': 'الأشخاص',
      'tourTransportationBus': 'حافلة النقل',
      'tourOptional': 'اختياري',
      'tourTotalPrice': 'السعر الإجمالي',
      'tourReserveInsight': 'احجز الجولة',
      'tourTransportUnavailable': 'النقل بالحافلة غير متاح لهذه الجولة',
      'tourWeatherUnavailable': 'معلومات الطقس غير متاحة',
      'tourMapUnavailable': 'الخريطة غير متاحة',
      'tourWriteReviewPrompt': 'هل شاركت في هذه الجولة؟',
      'tourNoReviewsYet': 'لا توجد مراجعات بعد. كن أول من يشارك تجربة الجولة.',
      'tourReviewSignInBody':
          'ترتبط مراجعات الجولات بحسابك حتى يثق المسافرون بمن شارك فيها.',
      'bookingStepTravelerInfo': 'بيانات المسافر',
      'bookingStepPayment': 'الدفع',
      'bookingStepConfirmation': 'التأكيد',
      'travelerInformation': 'بيانات المسافر',
      'travelerInformationHint': 'يرجى إدخال بيانات جميع المسافرين',
      'contactPerson': 'شخص الاتصال',
      'travelersLabel': 'المسافرون',
      'travelerNumbered': 'مسافر',
      'dateOfBirthHint': 'تاريخ الميلاد',
      'leadTraveler': 'المسافر الرئيسي',
      'leadTravelerHint': 'يصدر الحجز باسم هذا المسافر',
      'informationSecure': 'بياناتك آمنة ومشفرة',
      'continueToPayment': 'المتابعة إلى الدفع',
      'selectDialCode': 'اختر رمز الدولة',
      'travelerInfoIncomplete': 'يرجى إكمال اسم وتاريخ ميلاد كل مسافر.',
      'contactIncomplete': 'يرجى إدخال اسم وبريد إلكتروني ورقم هاتف صحيح.',
      'travelerTooYoung':
          'يجب أن يكون عمر كل مسافر في هذه الجولة {age} عامًا أو أكثر.',
      'travelerFutureBirthDate': 'لا يمكن أن يكون تاريخ الميلاد في المستقبل.',
      'noPlacesLeft': 'اكتمل حجز هذه الرحلة.',
      'onlyPlacesLeft': 'بقيت {count} أماكن فقط في هذه الرحلة.',
      'reserveSignInTitle': 'سجّل الدخول للحجز',
      'reserveSignInBody': 'يرتبط الحجز بحسابك حتى تجده لاحقًا ونعرف بمن نتصل.',
      'paymentDetails': 'تفاصيل الدفع',
      'paymentDetailsHint': 'أكمل الدفع لتأكيد الحجز',
      'bookingSummary': 'ملخص الحجز',
      'paymentMethodLabel': 'طريقة الدفع',
      'mastercardVisa': 'ماستركارد / فيزا',
      'totalLabel': 'الإجمالي',
      'selectPaymentMethod': 'اختر طريقة الدفع',
      'cardEntryNotLive':
          'الدفع بالبطاقة غير مفعّل بعد. لم يتم إرسال بيانات بطاقتك أو حفظها.',
      'paymentIncompleteCard':
          'يرجى إدخال رقم البطاقة وتاريخ الانتهاء ورمز CVV.',
      'paymentNoMethod': 'يرجى اختيار طريقة الدفع.',
      'useSavedCard': 'استخدم هذه البطاقة',
      // --- Checkout step 3 (Review & Confirm) ---
      'reviewConfirmTitle': 'المراجعة والتأكيد',
      'reviewConfirmHint': 'يرجى مراجعة تفاصيل حجزك قبل التأكيد.',
      'travelersInformation': 'معلومات المسافرين',
      'priceBreakdown': 'تفاصيل السعر',
      'travelerFee': 'رسوم المسافر',
      'priceEachTimes': '{count} × {price}',
      'reviewAgreeTerms': 'أوافق على {terms} و{policy}.',
      'reviewTermsLink': 'شروط الخدمة',
      'reviewPolicyLink': 'سياسة التطبيق',
      'reviewMustAgree':
          'يرجى الموافقة على شروط الخدمة وسياسة التطبيق للمتابعة.',
      'confirmAndPay': 'التأكيد والدفع {price}',
      'confirmPayNotLive':
          'الدفع غير مفعّل بعد، لذلك لم يتم خصم أي مبلغ ولم يتم إنشاء أي حجز.',
    },
  };

  String _t(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;

  String get chooseYourLanguage => _t('chooseYourLanguage');
  String get selectLanguageToContinue => _t('selectLanguageToContinue');
  String get logIn => _t('logIn');
  String get email => _t('email');
  String get password => _t('password');
  String get forgetPassword => _t('forgetPassword');
  String get forgetPasswordSubtitle => _t('forgetPasswordSubtitle');
  String get phoneNumber => _t('phoneNumber');
  String get emailAddress => _t('emailAddress');
  String get sendCode => _t('sendCode');
  String get selectContactMethod => _t('selectContactMethod');
  String get orLabel => _t('orLabel');
  String get dontHaveAccount => _t('dontHaveAccount');
  String get registerNow => _t('registerNow');
  String get continueAsGuest => _t('continueAsGuest');
  String get emailRequired => _t('emailRequired');
  String get emailInvalid => _t('emailInvalid');
  String get passwordRequired => _t('passwordRequired');

  // --- Verification Code screen ---
  String get verificationCode => _t('verificationCode');
  String get didntReceiveCode => _t('didntReceiveCode');
  String get resendNow => _t('resendNow');
  String get verify => _t('verify');
  String get codeIncomplete => _t('codeIncomplete');
  String get codeIncorrect => _t('codeIncorrect');
  String get codeExpired => _t('codeExpired');
  String get tooManyAttempts => _t('tooManyAttempts');
  String get codeResentPhone => _t('codeResentPhone');
  String get codeResentEmail => _t('codeResentEmail');
  String get sendCodeFailed => _t('sendCodeFailed');
  String get networkError => _t('networkError');

  /// The raw subtitle template, still containing the literal `{dest}`
  /// placeholder. The screen splits on it so the destination can be drawn
  /// bold (and left-to-right) inside an otherwise right-to-left sentence.
  String get verificationSubtitleTemplate => _t('verificationSubtitle');

  /// Splits [verificationSubtitleTemplate] into the text before and after
  /// `{dest}`. Returns `(before, after)`.
  (String, String) verificationSubtitleParts() =>
      _splitOnDest(verificationSubtitleTemplate);

  String resendIn(int seconds) =>
      _t('resendIn').replaceAll('{seconds}', '$seconds');

  // --- Register screen ---
  String get register => _t('register');
  String get fullName => _t('fullName');
  String get age => _t('age');
  String get gender => _t('gender');
  String get genderMale => _t('genderMale');
  String get genderFemale => _t('genderFemale');
  String get genderOther => _t('genderOther');
  String get genderOptional => _t('genderOptional');
  String get alreadyHaveAccount => _t('alreadyHaveAccount');
  String get logInHere => _t('logInHere');
  String get passwordHint => _t('passwordHint');
  String get acceptTerms => _t('acceptTerms');
  String get termsRequired => _t('termsRequired');
  String get fullNameRequired => _t('fullNameRequired');
  String get fullNameTooShort => _t('fullNameTooShort');
  String get dateOfBirthRequired => _t('dateOfBirthRequired');
  String get mustBe18 => _t('mustBe18');
  String get phoneRequired => _t('phoneRequired');
  String get phoneInvalid => _t('phoneInvalid');
  String get selectCountryCode => _t('selectCountryCode');
  String get accountCreated => _t('accountCreated');
  String get registerFailed => _t('registerFailed');
  String get emailInUse => _t('emailInUse');
  String get phoneInUse => _t('phoneInUse');

  // --- Register Complete screen ---
  String get registerComplete => _t('registerComplete');
  String get registerCompleteSubtitle => _t('registerCompleteSubtitle');
  String get explore => _t('explore');
  String get onboardingTitleLine1 => _t('onboardingTitleLine1');
  String get onboardingTitleLine2 => _t('onboardingTitleLine2');
  String get onboardingBody1 => _t('onboardingBody1');
  String get onboardingTitle2Line1 => _t('onboardingTitle2Line1');
  String get onboardingTitle2Line2 => _t('onboardingTitle2Line2');
  String get onboardingBody2 => _t('onboardingBody2');
  String get onboardingTitle3Line1 => _t('onboardingTitle3Line1');
  String get onboardingTitle3Line2 => _t('onboardingTitle3Line2');
  String get onboardingBody3 => _t('onboardingBody3');
  String get onboardingNext => _t('onboardingNext');

  // --- Account Setup screen ---
  String get accountSetup => _t('accountSetup');
  String get accountSetupSubtitle => _t('accountSetupSubtitle');
  String get username => _t('username');
  String get createAccount => _t('createAccount');
  String get chooseFromGallery => _t('chooseFromGallery');
  String get takePhoto => _t('takePhoto');
  String get removePhoto => _t('removePhoto');
  String get usernameRequired => _t('usernameRequired');
  String get usernameTooShort => _t('usernameTooShort');
  String get imageTooLarge => _t('imageTooLarge');
  String get imagePickFailed => _t('imagePickFailed');
  String get profileSaveFailed => _t('profileSaveFailed');
  String get cameraPermissionDenied => _t('cameraPermissionDenied');
  String get galleryPermissionDenied => _t('galleryPermissionDenied');

  // --- Terms of Service screen ---
  String get termsOfService => _t('termsOfService');
  String get termsAgreeCheckbox => _t('termsAgreeCheckbox');
  String get continueLabel => _t('continueLabel');
  String get termsLoadFailed => _t('termsLoadFailed');
  String get tryAgain => _t('tryAgain');
  String get termsNotReviewed => _t('termsNotReviewed');

  String lastUpdated(String date) =>
      _t('lastUpdated').replaceAll('{date}', date);

  /// Subtitle for the Verification Code screen when it is verifying a phone
  /// number during registration, rather than resetting a password.
  String get verifyNumberSubtitleTemplate => _t('verifyNumberSubtitle');

  /// Splits [verifyNumberSubtitleTemplate] around `{dest}` — see
  /// [verificationSubtitleParts].
  (String, String) verifyNumberSubtitleParts() =>
      _splitOnDest(verifyNumberSubtitleTemplate);

  /// Title and subtitle for the registration **email** verification step.
  String get verifyEmailTitle => _t('verifyEmailTitle');
  String get verifyEmailSubtitleTemplate => _t('verifyEmailSubtitle');
  String get emailVerified => _t('emailVerified');

  /// Splits [verifyEmailSubtitleTemplate] around `{dest}`.
  (String, String) verifyEmailSubtitleParts() =>
      _splitOnDest(verifyEmailSubtitleTemplate);

  static (String, String) _splitOnDest(String template) {
    const marker = '{dest}';
    final index = template.indexOf(marker);
    if (index < 0) return (template, '');
    return (
      template.substring(0, index),
      template.substring(index + marker.length),
    );
  }

  // --- Reset Password screen ---
  String get resetPassword => _t('resetPassword');
  String get resetPasswordSubtitle => _t('resetPasswordSubtitle');
  String get newPassword => _t('newPassword');
  String get confirmPassword => _t('confirmPassword');
  String get updatePassword => _t('updatePassword');
  String get passwordTooShort => _t('passwordTooShort');
  String get passwordNeedsUppercase => _t('passwordNeedsUppercase');
  String get passwordNeedsLowercase => _t('passwordNeedsLowercase');
  String get passwordNeedsSpecial => _t('passwordNeedsSpecial');
  String get confirmPasswordRequired => _t('confirmPasswordRequired');
  String get passwordsDontMatch => _t('passwordsDontMatch');
  String get passwordUpdated => _t('passwordUpdated');
  String get passwordUpdateFailed => _t('passwordUpdateFailed');
  String get passwordTooWeak => _t('passwordTooWeak');
  String get sessionExpired => _t('sessionExpired');

  // --- Home screen ---
  String get dearUser => _t('dearUser');
  String get whereWouldYouLikeToGo => _t('whereWouldYouLikeToGo');
  String get planYourJourney => _t('planYourJourney');
  String get exploreNature => _t('exploreNature');
  String get exploreNatureHint => _t('exploreNatureHint');
  String get whereToStay => _t('whereToStay');
  String get whereToStayHint => _t('whereToStayHint');
  String get hotelLocation => _t('hotelLocation');
  String get hotelLocationHint => _t('hotelLocationHint');
  String get hotelRecentSearches => _t('hotelRecentSearches');
  String get hotelDate => _t('hotelDate');
  String get hotelCheckIn => _t('hotelCheckIn');
  String get hotelCheckOut => _t('hotelCheckOut');
  String get hotelGuests => _t('hotelGuests');
  String get hotelAdult => _t('hotelAdult');
  String get hotelChild => _t('hotelChild');
  String get hotelRoom => _t('hotelRoom');
  String get hotelBed => _t('hotelBed');
  String get hotelOptions => _t('hotelOptions');
  String hotelOptionsSelected(int count) => count == 0
      ? _t('hotelNoOptions')
      : count == 1
      ? _t('hotelOneOption')
      : _t('hotelManyOptions').replaceAll('{count}', '$count');
  String get hotelPool => _t('hotelPool');
  String get hotelBar => _t('hotelBar');
  String get hotelRestaurant => _t('hotelRestaurant');
  String get hotelGym => _t('hotelGym');
  String get hotelParking => _t('hotelParking');
  String get hotelFreeWifi => _t('hotelFreeWifi');
  String get hotelBeach => _t('hotelBeach');
  String get hotelMoreOptions => _t('hotelMoreOptions');
  String get hotelSearch => _t('hotelSearch');
  String get hotelTrending => _t('hotelTrending');
  String get hotelPerNight => _t('hotelPerNight');
  String hotelDistanceFromCenter(double distance) => _t(
    'hotelDistanceFromCenter',
  ).replaceAll('{distance}', distance.toStringAsFixed(1));
  String hotelGuestSummary(int adults, int children, int rooms, int beds) {
    String count(String singular, String plural, int value) =>
        _t(value == 1 ? singular : plural).replaceAll('{count}', '$value');
    final adultText = count(
      'hotelAdultCountOne',
      'hotelAdultCountMany',
      adults,
    );
    final bedText = count('hotelBedCountOne', 'hotelBedCountMany', beds);
    if (children == 0 && rooms == 1) {
      return '$adultText, $bedText';
    }
    final childText = count(
      'hotelChildCountOne',
      'hotelChildCountMany',
      children,
    );
    final roomText = count('hotelRoomCountOne', 'hotelRoomCountMany', rooms);
    return '$adultText, $childText, $roomText, $bedText';
  }

  String get hotelDestinationRequired => _t('hotelDestinationRequired');
  String get hotelInvalidDates => _t('hotelInvalidDates');
  String get hotelPreviewData => _t('hotelPreviewData');
  String hotelCarouselPosition(int current, int total) => _t(
    'hotelCarouselPosition',
  ).replaceAll('{current}', '$current').replaceAll('{total}', '$total');
  String hotelStarClassification(int count) =>
      _t('hotelStarClassification').replaceAll('{count}', '$count');
  String hotelReviewScore(double score) =>
      _t('hotelReviewScore').replaceAll('{score}', score.toStringAsFixed(1));
  String hotelIncrease(String name) =>
      _t('hotelIncrease').replaceAll('{name}', name);
  String hotelDecrease(String name) =>
      _t('hotelDecrease').replaceAll('{name}', name);

  // --- Hotel Details page ---
  String get hotelDetails => _t('hotelDetails');
  String get hotelDetailNotFound => _t('hotelDetailNotFound');
  String get hotelDetailLoadFailed => _t('hotelDetailLoadFailed');
  String hotelGalleryPosition(int current, int total) => _t(
    'hotelGalleryPosition',
  ).replaceAll('{current}', '$current').replaceAll('{total}', '$total');
  String hotelGalleryImage(int current, int total) => _t(
    'hotelGalleryImage',
  ).replaceAll('{current}', '$current').replaceAll('{total}', '$total');
  String get hotelChange => _t('hotelChange');
  String get hotelUpdateStay => _t('hotelUpdateStay');
  String get hotelUpdateStayApply => _t('hotelUpdateStayApply');
  String get hotelStayUpdated => _t('hotelStayUpdated');
  String get hotelFacilities => _t('hotelFacilities');
  String get hotelAllFacilities => _t('hotelAllFacilities');
  String get hotelNoFacilities => _t('hotelNoFacilities');
  String get hotelSeeAll => _t('hotelSeeAll');
  String get hotelReviews => _t('hotelReviews');
  String hotelReviewCount(int count) => _t(
    count == 1 ? 'hotelReviewCountOne' : 'hotelReviewCountMany',
  ).replaceAll('{count}', '$count');
  String get hotelCleanliness => _t('hotelCleanliness');
  String get hotelComfort => _t('hotelComfort');
  String get hotelService => _t('hotelService');
  String get hotelStaff => _t('hotelStaff');
  String get hotelValue => _t('hotelValue');
  String get hotelMap => _t('hotelMap');
  String get hotelMapUnavailable => _t('hotelMapUnavailable');
  String get hotelNearby => _t('hotelNearby');
  String get hotelNearbyEmpty => _t('hotelNearbyEmpty');
  String get hotelNearbyAll => _t('hotelNearbyAll');

  /// The trailing text on a Nearby row. Falls back to the distance alone when
  /// the source has no travel time, rather than estimating one.
  String hotelNearbyDistance(double kilometres, int? minutes) {
    final distance = kilometres.toStringAsFixed(kilometres < 10 ? 1 : 0);
    if (minutes == null) {
      return _t('hotelNearbyDistance').replaceAll('{distance}', distance);
    }
    return _t(
      'hotelNearbyDistanceWithTime',
    ).replaceAll('{minutes}', '$minutes').replaceAll('{distance}', distance);
  }

  String get hotelRatingsAndComments => _t('hotelRatingsAndComments');
  String get hotelSelectRoom => _t('hotelSelectRoom');
  String get hotelChooseRoom => _t('hotelChooseRoom');
  String get hotelMockNotice => _t('hotelMockNotice');
  String get hotelNoRooms => _t('hotelNoRooms');
  String get hotelChangeDates => _t('hotelChangeDates');
  String get hotelBackToHotel => _t('hotelBackToHotel');
  String get hotelSeeRoomDetails => _t('hotelSeeRoomDetails');
  String hotelMaximumGuests(int count) =>
      _t('hotelMaximumGuests').replaceAll('{count}', '$count');
  String get hotelReserve => _t('hotelReserve');
  String hotelPriceForNights(int count) =>
      _t('hotelPriceForNights').replaceAll('{count}', '$count');
  String get hotelRechecking => _t('hotelRechecking');
  String get hotelCompleteBooking => _t('hotelCompleteBooking');
  String get hotelGuestDetails => _t('hotelGuestDetails');
  String get hotelSpecialRequestsHint => _t('hotelSpecialRequestsHint');
  String get hotelStripePreview => _t('hotelStripePreview');
  String get hotelFibPreview => _t('hotelFibPreview');
  String get hotelMockPaymentNotice => _t('hotelMockPaymentNotice');
  String get hotelRoomSubtotal => _t('hotelRoomSubtotal');
  String get hotelBookingConsent => _t('hotelBookingConsent');
  String get hotelConfirmMockBooking => _t('hotelConfirmMockBooking');
  String get hotelMockBookingComplete => _t('hotelMockBookingComplete');
  String get hotelMockBookingCompleteBody => _t('hotelMockBookingCompleteBody');
  String get hotelViewReservations => _t('hotelViewReservations');
  String get hotelGuestRequired => _t('hotelGuestRequired');
  String get hotelConsentRequired => _t('hotelConsentRequired');
  String get hotelRateUnavailable => _t('hotelRateUnavailable');
  String get hotelPropertyPolicies => _t('hotelPropertyPolicies');
  String get hotelPolicyCheckInFrom => _t('hotelPolicyCheckInFrom');
  String get hotelPolicyCheckOutUntil => _t('hotelPolicyCheckOutUntil');
  String get hotelPolicyChildren => _t('hotelPolicyChildren');
  String get hotelPolicyCribs => _t('hotelPolicyCribs');
  String get hotelPolicyExtraBeds => _t('hotelPolicyExtraBeds');
  String get hotelPolicyAgeRestriction => _t('hotelPolicyAgeRestriction');
  String hotelPolicyMinimumAge(int age) =>
      _t('hotelPolicyMinimumAge').replaceAll('{age}', '$age');
  String get hotelPolicyPets => _t('hotelPolicyPets');
  String get hotelPolicySmoking => _t('hotelPolicySmoking');
  String get hotelPolicyPayment => _t('hotelPolicyPayment');
  String get hotelPolicySpecialRequests => _t('hotelPolicySpecialRequests');
  String hotelPolicySpecialRequestsAllowed(bool allowed) => _t(
    allowed ? 'hotelPolicySpecialRequestsYes' : 'hotelPolicySpecialRequestsNo',
  );
  String get hotelPolicyAccessibility => _t('hotelPolicyAccessibility');
  String get hotelFacilityGeneral => _t('hotelFacilityGeneral');
  String get hotelFacilityInternet => _t('hotelFacilityInternet');
  String get hotelFacilityParking => _t('hotelFacilityParking');
  String get hotelFacilityFoodAndDrink => _t('hotelFacilityFoodAndDrink');
  String get hotelFacilityWellness => _t('hotelFacilityWellness');
  String get hotelFacilityPool => _t('hotelFacilityPool');
  String get hotelFacilityTransportation => _t('hotelFacilityTransportation');
  String get hotelFacilityRoom => _t('hotelFacilityRoom');
  String get hotelFacilityFamily => _t('hotelFacilityFamily');
  String get hotelFacilityAccessibility => _t('hotelFacilityAccessibility');
  String get hotelFacilityBusiness => _t('hotelFacilityBusiness');
  String get hotelFacilitySafety => _t('hotelFacilitySafety');
  String get hotelBedSingle => _t('hotelBedSingle');
  String get hotelBedTwin => _t('hotelBedTwin');
  String get hotelBedDouble => _t('hotelBedDouble');
  String get hotelBedQueen => _t('hotelBedQueen');
  String get hotelBedKing => _t('hotelBedKing');
  String get hotelBedSofa => _t('hotelBedSofa');
  String get hotelBedBunk => _t('hotelBedBunk');
  String hotelBedCount(int count, String bed) => _t(
    'hotelBedCount',
  ).replaceAll('{count}', '$count').replaceAll('{bed}', bed);
  String get hotelBreakfastIncluded => _t('hotelBreakfastIncluded');
  String get hotelBreakfastExtra => _t('hotelBreakfastExtra');
  String get hotelBreakfastUnavailable => _t('hotelBreakfastUnavailable');
  String get hotelTaxesAndFees => _t('hotelTaxesAndFees');
  String get hotelTaxesIncluded => _t('hotelTaxesIncluded');
  String get hotelTaxesExcluded => _t('hotelTaxesExcluded');
  String get hotelFreeCancellation => _t('hotelFreeCancellation');
  String get hotelPartiallyRefundable => _t('hotelPartiallyRefundable');
  String get hotelNonRefundable => _t('hotelNonRefundable');
  String get hotelPayNow => _t('hotelPayNow');
  String get hotelPayLater => _t('hotelPayLater');
  String get hotelPayAtProperty => _t('hotelPayAtProperty');
  String get hotelPrepaymentRequired => _t('hotelPrepaymentRequired');
  String get hotelPartialPrepayment => _t('hotelPartialPrepayment');
  String get hotelNoPrepayment => _t('hotelNoPrepayment');
  String hotelRoomsLeft(int count) => _t(
    count == 1 ? 'hotelRoomsLeftOne' : 'hotelRoomsLeftMany',
  ).replaceAll('{count}', '$count');
  String get bestPrice => _t('bestPrice');
  String get carRental => _t('carRental');
  String get carRentalHint => _t('carRentalHint');
  String get findACar => _t('findACar');
  String get carPickupDropOffLocation => _t('carPickupDropOffLocation');
  String get carPickup => _t('carPickup');
  String get carDropOff => _t('carDropOff');
  String get carPickupLocation => _t('carPickupLocation');
  String get carDropOffLocation => _t('carDropOffLocation');
  String get carDifferentDropOff => _t('carDifferentDropOff');
  String get carSelectDate => _t('carSelectDate');
  String get carSelectTime => _t('carSelectTime');
  String get carSearch => _t('carSearch');
  String get carSearching => _t('carSearching');
  String get carTrending => _t('carTrending');
  String get carAvailable => _t('carAvailable');
  String get carNoAvailable => _t('carNoAvailable');
  String get carSearchLocations => _t('carSearchLocations');
  String get carLocationSearchHint => _t('carLocationSearchHint');
  String get carLocationStartTyping => _t('carLocationStartTyping');
  String get carNoLocations => _t('carNoLocations');
  String get carLocationsFailed => _t('carLocationsFailed');
  String get carPickupLocationRequired => _t('carPickupLocationRequired');
  String get carDropOffLocationRequired => _t('carDropOffLocationRequired');
  String get carPickupDateRequired => _t('carPickupDateRequired');
  String get carPickupTimeRequired => _t('carPickupTimeRequired');
  String get carDropOffDateRequired => _t('carDropOffDateRequired');
  String get carDropOffTimeRequired => _t('carDropOffTimeRequired');
  String get carPickupFuture => _t('carPickupFuture');
  String get carDropOffAfterPickup => _t('carDropOffAfterPickup');
  String get carSearchFailed => _t('carSearchFailed');
  String carPersons(int count) =>
      _t('carPersons').replaceAll('{count}', '$count');
  String carBags(int count) => _t('carBags').replaceAll('{count}', '$count');
  String get carAirConditioning => _t('carAirConditioning');
  String get carHybrid => _t('carHybrid');
  String get carElectric => _t('carElectric');
  String get carPetrol => _t('carPetrol');
  String get carDiesel => _t('carDiesel');
  String get carPayAtPickup => _t('carPayAtPickup');
  String get carPayNow => _t('carPayNow');
  String carModelYear(int year) =>
      _t('carModelYear').replaceAll('{year}', '$year');
  String carPricePerDay(String price) =>
      _t('carPricePerDay').replaceAll('{price}', price);
  String get carPreviewData => _t('carPreviewData');
  String carResults(int count) => count == 1
      ? _t('carResultsOne')
      : _t('carResultsMany').replaceAll('{count}', '$count');
  String get carResultsEmptyTitle => _t('carResultsEmptyTitle');
  String get carResultsEmptyBody => _t('carResultsEmptyBody');
  String get carModifySearch => _t('carModifySearch');
  String get carResultsLoading => _t('carResultsLoading');
  String get carResultsListLabel => _t('carResultsListLabel');
  String carCarouselPosition(int current, int total) => _t(
    'carCarouselPosition',
  ).replaceAll('{current}', '$current').replaceAll('{total}', '$total');
  String get carDetails => _t('carDetails');
  String get carPickupDropOffDetails => _t('carPickupDropOffDetails');
  String get carLocation => _t('carLocation');
  String get carAdditionalOptions => _t('carAdditionalOptions');
  String get carApply => _t('carApply');
  String get carAutomatic => _t('carAutomatic');
  String get carManual => _t('carManual');
  String carPhotoPosition(int current, int total) => _t(
    'carPhotoPosition',
  ).replaceAll('{current}', '$current').replaceAll('{total}', '$total');
  String carGalleryLabel(String name) =>
      _t('carGalleryLabel').replaceAll('{name}', name);
  String carDecreaseQuantity(String name) =>
      _t('carDecreaseQuantity').replaceAll('{name}', name);
  String carIncreaseQuantity(String name) =>
      _t('carIncreaseQuantity').replaceAll('{name}', name);
  String carExtraTimesQuantity(String price, int count) => _t(
    'carExtraTimesQuantity',
  ).replaceAll('{price}', price).replaceAll('{count}', '$count');
  String get carPriceSummary => _t('carPriceSummary');
  String get carBaseRental => _t('carBaseRental');
  String get carExtrasTotal => _t('carExtrasTotal');
  String get carEstimatedTotal => _t('carEstimatedTotal');
  String carRentalDays(int count) => count == 1
      ? _t('carRentalDayOne')
      : _t('carRentalDaysMany').replaceAll('{count}', '$count');
  String get carEstimateNote => _t('carEstimateNote');
  String get carRentalConditions => _t('carRentalConditions');
  String get carFuelPolicy => _t('carFuelPolicy');
  String get carFuelFullToFull => _t('carFuelFullToFull');
  String get carFuelFullToEmpty => _t('carFuelFullToEmpty');
  String get carFuelSameToSame => _t('carFuelSameToSame');
  String get carMileage => _t('carMileage');
  String get carMileageUnlimited => _t('carMileageUnlimited');
  String carMileagePerDay(int count) =>
      _t('carMileagePerDay').replaceAll('{count}', '$count');
  String carMileageExtra(String price) =>
      _t('carMileageExtra').replaceAll('{price}', price);
  String get carDeposit => _t('carDeposit');
  String get carDamageExcess => _t('carDamageExcess');
  String get carFreeCancellation => _t('carFreeCancellation');
  String get carMinimumAge => _t('carMinimumAge');
  String carMinimumAgeValue(int age) =>
      _t('carMinimumAgeValue').replaceAll('{age}', '$age');
  String get carRequiredDocuments => _t('carRequiredDocuments');
  String get carOrSimilar => _t('carOrSimilar');
  String get flightTicketing => _t('flightTicketing');
  String get flightTicketingHint => _t('flightTicketingHint');
  String get findFlight => _t('findFlight');
  String get flightOneWay => _t('flightOneWay');
  String get flightRoundTrip => _t('flightRoundTrip');
  String get flightFrom => _t('flightFrom');
  String get flightTo => _t('flightTo');
  String get flightSearchAirport => _t('flightSearchAirport');
  String get flightAirportSearchHint => _t('flightAirportSearchHint');
  String get flightAirportStartTyping => _t('flightAirportStartTyping');
  String get flightNoAirportsFound => _t('flightNoAirportsFound');
  String get flightAirportLoadFailed => _t('flightAirportLoadFailed');
  String get flightDepartureDate => _t('flightDepartureDate');
  String get flightReturnDate => _t('flightReturnDate');
  String get flightPassengers => _t('flightPassengers');
  String get flightAdults => _t('flightAdults');
  String get flightChildren => _t('flightChildren');
  String get flightInfants => _t('flightInfants');
  String get flightCabinClass => _t('flightCabinClass');
  String flightSearchCabinClassLabel(CabinClass cabin) => switch (cabin) {
    CabinClass.economy => _t('flightCabinEconomy'),
    CabinClass.premiumEconomy => _t('flightCabinPremiumEconomy'),
    CabinClass.business => _t('flightCabinBusiness'),
    CabinClass.first => _t('flightCabinFirst'),
  };
  String get flightDirectOnly => _t('flightDirectOnly');
  String get flightSearch => _t('flightSearch');
  String get flightSearching => _t('flightSearching');
  String get done => _t('done');
  String get flightOriginRequired => _t('flightOriginRequired');
  String get flightDestinationRequired => _t('flightDestinationRequired');
  String get flightDifferentAirports => _t('flightDifferentAirports');
  String get flightDepartureRequired => _t('flightDepartureRequired');
  String get flightReturnRequired => _t('flightReturnRequired');
  String get flightSearchReady => _t('flightSearchReady');
  String flightPassengerSummary(int adults, int children, int infants) =>
      _t('flightPassengerSummary')
          .replaceAll('{adults}', '$adults')
          .replaceAll('{children}', '$children')
          .replaceAll('{infants}', '$infants');
  String flightResultsFound(int count) => count == 1
      ? _t('flightResultsOne')
      : _t('flightResultsMany').replaceAll('{count}', '$count');
  String get flightSortBest => _t('flightSortBest');
  String get flightSortCheapest => _t('flightSortCheapest');
  String get flightSortFastest => _t('flightSortFastest');
  String get flightSelect => _t('flightSelect');
  String get flightDirect => _t('flightDirect');
  String flightStops(int count) => switch (count) {
    0 => _t('flightDirect'),
    1 => _t('flightOneStop'),
    _ => _t('flightManyStops').replaceAll('{count}', '$count'),
  };
  String get flightOutbound => _t('flightOutbound');
  String get flightReturn => _t('flightReturn');
  String get flightTotalPrice => _t('flightTotalPrice');
  String get flightPerTraveler => _t('flightPerTraveler');
  String get flightResultsLoadFailed => _t('flightResultsLoadFailed');
  String get flightResultsEmptyTitle => _t('flightResultsEmptyTitle');
  String get flightResultsEmptyBody => _t('flightResultsEmptyBody');
  String get flightRetry => _t('flightRetry');
  String get flightPreviousDate => _t('flightPreviousDate');
  String get flightNextDate => _t('flightNextDate');
  String get flightOfferSelected => _t('flightOfferSelected');
  String get exploreToursTitle => _t('exploreToursTitle');
  String get exploreToursHint => _t('exploreToursHint');
  String get findTours => _t('findTours');
  String get navHome => _t('navHome');
  String get navTrips => _t('navTrips');
  String get navMap => _t('navMap');
  String get navSaved => _t('navSaved');
  String get featuredLoadFailed => _t('featuredLoadFailed');
  String get featuredEmpty => _t('featuredEmpty');
  String get signInToSave => _t('signInToSave');
  String get signInToSaveBody => _t('signInToSaveBody');
  String get notNow => _t('notNow');
  String get addedToFavorites => _t('addedToFavorites');
  String get removedFromFavorites => _t('removedFromFavorites');
  String get favoriteFailed => _t('favoriteFailed');
  String get comingSoon => _t('comingSoon');
  String get mapOpenFailed => _t('mapOpenFailed');
  String get menu => _t('menu');
  String get changeLanguage => _t('changeLanguage');

  // --- Home screen side drawer ---
  String get close => _t('close');
  String get services => _t('services');
  String get myBookings => _t('myBookings');
  String get billingPayments => _t('billingPayments');
  String get billingPaymentTitle => _t('billingPaymentTitle');
  String get currentPaymentMethod => _t('currentPaymentMethod');
  String get addPaymentMethod => _t('addPaymentMethod');
  String get addPaymentMethodDescription => _t('addPaymentMethodDescription');
  String get paymentInformationEncrypted => _t('paymentInformationEncrypted');
  String get addCard => _t('addCard');
  String get debitOrCreditCard => _t('debitOrCreditCard');
  String get secureCheckout => _t('secureCheckout');
  String get secureCardSetupUnavailable => _t('secureCardSetupUnavailable');
  String get paymentMethodAlreadyAdded => _t('paymentMethodAlreadyAdded');
  String get newCard => _t('newCard');
  String get newCardDescription => _t('newCardDescription');
  String get cardDetails => _t('cardDetails');
  String get cardholderName => _t('cardholderName');
  String get cardNumber => _t('cardNumber');
  String get expiryDate => _t('expiryDate');
  String get expiryHint => _t('expiryHint');
  String get cvv => _t('cvv');
  String get country => _t('country');
  String get yourCountry => _t('yourCountry');
  String get zipCode => _t('zipCode');
  String get optional => _t('optional');
  String get saveCardForFutureBookings => _t('saveCardForFutureBookings');
  String get editPaymentMethodLater => _t('editPaymentMethodLater');
  String get requiredField => _t('requiredField');
  String get invalidCardNumber => _t('invalidCardNumber');
  String get invalidExpiryDate => _t('invalidExpiryDate');
  String get invalidCvv => _t('invalidCvv');
  String get editProfile => _t('editProfile');
  String get editProfileSubtitle => _t('editProfileSubtitle');
  String get firstAndLastName => _t('firstAndLastName');
  String get firstName => _t('firstName');
  String get lastName => _t('lastName');
  String get firstAndLastNameRequired => _t('firstAndLastNameRequired');
  String get saveChanges => _t('saveChanges');
  String get profileUpdated => _t('profileUpdated');
  String get settingsUpdateFailed => _t('settingsUpdateFailed');
  String get changeEmail => _t('changeEmail');
  String get changeEmailSubtitle => _t('changeEmailSubtitle');
  String get confirmEmailIdentitySubtitle => _t('confirmEmailIdentitySubtitle');
  String get currentEmail => _t('currentEmail');
  String get newEmail => _t('newEmail');
  String get newEmailVerificationSubtitle => _t('newEmailVerificationSubtitle');
  String get emailUpdated => _t('emailUpdated');
  String get currentPassword => _t('currentPassword');
  String get enterValidEmail => _t('enterValidEmail');
  String get sendVerificationLink => _t('sendVerificationLink');
  String get emailVerificationSent => _t('emailVerificationSent');
  String get reauthenticationFailed => _t('reauthenticationFailed');
  String get changePhoneNumber => _t('changePhoneNumber');
  String get changePhoneSubtitle => _t('changePhoneSubtitle');
  String get newPhoneNumber => _t('newPhoneNumber');
  String get phoneInternationalFormat => _t('phoneInternationalFormat');
  String get verificationCodeSent => _t('verificationCodeSent');
  // `verificationCode` and `sendCode` are deliberately NOT redeclared here —
  // both already exist above (Login / Verification Code screen) and resolve to
  // the same keys. Declaring them twice does not compile.
  String get verifyAndSave => _t('verifyAndSave');
  String get invalidVerificationCode => _t('invalidVerificationCode');
  String get passwordChangeRules => _t('passwordChangeRules');
  String get kilometers => _t('kilometers');
  String get miles => _t('miles');
  String get milesShort => _t('milesShort');
  String get defaultPayment => _t('defaultPayment');
  String get debitCard => _t('debitCard');
  String get creditCard => _t('creditCard');
  String get kurdistanInternationalBank => _t('kurdistanInternationalBank');
  String get firstIraqiBank => _t('firstIraqiBank');
  String get newlyAddedCard => _t('newlyAddedCard');
  String get savedCard => _t('savedCard');
  String get add => _t('add');
  String get change => _t('change');
  String get delete => _t('delete');
  String get cancel => _t('cancel');
  String get setDefaultCard => _t('setDefaultCard');
  String get setDefaultCardBody => _t('setDefaultCardBody');
  String get defaultCardUpdated => _t('defaultCardUpdated');
  String get deleteCardTitle => _t('deleteCardTitle');
  String deleteCardBody(String last4) =>
      _t('deleteCardBody').replaceAll('{last4}', last4);
  String get cardDeleted => _t('cardDeleted');
  String get cardAdded => _t('cardAdded');
  String get billingSignInTitle => _t('billingSignInTitle');
  String get billingSignInBody => _t('billingSignInBody');
  String get photoSignInTitle => _t('photoSignInTitle');
  String get photoSignInBody => _t('photoSignInBody');
  String get paymentHistory => _t('paymentHistory');
  String get paid => _t('paid');
  String get pending => _t('pending');
  String get viewReceipt => _t('viewReceipt');
  String get hotel => _t('hotel');
  String get flight => _t('flight');
  String get car => _t('car');
  String get tour => _t('tour');
  String get mountainViewResort => _t('mountainViewResort');
  String get erbilToIstanbul => _t('erbilToIstanbul');
  String get suvRental => _t('suvRental');
  String get rawanduzCanyonAdventure => _t('rawanduzCanyonAdventure');
  String get paymentDateMay24 => _t('paymentDateMay24');
  String get paymentDateMay23 => _t('paymentDateMay23');
  String get paymentDateMay25 => _t('paymentDateMay25');
  String get paymentDateMay26 => _t('paymentDateMay26');
  String get settings => _t('settings');
  String get settingsAccount => _t('settingsAccount');
  String get settingsChangePassword => _t('settingsChangePassword');
  String get settingsPreferences => _t('settingsPreferences');
  String get settingsNotifications => _t('settingsNotifications');
  String get settingsTheme => _t('settingsTheme');
  String get settingsLanguage => _t('settingsLanguage');
  String get settingsUnits => _t('settingsUnits');
  String get settingsSecurityLegal => _t('settingsSecurityLegal');
  String get settingsSecurityPrivacy => _t('settingsSecurityPrivacy');
  String get settingsDeleteAccount => _t('settingsDeleteAccount');
  String get notificationsPermissionDenied =>
      _t('notificationsPermissionDenied');
  String get notificationsUpdateFailed => _t('notificationsUpdateFailed');
  String get languageEnglish => _t('languageEnglish');
  String get languageKurdish => _t('languageKurdish');
  String get languageArabic => _t('languageArabic');
  String get kilometersShort => _t('kilometersShort');
  String get currency => _t('currency');
  String get policy => _t('policy');
  String get helpSupport => _t('helpSupport');
  String get aboutUs => _t('aboutUs');
  String get contactWay => _t('contactWay');
  String get logOut => _t('logOut');
  String get guestUser => _t('guestUser');
  String get guestDrawerPrompt => _t('guestDrawerPrompt');
  String get signInRequired => _t('signInRequired');
  String get selectCurrency => _t('selectCurrency');
  String get currencyUSD => _t('currencyUSD');
  String get currencyIQD => _t('currencyIQD');
  String get currencyEUR => _t('currencyEUR');
  String get currencyUpdated => _t('currencyUpdated');
  String get currencyUpdateFailed => _t('currencyUpdateFailed');
  String get logOutFailed => _t('logOutFailed');
  String get profilePhotoUpdated => _t('profilePhotoUpdated');
  // --- Explore Nature screen ---
  String get filterHiking => _t('filterHiking');
  String get filterBeach => _t('filterBeach');
  String get filterSunsetView => _t('filterSunsetView');
  String get filterCustomize => _t('filterCustomize');
  String get locationLabel => _t('locationLabel');
  String get distanceLabel => _t('distanceLabel');
  String get natureSpotsLoadFailed => _t('natureSpotsLoadFailed');
  String get natureSpotsEmpty => _t('natureSpotsEmpty');
  String get highlightedEmpty => _t('highlightedEmpty');
  String get clearFilters => _t('clearFilters');
  String get aboutThisPlace => _t('aboutThisPlace');
  String get placeNameLabel => _t('placeNameLabel');
  String get placeDistanceLabel => _t('placeDistanceLabel');
  String get suggestedStaysNearby => _t('suggestedStaysNearby');
  String stayDistanceAway(String distance) =>
      _t('stayDistanceAway').replaceAll('{distance}', distance);
  String get weather => _t('weather');
  String get weatherUnavailable => _t('weatherUnavailable');
  String get sunny => _t('sunny');
  String get partlyCloudy => _t('partlyCloudy');
  String get cloudy => _t('cloudy');
  String get rainy => _t('rainy');
  String get snowy => _t('snowy');
  String get ratingsAndReviews => _t('ratingsAndReviews');
  String basedOnReviews(int count) =>
      _t('basedOnReviews').replaceAll('{count}', '$count');
  String get writeReviewPrompt => _t('writeReviewPrompt');
  String get writeReviewHint => _t('writeReviewHint');
  String get reviewsLoadFailed => _t('reviewsLoadFailed');
  String get noReviewsYet => _t('noReviewsYet');
  String get seeAllReviews => _t('seeAllReviews');
  String get openPlaceMap => _t('openPlaceMap');

  /// e.g. "2.5 km from current location". [distance] is already formatted and
  /// is drawn left-to-right by the card, even in Kurdish and Arabic — a
  /// measurement is not a sentence.
  String distanceFromCurrentLocation(String distance) =>
      _t('distanceFromCurrentLocation').replaceAll('{distance}', distance);

  String reviewsCount(int count) =>
      _t('reviewsCount').replaceAll('{count}', '$count');

  // --- Reviews & Ratings screen ---
  String get reviewsAndRatings => _t('reviewsAndRatings');
  String get averageRating => _t('averageRating');

  /// The "/ 10" suffix beside the average score. Kept separate from the number
  /// so the number can be drawn larger, exactly as the reference does.
  String get outOfTen => _t('outOfTen');
  String get allReviews => _t('allReviews');
  String get sortReviewsBy => _t('sortReviewsBy');
  String get noRatingsYet => _t('noRatingsYet');
  String get addYourReview => _t('addYourReview');
  String get yourRating => _t('yourRating');
  String get reviewCommentHint => _t('reviewCommentHint');
  String get postReview => _t('postReview');
  String get updateReview => _t('updateReview');
  String get reviewPosted => _t('reviewPosted');
  String get reviewUpdated => _t('reviewUpdated');
  String get reviewPostFailed => _t('reviewPostFailed');
  String get reviewRatingRequired => _t('reviewRatingRequired');
  String get reviewCommentTooShort => _t('reviewCommentTooShort');
  String get reviewCommentTooLong => _t('reviewCommentTooLong');
  String get reviewSignInTitle => _t('reviewSignInTitle');
  String get reviewSignInBody => _t('reviewSignInBody');
  String get yourReviewLabel => _t('yourReviewLabel');
  String get editYourReview => _t('editYourReview');
  String get helpfulVote => _t('helpfulVote');
  String get helpfulVoteRemove => _t('helpfulVoteRemove');
  String get helpfulSignInBody => _t('helpfulSignInBody');
  String get helpfulFailed => _t('helpfulFailed');
  String get loadMoreReviews => _t('loadMoreReviews');

  /// The label on the sort control. One method rather than four getters at the
  /// call site, so a new [ReviewSort] cannot be added without a label.
  String reviewSortLabel(ReviewSort sort) => switch (sort) {
    ReviewSort.mostRecent => _t('sortMostRecent'),
    ReviewSort.highestRated => _t('sortHighestRated'),
    ReviewSort.lowestRated => _t('sortLowestRated'),
    ReviewSort.mostHelpful => _t('sortMostHelpful'),
  };

  /// "128 reviews" / "1 review". Singular is a separate string rather than a
  /// suffix rule, because Kurdish and Arabic do not pluralise the way English
  /// does and a stripped "s" would be wrong in both.
  String reviewCountLabel(int count) =>
      count == 1 ? _t('oneReview') : reviewsCount(count);

  /// Relative age of a review ("3 hours ago"), in the coarsest unit that still
  /// says something useful. Computed from [createdAt] rather than stored, so a
  /// review never claims to be newer than it is.
  String reviewAge(DateTime createdAt, {DateTime? now}) {
    final elapsed = (now ?? DateTime.now()).difference(createdAt);
    if (elapsed.inMinutes < 60) return _t('reviewJustNow');
    if (elapsed.inHours < 24) {
      return elapsed.inHours == 1
          ? _t('reviewOneHourAgo')
          : _t('reviewHoursAgo').replaceAll('{count}', '${elapsed.inHours}');
    }
    if (elapsed.inDays < 7) {
      return elapsed.inDays == 1
          ? _t('reviewOneDayAgo')
          : _t('reviewDaysAgo').replaceAll('{count}', '${elapsed.inDays}');
    }
    if (elapsed.inDays < 30) {
      final weeks = elapsed.inDays ~/ 7;
      return weeks == 1
          ? _t('reviewOneWeekAgo')
          : _t('reviewWeeksAgo').replaceAll('{count}', '$weeks');
    }
    if (elapsed.inDays < 365) {
      final months = elapsed.inDays ~/ 30;
      return months == 1
          ? _t('reviewOneMonthAgo')
          : _t('reviewMonthsAgo').replaceAll('{count}', '$months');
    }
    final years = elapsed.inDays ~/ 365;
    return years == 1
        ? _t('reviewOneYearAgo')
        : _t('reviewYearsAgo').replaceAll('{count}', '$years');
  }

  // --- Customize Filters screen ---
  String get customizeFilters => _t('customizeFilters');
  String get customizeFiltersSubtitle => _t('customizeFiltersSubtitle');
  String get resetAll => _t('resetAll');
  String get placeType => _t('placeType');
  String get facilitiesAmenities => _t('facilitiesAmenities');

  /// "6 Filters selected". Zero and one get their own wording rather than
  /// "0 Filters selected" / "1 Filters selected" — Arabic and Kurdish do not
  /// tolerate a plural noun after 1 any better than English does.
  String filtersSelected(int count) {
    if (count == 0) return _t('noFiltersSelected');
    if (count == 1) return _t('oneFilterSelected');
    return _t('filtersSelected').replaceAll('{count}', '$count');
  }

  /// "Show 32 Places" — the label on the apply button.
  String showPlaces(int count) {
    if (count == 0) return _t('showNoPlaces');
    if (count == 1) return _t('showOnePlace');
    return _t('showPlaces').replaceAll('{count}', '$count');
  }

  String placeTypeLabel(NaturePlaceType type) => switch (type) {
    NaturePlaceType.forest => _t('placeTypeForest'),
    NaturePlaceType.mountain => _t('placeTypeMountain'),
    NaturePlaceType.canyon => _t('placeTypeCanyon'),
    NaturePlaceType.park => _t('placeTypePark'),
    NaturePlaceType.lake => _t('placeTypeLake'),
    NaturePlaceType.waterfall => _t('placeTypeWaterfall'),
    NaturePlaceType.river => _t('placeTypeRiver'),
    NaturePlaceType.museum => _t('placeTypeMuseum'),
  };

  String amenityLabel(NatureAmenity amenity) => switch (amenity) {
    NatureAmenity.parking => _t('amenityParking'),
    NatureAmenity.restrooms => _t('amenityRestrooms'),
    NatureAmenity.restaurants => _t('amenityRestaurants'),
    NatureAmenity.cafes => _t('amenityCafes'),
    NatureAmenity.mobileSignal => _t('amenityMobileSignal'),
    NatureAmenity.lodgingNearby => _t('amenityLodgingNearby'),
    NatureAmenity.atmNearby => _t('amenityAtmNearby'),
  };

  // --- Policy screen ---
  String get policyOfApp => _t('policyOfApp');
  String get policyOfAppSubtitle => _t('policyOfAppSubtitle');
  String get policyLoadFailed => _t('policyLoadFailed');

  // --- Help & Support screen ---
  String get helpAndSupport => _t('helpAndSupport');

  String helpTopicTitle(HelpTopic topic) => switch (topic) {
    HelpTopic.account => _t('helpAccountTitle'),
    HelpTopic.bookings => _t('helpBookingsTitle'),
    HelpTopic.payments => _t('helpPaymentsTitle'),
    HelpTopic.cancellation => _t('helpCancellationTitle'),
    HelpTopic.flights => _t('helpFlightsTitle'),
    HelpTopic.stays => _t('helpStaysTitle'),
    HelpTopic.carRental => _t('helpCarRentalTitle'),
    HelpTopic.tours => _t('helpToursTitle'),
    HelpTopic.safety => _t('helpSafetyTitle'),
    HelpTopic.contact => _t('helpContactTitle'),
  };

  /// The truncated question under each row's title, e.g. "How do I change my
  /// email or ...". Deliberately cut off in the source copy — it is a teaser
  /// for the questions inside, not a sentence.
  String helpTopicPreview(HelpTopic topic) => switch (topic) {
    HelpTopic.account => _t('helpAccountPreview'),
    HelpTopic.bookings => _t('helpBookingsPreview'),
    HelpTopic.payments => _t('helpPaymentsPreview'),
    HelpTopic.cancellation => _t('helpCancellationPreview'),
    HelpTopic.flights => _t('helpFlightsPreview'),
    HelpTopic.stays => _t('helpStaysPreview'),
    HelpTopic.carRental => _t('helpCarRentalPreview'),
    HelpTopic.tours => _t('helpToursPreview'),
    HelpTopic.safety => _t('helpSafetyPreview'),
    HelpTopic.contact => _t('helpContactPreview'),
  };

  String policyTopicTitle(PolicyTopic topic) => switch (topic) {
    PolicyTopic.privacy => _t('policyPrivacyTitle'),
    PolicyTopic.terms => _t('policyTermsTitle'),
    PolicyTopic.cancellation => _t('policyCancellationTitle'),
    PolicyTopic.payment => _t('policyPaymentTitle'),
    PolicyTopic.liability => _t('policyLiabilityTitle'),
    PolicyTopic.contact => _t('policyContactTitle'),
    PolicyTopic.accountDeletion => _t('policyAccountDeletionTitle'),
  };

  String policyTopicSubtitle(PolicyTopic topic) => switch (topic) {
    PolicyTopic.privacy => _t('policyPrivacySubtitle'),
    PolicyTopic.terms => _t('policyTermsSubtitle'),
    PolicyTopic.cancellation => _t('policyCancellationSubtitle'),
    PolicyTopic.payment => _t('policyPaymentSubtitle'),
    PolicyTopic.liability => _t('policyLiabilitySubtitle'),
    PolicyTopic.contact => _t('policyContactSubtitle'),
    PolicyTopic.accountDeletion => _t('policyAccountDeletionSubtitle'),
  };

  String placesCount(int count) =>
      _t('placesCount').replaceAll('{count}', '$count');

  // --- My Bookings screen ---
  String get myBookingsTitle => _t('myBookings');
  String get bookingsLoadFailed => _t('bookingsLoadFailed');
  String get bookingsEmptyTitle => _t('bookingsEmptyTitle');
  String get bookingsEmptyBody => _t('bookingsEmptyBody');
  String get bookingsEmptyFiltered => _t('bookingsEmptyFiltered');
  String get bookingsSignInTitle => _t('bookingsSignInTitle');
  String get bookingsSignInBody => _t('bookingsSignInBody');
  String get bookingsStartExploring => _t('bookingsStartExploring');
  String get bookingCheckIn => _t('bookingCheckIn');
  String get bookingCheckOut => _t('bookingCheckOut');
  String get bookingSeat => _t('bookingSeat');
  String get bookingDuration => _t('bookingDuration');
  String get bookingId => _t('bookingId');
  String get bookingPickup => _t('bookingPickup');
  String get bookingDropoff => _t('bookingDropoff');
  String get bookingTotalPaid => _t('bookingTotalPaid');

  String bookingTypeFilterLabel(BookingTypeFilter filter) => switch (filter) {
    BookingTypeFilter.all => _t('bookingsFilterAll'),
    BookingTypeFilter.hotels => _t('bookingsFilterHotels'),
    BookingTypeFilter.cars => _t('bookingsFilterCars'),
    BookingTypeFilter.flights => _t('bookingsFilterFlights'),
    BookingTypeFilter.tours => _t('bookingsFilterTours'),
  };

  String bookingTimeFilterLabel(BookingTimeFilter filter) => switch (filter) {
    BookingTimeFilter.upcoming => _t('bookingsSegmentUpcoming'),
    BookingTimeFilter.past => _t('bookingsSegmentPast'),
    BookingTimeFilter.cancelled => _t('bookingsSegmentCancelled'),
  };

  /// The empty state shown when a time segment has no bookings at all — more
  /// specific than [bookingsEmptyTitle], which covers "no bookings ever".
  String bookingsEmptySegment(BookingTimeFilter filter) => switch (filter) {
    BookingTimeFilter.upcoming => _t('bookingsEmptyUpcoming'),
    BookingTimeFilter.past => _t('bookingsEmptyPast'),
    BookingTimeFilter.cancelled => _t('bookingsEmptyCancelled'),
  };

  /// The card's type label — "HOTEL", "FLIGHT" and so on.
  String bookingTypeLabel(BookingType type) => switch (type) {
    BookingType.hotel => _t('bookingTypeHotel'),
    BookingType.car => _t('bookingTypeCar'),
    BookingType.flight => _t('bookingTypeFlight'),
    BookingType.tour => _t('bookingTypeTour'),
  };

  String bookingStatusLabel(BookingStatus status) => switch (status) {
    BookingStatus.confirmed => _t('bookingStatusConfirmed'),
    BookingStatus.pending => _t('bookingStatusPending'),
    BookingStatus.cancelled => _t('bookingStatusCancelled'),
    BookingStatus.completed => _t('bookingStatusCompleted'),
  };

  String get bookingStatusUpcoming => _t('bookingStatusUpcoming');

  String cabinClassLabel(CabinClass cabin) => switch (cabin) {
    CabinClass.economy => _t('cabinEconomy'),
    CabinClass.premiumEconomy => _t('cabinPremiumEconomy'),
    CabinClass.business => _t('cabinBusiness'),
    CabinClass.first => _t('cabinFirst'),
  };

  /// The noun for the person-count column, which differs per product: a hotel
  /// has guests, a tour has travelers, a car has a driver, a flight has a
  /// traveler. One schema field, four labels — see `DATA_MODEL.md`.
  String bookingGuestLabel(BookingType type) => switch (type) {
    BookingType.hotel => _t('bookingGuests'),
    BookingType.tour => _t('bookingTravelers'),
    BookingType.car => _t('bookingDriver'),
    BookingType.flight => _t('bookingTraveler'),
  };

  /// The primary action on each card, which differs per product.
  String bookingActionLabel(BookingType type) => switch (type) {
    BookingType.hotel => _t('bookingActionCheckIn'),
    BookingType.flight => _t('bookingActionOpenTicket'),
    BookingType.car => _t('bookingActionPickupInfo'),
    BookingType.tour => _t('bookingActionTourDetails'),
  };

  String adultsCount(int count) => count == 1
      ? _t('bookingAdultCount').replaceAll('{count}', '$count')
      : _t('bookingAdultsCount').replaceAll('{count}', '$count');

  String bookingHours(int count) =>
      _t('bookingHours').replaceAll('{count}', '$count');

  String monthName(int month) => _t('month${month.clamp(1, 12)}');

  /// "May 24, 2025" in English; "24 ئایار 2025" in Kurdish and Arabic, where
  /// the day precedes the month.
  ///
  /// Written by hand rather than via `intl`, which ships no `ku` locale — the
  /// same reason the rest of this file is hand-written. Digits stay Western in
  /// all three languages, matching how every other number in the app is drawn.
  String bookingDate(DateTime date) {
    final month = monthName(date.month);
    if (locale.languageCode == 'en') return '$month ${date.day}, ${date.year}';
    return '${date.day} $month ${date.year}';
  }

  // --- Explore Tours screen ---

  String get toursSearchHint => _t('toursSearchHint');
  String get toursDateHint => _t('toursDateHint');
  String get toursApply => _t('toursApply');
  String get clearDate => _t('clearDate');
  String get clearSearch => _t('clearSearch');
  String get trendingTours => _t('trendingTours');
  String get toursLoadFailed => _t('toursLoadFailed');
  String get toursEmpty => _t('toursEmpty');
  String get toursHighlightedEmpty => _t('toursHighlightedEmpty');
  String get tourPerPerson => _t('tourPerPerson');

  String get tourPerPersonBadge => _t('tourPerPersonBadge');
  String get tourNoReviews => _t('tourNoReviews');
  String get tourTravellers => _t('tourTravellers');
  String get tourGuideLanguages => _t('tourGuideLanguages');
  String get toursSortLabel => _t('toursSortLabel');
  String get toursRefine => _t('toursRefine');
  String get toursIncludes => _t('toursIncludes');
  String get toursDateRangeHint => _t('toursDateRangeHint');
  String get toursPriceApprox => _t('toursPriceApprox');
  String get toursClearAll => _t('toursClearAll');
  String get tourDetails => _t('tourDetails');
  String get tourFacilities => _t('tourFacilities');
  String get tourMap => _t('tourMap');
  String get tourCheckout => _t('tourCheckout');
  String get tourPerson => _t('tourPerson');
  String get tourTransportationBus => _t('tourTransportationBus');
  String get tourOptional => _t('tourOptional');
  String get tourTotalPrice => _t('tourTotalPrice');
  String get tourReserveInsight => _t('tourReserveInsight');
  String get tourTransportUnavailable => _t('tourTransportUnavailable');
  String get tourWeatherUnavailable => _t('tourWeatherUnavailable');
  String get tourMapUnavailable => _t('tourMapUnavailable');
  String get tourWriteReviewPrompt => _t('tourWriteReviewPrompt');
  String get tourNoReviewsYet => _t('tourNoReviewsYet');
  String get tourReviewSignInBody => _t('tourReviewSignInBody');

  // --- Booking: Traveler Info (checkout step 1) ---
  String get bookingStepTravelerInfo => _t('bookingStepTravelerInfo');
  String get bookingStepPayment => _t('bookingStepPayment');
  String get bookingStepConfirmation => _t('bookingStepConfirmation');
  String get travelerInformation => _t('travelerInformation');
  String get travelerInformationHint => _t('travelerInformationHint');
  String get contactPerson => _t('contactPerson');
  String get travelersLabel => _t('travelersLabel');
  String get dateOfBirthHint => _t('dateOfBirthHint');
  String get leadTraveler => _t('leadTraveler');
  String get leadTravelerHint => _t('leadTravelerHint');
  String get informationSecure => _t('informationSecure');
  String get continueToPayment => _t('continueToPayment');
  String get selectDialCode => _t('selectDialCode');
  String get travelerInfoIncomplete => _t('travelerInfoIncomplete');
  String get contactIncomplete => _t('contactIncomplete');
  String get travelerFutureBirthDate => _t('travelerFutureBirthDate');
  String get noPlacesLeft => _t('noPlacesLeft');
  String get reserveSignInTitle => _t('reserveSignInTitle');
  String get reserveSignInBody => _t('reserveSignInBody');

  // --- Booking: Payment (checkout step 2) ---
  String get paymentDetails => _t('paymentDetails');
  String get paymentDetailsHint => _t('paymentDetailsHint');
  String get bookingSummary => _t('bookingSummary');
  String get paymentMethodLabel => _t('paymentMethodLabel');
  String get mastercardVisa => _t('mastercardVisa');
  String get totalLabel => _t('totalLabel');
  String get selectPaymentMethod => _t('selectPaymentMethod');
  String get cardEntryNotLive => _t('cardEntryNotLive');
  String get paymentIncompleteCard => _t('paymentIncompleteCard');
  String get paymentNoMethod => _t('paymentNoMethod');
  String get useSavedCard => _t('useSavedCard');

  // --- Checkout step 3 (Review & Confirm) ---

  String get reviewConfirmTitle => _t('reviewConfirmTitle');
  String get reviewConfirmHint => _t('reviewConfirmHint');
  String get travelersInformation => _t('travelersInformation');
  String get priceBreakdown => _t('priceBreakdown');
  String get travelerFee => _t('travelerFee');
  String get reviewTermsLink => _t('reviewTermsLink');
  String get reviewPolicyLink => _t('reviewPolicyLink');
  String get reviewMustAgree => _t('reviewMustAgree');
  String get confirmPayNotLive => _t('confirmPayNotLive');

  /// "2 × $55" — the arithmetic behind one price-breakdown line.
  ///
  /// [price] arrives already formatted by `formatMoney`, so the currency
  /// symbol and the grouping are the same ones the totals use.
  String priceEachTimes(int count, String price) => _t(
    'priceEachTimes',
  ).replaceAll('{count}', '$count').replaceAll('{price}', price);

  /// "Confirm & Pay $65". [price] is pre-formatted, for the same reason.
  String confirmAndPay(String price) =>
      _t('confirmAndPay').replaceAll('{price}', price);

  /// The consent sentence, split around its two link labels so each can be
  /// drawn as a tappable span.
  ///
  /// Returns the literal runs *between* the placeholders, in reading order:
  /// `[before, between, after]`. Splitting here rather than in the screen
  /// keeps the word order a translator's decision — Arabic puts "و" between
  /// the two links with no space, and Kurdish reorders the sentence entirely.
  List<String> reviewAgreeTermsParts() {
    final template = _t('reviewAgreeTerms');
    final terms = template.indexOf('{terms}');
    final policy = template.indexOf('{policy}');
    // A translation that lost a placeholder must not throw on a screen the
    // user is looking at — it degrades to the sentence plus the two labels.
    if (terms < 0 || policy < 0 || policy < terms) {
      return [template, ' ', ' '];
    }
    return [
      template.substring(0, terms),
      template.substring(terms + '{terms}'.length, policy),
      template.substring(policy + '{policy}'.length),
    ];
  }

  /// "Traveler 1", "Traveler 2" — the numeral stays LTR in every language,
  /// like the other measurement sequences in `DESIGN_SYSTEM.md` 21.
  String travelerNumbered(int index) => '${_t('travelerNumbered')} $index';

  String travelerTooYoung(int age) =>
      _t('travelerTooYoung').replaceFirst('{age}', '$age');

  String onlyPlacesLeft(int count) =>
      _t('onlyPlacesLeft').replaceFirst('{count}', '$count');

  /// "128 reviews". A one-review tour gets its own string rather than
  /// "1 reviews" — and Kurdish and Arabic do not pluralize with an "s".
  String tourReviewCount(int count) => count == 1
      ? _t('tourReviewCountOne')
      : _t('tourReviewCount').replaceAll('{count}', '$count');

  /// "Only 3 spots left". Drawn only when the number is genuinely small; see
  /// [Tour.isLowAvailability].
  String tourSpotsLeft(int count) => count == 1
      ? _t('tourSpotsLeftOne')
      : _t('tourSpotsLeft').replaceAll('{count}', '$count');

  String tourTravellerCount(int count) => count == 1
      ? _t('tourTravellerCountOne')
      : _t('tourTravellerCount').replaceAll('{count}', '$count');

  /// "Total $220" — the party price beneath the per-person one.
  String tourTotalFor(String price) =>
      _t('tourTotalFor').replaceAll('{price}', price);

  String tourCancellationLabel(TourCancellationPolicy policy) =>
      switch (policy) {
        TourCancellationPolicy.free24h => _t('tourCancelFree24h'),
        TourCancellationPolicy.free48h => _t('tourCancelFree48h'),
        TourCancellationPolicy.free7d => _t('tourCancelFree7d'),
        TourCancellationPolicy.nonRefundable => _t('tourCancelNonRefundable'),
      };

  String tourGuideLanguageLabel(TourGuideLanguage language) =>
      switch (language) {
        TourGuideLanguage.english => _t('tourLanguageEnglish'),
        TourGuideLanguage.kurdish => _t('tourLanguageKurdish'),
        TourGuideLanguage.arabic => _t('tourLanguageArabic'),
        TourGuideLanguage.turkish => _t('tourLanguageTurkish'),
        TourGuideLanguage.persian => _t('tourLanguagePersian'),
      };

  String tourSortLabel(TourSort sort) => switch (sort) {
    TourSort.soonest => _t('toursSortSoonest'),
    TourSort.priceLowToHigh => _t('toursSortPriceLow'),
    TourSort.priceHighToLow => _t('toursSortPriceHigh'),
    TourSort.topRated => _t('toursSortTopRated'),
    TourSort.nearest => _t('toursSortNearest'),
  };

  /// "2 Days travel". Singular and plural are separate strings rather than one
  /// with an "s" appended, because neither Kurdish nor Arabic pluralizes that
  /// way.
  String tourDuration(int days) =>
      (days == 1 ? _t('tourDayTravel') : _t('tourDaysTravel')).replaceAll(
        '{count}',
        '$days',
      );

  String tourFeatureLabel(TourFeature feature) => switch (feature) {
    TourFeature.camping => _t('tourFeatureCamping'),
    TourFeature.hiking => _t('tourFeatureHiking'),
    TourFeature.guide => _t('tourFeatureGuide'),
    TourFeature.food => _t('tourFeatureFood'),
    TourFeature.swimming => _t('tourFeatureSwimming'),
    TourFeature.campfire => _t('tourFeatureCampfire'),
    TourFeature.transport => _t('tourFeatureTransport'),
    TourFeature.photography => _t('tourFeaturePhotography'),
    TourFeature.activity => _t('tourFeatureActivity'),
    TourFeature.wifi => _t('tourFeatureWifi'),
    TourFeature.electricity => _t('tourFeatureElectricity'),
    TourFeature.tent => _t('tourFeatureTent'),
  };

  /// The month as drawn in a tour's date range — abbreviated in English,
  /// spelled out in Kurdish and Arabic.
  ///
  /// Those two have no conventional three-letter abbreviation, and a made-up
  /// one would be worse than a long label that wraps.
  String _monthLabel(int month) => locale.languageCode == 'en'
      ? _t('monthShort${month.clamp(1, 12)}')
      : monthName(month);

  /// "Aug 14 - Aug 16", collapsing to "Aug 14 - 16" when both ends fall in the
  /// same month and to a single date when the tour runs for one day.
  ///
  /// Kurdish and Arabic put the day first ("14 - 16 ئاب"), the same rule
  /// [bookingDate] follows. Digits stay Western in all three languages,
  /// matching every other number in the app.
  String tourDateRange(DateTime start, DateTime? end) {
    final isEnglish = locale.languageCode == 'en';
    String single(DateTime date) {
      final month = _monthLabel(date.month);
      return isEnglish ? '$month ${date.day}' : '${date.day} $month';
    }

    if (end == null ||
        (end.year == start.year &&
            end.month == start.month &&
            end.day == start.day)) {
      return single(start);
    }
    if (end.year == start.year && end.month == start.month) {
      final month = _monthLabel(start.month);
      return isEnglish
          ? '$month ${start.day} - ${end.day}'
          : '${start.day} - ${end.day} $month';
    }
    return '${single(start)} - ${single(end)}';
  }

  /// "9:35 AM" — 12-hour in all three languages, matching the reference.
  String bookingTime(DateTime time) {
    final isPm = time.hour >= 12;
    var hour = time.hour % 12;
    if (hour == 0) hour = 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${isPm ? _t('timePm') : _t('timeAm')}';
  }

  /// "2h 45m", assembled from digits only so it needs no per-language string.
  String flightDuration(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '${rest}m';
    if (rest == 0) return '${hours}h';
    return '${hours}h ${rest}m';
  }

  /// Time-of-day greeting, e.g. "Good evening".
  ///
  /// Three buckets. There is deliberately **no "Good night"**: the dashboard
  /// greets someone who has just opened the app, and telling them good night
  /// reads as a farewell. Evening therefore runs from 17:00 straight through
  /// to 05:00, so a 1am visit still reads "Good evening".
  ///
  /// The afternoon band stays, because without it 13:00 would have to read
  /// either "Good morning" or "Good evening" — both wrong in all three
  /// languages.
  String greetingForHour(int hour) {
    if (hour >= 5 && hour < 12) return _t('goodMorning');
    if (hour >= 12 && hour < 17) return _t('goodAfternoon');
    return _t('goodEvening');
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const <String>['en', 'ku', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// --- Kurdish fallback delegates -------------------------------------------
// Flutter's global localizations don't support `ku`, so for Kurdish we reuse
// Arabic's localizations. That also gives Kurdish right-to-left layout.

class _KurdishMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _KurdishMaterialDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    // Initializes the bundled `intl` Arabic symbols used by the constructor
    // below; Kurdish then overrides every displayed weekday/month name.
    await GlobalMaterialLocalizations.delegate.load(const Locale('ar'));
    return _KurdishMaterialLocalizations();
  }

  @override
  bool shouldReload(_KurdishMaterialDelegate old) => false;
}

/// Arabic supplies the translated Material control labels and RTL behavior,
/// while these overrides keep every calendar/date surface in Sorani Kurdish.
class _KurdishMaterialLocalizations extends MaterialLocalizationAr {
  _KurdishMaterialLocalizations()
    : super(
        localeName: 'ar',
        fullYearFormat: intl.DateFormat('y', 'ar'),
        compactDateFormat: intl.DateFormat('dd/MM/y', 'ar'),
        shortDateFormat: intl.DateFormat('dd/MM/y', 'ar'),
        mediumDateFormat: intl.DateFormat('dd MMM y', 'ar'),
        longDateFormat: intl.DateFormat('EEEE، d MMMM y', 'ar'),
        yearMonthFormat: intl.DateFormat('MMMM y', 'ar'),
        shortMonthDayFormat: intl.DateFormat('d MMM', 'ar'),
        decimalFormat: intl.NumberFormat.decimalPattern('ar'),
        twoDigitZeroPaddedFormat: intl.NumberFormat('00', 'ar'),
      );

  static const List<String> _months = <String>[
    '',
    'کانوونی دووەم',
    'شوبات',
    'ئازار',
    'نیسان',
    'ئایار',
    'حوزەیران',
    'تەمموز',
    'ئاب',
    'ئەیلوول',
    'تشرینی یەکەم',
    'تشرینی دووەم',
    'کانوونی یەکەم',
  ];

  static const List<String> _weekdays = <String>[
    '',
    'دووشەممە',
    'سێشەممە',
    'چوارشەممە',
    'پێنجشەممە',
    'هەینی',
    'شەممە',
    'یەکشەممە',
  ];

  String _number(int value) => formatDecimal(value);
  String _month(DateTime date) => _months[date.month];

  @override
  String formatShortDate(DateTime date) =>
      '${_number(date.day)}/${_number(date.month)}/${_number(date.year)}';

  @override
  String formatMediumDate(DateTime date) =>
      '${_number(date.day)} ${_month(date)} ${_number(date.year)}';

  @override
  String formatFullDate(DateTime date) =>
      '${_weekdays[date.weekday]}، ${formatMediumDate(date)}';

  @override
  String formatMonthYear(DateTime date) =>
      '${_month(date)} ${_number(date.year)}';

  @override
  String formatShortMonthDay(DateTime date) =>
      '${_number(date.day)} ${_month(date)}';

  /// Sunday-first indexing required by Material; calendars rotate this list
  /// using [firstDayOfWeekIndex] so Saturday is displayed first.
  @override
  List<String> get narrowWeekdays => const <String>[
    'ی',
    'د',
    'س',
    'چ',
    'پ',
    'ه',
    'ش',
  ];

  @override
  int get firstDayOfWeekIndex => 6;
}

class _KurdishCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _KurdishCupertinoDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('ar'));

  @override
  bool shouldReload(_KurdishCupertinoDelegate old) => false;
}

class _KurdishWidgetsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _KurdishWidgetsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(const Locale('ar'));

  @override
  bool shouldReload(_KurdishWidgetsDelegate old) => false;
}
