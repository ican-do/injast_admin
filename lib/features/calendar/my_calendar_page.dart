import 'package:flutter/material.dart';
import 'package:injast_admin/features/shared/admin_ui.dart';
import 'package:injast_admin/file_management/local_calendar_store.dart';
import 'package:shamsi_date/shamsi_date.dart';

class MyCalendarPage extends StatefulWidget {
  const MyCalendarPage({super.key, required this.codeCo, this.userId});
  final String codeCo;
  final String? userId;

  @override
  State<MyCalendarPage> createState() => _MyCalendarPageState();
}

class _MyCalendarPageState extends State<MyCalendarPage> {
  static const _months = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند'
  ];
  static const _weekdays = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
  late Jalali _visibleMonth;
  late DateTime _selectedDate;
  List<LocalCalendarTask> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final jalali = Jalali.fromDateTime(now);
    _visibleMonth = Jalali(jalali.year, jalali.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _load() async {
    final tasks = await LocalCalendarStore.instance
        .listTasks(codeCo: widget.codeCo, userId: widget.userId);
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<LocalCalendarTask> get _selectedTasks =>
      _tasks.where((e) => _sameDay(e.dueDate, _selectedDate)).toList();

  int _taskCount(DateTime date) =>
      _tasks.where((e) => _sameDay(e.dueDate, date)).length;

  void _moveMonth(int delta) {
    var year = _visibleMonth.year;
    var month = _visibleMonth.month + delta;
    if (month > 12) {
      year++;
      month = 1;
    } else if (month < 1) {
      year--;
      month = 12;
    }
    setState(() => _visibleMonth = Jalali(year, month, 1));
  }

  Future<void> _addTask() async {
    final title = TextEditingController();
    final description = TextEditingController();
    DateTime date = _selectedDate;
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setLocal) {
          final j = Jalali.fromDateTime(date);
          return AlertDialog(
            title: const Text('یادآور جدید'),
            content: SizedBox(
              width: 500,
              child: Form(
                key: key,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: title,
                    autofocus: true,
                    decoration: AdminUi.fieldDecoration('عنوان'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'عنوان را وارد کنید'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: description,
                      decoration: AdminUi.fieldDecoration('توضیحات'),
                      minLines: 3,
                      maxLines: 6),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setLocal(() => date = picked);
                    },
                    child: InputDecorator(
                      decoration: AdminUi.fieldDecoration('تاریخ'),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}'),
                            const Icon(Icons.calendar_month_outlined),
                          ]),
                    ),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('انصراف')),
              FilledButton(
                  onPressed: () {
                    if (key.currentState!.validate()) Navigator.pop(ctx, true);
                  },
                  child: const Text('افزودن')),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    await LocalCalendarStore.instance.addTask(
      codeCo: widget.codeCo,
      userId: widget.userId,
      title: title.text.trim(),
      description: description.text.trim(),
      dueDate: date,
    );
    if (!mounted) return;
    setState(() {
      _selectedDate = date;
      final j = Jalali.fromDateTime(date);
      _visibleMonth = Jalali(j.year, j.month, 1);
    });
    await _load();
    if (mounted) showAdminSnack(context, 'یادآور افزوده شد');
  }

  void _delete(LocalCalendarTask task) => showAdminConfirm(
        context: context,
        title: 'حذف یادآور',
        message: '«${task.title}» حذف شود؟',
        confirmLabel: 'حذف',
        onConfirm: () async {
          await LocalCalendarStore.instance.deleteTask(
              codeCo: widget.codeCo, userId: widget.userId, taskId: task.id);
          await _load();
          if (mounted) showAdminSnack(context, 'یادآور حذف شد');
        },
      );

  @override
  Widget build(BuildContext context) {
    final selectedJalali = Jalali.fromDateTime(_selectedDate);
    return AdminPageShell(
      title: 'تقویم من',
      subtitle: '${_tasks.length} یادآور',
      icon: Icons.calendar_month_outlined,
      maxWidth: 1400,
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _addTask,
          icon: const Icon(Icons.add),
          label: const Text('یادآور جدید')),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final calendar = _calendarCard();
                final taskList = _tasksCard(selectedJalali);
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                              Expanded(flex: 3, child: calendar),
                              const SizedBox(width: 16),
                              Expanded(flex: 2, child: taskList),
                            ])
                      : Column(children: [
                          SizedBox(height: 520, child: calendar),
                          const SizedBox(height: 16),
                          Expanded(child: taskList),
                        ]),
                );
              },
            ),
    );
  }

  Widget _calendarCard() {
    final firstDate = _visibleMonth.toDateTime();
    final leadingDays = (firstDate.weekday + 1) % 7;
    final days = _visibleMonth.monthLength;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AdminUi.cardDecoration(),
      child: Column(children: [
        Row(children: [
          IconButton(
              onPressed: () => _moveMonth(-1),
              tooltip: 'ماه قبل',
              icon: const Icon(Icons.chevron_right)),
          Expanded(
            child: Text(
              '${_months[_visibleMonth.month - 1]} ${_visibleMonth.year}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AdminUi.ink),
            ),
          ),
          TextButton(
            onPressed: () {
              final now = DateTime.now();
              final j = Jalali.fromDateTime(now);
              setState(() {
                _visibleMonth = Jalali(j.year, j.month, 1);
                _selectedDate = DateTime(now.year, now.month, now.day);
              });
            },
            child: const Text('امروز'),
          ),
          IconButton(
              onPressed: () => _moveMonth(1),
              tooltip: 'ماه بعد',
              icon: const Icon(Icons.chevron_left)),
        ]),
        const SizedBox(height: 14),
        Row(
            children: _weekdays
                .map((e) => Expanded(
                    child: Center(
                        child: Text(e,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AdminUi.muted)))))
                .toList()),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.08,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6),
            itemCount: leadingDays + days,
            itemBuilder: (_, index) {
              if (index < leadingDays) return const SizedBox.shrink();
              final day = index - leadingDays + 1;
              final date = Jalali(_visibleMonth.year, _visibleMonth.month, day)
                  .toDateTime();
              final selected = _sameDay(date, _selectedDate);
              final today = _sameDay(date, DateTime.now());
              final count = _taskCount(date);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _selectedDate = date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: selected
                        ? AdminUi.ink
                        : (today
                            ? AdminUi.ink.withValues(alpha: .07)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: selected ? AdminUi.ink : AdminUi.cardBorder),
                  ),
                  child: Stack(children: [
                    Center(
                        child: Text('$day',
                            style: TextStyle(
                                fontWeight: selected || today
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: selected ? Colors.white : AdminUi.ink))),
                    if (count > 0)
                      Positioned(
                        bottom: 5,
                        left: 5,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: selected ? Colors.white : Colors.orange,
                              shape: BoxShape.circle),
                          child: Text('$count',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      selected ? AdminUi.ink : Colors.white)),
                        ),
                      ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _tasksCard(Jalali selected) {
    final items = _selectedTasks;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AdminUi.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '${selected.day} ${_months[selected.month - 1]} ${selected.year}',
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: AdminUi.ink),
        ),
        const SizedBox(height: 4),
        Text('${items.length} یادآور برای این روز',
            style: const TextStyle(color: AdminUi.muted)),
        const Divider(height: 28),
        Expanded(
          child: items.isEmpty
              ? const AdminEmptyState(
                  message: 'برای این روز یادآوری ثبت نشده است',
                  icon: Icons.event_available_outlined)
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final task = items[i];
                    return Container(
                      padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
                      decoration: BoxDecoration(
                          color: AdminUi.pageBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AdminUi.cardBorder)),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                                padding: EdgeInsets.only(top: 5),
                                child: Icon(Icons.check_circle_outline,
                                    color: Colors.teal)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(task.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  if (task.description.isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(task.description,
                                        style: const TextStyle(
                                            color: AdminUi.muted))
                                  ],
                                ])),
                            IconButton(
                                onPressed: () => _delete(task),
                                tooltip: 'حذف',
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red)),
                          ]),
                    );
                  },
                ),
        ),
        const SizedBox(height: 10),
        SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
                onPressed: _addTask,
                icon: const Icon(Icons.add),
                label: const Text('افزودن یادآور برای این روز'))),
      ]),
    );
  }
}
