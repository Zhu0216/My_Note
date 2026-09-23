import 'package:flutter/material.dart';

const appPickerLocale = Locale('zh', 'TW');

Widget appPickerBuilder(BuildContext context, Widget? child) {
  final mediaQuery = MediaQuery.of(context);
  return Localizations.override(
    context: context,
    locale: appPickerLocale,
    child: MediaQuery(
      data: mediaQuery.copyWith(alwaysUse24HourFormat: true),
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    locale: appPickerLocale,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: '選擇日期',
    cancelText: '取消',
    confirmText: '確定',
    fieldLabelText: '輸入日期',
    fieldHintText: '年/月/日',
    errorFormatText: '請輸入有效日期',
    errorInvalidText: '日期超出範圍',
    builder: appPickerBuilder,
  );
}

Future<TimeOfDay?> showAppTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
  String helpText = '選擇時間',
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    initialEntryMode: TimePickerEntryMode.dial,
    helpText: helpText,
    cancelText: '取消',
    confirmText: '確定',
    hourLabelText: '小時',
    minuteLabelText: '分鐘',
    errorInvalidText: '請輸入有效時間',
    builder: appPickerBuilder,
  );
}

TimeOfDay timeOfDate(DateTime value) {
  return TimeOfDay(hour: value.hour, minute: value.minute);
}

DateTime combineDateAndTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

DateTime combinePickedDateWithCurrentTime(
  DateTime pickedDate,
  DateTime current,
) {
  return DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    current.hour,
    current.minute,
  );
}
