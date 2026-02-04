import 'package:transconnect/features/migration_planner/domain/models/destination.dart';

class MigrationDestinations {
  MigrationDestinations._();

  static const List<DestinationPreset> all = [
    DestinationPreset(
      id: 'il-metropolis',
      name: 'Metropolis, IL (I-24 / US-45)',
      latitude: 37.1517,
      longitude: -88.7323,
      type: DestinationType.illinoisEntry,
      description: 'Ohio River crossing near western KY (Paducah area).',
    ),
    DestinationPreset(
      id: 'il-cairo',
      name: 'Cairo, IL (I-57 / US-60)',
      latitude: 37.0053,
      longitude: -89.1765,
      type: DestinationType.illinoisEntry,
      description: 'Southern tip of IL near KY/MO borders.',
    ),
    DestinationPreset(
      id: 'il-henderson',
      name: 'Henderson, KY → Evansville, IN (Alt nearby)',
      latitude: 37.9748,
      longitude: -87.5558,
      type: DestinationType.illinoisEntry,
      description: 'Regional crossing area with multiple bridge options.',
    ),
    DestinationPreset(
      id: 'canada-detroit',
      name: 'Detroit–Windsor Crossing (MI/ON)',
      latitude: 42.3293,
      longitude: -83.0411,
      type: DestinationType.canadaBorder,
      description: 'Ambassador Bridge / Detroit-Windsor Tunnel area.',
    ),
    DestinationPreset(
      id: 'canada-buffalo',
      name: 'Buffalo–Fort Erie Crossing (NY/ON)',
      latitude: 42.9184,
      longitude: -78.9052,
      type: DestinationType.canadaBorder,
      description: 'Peace Bridge / Buffalo border region.',
    ),
    DestinationPreset(
      id: 'canada-sault',
      name: 'Sault Ste. Marie Crossing (MI/ON)',
      latitude: 46.5115,
      longitude: -84.3467,
      type: DestinationType.canadaBorder,
      description: 'Soo Locks border region.',
    ),
    DestinationPreset(
      id: 'mexico-laredo',
      name: 'Laredo Crossing (TX/NL)',
      latitude: 27.5024,
      longitude: -99.5075,
      type: DestinationType.mexicoBorder,
      description: 'Major Texas border entry near Laredo.',
    ),
    DestinationPreset(
      id: 'mexico-el-paso',
      name: 'El Paso Crossing (TX/CH)',
      latitude: 31.7571,
      longitude: -106.4875,
      type: DestinationType.mexicoBorder,
      description: 'Paso del Norte / downtown El Paso region.',
    ),
    DestinationPreset(
      id: 'mexico-brownsville',
      name: 'Brownsville Crossing (TX/TM)',
      latitude: 25.9017,
      longitude: -97.4975,
      type: DestinationType.mexicoBorder,
      description: 'Gateway bridge area near Brownsville.',
    ),
  ];

  static List<DestinationPreset> byType(DestinationType type) {
    return all.where((preset) => preset.type == type).toList();
  }
}
