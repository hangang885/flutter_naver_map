import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maptest/naver_key.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NaverMapSdk.instance.initialize(clientId: 'uwq11lzksy');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Position position;
  late final NaverMapController mapController;

  @override
  void initState() {
    super.initState();
    naverMapInitCheck();
  }

  naverMapInitCheck() async {
    await NaverMapSdk.instance.initialize(
        clientId: NaverKey.mapClientId,
        onAuthFailed: (ex) {
          print("********* 네이버맵 인증오류 : $ex *********");
        });
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    position = await Geolocator.getCurrentPosition();
    return position;
  }

  Future<void> fetchRestaurants() async {
    final Dio dio = Dio();
    final String query = '서울대입구역';
    final int display = 5; // 검색 결과 개수
    final int start = 1; // 검색 시작 위치
    final String sort = 'random'; // 정렬 옵션

    final String url = 'https://openapi.naver.com/v1/search/local.json';
    final Map<String, dynamic> headers = {
      'X-Naver-Client-Id': NaverKey.clientId,
      'X-Naver-Client-Secret': NaverKey.clientSecret,
    };
    print("position.latitude.toString() ${position.latitude.toString()}");
    print("position.longitude.toString() ${position.longitude.toString()}");
    final Map<String, dynamic> params = {
      'query': query,
      'display': display,
      'start': start,
      'sort': sort,
      'latitude': position.latitude.toString(),
      'longitude': position.longitude.toString(),
    };

    try {
      final Response response = await dio.get(url,
          queryParameters: params, options: Options(headers: headers));
      print("respones ${response.data}");
      await fetchDirections();
    } catch (e) {
      print('Error fetching restaurants: $e');
    }
  }

  Future<void> fetchDirections() async {
    final Dio dio = Dio();
    const String url = 'https://naveropenapi.apigw.ntruss.com/map-direction/v1/driving';
    final Map<String, dynamic> headers = {
      'X-NCP-APIGW-API-KEY-ID': NaverKey.mapClientId,
      'X-NCP-APIGW-API-KEY': NaverKey.mapClientSecret,
    };
    final Map<String, dynamic> params = {
      'start': '126.95275023,37.48127777',
      'goal': '127.04129285,37.51722339',
      'option': 'trafast',  // 가장 빠른 경로1
    };

    try {
      final Response response = await dio.get(url, queryParameters: params, options: Options(headers: headers));
      print("response ${response.data['route']['trafast'][0]['path']} ");
    } catch (e) {
      print('Error fetching directions: $e');
    }
  }

  setCurrentMarker() async {
    mapController.getLocationTrackingMode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _determinePosition(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return NaverMap(
              onMapTapped: (point, latLng) {
                fetchRestaurants();
              },
              options: NaverMapViewOptions(
                mapType: NMapType.basic,
                indoorEnable: true,
                locationButtonEnable: true,
                indoorLevelPickerEnable: true,
                initialCameraPosition: NCameraPosition(
                    target: NLatLng(snapshot.data?.latitude ?? 0.0,
                        snapshot.data?.longitude ?? 0.0),
                    zoom: 17,
                    bearing: 0,
                    tilt: 0),
              ),
              onMapReady: (controller) {
                print("네이버 맵 로딩됨!");
                mapController = controller;
                setCurrentMarker();
              },
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
