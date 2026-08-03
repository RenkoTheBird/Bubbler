import 'package:flutter/material.dart';

import '../../data/models/topics.dart';
import '../theme/topic_style.dart';

/// Searchable preferred/blacklist topic editor — Swift `PreferenceTopicsEditor`.
class PreferenceTopicsEditor extends StatefulWidget {
  const PreferenceTopicsEditor({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.topics,
    required this.onChanged,
    this.conflictingTopics,
    this.onConflictingChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<String> topics;
  final ValueChanged<List<String>> onChanged;

  /// When set, selecting a topic also removes it from this conflicting list
  /// (preferred ↔ blacklisted), matching iOS merge behavior.
  final List<String>? conflictingTopics;
  final ValueChanged<List<String>>? onConflictingChanged;

  @override
  State<PreferenceTopicsEditor> createState() => _PreferenceTopicsEditorState();
}

class _PreferenceTopicsEditorState extends State<PreferenceTopicsEditor> {
  final _draftController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _draftController.dispose();
    super.dispose();
  }

  List<String> get _matchingTopics =>
      KnownTopics.matching(_draftController.text, excluding: widget.topics);

  void _addTopic() {
    final trimmed = _draftController.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorMessage = null);
      return;
    }

    final topic = KnownTopics.resolve(trimmed);
    if (topic == null) {
      setState(() {
        _errorMessage =
            'Unknown topic: "$trimmed". Choose one from the list of existing topics.';
      });
      return;
    }

    _selectTopic(topic);
  }

  void _selectTopic(String topic) {
    final resolved = KnownTopics.resolve(topic);
    if (resolved == null) {
      setState(() {
        _errorMessage =
            'Unknown topic: "$topic". Choose one from the list of existing topics.';
      });
      return;
    }

    // Clear the other list first so preferred → blacklisted doesn't get
    // dropped by merge (preferred wins when both are present).
    final conflicting = widget.conflictingTopics;
    final onConflicting = widget.onConflictingChanged;
    if (conflicting != null && onConflicting != null) {
      onConflicting(TopicPreferenceList.remove(resolved, conflicting));
    }

    widget.onChanged(TopicPreferenceList.add(resolved, widget.topics));
    _draftController.clear();
    setState(() => _errorMessage = null);
  }

  void _removeTopic(String topic) {
    widget.onChanged(TopicPreferenceList.remove(topic, widget.topics));
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draftController.text.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: widget.iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          _SearchField(
            controller: _draftController,
            iconColor: widget.iconColor,
            onChanged: (_) => setState(() => _errorMessage = null),
            onSubmitted: (_) => _addTopic(),
            onClear: () {
              _draftController.clear();
              setState(() => _errorMessage = null);
            },
            onAdd: _addTopic,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.withValues(alpha: 0.95),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (draft.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SuggestionResults(
              draft: draft,
              matching: _matchingTopics,
              onSelect: _selectTopic,
            ),
          ],
          const SizedBox(height: 14),
          if (widget.topics.isEmpty)
            Text(
              'No topics added yet.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            )
          else
            _TopicChipGrid(
              topics: widget.topics,
              onRemove: _removeTopic,
            ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.iconColor,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onAdd,
  });

  final TextEditingController controller;
  final Color iconColor;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: iconColor.withValues(alpha: 0.9), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Search existing topics...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              onPressed: onClear,
              icon: Icon(
                Icons.cancel,
                color: Colors.white.withValues(alpha: 0.55),
                size: 18,
              ),
              tooltip: 'Clear topic search',
              visualDensity: VisualDensity.compact,
            ),
          TextButton(
            onPressed: onAdd,
            child: const Text(
              'Add',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionResults extends StatelessWidget {
  const _SuggestionResults({
    required this.draft,
    required this.matching,
    required this.onSelect,
  });

  final String draft;
  final List<String> matching;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (matching.isEmpty) {
      return Text(
        'No existing topics match "$draft".',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 12,
        ),
      );
    }

    return Column(
      children: [
        for (final topic in matching) ...[
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelect(topic),
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: Icon(
                        TopicStyle.icon(topic),
                        size: 16,
                        color: TopicStyle.color(topic),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        KnownTopics.displayName(topic),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.add_circle,
                      color: Colors.white.withValues(alpha: 0.55),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _TopicChipGrid extends StatelessWidget {
  const _TopicChipGrid({
    required this.topics,
    required this.onRemove,
  });

  final List<String> topics;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final topic in topics)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  KnownTopics.displayName(topic),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onRemove(topic),
                  child: const Icon(Icons.cancel, size: 14, color: Colors.white),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
