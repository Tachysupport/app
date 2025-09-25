import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../providers/calendar_provider.dart';
import '../models/calendar_event.dart';
import '../providers/app_provider.dart';

class NewEventScreen extends StatefulWidget {
  final CalendarEvent? event;
  const NewEventScreen({super.key, this.event});

  @override
  State<NewEventScreen> createState() => _NewEventScreenState();
}

class _NewEventScreenState extends State<NewEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _guestsController = TextEditingController();
  final _attachmentController = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _isAllDay;
  late Color _eventColor;
  late String _selectedRecurrence;
  late int _reminderMinutes;
  final List<String> _recurrenceOptions = [
    'Does not repeat',
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
  ];

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      _titleController.text = event.title;
      _descriptionController.text = event.description;
      _locationController.text = event.location;
      _selectedDate = event.startTime;
      _startTime = TimeOfDay(
        hour: event.startTime.hour,
        minute: event.startTime.minute,
      );
      _endTime = TimeOfDay(
        hour: event.endTime.hour,
        minute: event.endTime.minute,
      );
      _isAllDay = event.isAllDay;
      _eventColor = event.color;
      _selectedRecurrence = event.recurrence;
      _reminderMinutes = event.reminderMinutes;
      _attachmentController.text = event.attachment;
    } else {
      _selectedDate = DateTime.now();
      _startTime = TimeOfDay.now();
      _endTime = TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 1);
      _isAllDay = false;
      _eventColor = Colors.blue;
      _selectedRecurrence = 'Does not repeat';
      // Get default reminder time from AppProvider
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      _reminderMinutes = appProvider.settings['reminderTime'] ?? 15;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _guestsController.dispose();
    _attachmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.event == null ? 'Add New Event' : 'Edit Event',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveEvent,
        icon: const Icon(Icons.save),
        label: const Text('Save'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Center(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: 300.w, maxWidth: 370.w),
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Event Details',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Title',
                              prefixIcon: Icon(Icons.title),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a title';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16.h),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              prefixIcon: Icon(Icons.notes),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            maxLines: 3,
                          ),
                          SizedBox(height: 16.h),
                          TextFormField(
                            controller: _locationController,
                            decoration: InputDecoration(
                              labelText: 'Location',
                              prefixIcon: Icon(Icons.location_on),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            'Time',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectDate(context),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Date',
                                      prefixIcon: Icon(Icons.calendar_today),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      DateFormat(
                                        'MMM dd, yyyy',
                                      ).format(_selectedDate),
                                      style: TextStyle(fontSize: 14.sp),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _isAllDay,
                                    onChanged: (val) {
                                      setState(() {
                                        _isAllDay = val!;
                                      });
                                    },
                                  ),
                                  Text(
                                    'All-day',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (!_isAllDay) ...[
                            SizedBox(height: 12.h),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectTime(context, true),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Start Time',
                                        prefixIcon: Icon(Icons.access_time),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        _startTime.format(context),
                                        style: TextStyle(fontSize: 14.sp),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _selectTime(context, false),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'End Time',
                                        prefixIcon: Icon(Icons.access_time),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8.r,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        _endTime.format(context),
                                        style: TextStyle(fontSize: 14.sp),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          SizedBox(height: 24.h),
                          Text(
                            'Options',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Text(
                                'Event color:',
                                style: TextStyle(fontSize: 14.sp),
                              ),
                              SizedBox(width: 8.w),
                              GestureDetector(
                                onTap: () async {
                                  final Color? picked = await showDialog<Color>(
                                    context: context,
                                    builder: (context) => _ColorPickerDialog(
                                      selected: _eventColor,
                                    ),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _eventColor = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  width: 28.w,
                                  height: 28.w,
                                  decoration: BoxDecoration(
                                    color: _eventColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 2.w,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          Row(
                            children: [
                              Icon(Icons.alarm, size: 20.w),
                              SizedBox(width: 8.w),
                              Text(
                                'Reminder:',
                                style: TextStyle(fontSize: 14.sp),
                              ),
                              SizedBox(width: 8.w),
                              DropdownButton<int>(
                                value: _reminderMinutes,
                                items: (() {
                                  final defaultItems = [0, 5, 10, 15, 30, 60];
                                  final items = List<int>.from(defaultItems);
                                  if (!items.contains(_reminderMinutes)) {
                                    items.add(_reminderMinutes);
                                  }
                                  items.sort();
                                  return items
                                      .map(
                                        (min) => DropdownMenuItem(
                                          value: min,
                                          child: Text(
                                            min == 0
                                                ? 'None'
                                                : '$min min before',
                                          ),
                                        ),
                                      )
                                      .toList();
                                })(),
                                onChanged: (val) {
                                  setState(() {
                                    _reminderMinutes = val!;
                                  });
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          Row(
                            children: [
                              Icon(Icons.repeat, size: 20.w),
                              SizedBox(width: 8.w),
                              Text(
                                'Repeat:',
                                style: TextStyle(fontSize: 14.sp),
                              ),
                              SizedBox(width: 8.w),
                              DropdownButton<String>(
                                value: _selectedRecurrence,
                                items: _recurrenceOptions
                                    .map(
                                      (rec) => DropdownMenuItem(
                                        value: rec,
                                        child: Text(rec),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedRecurrence = val!;
                                  });
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          TextFormField(
                            controller: _attachmentController,
                            decoration: InputDecoration(
                              labelText: 'Attachment (URL)',
                              prefixIcon: Icon(Icons.attach_file),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                          ),
                          SizedBox(height: 24.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
          if (_endTime.hour < _startTime.hour ||
              (_endTime.hour == _startTime.hour &&
                  _endTime.minute <= _startTime.minute)) {
            _endTime = _startTime.hour == 23
                ? const TimeOfDay(hour: 23, minute: 59)
                : _startTime.replacing(hour: _startTime.hour + 1);
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _saveEvent() async {
    if (_formKey.currentState!.validate()) {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _isAllDay ? 0 : _startTime.hour,
        _isAllDay ? 0 : _startTime.minute,
      );
      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _isAllDay ? 23 : _endTime.hour,
        _isAllDay ? 59 : _endTime.minute,
      );

      final calendarProvider = context.read<CalendarProvider>();

      try {
        if (widget.event == null) {
          // Create a new event
          final newEvent = CalendarEvent(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: _titleController.text,
            description: _descriptionController.text,
            startTime: startDateTime,
            endTime: endDateTime,
            location: _locationController.text,
            color: _eventColor,
            reminderMinutes: _reminderMinutes,
            recurrence: _selectedRecurrence,
            attachment: _attachmentController.text,
            isAllDay: _isAllDay,
          );
          await calendarProvider.addEvent(newEvent);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Event created successfully')),
            );
          }
        } else {
          // Update the existing event
          final updatedEvent = widget.event!.copyWith(
            title: _titleController.text,
            description: _descriptionController.text,
            startTime: startDateTime,
            endTime: endDateTime,
            location: _locationController.text,
            color: _eventColor,
            reminderMinutes: _reminderMinutes,
            recurrence: _selectedRecurrence,
            attachment: _attachmentController.text,
            isAllDay: _isAllDay,
          );
          await calendarProvider.updateEvent(updatedEvent);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Event updated successfully')),
            );
          }
        }
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _ColorPickerDialog extends StatelessWidget {
  final Color selected;
  const _ColorPickerDialog({required this.selected});

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.brown,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
      Colors.lime,
      Colors.deepOrange,
      Colors.deepPurple,
      Colors.lightBlue,
      Colors.lightGreen,
      Colors.yellow,
      Colors.grey,
      Colors.black,
    ];
    return AlertDialog(
      title: const Text('Pick a color'),
      content: SizedBox(
        width: 300,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((color) {
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(color),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected == color
                        ? Colors.black
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
