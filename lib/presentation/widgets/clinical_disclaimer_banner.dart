import 'package:acl_rehab/core/constants/app_constants.dart';
import 'package:flutter/material.dart';

class ClinicalDisclaimerBanner extends StatelessWidget {
  const ClinicalDisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: AppConstants.medicalDisclaimer,
      child: Card(
        color: scheme.secondaryContainer.withValues(alpha: 0.78),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.cardPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppConstants.medicalDisclaimer,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
