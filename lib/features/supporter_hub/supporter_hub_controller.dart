import 'package:flutter/foundation.dart';

enum TaskSource { npoCommunity, asana }

enum TaskPriority { urgent, normal, low }

enum SupporterKind { volunteer, donor, prospect }

class SupporterTask {
  const SupporterTask({
    required this.id,
    required this.title,
    required this.owner,
    required this.dueLabel,
    required this.project,
    required this.priority,
    required this.source,
    this.isComplete = false,
  });

  final String id;
  final String title;
  final String owner;
  final String dueLabel;
  final String project;
  final TaskPriority priority;
  final TaskSource source;
  final bool isComplete;

  SupporterTask copyWith({bool? isComplete}) {
    return SupporterTask(
      id: id,
      title: title,
      owner: owner,
      dueLabel: dueLabel,
      project: project,
      priority: priority,
      source: source,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

class EventPlan {
  const EventPlan({
    required this.id,
    required this.name,
    required this.dateLabel,
    required this.location,
    required this.volunteersFilled,
    required this.volunteersNeeded,
    required this.openTasks,
    required this.status,
  });

  final String id;
  final String name;
  final String dateLabel;
  final String location;
  final int volunteersFilled;
  final int volunteersNeeded;
  final int openTasks;
  final String status;

  double get volunteerProgress {
    if (volunteersNeeded == 0) return 1;
    return volunteersFilled / volunteersNeeded;
  }
}

class FundraisingPipeline {
  const FundraisingPipeline({
    required this.id,
    required this.name,
    required this.stage,
    required this.amountLabel,
    required this.nextStep,
    required this.owner,
  });

  final String id;
  final String name;
  final String stage;
  final String amountLabel;
  final String nextStep;
  final String owner;
}

class SupporterRecord {
  const SupporterRecord({
    required this.id,
    required this.name,
    required this.kind,
    required this.detail,
    required this.nextTouch,
  });

  final String id;
  final String name;
  final SupporterKind kind;
  final String detail;
  final String nextTouch;
}

class SupporterHubController extends ChangeNotifier {
  SupporterHubController.demo()
    : _tasks = List.of(_demoTasks),
      events = _demoEvents,
      fundraising = _demoFundraising,
      supporters = _demoSupporters;

  int _selectedIndex = 0;
  final List<SupporterTask> _tasks;

  final List<EventPlan> events;
  final List<FundraisingPipeline> fundraising;
  final List<SupporterRecord> supporters;

  int get selectedIndex => _selectedIndex;
  List<SupporterTask> get tasks => List.unmodifiable(_tasks);
  int get openTaskCount => _tasks.where((task) => !task.isComplete).length;
  int get volunteerOpenings => events.fold(
    0,
    (total, event) => total + (event.volunteersNeeded - event.volunteersFilled),
  );

  void selectTool(int index) {
    if (_selectedIndex == index) return;
    _selectedIndex = index;
    notifyListeners();
  }

  void toggleTask(String id) {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index == -1) return;
    final task = _tasks[index];
    _tasks[index] = task.copyWith(isComplete: !task.isComplete);
    notifyListeners();
  }

  void addTask({
    required String title,
    required String owner,
    required String dueLabel,
    required String project,
  }) {
    _tasks.insert(
      0,
      SupporterTask(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        owner: owner,
        dueLabel: dueLabel,
        project: project,
        priority: TaskPriority.normal,
        source: TaskSource.npoCommunity,
      ),
    );
    notifyListeners();
  }
}

const _demoTasks = <SupporterTask>[
  SupporterTask(
    id: 'task-1',
    title: 'Confirm table hosts for the fall benefit',
    owner: 'Maya',
    dueLabel: 'Today',
    project: 'Fall Benefit',
    priority: TaskPriority.urgent,
    source: TaskSource.asana,
  ),
  SupporterTask(
    id: 'task-2',
    title: 'Review volunteer briefing and assignments',
    owner: 'Jordan',
    dueLabel: 'Tomorrow',
    project: 'Community Open House',
    priority: TaskPriority.normal,
    source: TaskSource.npoCommunity,
  ),
  SupporterTask(
    id: 'task-3',
    title: 'Prepare sponsor follow-up list',
    owner: 'Avery',
    dueLabel: 'Aug 8',
    project: 'Development',
    priority: TaskPriority.normal,
    source: TaskSource.asana,
  ),
  SupporterTask(
    id: 'task-4',
    title: 'Send thank-you notes to event volunteers',
    owner: 'You',
    dueLabel: 'Aug 9',
    project: 'Volunteer Care',
    priority: TaskPriority.low,
    source: TaskSource.npoCommunity,
  ),
];

const _demoEvents = <EventPlan>[
  EventPlan(
    id: 'event-1',
    name: 'Community Open House',
    dateLabel: 'Sat, Aug 15 - 10:00 AM',
    location: 'Civic Center',
    volunteersFilled: 14,
    volunteersNeeded: 18,
    openTasks: 6,
    status: 'Staffing',
  ),
  EventPlan(
    id: 'event-2',
    name: 'Fall Benefit',
    dateLabel: 'Thu, Sep 24 - 6:30 PM',
    location: 'The Foundry',
    volunteersFilled: 9,
    volunteersNeeded: 24,
    openTasks: 11,
    status: 'Planning',
  ),
  EventPlan(
    id: 'event-3',
    name: 'Supporter Welcome Night',
    dateLabel: 'Tue, Oct 6 - 5:30 PM',
    location: 'NPO Office',
    volunteersFilled: 5,
    volunteersNeeded: 8,
    openTasks: 3,
    status: 'On track',
  ),
];

const _demoFundraising = <FundraisingPipeline>[
  FundraisingPipeline(
    id: 'fund-1',
    name: 'River City Foundation',
    stage: 'Proposal',
    amountLabel: r'$25,000',
    nextStep: 'Proposal review on Aug 10',
    owner: 'Maya',
  ),
  FundraisingPipeline(
    id: 'fund-2',
    name: 'Northstar Manufacturing',
    stage: 'Cultivation',
    amountLabel: r'$10,000',
    nextStep: 'Schedule workplace visit',
    owner: 'Jordan',
  ),
  FundraisingPipeline(
    id: 'fund-3',
    name: 'Fall Benefit Hosts',
    stage: 'Stewardship',
    amountLabel: r'$18,500',
    nextStep: 'Share host toolkit',
    owner: 'Avery',
  ),
];

const _demoSupporters = <SupporterRecord>[
  SupporterRecord(
    id: 'person-1',
    name: 'Taylor Morgan',
    kind: SupporterKind.volunteer,
    detail: 'Event lead - 24 volunteer hours',
    nextTouch: 'Briefing Aug 12',
  ),
  SupporterRecord(
    id: 'person-2',
    name: 'Casey Brooks',
    kind: SupporterKind.donor,
    detail: 'Monthly supporter - 3 years',
    nextTouch: 'Thank-you call this week',
  ),
  SupporterRecord(
    id: 'person-3',
    name: 'Morgan Reed',
    kind: SupporterKind.prospect,
    detail: 'Introduced by board member',
    nextTouch: 'Coffee meeting Aug 18',
  ),
  SupporterRecord(
    id: 'person-4',
    name: 'Riley Chen',
    kind: SupporterKind.volunteer,
    detail: 'Registration and hospitality',
    nextTouch: 'Open House Aug 15',
  ),
];
