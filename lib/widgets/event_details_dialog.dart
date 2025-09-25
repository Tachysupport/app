import 'package:flutter/material.dart';
import '../models/calendar_event.dart';

class EventDetailsDialog extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback? onEdit;
  final VoidCallback? onMarkCompleted;

  const EventDetailsDialog({
    super.key,
    required this.event,
    this.onEdit,
    this.onMarkCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (event.isCompleted)
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'Time: ${event.timeRange}',
                style: TextStyle(fontSize: 16),
              ),
              if (event.location.isNotEmpty) ...[
                SizedBox(height: 8),
                Text('Location: ${event.location}', style: TextStyle(fontSize: 16)),
              ],
              if (event.description.isNotEmpty) ...[
                SizedBox(height: 8),
                Text('Description:', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(event.description, style: TextStyle(fontSize: 15)),
              ],
              SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onMarkCompleted != null && !event.isCompleted)
                    TextButton.icon(
                      icon: Icon(Icons.check),
                      label: Text('Mark Completed'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onMarkCompleted!();
                      },
                    ),
                  if (onEdit != null)
                    TextButton.icon(
                      icon: Icon(Icons.edit),
                      label: Text('Edit'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onEdit!();
                      },
                    ),
                  TextButton(
                    child: Text('Close'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
