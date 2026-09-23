part of '../main.dart';

/// Domain enums and mutable records used by the local-first application.
///
/// These remain in the app library while persistence is migrated out of the
/// presentation layer. Keeping the records here avoids feature pages owning
/// their own incompatible copies of the same data.
enum CalendarViewMode { month, week, list }

enum SubscriptionCycle { monthly, yearly, custom }

enum EntryType { income, expense }

enum HomeSectionId { metrics, schedule, subscriptions, notes, todos }

enum HomeSectionStyle { list, grid }

enum NotesViewMode { grid, list, compact }

enum NotesSortField { createdAt, updatedAt, title, tag }

enum SortDirection { ascending, descending }

enum NotesDateFilter { all, oneDay, sevenDays, thirtyDays }

enum NoteTemplateType { general, plan, mindMap, lifeSheet }

enum NoteImageAlignment { free, left, center, right }

enum NoteBackgroundMode { fill, stretch, repeat }

enum AppNavBarStyle { template6 }

enum NoteEditorMenuAction { background, insertNote, export }

class NoteItem {
  NoteItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.deletedAt,
    this.templateType = NoteTemplateType.general,
    Map<String, dynamic>? templateData,
    Map<String, dynamic>? style,
    List<Map<String, dynamic>>? images,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? background,
    List<RelatedItemLink>? links,
  }) : templateData = templateData ?? defaultNoteTemplateData(templateType),
       style = style ?? defaultNoteStyle(),
       images = images ?? <Map<String, dynamic>>[],
       attachments = attachments ?? <Map<String, dynamic>>[],
       background = background ?? defaultNoteBackground(),
       links = normalizeRelatedItemLinks(links);

  final String id;
  String title;
  String body;
  String category;
  List<String> tags;
  DateTime createdAt;
  DateTime updatedAt;
  bool isPinned;
  DateTime? deletedAt;
  NoteTemplateType templateType;
  Map<String, dynamic> templateData;
  Map<String, dynamic> style;
  List<Map<String, dynamic>> images;
  List<Map<String, dynamic>> attachments;
  Map<String, dynamic> background;
  List<RelatedItemLink> links;
}

class ScheduleItem {
  ScheduleItem({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.location,
    required this.notes,
    required this.remindBeforeMinutes,
    List<RelatedItemLink>? links,
  }) : links = normalizeRelatedItemLinks(links);

  final String id;
  String title;
  DateTime start;
  DateTime end;
  String location;
  String notes;
  int remindBeforeMinutes;
  List<RelatedItemLink> links;
}

class SubscriptionItem {
  SubscriptionItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.cycle,
    required this.nextPaymentDate,
    required this.paymentMethod,
    required this.category,
    required this.reminderDays,
    this.isActive = true,
    List<RelatedItemLink>? links,
  }) : links = normalizeRelatedItemLinks(links);

  final String id;
  String name;
  double amount;
  SubscriptionCycle cycle;
  DateTime nextPaymentDate;
  String paymentMethod;
  String category;
  int reminderDays;
  bool isActive;
  List<RelatedItemLink> links;
}

class FinanceEntry {
  FinanceEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.category,
    required this.account,
    required this.date,
    required this.note,
    List<RelatedItemLink>? links,
  }) : links = normalizeRelatedItemLinks(links);

  final String id;
  EntryType type;
  String title;
  double amount;
  String category;
  String account;
  DateTime date;
  String note;
  List<RelatedItemLink> links;
}

/// Legacy name retained during migration. [amount] will become opening balance
/// once finance accounts calculate their live balance from ledger entries.
class SavingsAccount {
  SavingsAccount({
    required this.id,
    required this.name,
    required this.amount,
    List<RelatedItemLink>? links,
  }) : links = normalizeRelatedItemLinks(links);

  final String id;
  String name;
  double amount;
  List<RelatedItemLink> links;
}

class TodoItem {
  TodoItem({
    required this.id,
    required this.title,
    this.done = false,
    this.dueDate,
    this.reminderEnabled = false,
    this.reminderTime,
    this.completedAt,
    this.sortOrder = 0,
    List<RelatedItemLink>? links,
  }) : links = normalizeRelatedItemLinks(links);

  final String id;
  String title;
  bool done;
  DateTime? dueDate;
  bool reminderEnabled;
  TimeOfDay? reminderTime;
  DateTime? completedAt;
  int sortOrder;
  List<RelatedItemLink> links;
}
