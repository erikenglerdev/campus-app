// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Erik Engler and Jona Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/safe_link_launcher.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../application/grade_account_controller.dart';
import '../application/grades_providers.dart';
import '../domain/grade_credentials.dart';
import 'grade_messages.dart';

/// Sign-in screen for the HIS-QIS exam portal.
///
/// Explains, before anything is typed, that the connection is direct and
/// encrypted to the official portal, that the campus servers never receive the
/// credentials or grades, and that the credentials are kept only in the device's
/// secure keystore — and requires explicit consent to that local storage.
class GradeSetupScreen extends ConsumerStatefulWidget {
  const GradeSetupScreen({super.key});

  @override
  ConsumerState<GradeSetupScreen> createState() => _GradeSetupScreenState();
}

class _GradeSetupScreenState extends ConsumerState<GradeSetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _consent = false;
  bool _busy = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    if (_busy) return;
    final bool valid = _formKey.currentState?.validate() ?? false;
    if (!_consent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.gradeSetupConsentRequired)));
      return;
    }
    if (!valid) return;

    setState(() => _busy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(gradeAccountControllerProvider.notifier)
          .signIn(
            username: _usernameController.text,
            password: _passwordController.text,
          );
      // On success the gate rebuilds into the overview.
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(gradeFailureMessage(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPortal() async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final LinkLaunchResult result = await ref
        .read(linkLauncherProvider)
        .open(ref.read(qisProfileProvider).portalUrl);
    if (result != LinkLaunchResult.opened) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorLinkNotOpened)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.gradesTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              Text(l10n.gradeSetupHeadline, style: text.titleLarge),
              const SizedBox(height: AppSpacing.md),
              _InfoCard(icon: Icons.lock_outline, text: l10n.gradeSetupIntro),
              const SizedBox(height: AppSpacing.sm),
              _InfoCard(
                icon: Icons.shield_outlined,
                text: l10n.gradeSetupPrivacy,
              ),
              const SizedBox(height: AppSpacing.sm),
              _InfoCard(
                icon: Icons.info_outline,
                text: l10n.aboutIndependenceNotice,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _usernameController,
                enabled: !_busy,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.gradeSetupUsernameLabel,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (String? value) => isValidUsername(value)
                    ? null
                    : l10n.gradeSetupUsernameRequired,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _passwordController,
                enabled: !_busy,
                obscureText: _obscurePassword,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.gradeSetupPasswordLabel,
                  prefixIcon: const Icon(Icons.password_outlined),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (String? value) => isValidPassword(value)
                    ? null
                    : l10n.gradeSetupPasswordRequired,
              ),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                value: _consent,
                onChanged: _busy
                    ? null
                    : (bool? v) => setState(() => _consent = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.gradeSetupConsent, style: text.bodyMedium),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: AppSizes.icon,
                        width: AppSizes.icon,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.gradeSetupSubmit),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: _busy ? null : _openPortal,
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.gradeSetupPortalLink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: AppSizes.icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}
