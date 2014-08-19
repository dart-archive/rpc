import 'package:endpoints/endpoints.dart';
import 'package:cloud_datastore/cloud_datastore.dart';
import 'package:appengine/appengine.dart';
import 'dart:async';

@ModelMetadata(const MessageDesc())
class Message extends Model {
  @ApiProperty(description: 'Datastore ID of the Message', variant: 'uint64')
  int id;

  @ApiProperty(description: 'Message text')
  String text;

  @ApiProperty(description: 'Date of the message')
  DateTime date;

  Message() {
    // Automatically set current date for new messages
    date = new DateTime.now();
  }
}

class MessageDesc extends ModelDescription {
  final id = const IntProperty();
  final text = const StringProperty();
  final date = const DateTimeProperty();

  const MessageDesc() : super ('Message');
}

class MessageList {
  List<Message> items;

  MessageList([this.items = const []]);
}

@ApiClass(
  name: 'dartDBApi',
  version: 'v1',
  description: 'Combining datastore and endpoints!'
)
class DartDBApi {
  @ApiMethod(
    name: 'messages.list',
    path: 'messages',
    description: 'Retrieve list of messages'
  )
  Future<MessageList> list(VoidMessage _) {
    return context.services.db.query(Message).run()
             .then((List<Message> list) => new MessageList(list));
  }

  @ApiMethod(
    name: 'messages.insert',
    path: 'messages',
    method: 'POST',
    description: 'Insert a new message'
  )
  Future<Message> insert(Message message) {
    return context.services.db.commit(inserts: [message]).then((_) => message);
  }
}