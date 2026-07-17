import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/l10n/l10n.dart';
import '../data/models/film.dart';

/// Dialogues d'ajout partagés entre la fiche détail et le pense-bête :
/// possession (support + date d'acquisition) et visionnage (date + note +
/// commentaire).

String _fmtDate(BuildContext context, DateTime d) =>
    DateFormat.yMd(Localizations.localeOf(context).toString()).format(d);

/// Résultat de [AddCollectionDialog].
class CollChoice {
  CollChoice(this.medium, this.date);
  final Medium medium;
  final DateTime date;
}

/// Résultat de [AddHistoryDialog].
class HistChoice {
  HistChoice(this.date, this.rating, this.comment);
  final DateTime date;
  final double? rating;
  final String? comment;
}

/// « Ajouter à la collection » : choix du support et de la date d'acquisition.
class AddCollectionDialog extends StatefulWidget {
  const AddCollectionDialog({super.key});

  @override
  State<AddCollectionDialog> createState() => _AddCollectionDialogState();
}

class _AddCollectionDialogState extends State<AddCollectionDialog> {
  Medium _medium = Medium.dvd;
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.detailsAddToCollection),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.detailsMediumLabel),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: Medium.values
                  .map((m) => ChoiceChip(
                        label: Text(m.label),
                        avatar: Icon(m.icon, size: 18),
                        selected: _medium == m,
                        onSelected: (_) => setState(() => _medium = m),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            DateRow(
              text: l10n.detailsAcquiredOn(_fmtDate(context, _date)),
              date: _date,
              onPick: (d) => setState(() => _date = d),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, CollChoice(_medium, _date)),
          child: Text(l10n.add),
        ),
      ],
    );
  }
}

/// « Ajouter/modifier un visionnage » : date, note (0 = non noté), commentaire.
class AddHistoryDialog extends StatefulWidget {
  const AddHistoryDialog({
    super.key,
    this.initialDate,
    this.initialRating,
    this.initialComment,
    this.title,
    this.header,
  });

  final DateTime? initialDate;
  final double? initialRating;
  final String? initialComment;

  /// Titre du dialogue ; par défaut « Ajouter un visionnage » (localisé).
  final String? title;

  /// Contenu optionnel affiché en tête (ex. vignette + infos de l'épisode).
  final Widget? header;

  @override
  State<AddHistoryDialog> createState() => _AddHistoryDialogState();
}

class _AddHistoryDialogState extends State<AddHistoryDialog> {
  late DateTime _date = widget.initialDate ?? DateTime.now();
  late double _rating = widget.initialRating ?? 0;
  late final TextEditingController _comment =
      TextEditingController(text: widget.initialComment ?? '');

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title ?? l10n.detailsAddViewing),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.header != null) ...[
              widget.header!,
              const SizedBox(height: 12),
            ],
            DateRow(
              text: l10n.detailsWatchedOn(_fmtDate(context, _date)),
              date: _date,
              onPick: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l10n.detailsRatingLabel),
                Expanded(
                  child: Slider(
                    value: _rating,
                    min: 0,
                    max: 10,
                    divisions: 20,
                    label: _rating == 0
                        ? l10n.detailsRatingNone
                        : _rating.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    _rating == 0 ? '—' : _rating.toStringAsFixed(1),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            TextField(
              controller: _comment,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.detailsCommentLabel,
                hintText: l10n.detailsCommentHint,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            HistChoice(
              _date,
              _rating > 0 ? _rating : null,
              _comment.text.trim().isEmpty ? null : _comment.text.trim(),
            ),
          ),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// Ligne « texte + bouton Modifier » ouvrant un sélecteur de date.
class DateRow extends StatelessWidget {
  const DateRow(
      {super.key, required this.text, required this.date, required this.onPick});

  /// Texte complet déjà localisé (ex. « Acquis le 12/07/2026 »).
  final String text;
  final DateTime date;
  final void Function(DateTime) onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text)),
        TextButton(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(1900),
              lastDate: now,
            );
            if (picked != null) onPick(picked);
          },
          child: Text(context.l10n.detailsEditButton),
        ),
      ],
    );
  }
}
