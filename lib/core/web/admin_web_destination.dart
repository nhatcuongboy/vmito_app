import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/web/app_web_view.dart';
import 'package:vmito_app/features/auth/domain/user.dart';

/// The administrator-only destinations provided by the Vmito web app.
///
/// Flutter owns their entry points and app bar while the web app owns their
/// content. Keeping the mapping here prevents paths, titles and permissions
/// from drifting apart as more embedded pages are added.
enum AdminWebDestination {
  dashboard('/admin', AppIcons.grid2x2),
  users('/admin/users', AppIcons.users),
  sessions('/admin/sessions', AppIcons.calendarMonth),
  notifications('/admin/notifications', AppIcons.notifications),
  feedback('/admin/feedback', AppIcons.chat),
  generalSettings('/admin/general', AppIcons.filter),
  levelDescriptions('/admin/level-descriptions', AppIcons.award),
  points('/admin/points', AppIcons.sparkles),
  venues('/admin/venues', AppIcons.location),
  clubApproval('/admin/clubs/pending', AppIcons.shieldCheck),
  news('/admin/news', AppIcons.news),
  welcomePopup('/admin/welcome-popups', AppIcons.megaphone);

  const AdminWebDestination(this.relativePath, this.icon);

  final String relativePath;
  final IconData icon;

  String titleFor(Locale locale) => switch (locale.languageCode) {
    'en' => switch (this) {
      dashboard => 'Dashboard',
      users => 'Users',
      sessions => 'Manage Sessions (Admin)',
      notifications => 'Notifications',
      feedback => 'Contact & Bug Report',
      generalSettings => 'General Settings',
      levelDescriptions => 'Level Descriptions',
      points => 'Points & Ranking',
      venues => 'Venues',
      clubApproval => 'Club Approval',
      news => 'News Management',
      welcomePopup => 'Welcome Popup',
    },
    'zh' => switch (this) {
      dashboard => '控制台',
      users => '用户',
      sessions => '赛事管理（管理员）',
      notifications => '通知',
      feedback => '联系与问题反馈',
      generalSettings => '通用设置',
      levelDescriptions => '等级说明',
      points => '积分与排名',
      venues => '场地',
      clubApproval => '审核社群',
      news => '资讯管理',
      welcomePopup => '欢迎弹窗',
    },
    _ => switch (this) {
      dashboard => 'Bảng điều khiển',
      users => 'Người dùng',
      sessions => 'Quản lý kèo (Admin)',
      notifications => 'Thông báo',
      feedback => 'Liên hệ & Báo lỗi',
      generalSettings => 'Cài đặt chung',
      levelDescriptions => 'Mô tả trình độ',
      points => 'Điểm & xếp hạng',
      venues => 'Sân bãi',
      clubApproval => 'Duyệt nhóm',
      news => 'Quản lý tin tức',
      welcomePopup => 'Popup chào mừng',
    },
  };

  AppWebPage pageFor(Locale locale) {
    final languageCode = locale.languageCode == 'zh'
        ? 'cn'
        : locale.languageCode;
    return AppWebPage(
      path: '/$languageCode$relativePath',
      title: titleFor(locale),
      requiresAuth: true,
      embedded: true,
    );
  }
}

/// Opens an admin web page only for an administrator, even if a caller bypasses
/// the drawer's visibility condition.
Future<void> openAdminWebDestination(
  BuildContext context,
  User? user,
  AdminWebDestination destination,
) async {
  if (!canOpenAdminWebDestination(user)) return;
  await AppWebView.open(
    context,
    ProviderScope.containerOf(context),
    destination.pageFor(Localizations.localeOf(context)),
  );
}

bool canOpenAdminWebDestination(User? user) => user?.isAdmin == true;
