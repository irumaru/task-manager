import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/task_repository.dart';

class FilterState {
  final TaskFilter filter;
  final SortField sortField;
  final SortOrder sortOrder;
  final bool showCompleted;

  const FilterState({
    this.filter = const TaskFilter(),
    this.sortField = SortField.createdAt,
    this.sortOrder = SortOrder.desc,
    this.showCompleted = false,
  });

  FilterState copyWith({
    TaskFilter? filter,
    SortField? sortField,
    SortOrder? sortOrder,
    bool? showCompleted,
  }) {
    return FilterState(
      filter: filter ?? this.filter,
      sortField: sortField ?? this.sortField,
      sortOrder: sortOrder ?? this.sortOrder,
      showCompleted: showCompleted ?? this.showCompleted,
    );
  }
}

class FilterNotifier extends Notifier<FilterState> {
  @override
  FilterState build() => const FilterState();

  void setSearchQuery(String query) {
    state = state.copyWith(filter: state.filter.copyWith(searchQuery: query));
  }

  void setTagIds(List<int> ids) {
    state = state.copyWith(filter: state.filter.copyWith(tagIds: ids));
  }

  void setPriorityIds(List<int> ids) {
    state = state.copyWith(filter: state.filter.copyWith(priorityIds: ids));
  }

  void setStatusIds(List<int> ids) {
    state = state.copyWith(filter: state.filter.copyWith(statusIds: ids));
  }

  void setIsOverdue(bool? value) {
    state = state.copyWith(filter: state.filter.copyWith(isOverdue: value));
  }

  void toggleShowCompleted() {
    state = state.copyWith(showCompleted: !state.showCompleted);
  }

  void setSortField(SortField field) {
    state = state.copyWith(sortField: field);
  }

  void setSortOrder(SortOrder order) {
    state = state.copyWith(sortOrder: order);
  }

  void reset() {
    state = const FilterState();
  }
}

final filterProvider =
    NotifierProvider<FilterNotifier, FilterState>(FilterNotifier.new);
