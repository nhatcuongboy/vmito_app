// The family generic is a DateTime; spelling the whole provider type out adds
// nothing over the declaration below.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/utils/minute_ticker.dart';

/// Whole minutes since a match started, updated on the minute.
///
/// Keyed by the start time rather than the court id so two courts started in
/// the same minute share one ticker, and so the stream restarts by itself when
/// a court begins a new match.
///
/// `autoDispose` matters here: without it every match a host ever opened would
/// keep a timer alive for the rest of the session.
final matchElapsedProvider = StreamProvider.autoDispose.family<int, DateTime>(
  (ref, startTime) => minuteTicker(startTime),
);
