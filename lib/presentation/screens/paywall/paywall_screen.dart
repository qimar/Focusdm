import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../core/services/purchase_service.dart';
import '../../widgets/animated_transitions.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  static const Color _bg = Color(0xFF0C1014);
  static const Color _cardBg = Color(0xFF212328);
  static const Color _surface = Color(0xFF25292E);
  static const Color _borderDark = Color(0xFF2F333A);
  static const Color _textSecondary = Color(0xFFA8A8A8);
  static const Color _emerald = Color(0xFF34D399);

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    PurchaseService.instance.addListener(_onPurchaseStateChanged);
  }

  void _onPurchaseStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    PurchaseService.instance.removeListener(_onPurchaseStateChanged);
    super.dispose();
  }

  Future<void> _handlePurchase() async {
    setState(() => _isProcessing = true);
    final success = await PurchaseService.instance.purchasePro();
    setState(() => _isProcessing = false);

    if (mounted) {
      if (success) {
        _showSuccessSnackbar('Welcome to Focus DM Pro!');
        Navigator.of(context).pop(true);
      } else {
        _showErrorSnackbar('Purchase could not be completed.');
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isProcessing = true);
    final isPro = await PurchaseService.instance.restorePurchases();
    setState(() => _isProcessing = false);

    if (mounted) {
      if (isPro) {
        _showSuccessSnackbar('Purchases restored successfully!');
        Navigator.of(context).pop(true);
      } else {
        _showErrorSnackbar('No prior purchases found to restore.');
      }
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF16261E),
        content: Text(message, style: const TextStyle(color: _emerald)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _surface,
        content: Text(message, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final price = PurchaseService.instance.localizedPriceString;

    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 5.w),
                  child: Column(
                    children: [
                      // Top Bar with Close and Restore (Scrolls with the body)
                      Padding(
                        padding: EdgeInsets.only(top: 0.8.h, bottom: 0.5.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(Icons.close_rounded, color: Colors.white70, size: 6.5.w),
                              onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: _isProcessing ? null : _handleRestore,
                              child: Text(
                                'Restore',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 1.h),

                // Glowing Hero Icon
                      Container(
                        width: 18.w,
                        height: 18.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _cardBg,
                          border: Border.all(color: _borderDark, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.10),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(Icons.lock_open_rounded, color: Colors.white, size: 8.5.w),
                        ),
                      ),
                      SizedBox(height: 2.h),

                      // Headline
                      Text(
                        'Take Back Your Focus',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 0.8.h),
                      Text(
                        'One small investment. A lifetime of reclaimed attention.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 12.sp,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: 3.5.h),

                      // Value-Prop Feature Cards
                      _buildFeatureRow(
                        icon: Icons.all_inclusive_rounded,
                        title: 'Unlimited Focus Mode',
                        description: 'Lock Instagram for full workdays or custom deep-work sessions (Free is capped at 30 min).',
                      ),
                      SizedBox(height: 2.h),
                      _buildFeatureRow(
                        icon: Icons.alarm_on_rounded,
                        title: 'Scheduled Recurring Focus',
                        description: 'Automate distraction-free hours during workdays or bedtime with zero manual toggles.',
                      ),
                      SizedBox(height: 2.h),
                      _buildFeatureRow(
                        icon: Icons.fingerprint_rounded,
                        title: 'Biometric Chat Privacy',
                        description: 'Keep your direct messages guarded behind Face ID, fingerprint, and PIN.',
                      ),
                      SizedBox(height: 2.h),
                      _buildFeatureRow(
                        icon: Icons.notifications_active_rounded,
                        title: 'Direct Message Push Alerts',
                        description: 'Stay reachable with real-time DM notifications while keeping feeds and reels blocked.',
                      ),
                      SizedBox(height: 2.h),
                      _buildFeatureRow(
                        icon: Icons.bolt_rounded,
                        title: 'All Future Updates Included',
                        description: 'No subscription. No recurring charges. Pay once, own Focus DM Pro forever.',
                      ),

                      SizedBox(height: 3.5.h),

                      // Pricing Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(4.5.w),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.05),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Lifetime Access',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 2.w),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16261E),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: _emerald.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        'PAY ONCE',
                                        style: TextStyle(
                                          color: _emerald,
                                          fontSize: 8.5.sp,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 0.5.h),
                                Text(
                                  'No recurring fees • Lifetime updates',
                                  style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 10.5.sp,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              price,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 2.h),
                    ],
                  ),
                ),
              ),

              // Bottom CTA Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                child: Column(
                  children: [
                    BouncyTap(
                      onTap: _isProcessing ? null : _handlePurchase,
                      child: Container(
                        width: double.infinity,
                        height: 6.5.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Unlock Focus DM Pro',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 1.2.h),
                    Text(
                      'Secured by Google Play • Instant access across all your devices',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF737373),
                        fontSize: 9.5.sp,
                      ),
                    ),
                    SizedBox(height: 1.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10.w,
          height: 10.w,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _borderDark),
          ),
          child: Icon(icon, color: Colors.white, size: 5.w),
        ),
        SizedBox(width: 3.5.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 0.3.h),
              Text(
                description,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 11.sp,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
