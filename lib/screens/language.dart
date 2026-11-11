import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../ui.dart';

/// First open only: the person picks Bangla or English before anything else. Both languages are
/// shown at once, since neither has been chosen yet. It can be changed later under Me.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: K.deep,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: K.brandGradient),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Spacer(),
                  const Center(child: Logo(height: 72)),
                  const SizedBox(height: 32),
                  Text(
                    'ভাষা বেছে নিন',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose your language',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const Spacer(),
                  _Choice(label: 'বাংলা', lang: 'bn'),
                  const SizedBox(height: 12),
                  _Choice(label: 'English', lang: 'en'),
                  const SizedBox(height: 12),
                ]),
              ),
            ),
          ),
        ),
      );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.lang});
  final String label, lang;
  @override
  Widget build(BuildContext context) => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: K.deep,
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          session.setLang(lang);
        },
        child: Text(label),
      );
}
