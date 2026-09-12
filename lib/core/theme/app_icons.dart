import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

/// Centralized icon registry mapping semantic UI icons to Lucide icons.
///
/// Designed to align Flutter app icons with `vmito-fe` (which uses `lucide-react`).
abstract final class AppIcons {
  // --- Navigation & Shell ----------------------------------------------------
  static const IconData home = LucideIcons.house;
  static const IconData sessions = LucideIcons.clipboard_list;
  static const IconData clipboardList = LucideIcons.clipboard_list;
  static const IconData feed = LucideIcons.newspaper;
  static const IconData notifications = LucideIcons.bell;
  static const IconData profile = LucideIcons.user;
  static const IconData venue = LucideIcons.map_pin;
  static const IconData clubs = LucideIcons.users;
  static const IconData billing = LucideIcons.receipt;
  static const IconData reminders = LucideIcons.bell_ring;
  static const IconData menu = LucideIcons.menu;
  static const IconData moreVert = LucideIcons.ellipsis_vertical;
  static const IconData moreHorizontal = LucideIcons.ellipsis;

  // --- Actions & Controls ----------------------------------------------------
  static const IconData search = LucideIcons.search;
  static const IconData searchOff = LucideIcons.search_x;
  static const IconData searchHistory = LucideIcons.rotate_ccw_clock;
  // Discovery entries reuse the entity icon in its "search" variant so they
  // stay distinguishable from the management entries for the same entity.
  static const IconData searchSessions = LucideIcons.calendar_search;
  static const IconData searchVenues = LucideIcons.map_pin_search;
  static const IconData searchClubs = LucideIcons.user_round_search;
  static const IconData close = LucideIcons.x;
  static const IconData cancel = LucideIcons.circle_x;
  static const IconData add = LucideIcons.plus;
  static const IconData addCircle = LucideIcons.circle_plus;
  static const IconData removeCircle = LucideIcons.circle_minus;
  static const IconData queueNext = LucideIcons.list_plus;
  static const IconData delete = LucideIcons.trash;
  static const IconData edit = LucideIcons.pencil;
  static const IconData share = LucideIcons.share_2;
  static const IconData externalLink = LucideIcons.external_link;
  static const IconData chevronRight = LucideIcons.chevron_right;
  static const IconData chevronLeft = LucideIcons.chevron_left;
  static const IconData chevronDown = LucideIcons.chevron_down;
  static const IconData chevronUp = LucideIcons.chevron_up;
  static const IconData sortAlpha = LucideIcons.arrow_down_a_z;
  static const IconData sortAlphaDesc = LucideIcons.arrow_down_z_a;
  static const IconData sortOrder = LucideIcons.arrow_up_down;
  static const IconData sortNumberAsc = LucideIcons.arrow_up_0_1;
  static const IconData sortNumberDesc = LucideIcons.arrow_down_0_1;
  static const IconData calendarClock = LucideIcons.calendar_clock;
  static const IconData calendarArrowDown = LucideIcons.calendar_arrow_down;
  static const IconData trendingUp = LucideIcons.trending_up;
  static const IconData grid2x2 = LucideIcons.grid_2x2;
  static const IconData arrowBack = LucideIcons.arrow_left;
  static const IconData arrowForward = LucideIcons.arrow_right;
  static const IconData arrowUpward = LucideIcons.arrow_up;
  static const IconData arrowDownward = LucideIcons.arrow_down;
  static const IconData refresh = LucideIcons.rotate_cw;
  static const IconData filter = LucideIcons.sliders_horizontal;
  static const IconData tune = LucideIcons.sliders_vertical;
  static const IconData settings = LucideIcons.settings;
  static const IconData check = LucideIcons.check;
  static const IconData checkCircle = LucideIcons.circle_check;
  static const IconData checkAll = LucideIcons.check_check;
  static const IconData info = LucideIcons.info;
  static const IconData warning = LucideIcons.triangle_alert;
  static const IconData error = LucideIcons.circle_alert;
  static const IconData help = LucideIcons.circle_question_mark;
  static const IconData copy = LucideIcons.copy;
  static const IconData history = LucideIcons.rotate_ccw;
  static const IconData link = LucideIcons.link;
  static const IconData download = LucideIcons.download;
  static const IconData upload = LucideIcons.upload;
  static const IconData save = LucideIcons.save;
  static const IconData undo = LucideIcons.undo_2;
  static const IconData repeat = LucideIcons.repeat;
  static const IconData shuffle = LucideIcons.shuffle;
  static const IconData calculator = LucideIcons.calculator;

