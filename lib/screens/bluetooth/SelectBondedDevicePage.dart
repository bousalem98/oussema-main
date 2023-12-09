// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:ghada/utils/colors.dart';
import 'package:permission_handler/permission_handler.dart';
import './BluetoothDeviceListEntry.dart';

class SelectBondedDevicePage extends StatefulWidget {
  final bool checkAvailability;
  const SelectBondedDevicePage({this.checkAvailability = true});

  @override
  _SelectBondedDevicePage createState() => new _SelectBondedDevicePage();
}

enum _DeviceAvailability {
  // no,
  maybe,
  yes,
}

class _DeviceWithAvailability {
  BluetoothDevice device;
  _DeviceAvailability availability;
  int? rssi;

  _DeviceWithAvailability(this.device, this.availability, [this.rssi]);
}

class _SelectBondedDevicePage extends State<SelectBondedDevicePage> {
  List<_DeviceWithAvailability> devices =
      List<_DeviceWithAvailability>.empty(growable: true);

  // Availability
  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStreamSubscription;
  bool _isDiscovering = false;

  _SelectBondedDevicePage();

  @override
  Future<void> initState() async {
    super.initState();

    _isDiscovering = widget.checkAvailability;

    if (_isDiscovering) {
      _startDiscovery();
    }
    var status = await Permission.bluetoothScan.request().isGranted;
    if (!status) {
      // The user opted to never again see the permission request dialog for this
      // app. The only way to change the permission's status now is to let the
      // user manually enables it in the system settings.

      openAppSettings();
    } else {
      FlutterBluetoothSerial.instance
          .getBondedDevices()
          .then((List<BluetoothDevice> bondedDevices) {
        setState(() {
          devices = bondedDevices
              .map(
                (device) => _DeviceWithAvailability(
                  device,
                  widget.checkAvailability
                      ? _DeviceAvailability.maybe
                      : _DeviceAvailability.yes,
                ),
              )
              .toList();
        });
      });
    }
  }

  void _restartDiscovery() {
    setState(() {
      _isDiscovering = true;
    });

    _startDiscovery();
  }

  void _startDiscovery() {
    _discoveryStreamSubscription =
        FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      setState(() {
        Iterator i = devices.iterator;
        while (i.moveNext()) {
          var _device = i.current;
          if (_device.device == r.device) {
            _device.availability = _DeviceAvailability.yes;
            _device.rssi = r.rssi;
          }
        }
      });
    });

    _discoveryStreamSubscription?.onDone(() {
      setState(() {
        _isDiscovering = false;
      });
    });
  }

  @override
  void dispose() {
    _discoveryStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<BluetoothDeviceListEntry> list = devices
        .map((_device) => BluetoothDeviceListEntry(
              device: _device.device,
              rssi: _device.rssi,
              enabled: _device.availability == _DeviceAvailability.yes,
              onTap: () {
                Navigator.of(context).pop(_device.device);
              },
            ))
        .toList();

    return Scaffold(
      backgroundColor: lightColor,
      appBar: AppBar(
          backgroundColor: warmBlueColor,
          title: Text(AppLocalizations.of(context)!.selectDevice),
          actions: <Widget>[
            _isDiscovering
                ? FittedBox(
                    child: Container(
                      margin: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        color: warmBlueColor,
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.replay),
                    onPressed: _restartDiscovery,
                  )
          ],
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(50),
              bottomRight: Radius.circular(50),
            ),
          ),
          elevation: 0),
      body: ListView(children: list),
    );
  }
}