import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hn_state_example/core/data/news_item.dart';
import 'package:hn_state_example/core/services/index.dart';

class UngrowableUnmodifiableListView<T> extends UnmodifiableListView<T> {
  final int _length;

  UngrowableUnmodifiableListView(Iterable<T> source)
      : _length = source.length,
        super(source);

  @override
  int get length => min(_length, super.length);
}

enum StoriesTypes {
  newStories,
  topStories,
}

class NewsRepository {
  NewsRepository(this._newsApi);

  final NewsApi _newsApi;

  Queue<int> _storiesQueue;
  var _storiesBacking = <NewsItem>[];

  StoriesTypes _type;
  ValueNotifier<List<NewsItem>> _stories;
  ValueListenable<List<NewsItem>> stories(StoriesTypes type) {
    assert(_type == null || type == _type);
    _type = type;
    if (_stories == null) {
      switch (type) {
        case StoriesTypes.newStories:
          _apiCall = _newsApi.newStories;
          break;
        case StoriesTypes.topStories:
          _apiCall = _newsApi.topStories;
          break;
      }
      _stories = ValueNotifier<List<NewsItem>>(null);
    }
    if (_storiesQueue == null) {
      nextStoriesPage();
    }
    return _stories;
  }

  Future<List<int>> Function() _apiCall;

  Future<void> _loadingStories;
  Future<void> get loadingStories => _loadingStories;
  bool get hasNextStoriesPage => _storiesQueue?.isNotEmpty ?? true;
  Future<void> nextStoriesPage() async {
    if (_loadingStories != null || !hasNextStoriesPage) return;
    _loadingStories = () async {
      try {
        if (_storiesQueue == null) {
          final ids = await _apiCall();
          _storiesQueue = ListQueue<int>(ids.length);
          _storiesQueue.addAll(ids);
        }
        final ids = [
          for (int i = 0; i < 3; i++)
            if (_storiesQueue.isNotEmpty) _storiesQueue.removeFirst()
        ];
        final items = await Future.wait(ids.map(_newsApi.item));
        _storiesBacking.addAll(items.where((i) => i != null));
        _stories.value = UngrowableUnmodifiableListView(_storiesBacking);
      } finally {
        _loadingStories = null;
      }
    }();
    await _loadingStories;
  }

  Future<void> reset() async {
    await _loadingStories;
    _type = null;
    _storiesQueue = null;
    _storiesBacking = <NewsItem>[];
  }
}
