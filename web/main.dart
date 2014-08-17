import 'dart:html';
import 'package:mydartapi_v1_api/mydartapi_v1_api_browser.dart' as myapi;
import 'package:mydartapi_v1_api/mydartapi_v1_api_client.dart' as myapi_client;

void main() {
  var api = new myapi.MyDartApi();
  var container = querySelector('#output');
  api.test.get().then((myapi_client.MyResponse response) {
    container.appendText(response.toString());
  });
}
