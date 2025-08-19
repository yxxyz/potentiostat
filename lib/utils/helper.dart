import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

///////////////////////// BLE FUNCTIONS /////////////////////////////////////

/// Function to send data via BLE
Future<void> sendData({
  required BluetoothCharacteristic? characteristic,
  required List<int> data,
}) async {
  if (characteristic != null) {
    try {
      await characteristic.write(data, withoutResponse: false);
      print("Data sent: $data");
    } catch (e) {
      print("Error sending data: $e");
    }
  } else {
    print("Write characteristic not found!");
  }
}

Future<void> enableNotifications({
required BluetoothCharacteristic characteristic,
required Function(BluetoothCharacteristic) onACKReceived,
// required Function(List<int>) onDataReceived,
}) async {
  try {
    await characteristic.setNotifyValue(true);
    characteristic.lastValueStream.listen((value) {
      String received = String.fromCharCodes(value);
      print("Received: $received");

      // Check for ACK response
      if (received.trim() == "ACK") {
        print("✅ ACK received. Proceeding to the next page...");
        onACKReceived(characteristic);  // Call the provided callback for ACK
      }
    });

    print("✅ Notifications enabled for characteristic: ${characteristic.uuid}");
  } catch (e) {
    print("⚠️ Error enabling notifications: $e");
  }
}

Future<void> discoverServices({
  required BluetoothDevice device,
  required Function(BluetoothCharacteristic) onCharacteristicFound,
  // required Function(BluetoothCharacteristic) onACKReceived,
}) async {
  List<BluetoothService> services = await device.discoverServices();

  for (BluetoothService service in services) {
    print("Service UUID: ${service.uuid}");
    for (BluetoothCharacteristic characteristic in service.characteristics) {
      print("Characteristic UUID: ${characteristic.uuid}");

      // Check for the FFE0/FFE1 HM10 service & characteristic
      if (service.uuid.toString().toLowerCase().contains("ffe0") &&
          characteristic.uuid.toString().toLowerCase().contains("ffe1")) {
        print("HM10 characteristic found: ${characteristic.uuid}");

        // Call callback to set characteristic in the widget
        onCharacteristicFound(characteristic);

        // Enable notifications with ACK handler
        // await enableNotifications(
        //   characteristic: characteristic,
        //   onACKReceived: (c) => onACKReceived(c),
        // );
      }
    }
  }
}

Future<void> connectToDevice({
  required BluetoothDevice device,
  required Function() onConnected,
  required Future<void> Function(BluetoothDevice) discoverServices,
}) async {
  try {
    print("Checking device connection state...");
    BluetoothConnectionState currentState = await device.connectionState.first;
    if (currentState != BluetoothConnectionState.connected) {
      print("Device not connected, connecting now...");
      await device.connect();
      await Future.delayed(Duration(seconds: 2));
    } 
    else {
      print("Device already connected, re-running service discovery...");
    }

    await discoverServices(device);
    onConnected(); // call the callback to update state in the UI
    print("Connected and services discovered.");
  } catch (e) {
    print("Connection failed: $e");
  }
}

////////////////////////////// SHARED WIDGETS //////////////////////////////////////
Widget buildBackIcon({
  required BuildContext context,
  required Function(int) updatePageIndex,
  required String pageKey,
  required Map<String, int> pageIndices,
  BluetoothCharacteristic? writeCharacteristic,
  List<int>? bleMessage,
}) {
  return Container(
    color: Colors.transparent,
    child: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, color: Color.fromARGB(255, 224, 224, 224)),
      onPressed: () async {
        print("Back button pressed. Sending '0' to Arduino...");
        if (writeCharacteristic != null && bleMessage != null) {
          await sendData(characteristic: writeCharacteristic, data: bleMessage);
        }

        final targetIndex = pageIndices[pageKey];
        if (targetIndex != null) {
          updatePageIndex(targetIndex);
        }
      },
    ),
  );
}

Widget buildNextButton({
  required bool enabled,
  required VoidCallback onPressed,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: Color.fromARGB(77, 163, 163, 163),
          disabledForegroundColor: Colors.white70,
        ),
        child: const Text(
          "Next",
          style: TextStyle(
            color: Color.fromARGB(255, 18, 18, 18),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}