import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import '../../../core/services/app_lock_service.dart';
import '../../widgets/animated_transitions.dart';

class PinLockScreen extends StatefulWidget {
  final bool isSetupMode;
  final VoidCallback? onSetupSuccess;

  const PinLockScreen({
    super.key,
    this.isSetupMode = false,
    this.onSetupSuccess,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  static const Color _bg = Color(0xFF0C1014);
  static const Color _keyBg = Color(0xFF212328);

  String _enteredPin = '';
  String? _firstPin; // Used in setup mode for confirmation
  bool _isConfirming = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (!widget.isSetupMode) {
      _tryBiometrics();
    }
  }

  Future<void> _tryBiometrics() async {
    final lockService = AppLockService.instance;
    if (lockService.isBiometricsEnabled) {
      final success = await lockService.authenticateWithBiometrics();
      if (success && mounted) {
        // Unlocked!
      }
    }
  }

  void _onKeyPress(String val) {
    if (_enteredPin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin += val;
        _errorMessage = '';
      });

      if (_enteredPin.length == 4) {
        _handlePinComplete();
      }
    }
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = '';
      });
    }
  }

  void _handlePinComplete() {
    if (widget.isSetupMode) {
      if (!_isConfirming) {
        // Move to confirm step
        setState(() {
          _firstPin = _enteredPin;
          _enteredPin = '';
          _isConfirming = true;
        });
      } else {
        // Verifying confirmation match
        if (_enteredPin == _firstPin) {
          AppLockService.instance.setPin(_enteredPin);
          widget.onSetupSuccess?.call();
          Navigator.of(context).pop(true);
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _errorMessage = 'PINs did not match. Try again.';
            _enteredPin = '';
            _firstPin = null;
            _isConfirming = false;
          });
        }
      }
    } else {
      // Unlock mode
      final success = AppLockService.instance.verifyPin(_enteredPin);
      if (!success) {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = 'Incorrect PIN';
          _enteredPin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title;
    if (widget.isSetupMode) {
      title = _isConfirming ? 'Confirm your 4-digit PIN' : 'Create a 4-digit PIN';
    } else {
      title = 'Enter your PIN';
    }

    return PopScope(
      canPop: widget.isSetupMode,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: widget.isSetupMode
            ? AppBar(
                backgroundColor: _bg,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.close_rounded, color: Colors.white, size: 5.5.w),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              )
            : null,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.w),
                      child: Column(
                        children: [
                          const Spacer(flex: 2),

                          // Icon / Title
                          Container(
                            width: 15.w,
                            height: 15.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _keyBg,
                              border: Border.all(color: const Color(0xFF2F333A)),
                            ),
                            child: Icon(Icons.lock_rounded, color: Colors.white, size: 7.w),
                          ),
                          SizedBox(height: 2.5.h),
                          Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            widget.isSetupMode
                                ? 'Protect your Instagram DMs from prying eyes'
                                : 'Focus DM is locked',
                            style: TextStyle(
                              color: const Color(0xFFA8A8A8),
                              fontSize: 11.5.sp,
                            ),
                          ),
                          SizedBox(height: 3.h),

                          // 4 PIN Dots
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              final filled = index < _enteredPin.length;
                              return Container(
                                margin: EdgeInsets.symmetric(horizontal: 2.5.w),
                                width: 4.w,
                                height: 4.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: filled ? Colors.white : Colors.transparent,
                                  border: Border.all(
                                    color: filled ? Colors.white : const Color(0xFF4A4E57),
                                    width: 2,
                                  ),
                                ),
                              );
                            }),
                          ),

                          if (_errorMessage.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Text(
                              _errorMessage,
                              style: TextStyle(
                                color: const Color(0xFFED4956),
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],

                          const Spacer(flex: 3),

                          // Custom Numeric Keypad
                          _buildKeypad(),

                          const Spacer(flex: 2),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _buildKeyRow(['1', '2', '3']),
        SizedBox(height: 2.h),
        _buildKeyRow(['4', '5', '6']),
        SizedBox(height: 2.h),
        _buildKeyRow(['7', '8', '9']),
        SizedBox(height: 2.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Biometric button (if unlock mode)
            if (!widget.isSetupMode)
              _buildSpecialKey(
                icon: Icons.fingerprint_rounded,
                onTap: _tryBiometrics,
              )
            else
              SizedBox(width: 20.w, height: 20.w),

            _buildKey('0'),

            // Delete button
            _buildSpecialKey(
              icon: Icons.backspace_outlined,
              onTap: _onDelete,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildKey(k)).toList(),
    );
  }

  Widget _buildKey(String value) {
    return BouncyTap(
      onTap: () => _onKeyPress(value),
      child: Container(
        width: 19.w,
        height: 19.w,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _keyBg,
        ),
        alignment: Alignment.center,
        child: Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({required IconData icon, required VoidCallback onTap}) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        width: 19.w,
        height: 19.w,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 7.w),
      ),
    );
  }
}
