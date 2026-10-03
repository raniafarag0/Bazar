import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'home_screen.dart';

class OtpScreen extends StatefulWidget {
  final bool isPhone;
  final String? email;

  const OtpScreen({super.key, required this.isPhone, this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final otpController = TextEditingController();
  final phoneController = TextEditingController();

  String? verificationId;

  bool loading = false;
  bool codeSent = false;
  bool navigating = false;

  Future<void> sendPhoneCode() async {
    final phone = phoneController.text.trim();

    if (phone.isEmpty) {
      showMessage('Enter your phone number');
      return;
    }

    // Use international format, e.g. +201001234567.
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      showMessage(
        'Enter a valid phone number with country code, e.g. +201001234567',
      );
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);

            if (!mounted) return;
            goHome();
          } on FirebaseAuthException catch (e) {
            if (!mounted) return;
            showMessage(_authErrorMessage(e.code));
            setState(() => loading = false);
          } catch (_) {
            if (!mounted) return;
            showMessage('Phone verification failed. Please try again.');
            setState(() => loading = false);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          setState(() => loading = false);
          showMessage(_authErrorMessage(e.code));
        },
        codeSent: (String id, int? resendToken) {
          verificationId = id;

          if (!mounted) return;

          setState(() {
            codeSent = true;
            loading = false;
          });

          showMessage('Verification code sent');
        },
        codeAutoRetrievalTimeout: (String id) {
          verificationId = id;
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      showMessage(_authErrorMessage(e.code));
    } catch (_) {
      if (!mounted) return;

      setState(() => loading = false);
      showMessage('Could not send the code. Please try again.');
    }
  }

  Future<void> verifyPhoneCode() async {
    if (verificationId == null) {
      showMessage('Please request a code first');
      return;
    }

    final code = otpController.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      showMessage('Enter the 6-digit code');
      return;
    }

    setState(() => loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId!,
        smsCode: code,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      goHome();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showMessage(_authErrorMessage(e.code));
    } catch (_) {
      if (!mounted) return;
      showMessage('Could not verify the code. Please try again.');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> checkEmailVerification() async {
    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        showMessage('Please sign in again');
        return;
      }

      await user.reload();

      final updatedUser = FirebaseAuth.instance.currentUser;

      if (!mounted) return;

      if (updatedUser?.emailVerified == true) {
        goHome();
      } else {
        showMessage('Please verify your email first');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showMessage(_authErrorMessage(e.code));
    } catch (_) {
      if (!mounted) return;
      showMessage('Could not check verification. Please try again.');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> resendEmail() async {
    if (loading) return;

    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        showMessage('Please sign in again');
        return;
      }

      await user.sendEmailVerification();

      if (!mounted) return;
      showMessage('Verification email sent. Check your inbox.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showMessage(_authErrorMessage(e.code));
    } catch (_) {
      if (!mounted) return;
      showMessage('Could not send email. Please try again.');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'The phone number is invalid.';
      case 'invalid-verification-code':
        return 'Incorrect verification code.';
      case 'session-expired':
        return 'The code has expired. Please request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'network-request-failed':
        return 'Check your internet connection.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'requires-recent-login':
        return 'Please sign in again and retry.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  void goHome() {
    if (!mounted || navigating) return;

    navigating = true;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.primary),
      );
  }

  @override
  void dispose() {
    otpController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: widget.isPhone ? phoneContent() : emailContent(),
        ),
      ),
    );
  }

  Widget phoneContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 35),

        const Icon(Icons.phone_android, size: 70, color: AppColors.primary),

        const SizedBox(height: 25),

        const Text(
          'Phone Verification',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          codeSent
              ? 'Enter the code sent to your phone'
              : 'Enter your phone number with country code',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),

        const SizedBox(height: 30),

        if (!codeSent)
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            enabled: !loading,
            decoration: InputDecoration(
              hintText: '+201001234567',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

        if (codeSent)
          TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            enabled: !loading,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: '------',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: loading
                ? null
                : codeSent
                ? verifyPhoneCode
                : sendPhoneCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: loading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(codeSent ? 'Verify Code' : 'Send Code'),
          ),
        ),
      ],
    );
  }

  Widget emailContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 35),

        const Icon(
          Icons.mark_email_read_outlined,
          size: 75,
          color: AppColors.primary,
        ),

        const SizedBox(height: 25),

        const Text(
          'Verify Your Email',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'We sent a verification link to:',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted),
        ),

        const SizedBox(height: 8),

        Text(
          widget.email ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Open your email and click the verification link, then return here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, height: 1.5),
        ),

        const Spacer(),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: loading ? null : checkEmailVerification,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('I Verified My Email'),
          ),
        ),

        TextButton(
          onPressed: loading ? null : resendEmail,
          child: const Text('Resend Verification Email'),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}
