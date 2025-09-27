// import 'package:flutter/material.dart';

// /// A custom styled AlertDialog that follows the app's design system
// class CAlertDialog extends StatelessWidget {
//   final String title;
//   final String content;
//   final List<Widget> actions;
//   final IconData? icon;
//   final Color? iconColor;
//   final bool isDestructive;
//   final double borderRadius;

//   const CAlertDialog({
//     super.key,
//     required this.title,
//     required this.content,
//     required this.actions,
//     this.icon,
//     this.iconColor,
//     this.isDestructive = false,
//     this.borderRadius = 16.0, // Default border radius
//   });

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final effectiveIconColor = iconColor ??
//         (isDestructive ? theme.colorScheme.error : theme.colorScheme.primary);

//     return AlertDialog(
//       backgroundColor: theme.colorScheme.surfaceContainer,
//       shape: theme.dialogTheme.shape ??
//           RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(borderRadius),
//           ),
//       elevation: 8,
//       title: Row(
//         children: [
//           if (icon != null) ...[
//             Icon(
//               icon!,
//               color: effectiveIconColor,
//               size: 24,
//             ),
//             const SizedBox(width: 12),
//           ],
//           Expanded(
//             child: Text(
//               title,
//               style: theme.textTheme.titleLarge?.copyWith(
//                 fontWeight: FontWeight.bold,
//                 color: isDestructive
//                     ? theme.colorScheme.error
//                     : theme.colorScheme.onSurface,
//               ),
//             ),
//           ),
//         ],
//       ),
//       content: Text(
//         content,
//         style: theme.textTheme.bodyMedium?.copyWith(
//           color: theme.colorScheme.onSurfaceVariant,
//         ),
//       ),
//       actions: actions,
//       actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//     );
//   }
// }

// /// Convenience methods for common dialog types
// extension CAlertDialogExtensions on CAlertDialog {
//   /// Shows a confirmation dialog with Cancel/Confirm buttons
//   static Future<bool?> showConfirmation({
//     required BuildContext context,
//     required String title,
//     required String content,
//     String confirmText = 'Confirm',
//     String cancelText = 'Cancel',
//     IconData? icon,
//     bool isDestructive = false,
//     VoidCallback? onConfirm,
//   }) {
//     return showDialog<bool>(
//       context: context,
//       builder: (context) => CAlertDialog(
//         title: title,
//         content: content,
//         icon: icon,
//         isDestructive: isDestructive,
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             style: TextButton.styleFrom(
//               foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
//             ),
//             child: Text(cancelText),
//           ),
//           FilledButton(
//             onPressed: () {
//               Navigator.of(context).pop(true);
//               onConfirm?.call();
//             },
//             style: isDestructive
//                 ? FilledButton.styleFrom(
//                     backgroundColor: Theme.of(context).colorScheme.error,
//                     foregroundColor: Theme.of(context).colorScheme.onError,
//                   )
//                 : null,
//             child: Text(confirmText),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Shows an info dialog with just an OK button
//   static Future<void> showInfo({
//     required BuildContext context,
//     required String title,
//     required String content,
//     IconData? icon,
//     String okText = 'OK',
//   }) {
//     return showDialog<void>(
//       context: context,
//       builder: (context) => CAlertDialog(
//         title: title,
//         content: content,
//         icon: icon,
//         actions: [
//           FilledButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text(okText),
//           ),
//         ],
//       ),
//     );
//   }
// }
