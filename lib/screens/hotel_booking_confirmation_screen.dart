import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/booking.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_panel.dart';
import '../widgets/page_background.dart';
import '../widgets/primary_button.dart';
import 'hotel_checkout_screen.dart';
import 'hotel_assets.dart';
import 'my_bookings_screen.dart';

class HotelBookingConfirmationScreen extends StatelessWidget {
  const HotelBookingConfirmationScreen({
    super.key,
    required this.booking,
    required this.paymentMethod,
  });

  final Booking booking;
  final HotelPaymentMethod paymentMethod;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBackground(
        imageAsset: hotelBackgroundAsset,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: GlassPanel(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.selectionAccent(context),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.science_outlined,
                          size: 38,
                          color: AppColors.selectionAccent(context),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.hotelMockBookingComplete,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.heading(context),
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.hotelMockBookingCompleteBody,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.secondaryText(context)),
                      ),
                      const SizedBox(height: 20),
                      GlassPanel(
                        depth: GlassDepth.middle,
                        borderRadius: 20,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              booking.display.title(language),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(booking.display.roomName ?? ''),
                            const SizedBox(height: 10),
                            SelectableText(
                              booking.bookingReference,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              paymentMethod == HotelPaymentMethod.stripe
                                  ? l10n.hotelStripePreview
                                  : l10n.hotelFibPreview,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      PrimaryButton(
                        label: l10n.hotelViewReservations,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MyBookingsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).popUntil(
                          (route) => route.settings.name == '/hotel/detail',
                        ),
                        child: Text(l10n.hotelBackToHotel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