  // --- Visibility & Security -------------------------------------------------
  static const IconData eye = LucideIcons.eye;
  static const IconData eyeOff = LucideIcons.eye_off;
  static const IconData lock = LucideIcons.lock;
  static const IconData biometric = LucideIcons.scan_face;
  static const IconData fingerprint = LucideIcons.fingerprint_pattern;
  static const IconData shield = LucideIcons.shield;
  static const IconData shieldCheck = LucideIcons.shield_check;
  static const IconData verified = LucideIcons.badge_check;
  static const IconData login = LucideIcons.log_in;
  static const IconData logout = LucideIcons.log_out;

  // --- Time & Location -------------------------------------------------------
  static const IconData calendar = LucideIcons.calendar;
  static const IconData calendarMonth = LucideIcons.calendar_days;
  static const IconData calendarX = LucideIcons.calendar_x;
  static const IconData clock = LucideIcons.clock;
  static const IconData timer = LucideIcons.timer;
  static const IconData hourglass = LucideIcons.hourglass;
  static const IconData mapPin = LucideIcons.map_pin;
  static const IconData location = LucideIcons.map_pin;
  static const IconData addLocation = LucideIcons.map_pin_plus;
  static const IconData navigation = LucideIcons.navigation;
  static const IconData directions = LucideIcons.route;
  static const IconData myLocation = LucideIcons.crosshair;

  // --- Media & Social --------------------------------------------------------
  static const IconData star = LucideIcons.star;
  static const IconData trophy = LucideIcons.trophy;
  static const IconData award = LucideIcons.award;
  static const IconData crown = LucideIcons.crown;
  static const IconData layers = LucideIcons.layers;
  static const IconData gavel = LucideIcons.gavel;
  static const IconData sparkles = LucideIcons.sparkles;
  static const IconData flame = LucideIcons.flame;
  static const IconData flameFilled = Icons.local_fire_department;
  static const IconData favorite = LucideIcons.heart;
  static const IconData favoriteFilled = Icons.favorite;
  static const IconData chat = LucideIcons.message_square;
  static const IconData send = LucideIcons.send;
  static const IconData mail = LucideIcons.mail;
  static const IconData phone = LucideIcons.phone;
  static const IconData car = LucideIcons.car_front;
  static const IconData canteen = LucideIcons.utensils_crossed;
  static const IconData wifi = LucideIcons.wifi;
  static const IconData camera = LucideIcons.camera;
  static const IconData image = LucideIcons.image;
  static const IconData imagePlus = LucideIcons.image_plus;
  static const IconData imageOff = LucideIcons.image_off;
  static const IconData facebook = Icons.facebook;
  static const IconData play = LucideIcons.play;
  static const IconData playCircle = LucideIcons.circle_play;
  static const IconData pause = LucideIcons.pause;
  static const IconData stop = LucideIcons.square;
  static const IconData square = LucideIcons.square;
  static const IconData volume = LucideIcons.volume_2;

  // --- Sports & Badges -------------------------------------------------------
  static const IconData court = LucideIcons.dumbbell;
  static const IconData tag = LucideIcons.tag;
  static const IconData badge = LucideIcons.badge;
  static const IconData grid = LucideIcons.grid_3x3;
  static const IconData list = LucideIcons.list;
  static const IconData users = LucideIcons.users;
  static const IconData user = LucideIcons.user;
  static const IconData male = LucideIcons.mars;
  static const IconData female = LucideIcons.venus;
  static const IconData userPlus = LucideIcons.user_plus;
  static const IconData userCheck = LucideIcons.user_check;
  static const IconData userMinus = LucideIcons.user_minus;
  static const IconData handshake = LucideIcons.handshake;
  static const IconData swords = LucideIcons.swords;
  static const IconData pin = LucideIcons.pin;
  static const IconData language = LucideIcons.globe;
  static const IconData wifiOff = LucideIcons.wifi_off;
  static const IconData campaign = LucideIcons.megaphone;
  static const IconData circle = LucideIcons.circle;

  // --- Financial & Commerce --------------------------------------------------
  static const IconData bank = LucideIcons.landmark;
  static const IconData banknote = LucideIcons.banknote;
  static const IconData building = LucideIcons.building_2;
  static const IconData dollarCircle = LucideIcons.circle_dollar_sign;
  static const IconData dollarSign = LucideIcons.dollar_sign;
  static const IconData creditCard = LucideIcons.credit_card;
  static const IconData priceTag = LucideIcons.badge_dollar_sign;
  static const IconData receipt = LucideIcons.receipt;
  static const IconData ticket = LucideIcons.ticket;

  // --- Theme & Notes ---------------------------------------------------------
  static const IconData themeSystem = Icons.brightness_auto;
  static const IconData dark = LucideIcons.moon;
  static const IconData light = LucideIcons.sun;
  static const IconData notes = LucideIcons.notebook_text;
}
