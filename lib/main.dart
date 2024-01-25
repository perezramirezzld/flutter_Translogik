

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
    final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
    late BluetoothConnection connection;
    late List<BluetoothDevice> _devicesList = [];
    List <Map<String, String>> inComingData = [];

    StreamSubscription<List<int>>? dataSubscription;

    bool devicesLoad = false;
    bool get isConnected => connection.isConnected;
    String devicesMacAddress = "";
    String text = "";

    @override
    void initState() {
      super.initState();
      _requestPermission();
      FlutterBluetoothSerial.instance.requestEnable();
    }


    void _requestPermission() async {
      await Permission.location.request();
      await Permission.storage.request();
      await Permission.bluetooth.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
    }

Future<List<BluetoothDevice>> getPairedDevices() async {
    List<BluetoothDevice> getDevicesList = [];
    try {
      getDevicesList = await _bluetooth.getBondedDevices();
    } on PlatformException {
      print("Error");
    }
    return getDevicesList;
  }

  void showSnackBar(String value){
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        margin: const EdgeInsets.all(50),
        elevation: 1,
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void searchDevices()async{
    _devicesList = await getPairedDevices();
    setState(() {
      _devicesList;
      devicesLoad=true;
    });
  }

  void disconnectDevice(){
    setState(() {
      devicesMacAddress='';
      inComingData=[];
    });
    connection.close();
  }

  void connectDevice(String address){
    BluetoothConnection.toAddress(address).then((conn) {
      connection = conn;
      setState(() {
        devicesMacAddress=address;
      });
      listenForData();
    });
  }
  void ResumeForData(){
    dataSubscription?.resume();
  }

  void funcTread(){

  }

  void listenForData(){  
      String Datatype = '' ;
      bool IsPressure = false;

    connection.input!.listen((Uint8List data) {
      bool valido = false;
      String serialData = ascii.decode(data);

      if(serialData[0].contains('T')){
        Datatype = '';
        IsPressure = false;
      }
      if(serialData[0].contains('P')){
        Datatype = '';
        IsPressure = true;
      }

      if(!IsPressure){
      for (int i = 0; i < serialData.length; i++) {
        Datatype = Datatype + serialData[i];
      }
      if(Datatype.length >= 5){
        valido = true;
      }
      }else{
        for (int i = 0; i < serialData.length; i++) {
        Datatype = Datatype + serialData[i];
      }
        if(Datatype.length >= 6){
        valido = true;
      }
      }


     if(valido){
          showSnackBar('Recibiendo datos $Datatype');
        setState(() {
        inComingData.insert(0,
          {
            "time": DateFormat('HH:mm:ss').format(DateTime.now()),
            "data": Datatype
          });
           valido = false;
          Datatype = '';
          serialData = '';
          data = Uint8List.fromList([]);
          IsPressure= false;
          Future.delayed( const Duration(milliseconds: 2             
        ), () {
          listenForData();
        });
      });
        }
       
      if (ascii.decode(data).contains('!')) {
      dataSubscription?.cancel(); // Cancelar la suscripción cuando se encuentra '!'.
      connection.finish();
      print('Disconnecting by local host');
    }
  }, onDone: () {
    print('Disconnected by remote request');
  });
}

//Para enviar comandos al dispositivo
 void sendMessageBluetooth() async {
  try {
    print('Sending data');
    showSnackBar('Enviando datos');
    // Adjust command string based on device requirements
    connection.output.add(Uint8List.fromList(utf8.encode("X4" "\r\n")));
      await connection.output.allSent;// Wait for data to be sent

    // Optionally flush the output stream
   // connection.output.flush();

  } catch (error) {
    print('Error sending command: $error');
    // Handle the error appropriately
  }
}

  @override
  void dispose() {
    if (isConnected) {
      connection.dispose();
    }
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
     resizeToAvoidBottomInset: true,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        title: const Text('Comunicacion datos serie'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: ()=> searchDevices(),
                  child: const Text('Buscar dispositivos')
                )
              ),
              if(devicesLoad && _devicesList.isNotEmpty) Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black12,
                    width: 1,
                  ),
                ),

                height: 200,
                width: double.infinity,
                child:
                ListView.builder(
                  physics: _devicesList.length < 3 ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
                  itemCount: _devicesList.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      onTap: () => devicesMacAddress!=_devicesList[index].address.toString() ? connectDevice(_devicesList[index].address.toString()) : disconnectDevice(),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _devicesList[index].name.toString(),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: devicesMacAddress!=_devicesList[index].address.toString() ? Colors.blue : Colors.green
                            ),
                          ),
                          Text(
                              _devicesList[index].address.toString(),
                              style: const TextStyle(fontWeight: FontWeight.w300)
                          )
                        ],
                      ),
                      subtitle: devicesMacAddress!=_devicesList[index].address.toString() ? const Text("Clic para conectar") : const Text('Clic para desconectar'),
                    );
                  },
                )
              ),
               SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: devicesMacAddress.isNotEmpty ? () => ResumeForData(): null,
                  child: const Text('Capturar datos')
                ),
              ),
              if(devicesMacAddress.isNotEmpty)const Padding(
                padding: EdgeInsets.only(top:10.0),
                child: Text('Datos entrantes'),
              ),
              if(devicesMacAddress.isNotEmpty)Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black12,
                    width: 1,
                  ),
                ),
                child: ListView.builder(
                  physics: inComingData.length < 4 ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(0),
                  itemCount: inComingData.length,
                  itemBuilder: (ctx, i){
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                      child: RichText(
                        text: TextSpan(
                          text: '${inComingData[i]['time']}   ',
                          style: const TextStyle(color: Colors.black54, fontSize: 13),
                          children: <TextSpan>[
                            TextSpan(
                              text: '${inComingData[i]['data']} ',
                              style: const TextStyle(color: Colors.black, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    );
                  }),
              ),
              Center(
                child: RichText(
                  text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'kk',
                      style: TextStyle(
                        color: Colors.black26,
                        fontSize: 10
                      ),
                    ),
                    TextSpan(
                      text: 'blutuch',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 11
                      ),
                    ),
                  ],
                ),
              )
            )],
          ),
        ),
      ),
    );
  }
}
