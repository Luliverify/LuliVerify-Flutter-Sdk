import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'luli_components.dart';

/// Internal attribution footer shared across SDK-owned states.
class LuliPoweredBy extends StatelessWidget {
  /// Creates the LuliVerify attribution footer.
  const LuliPoweredBy({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Powered by ',
            style: TextStyle(color: LuliVerifyDesign.muted),
          ),
          TextSpan(
            text: 'LuliVerify',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12),
    ),
  );
}

/// Internal preparation guidance tailored to tools present in the workflow.
class LuliWelcomeIntro extends StatelessWidget {
  /// Creates guidance that mentions documents/selfie lighting only when relevant.
  const LuliWelcomeIntro({
    super.key,
    this.documents = false,
    this.selfie = false,
  });

  /// Whether this workflow contains document capture and selfie-related steps.
  final bool documents, selfie;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8),
        _IntroRow(
          LucideIcons.fileText,
          documents ? 'Have your documents ready' : 'Check your information',
          documents
              ? 'Use clear photos with all details visible.'
              : 'Make sure the information you provide is accurate.',
        ),
        SizedBox(height: 24),
        _IntroRow(
          LucideIcons.sun,
          selfie ? 'Find a well-lit space' : 'Follow the steps',
          selfie
              ? 'Good lighting helps when taking your photo.'
              : 'We’ll guide you through the information this business needs.',
        ),
        SizedBox(height: 24),
      ],
    ),
  );
}

/// Displays one preparation instruction with an outline icon.
class _IntroRow extends StatelessWidget {
  const _IntroRow(this.icon, this.title, this.description);
  final IconData icon;
  final String title, description;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 22, color: LuliVerifyDesign.primary),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: LuliVerifyDesign.muted,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Internal scroll-safe terminal screen; communicates submission rather than approval.
class LuliTerminalView extends StatelessWidget {
  /// Creates terminal copy and a host-controlled return action.
  const LuliTerminalView({
    super.key,
    required this.expired,
    required this.completed,
    required this.cancelled,
    required this.onClose,
  });

  /// LuliVerify/local lifecycle indicators selecting the terminal message.
  final bool expired, completed, cancelled;

  /// Host action invoked by Return to app; does not itself authorize or resume.
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 512,
            minHeight: (constraints.maxHeight - 44).clamp(0, double.infinity),
          ),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: LuliVerifyDesign.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      completed
                          ? LucideIcons.circleCheck
                          : expired
                          ? LucideIcons.clock
                          : LucideIcons.circleAlert,
                      size: 40,
                      color: LuliVerifyDesign.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  expired
                      ? 'Let’s start again'
                      : completed
                      ? 'Verification submitted'
                      : cancelled
                      ? 'Verification cancelled'
                      : 'We couldn’t finish',
                  style: const TextStyle(
                    fontSize: 32,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.7,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  expired
                      ? 'This verification session has expired. Return to the app to begin a new session.'
                      : completed
                      ? 'Your information has been submitted. The business will confirm the final outcome.'
                      : 'Return to the app when you’re ready to try again, or contact the business for help.',
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: LuliVerifyDesign.muted,
                  ),
                ),
                const SizedBox(height: 48),
                const Spacer(),
                LuliButton(label: 'Return to app', onPressed: onClose),
                const LuliPoweredBy(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
