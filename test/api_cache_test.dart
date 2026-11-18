import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kazsetu_mobile/api.dart';

void main() {
  test('live data is never cached; the rest is cached for a time that fits it', () {
    for (final live in ['me', 'profile', 'chat', 'chat/u1', 'tasks/new', 'my/gigs/new', 'my/tasks/t1', 'my/gigs/g1']) {
      expect(Session.cacheFor(live), Duration.zero, reason: live);
    }
    expect(Session.cacheFor('lookups'), const Duration(hours: 1));
    for (final mine in ['my/posts', 'my/gigs', 'my/tasks/t1/candidates', 'activity', 'applications/a1', 'credits', 'verification']) {
      expect(Session.cacheFor(mine), const Duration(minutes: 1), reason: mine);
    }
    for (final public in ['tasks', 'tasks/t1', 'gigs', 'gigs/g1', 'people/sakinahmad']) {
      expect(Session.cacheFor(public), const Duration(minutes: 5), reason: public);
    }
  });

  test('a second read is answered from memory, a refresh or a write goes to the server', () async {
    var calls = 0;
    final client = MockClient((r) async {
      calls++;
      return http.Response(jsonEncode({'n': calls}), 200);
    });
    await http.runWithClient(() async {
      final s = Session();
      expect(await s.get('tasks'), {'n': 1});
      expect(await s.get('tasks'), {'n': 1}); // cached
      expect(await s.get('me'), {'n': 2});
      expect(await s.get('me'), {'n': 3}); // never cached
      final both = await Future.wait([s.get('chat'), s.get('chat')]);
      expect(both, [{'n': 4}, {'n': 4}]); // one request in flight, shared
      expect(await s.fresh(() => s.get('tasks')), {'n': 5});
      await s.post('tasks/t1/apply');
      expect(await s.get('tasks'), {'n': 7}); // the write cleared it
    }, () => client);
  });
}
