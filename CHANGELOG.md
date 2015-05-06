# Changelog

## 0.4.3

- Support constructors taking arguments for message classes used only for
  responses (however not when generating client stubs inside existing
  project).
- Make sure we return header values as strings if passed as strings.

## 0.4.2

- Fix bug with handling OPTIONS request from Shelf.

## 0.4.1

- Fix windows path handling in the generate script.

## 0.4.0

- API method context with the request uri and request headers
- Change HttpApiRequest to take the requested URI instead of path and query
  parameters.
- Change RpcError's msg and code fields to message and statusCode
- Added api.dart file for use in common code shared between server and client

## 0.3.0 

- Adding support for generating Discovery Documents without running the server
- Adding support for generating Dart client stub code from the annotated server
  code

## 0.2.0

- Disallow null to be returned from method declaring a non VoidMessage return type
- Fixed bug when encoding min/max for integers in the discovery document
- Restricted the set of ApiProperty fields depending on the type of the property
- Added min/max and type bound checking for integer and double return values
- Fixed bug with DateTime default value
- Improved error messages

## 0.1.0

- Initial version
