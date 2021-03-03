import 'dart:convert';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:posso_estender_roupa/secret.dart';

Future<EstenderRoupaLocal> _fetchLocal() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.deniedForever) {
    return Future.error(
        'Location permissions are permantly denied, we cannot request permissions.');
  }

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return Future.error(
          'Location permissions are denied (actual value: $permission).');
    }
  }

  var currentPosition = await Geolocator.getCurrentPosition();

  return EstenderRoupaLocal(
      currentPosition.latitude, currentPosition.longitude);
}

class EstenderRoupaLocal {
  final double latitude;
  final double longitude;
  EstenderRoupaLocal(this.latitude, this.longitude);
}

Future<EstenderRoupaModel> _getData() async {
  final local = await _fetchLocal();
  Secret secret = await SecretLoader(secretPath: "secrets.json").load();
  final appkey = secret.apiKey;
  String url =
      "http://api.weatherapi.com/v1/forecast.json?key=$appkey&q=${local.latitude},${local.longitude}&days=2";

  final weather = await http.get(url);
  if (weather.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    return EstenderRoupaModel(weather.body);
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load weather');
  }
}

class EstenderRoupaModel {
  dynamic model;
  List<charts.Series<TimeSeriesWeather, DateTime>> chartData;

  EstenderRoupaModel(String json) {
    this.model = jsonDecode(json);
    chartData = new List<charts.Series<TimeSeriesWeather, DateTime>>();
    createChartData(this.model);
  }

  void createChartData(model) {
    List<TimeSeriesWeather> temp = new List<TimeSeriesWeather>();
    List<TimeSeriesWeather> precip = new List<TimeSeriesWeather>();
    List<TimeSeriesWeather> humidity = new List<TimeSeriesWeather>();
    for (var forecastday in model['forecast']['forecastday']) {
      for (var hour in forecastday['hour']) {
        DateTime dt = DateTime.parse(hour['time']);
        temp.add(new TimeSeriesWeather(dt, hour['temp_c']));
        precip.add(new TimeSeriesWeather(dt, hour['precip_mm']));
        int ih = hour['humidity'];
        humidity.add(new TimeSeriesWeather(dt, ih.toDouble()));
      }
    }

    chartData.add(new charts.Series<TimeSeriesWeather, DateTime>(
      id: 'temp',
      domainFn: (TimeSeriesWeather sales, _) => sales.time,
      measureFn: (TimeSeriesWeather sales, _) => sales.value,
      data: temp,
    ));
    chartData.add(new charts.Series<TimeSeriesWeather, DateTime>(
      id: 'precip',
      domainFn: (TimeSeriesWeather sales, _) => sales.time,
      measureFn: (TimeSeriesWeather sales, _) => sales.value,
      data: precip,
    ));
    chartData.add(new charts.Series<TimeSeriesWeather, DateTime>(
      id: 'humidade',
      domainFn: (TimeSeriesWeather sales, _) => sales.time,
      measureFn: (TimeSeriesWeather sales, _) => sales.value,
      data: humidity,
    ));
  }
}

class TimeSeriesWeather {
  final DateTime time;
  final double value;

  TimeSeriesWeather(this.time, this.value);
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Posso Estender Roupa',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Posso Estender Roupa'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<EstenderRoupaLocal> futureLocal;
  Future<EstenderRoupaModel> futureModel;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    futureModel = _getData();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Posso Estender Roupa",
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Posso Estender Roupa'),
        ),
        body: Center(
          child: FutureBuilder<EstenderRoupaModel>(
              future: futureModel,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Container(
                    padding: EdgeInsets.all(10),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Image.network(
                                              "https:${snapshot.data.model['current']['condition']['icon']}")
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Text("Local:"),
                                          Text(snapshot.data.model['location']
                                              ['name']),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Text("Região:"),
                                          Text(snapshot.data.model['location']
                                              ['region']),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Text("Pais:"),
                                          Text(snapshot.data.model['location']
                                              ['country']),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Text("Lat e Lon:"),
                                          Text(
                                              "${snapshot.data.model['location']['lat']},${snapshot.data.model['location']['lon']}"),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Text("Temperatura:"),
                                          Text(
                                              "${snapshot.data.model['current']['temp_c']} C"),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Text("Vento:"),
                                          Text(
                                              "${snapshot.data.model['current']['wind_kph']} Kp/h"),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Text("Precipitação:"),
                                          Text(
                                              "${snapshot.data.model['current']['precip_mm']} mm de chuva"),
                                        ],
                                      ),
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceEvenly,
                                                children: [
                                                  for (var day in snapshot.data
                                                          .model["forecast"]
                                                      ["forecastday"])
                                                    Column(children: [
                                                      Row(
                                                        children: [
                                                          Text(
                                                            "Posso estender a roupa no dia ${day['date']}  ...",
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                          if (day['day'][
                                                                  'daily_will_it_rain'] !=
                                                              0)
                                                            Image.asset(
                                                              'images/clothes-line-no.png',
                                                              height: 64,
                                                              width: 64,
                                                            )
                                                          else
                                                            Image.asset(
                                                              'images/clothes-line-yes.png',
                                                              height: 64,
                                                              width: 64,
                                                            ),
                                                        ],
                                                      ),
                                                      Row(
                                                        children: [
                                                          Text(
                                                            "Probabilidade de chuva ${day['day']['daily_chance_of_rain']} %",
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          )
                                                        ],
                                                      )
                                                    ]),
                                                ])
                                          ]),
                                      Row(
                                        children: [
                                          Padding(
                                            padding: new EdgeInsets.all(32.0),
                                            child: new SizedBox(
                                              width: 300.0,
                                              height: 250.0,
                                              child: charts.TimeSeriesChart(
                                                snapshot.data.chartData,
                                                animate: true,
                                                primaryMeasureAxis: new charts
                                                        .NumericAxisSpec(
                                                    tickProviderSpec: new charts
                                                            .BasicNumericTickProviderSpec(
                                                        desiredTickCount: 4)),
                                                domainAxis: new charts
                                                        .DateTimeAxisSpec(
                                                    tickFormatterSpec: new charts
                                                            .AutoDateTimeTickFormatterSpec(
                                                        day: new charts
                                                                .TimeFormatterSpec(
                                                            format: 'dd/MM',
                                                            transitionFormat:
                                                                'dd/MM'))),
                                                behaviors: [
                                                  new charts.SeriesLegend(
                                                    position: charts
                                                        .BehaviorPosition.end,
                                                    horizontalFirst: false,
                                                    cellPadding:
                                                        new EdgeInsets.only(
                                                            right: 4.0,
                                                            bottom: 4.0),
                                                  ),
                                                  new charts.RangeAnnotation([
                                                    new charts
                                                            .LineAnnotationSegment(
                                                        DateTime.now(),
                                                        charts
                                                            .RangeAnnotationAxisType
                                                            .domain,
                                                        color: charts
                                                            .MaterialPalette
                                                            .green
                                                            .shadeDefault,
                                                        startLabel: 'Hoje'),
                                                  ]),
                                                ],
                                              ),
                                            ),
                                          )
                                        ],
                                      )
                                    ]),
                              ]),
                        ]),
                  );
                } else if (snapshot.hasError) {
                  return Text("${snapshot.error}");
                }
                return CircularProgressIndicator();
              }),
        ),
      ),
    );
  }
}
