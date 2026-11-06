import 'package:flutter/material.dart';
import '../widgets/xq/xq_icons.dart';
import 'package:provider/provider.dart';
import '../stores/theme_state.dart';

class LegalPage extends StatelessWidget {
  final bool isPrivacy;

  const LegalPage({super.key, this.isPrivacy = true});

  static const _privacyContent = '''
隐私政策

更新日期：2026年5月25日
生效日期：2026年5月25日

本政策依据《中华人民共和国个人信息保护法》(2021)、《App违法违规收集使用个人信息行为认定方法》、《常见类型移动互联网应用程序必要个人信息范围规定》等法律法规制定。

一、我们收集的信息

1. 账号信息：注册或登录时提交的手机号、昵称及加密密码。
2. 内容信息：你主动填写的心情记录、日记、树洞内容、时光胶囊、好友互动内容。
3. 位置信息：你授权定位权限后，用于获取城市天气和城迹功能。
4. 设备信息：设备型号、系统版本、网络环境等必要技术信息。
5. 验证码信息：找回密码等安全验证场景下，通过短信发送的一次性验证码。

我们不收集：通讯录、短信记录、浏览历史、行踪轨迹。

二、信息使用目的

1. 完成注册登录、身份校验、账号安全与密码找回。
2. 提供天气查询、心情记录、日记、树洞、好友互动、时光胶囊等核心服务。
3. 维护服务稳定性、故障排查与异常风控。
4. 你开启提醒功能后，在设备本地展示签到、胶囊到期等提醒。

三、信息存储与安全

1. 密码通过加密散列存储，不以明文保存。
2. 业务数据存储于服务器，超出必要期限后依法删除或匿名化。
3. 接口访问、异常行为与数据写入在必要范围内进行安全控制。

四、权限说明

1. 定位权限：获取所在城市天气信息。
2. 相册权限：选择头像或记录照片。
3. 通知权限：展示签到与胶囊到期提醒。
4. 权限可在系统设置中随时关闭。

五、你的权利

你可依法访问、更正、删除个人信息，申请注销账号（App内「我的 → 退出登录 → 彻底注销账号」），或撤回权限授权。联系我们：QQ交流群或App内反馈渠道。
''';

  static const _termsContent = '''
用户协议

更新日期：2026年5月25日
生效日期：2026年5月25日

一、服务说明

拾晴日记提供天气查询、心情记录、日记、树洞、好友互动、时光胶囊等服务。我们会在现有技术能力范围内持续优化，但不保证所有功能在任何情况下均无中断。

二、账号使用

1. 你应通过真实手机号注册账号，并妥善保管密码及验证码。
2. 你应对账号下发生的操作承担相应责任。
3. 注销账号后重新注册，将创建新账号身份。

三、用户行为规范

你不得利用本应用从事以下行为：
1. 发布违法、侮辱、仇恨、淫秽、骚扰或侵犯他人权益的内容；
2. 冒充他人、恶意骚扰或干扰其他用户；
3. 利用技术手段攻击、抓取或批量滥用的行为；
4. 其他违反法律法规的行为。

四、内容权利

你发布的内容知识产权归你所有，但你在使用本服务所必需的范围内授权我们进行存储、展示与必要处理。

五、服务限制

1. 天气服务依赖第三方数据源，不对实时准确性作无限承诺。
2. 提醒功能受系统权限与设备状态影响，极端情况可能延迟或未展示。
3. 本应用不构成医疗或心理诊断建议。

六、协议更新

我们可能根据业务调整或法律要求更新本协议，更新后在应用内展示即生效。

七、争议解决

本协议适用中华人民共和国法律。协商不成的，可依法向有管辖权的人民法院提起诉讼。
''';

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    final title = isPrivacy ? '隐私政策' : '用户协议';
    final content = isPrivacy ? _privacyContent : _termsContent;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(title, style: TextStyle(color: theme.textPrimary)),
        backgroundColor: theme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: XqIcon(XqIcons.back, color: theme.accentColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(
            content,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 14,
              height: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}
