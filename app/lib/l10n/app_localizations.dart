import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  String get appTitle => _t('appTitle', 'BrickFinder');
  String get captureTitle => _t('captureTitle', '拍照识别');
  String get takePhoto => _t('takePhoto', '拍照');
  String get pickFromGallery => _t('pickFromGallery', '从相册选择');
  String get confirmTitle => _t('confirmTitle', '确认照片');
  String get photoSelected => _t('photoSelected', '已选 1 张照片');
  String get retake => _t('retake', '重新拍/选');
  String get startRecognize => _t('startRecognize', '开始识别');
  String get recognizing => _t('recognizing', '正在识别砖块…');
  String get estimateTime => _t('estimateTime', '大约需要 5-15 秒');
  String get cancel => _t('cancel', '取消');
  String get partList => _t('partList', '零件清单');
  String get unknownColor => _t('unknownColor', '未知颜色');
  String get emptyHome => _t('emptyHome', '点击上方按钮，拍照识别你的乐高砖块');
  String get emptyResult => _t('emptyResult', '未识别出零件，试试换个角度或光线');
  String get favorites => _t('favorites', '收藏');
  String get settings => _t('settings', '设置');
  String get history => _t('history', '历史清单');
  String get photoGuide => _t('photoGuide', '把砖块平铺在浅色背景上，不要堆叠，效果更好');
  String get retakeHint => _t('retakeHint', '建议把砖块平铺在浅色背景上识别效果更好');

  String _t(String key, String zh) {
    if (locale.languageCode == 'en') {
      return _enStrings[key] ?? zh;
    }
    return zh;
  }

  static const Map<String, String> _enStrings = {
    'appTitle': 'BrickFinder',
    'captureTitle': 'Scan',
    'takePhoto': 'Take Photo',
    'pickFromGallery': 'Choose from Gallery',
    'confirmTitle': 'Confirm Photo',
    'photoSelected': '1 photo selected',
    'retake': 'Retake',
    'startRecognize': 'Start Recognition',
    'recognizing': 'Recognizing bricks…',
    'estimateTime': 'About 5-15 seconds',
    'cancel': 'Cancel',
    'partList': 'Parts List',
    'unknownColor': 'Unknown color',
    'emptyHome': 'Tap the button above to scan your Lego bricks',
    'emptyResult': 'No parts recognized. Try a different angle or lighting',
    'favorites': 'Favorites',
    'settings': 'Settings',
    'history': 'History',
    'photoGuide': 'Place bricks on a light background for best results',
    'retakeHint': 'Place bricks on a light background for better recognition',
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['zh', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
