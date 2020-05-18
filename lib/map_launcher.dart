import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MapType {
  apple,
  apple_directions_mode,
  google,
  google_navigation_mode,
  waze
}

String _enumToString(o) => o.toString().split('.').last;

T _enumFromString<T>(Iterable<T> values, String value) {
  return values.firstWhere((type) => type.toString().split('.').last == value,
      orElse: () => null);
}

class Coords {
  final double latitude;
  final double longitude;

  Coords(this.latitude, this.longitude);
}

class AvailableMap {
  String mapName;
  MapType mapType;
  AssetImage icon;

  AvailableMap({this.mapName, this.mapType, this.icon});

  static AvailableMap fromJson(json) {
    return AvailableMap(
      mapName: json['mapName'],
      mapType: _enumFromString(MapType.values, json['mapType']),
      icon: AssetImage(
        'assets/icons/${json['mapType']}.png',
        package: 'map_launcher',
      ),
    );
  }

  Future<void> showMarker({
    @required Coords coords,
    @required String title,
    @required String description,
  }) {
    return MapLauncher.launchMap(
      mapType: mapType,
      coords: coords,
      title: title,
      description: description,
    );
  }

  Future<void> showMarkersForNavigation({
    @required Coords destination,
    @required String title,
    @required String description,
  }) {
    return MapLauncher.launchMapForNavigation(
      mapType: mapType,
      destination: destination,
      title: title,
      description: description,
    );
  }

  @override
  String toString() {
    return 'AvailableMap { mapName: $mapName, mapType: ${_enumToString(mapType)} }';
  }
}

String _getMapUrl(
    MapType mapType,
    Coords coords, [
      String title,
      String description,
    ]) {
  switch (mapType) {
    case MapType.google:
      if (Platform.isIOS) {
        return 'comgooglemaps://?q=${coords.latitude},${coords.longitude}($title)';
      }
      return 'geo:0,0?q=${coords.latitude},${coords.longitude}($title)';
    case MapType.apple:
      return 'http://maps.apple.com/maps?saddr=${coords.latitude},${coords.longitude}';
    case MapType.waze:
      return 'waze://?ll=${coords.latitude},${coords.longitude}&zoom=10';
    default:
      return null;
  }
}

String _getMapUrlForNavigation(
    MapType mapType,
    Coords endCoordinates, [
      String title,
      String description,
    ]) {
  switch (mapType) {
    case MapType.google_navigation_mode:
      if (Platform.isIOS) {
        // See: https://developers.google.com/maps/documentation/urls/ios-urlscheme
        return 'comgooglemaps://?daddr=${endCoordinates.latitude},${endCoordinates.longitude}&directionsmode=driving($title)';
      }
      // See: https://developers.google.com/maps/documentation/urls/android-intents#launch_turn-by-turn_navigation
      return 'google.navigation:q=${endCoordinates.latitude},${endCoordinates.longitude}($title)';
    case MapType.apple_directions_mode:
    // See: https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/MapLinks/MapLinks.html
      return 'http://maps.apple.com/maps?daddr=${endCoordinates.latitude},${endCoordinates.longitude}&dirflg=d';
    default:
      return null;
  }
}

class MapLauncher {
  static const MethodChannel _channel = const MethodChannel('map_launcher');

  static Future<List<AvailableMap>> get installedMaps async {
    final maps = await _channel.invokeMethod('getInstalledMaps');
    return List<AvailableMap>.from(
      maps.map((map) => AvailableMap.fromJson(map)),
    );
  }

  static Future<dynamic> launchMap({
    @required MapType mapType,
    @required Coords coords,
    @required String title,
    @required String description,
  }) async {
    final url = _getMapUrl(mapType, coords, title, description);
    final Map<String, String> args = {
      'mapType': _enumToString(mapType),
      'url': Uri.encodeFull(url),
      'title': title,
      'description': description,
      'latitude': coords.latitude.toString(),
      'longitude': coords.longitude.toString(),
    };
    return _channel.invokeMethod('launchMap', args);
  }

  static Future<dynamic> launchMapForNavigation({
    @required MapType mapType,
    @required Coords destination,
    @required String title,
    @required String description,
  }) async {
    final url = _getMapUrlForNavigation(
        mapType, destination, title, description);
    final Map<String, String> args = {
      'mapType': _enumToString(mapType),
      'url': Uri.encodeFull(url),
      'title': title,
      'description': description,
      'latitude': destination.latitude.toString(),
      'longitude': destination.longitude.toString(),
    };
    return Platform.isIOS
        ? _channel.invokeMethod('launchMapForNav', args)
        : _channel.invokeMethod('launchMap', args);
  }

  static Future<bool> isMapAvailable(MapType mapType) async {
    return _channel.invokeMethod(
      'isMapAvailable',
      {'mapType': _enumToString(mapType)},
    );
  }
}