import 'package:flutter/material.dart';
import 'package:objectdb/objectdb.dart';
import 'package:objectdb/src/objectdb_storage_indexeddb.dart';

import 'package:lipsum/lipsum.dart' as lipsum;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MyHomePage(), theme: ThemeData.dark());
  }
}

class Event extends Schema {
  late final String title;
  late final String description;
  late final DateTime date;

  Event(this.title, this.description, this.date);

  Event.fromMap(Map data) {
    title = data['title'];
    description = data['description'];
    date = DateTime.fromMillisecondsSinceEpoch(data['date']);
  }

  @override
  Map toMap() => {
        'title': title,
        'description': description,
        'date': date.millisecondsSinceEpoch,
      };
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final searchController = TextEditingController();
  final db = SchemaDB<Event>(
    IndexedDBStorage('events'),
    (data) => Event.fromMap(data),
  );
  final List<Event> events = [];
  String search = '';

  void updateFromDB() async {
    var regex = RegExp(RegExp.escape(search), caseSensitive: false);
    var res = await db.find({
      Op.or: {'title': regex, 'description': regex}
    });
    setState(() {
      events.clear();
      events.addAll(res);
    });
  }

  initState() {
    updateFromDB();
    searchController.addListener(() {
      setState(() {
        search = searchController.text;
      });
      updateFromDB();
    });
    super.initState();
  }

  void dispose() {
    Future.microtask(() async => await db.close());
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: TextField(
              controller: searchController,
              decoration: InputDecoration(icon: Icon(Icons.search)))),
      body: ListView.builder(
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return Dismissible(
              key: Key(event.id!),
              onDismissed: (direction) {
                db.remove({'_id': event.id!}).then((_) => updateFromDB());
              },
              background: Container(color: Colors.red),
              child: ListTile(
                  title: Text(event.title), subtitle: Text(event.description)),
            );
          }),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            db
                .insert(Event(
                  lipsum.createWord(numWords: 3),
                  lipsum.createSentence(numSentences: 2),
                  DateTime.now(),
                ))
                .then((_) => updateFromDB());
          },
          child: Icon(Icons.plus_one)),
    );
  }
}
