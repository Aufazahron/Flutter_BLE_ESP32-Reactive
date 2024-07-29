import 'dart:async';
import 'dart:convert';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class BleController extends GetxController {
  final flutterReactiveBle = FlutterReactiveBle();
  final _devices = <DiscoveredDevice>[].obs;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _notificationSubscription;
  DiscoveredDevice? _connectedDevice;
  var isScanning = false.obs;
  var isConnected = false.obs;
  var receivedData = "".obs;
  var sensorDataList = <Map<String, dynamic>>[].obs;

  final Uuid serviceUuid = Uuid.parse("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  final Uuid characteristicUuid = Uuid.parse("beb5483e-36e1-4688-b7f5-ea07361b26a8");

  @override
  void onClose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.onClose();
  }

  Future<void> scanDevices() async {
    var blePermission = await Permission.bluetoothScan.status;
    if (blePermission.isDenied) {
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
    }

    isScanning.value = true;

    _scanSubscription = flutterReactiveBle.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
      requireLocationServicesEnabled: true,
    ).listen((device) {
      if (!_devices.any((d) => d.id == device.id)) {
        _devices.add(device);
      }
    });

    // Stop scanning after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      _scanSubscription?.cancel();
      isScanning.value = false;
    });
  }

  void stopScanning() {
    _scanSubscription?.cancel();
    isScanning.value = false;
  }

  Future<void> connectToDevice(DiscoveredDevice device) async {
    final connection = flutterReactiveBle.connectToDevice(
      id: device.id,
      servicesWithCharacteristicsToDiscover: {serviceUuid: [characteristicUuid]},
    );

    _connectionSubscription = connection.listen((connectionState) async {
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        _connectedDevice = device;
        isConnected.value = true;

        // Request MTU size change
        await flutterReactiveBle.requestMtu(deviceId: device.id, mtu: 200);

        // Delay 2 seconds before reading data
        await Future.delayed(const Duration(seconds: 2));

        final characteristic = QualifiedCharacteristic(
          serviceId: serviceUuid,
          characteristicId: characteristicUuid,
          deviceId: device.id,
        );

        _notificationSubscription = flutterReactiveBle
            .subscribeToCharacteristic(characteristic)
            .listen((data) {
          String receivedString = utf8.decode(data);
          receivedData.value = receivedString;
          _parseSensorData(receivedString);
        });

        print("Connected to ${device.name}");
      } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
        _notificationSubscription?.cancel();
        _connectedDevice = null;
        isConnected.value = false;
      }
    });
  }

  void disconnectFromDevice() {
    _notificationSubscription?.cancel();
    _connectionSubscription?.cancel();
    _connectedDevice = null;
    isConnected.value = false;
  }

  Future<void> sendDataToConnectedDevice(List<int> data) async {
    if (_connectedDevice == null) return;

    final characteristic = QualifiedCharacteristic(
      serviceId: serviceUuid,
      characteristicId: characteristicUuid,
      deviceId: _connectedDevice!.id,
    );

    await flutterReactiveBle.writeCharacteristicWithResponse(characteristic, value: data);
  }

  void sendRequestToEsp32() {
    sendDataToConnectedDevice(utf8.encode("send"));
  }

  List<DiscoveredDevice> get devices => _devices;

  String get connectedDeviceName => _connectedDevice?.name ?? "Unknown Device";

  void _parseSensorData(String data) {
    List<String> lines = data.split('\n');
    for (String line in lines) {
      List<String> parts = line.split(',');
      if (parts.length == 11) {
        Map<String, dynamic> sensorData = {
          'ID': parts[0],
          'Location': parts[1],
          'Type': parts[2],
          'Date': parts[3],
          'Clock': parts[4],
          'O3': parts[5],
          'NO2': parts[6],
          'SO2': parts[7],
          'NMHC': parts[8],
          'NH3': parts[9],
          'H2S': parts[10],
        };
        sensorDataList.add(sensorData);
      }
    }
  }
}
