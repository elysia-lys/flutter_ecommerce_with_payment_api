# Flutter E-commerce with Internet Payment Gateway Integration

This is an e-commerce project using flutter to create an workable andriod application, integrating with our 

### AMPERSANDPAY PAYMENET GATEWAY.
---
###### Flutter is a framework tools which uses the language Dart. Hence alot of dependencies and versions you can get from https://pub.dev/ 
#### Documents 
##### Docs 
- e-commerce api
- e-commerce ipg
##### Tools
- firebase
- flutter sdk
- postman
- vscode
---
#### Important source files
- order_checkout.dart
- call_api.dart
- payment_webview.dart
- query-transaction.dart
- finish_checkout.dart
##### These files are important for the linking between e-commerce and payment gateway
---
#### When starting and running the program
You can just run & debugged, but it will take quite some time for it to load finish.

So, you can just run, to create the build file

Then stop running and type 'flutter run --' on your terminal

It should start the app faster than running 'run & debugged' 

#### For firebase
There is 1 collection in firebase call "paidProducts". 

The delivery status in paidProducts can vary by 'admin' changing it manually
- not_started
- delivering
- Completed (this will automatically set when user click 'order receive' button)

#### Andriod version
Andriod version below 9, is not compatible, it may be because of the dart versions

but the payment SSL certificate is new, hence it may also not work when it reach the payment part. 
### For more info about flutter: 
- https://docs.flutter.dev/ flutter docs
- https://docs.flutter.dev/get-started/codelab write your first app with flutter tutorial
- https://pub.dev/ get dart dependencies version
--- 
