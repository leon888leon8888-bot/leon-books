String membershipLabel(String value) {
  switch (value) {
    case 'founder':
      return '自用版';
    case 'vip':
      return '会员';
    case 'premium':
      return '高级版';
    default:
      return value.isEmpty ? '自用版' : value;
  }
}

String sourceTypeLabel(String value) {
  switch (value) {
    case 'book':
    case 'text':
      return '小说';
    case 'comic':
      return '漫画';
    case 'audio':
      return '听书';
    case 'rss':
      return 'RSS';
    default:
      return value.isEmpty ? '未知类型' : value;
  }
}

String sourceStatusLabel(String value) {
  switch (value) {
    case 'ok':
      return '可用';
    case 'unknown':
      return '未校验';
    case 'timeout':
      return '超时';
    case 'soft_fail':
      return '异常';
    case 'hard_fail':
      return '失效';
    case 'disabled':
      return '已停用';
    default:
      return value.isEmpty ? '未校验' : value;
  }
}

String importTypeLabel(String value) {
  switch (value) {
    case 'bookSource':
      return '书源';
    case 'rssSource':
      return 'RSS 源';
    case 'replaceRule':
      return '净化规则';
    case 'httpTTS':
      return '朗读音源';
    case 'theme':
      return '主题';
    case 'readConfig':
      return '阅读配置';
    case 'addToBookshelf':
      return '加入书架';
    default:
      return value.isEmpty ? '未知类型' : value;
  }
}

String themeLabel(String value) {
  switch (value) {
    case 'paper':
      return '纸张';
    case 'night':
      return '夜间';
    default:
      return value.isEmpty ? '默认' : value;
  }
}

String pageModeLabel(String value) {
  switch (value) {
    case 'slide':
      return '翻页';
    case 'scroll':
      return '滚动';
    default:
      return value.isEmpty ? '默认' : value;
  }
}

String fontFamilyLabel(String value) {
  switch (value) {
    case 'system':
      return '系统默认';
    case 'PingFang SC':
      return '苹方';
    default:
      return value.isEmpty ? '系统默认' : value;
  }
}

String boolLabel(bool value) => value ? '开启' : '关闭';
