import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';

/// Asks before removing finished download records and their local files.
Future<bool> confirmDeleteFinishedDownloads(
  BuildContext context, {
  required AppStrings strings,
  required int count,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(strings.deleteFinishedDownloadsTitle),
          content: Text(strings.deleteFinishedDownloadsMessage(count)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(strings.deleteAction),
            ),
          ],
        ),
      ) ??
      false;
}
