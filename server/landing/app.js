// 微信 / QQ 内置浏览器不让下载安装包：点下载时提示从右上角换到浏览器打开
(function () {
  var ua = navigator.userAgent || '';
  var inApp = /MicroMessenger|QQ\//i.test(ua);
  var tip = document.getElementById('open-in-browser');
  var btn = document.getElementById('download');
  if (inApp && btn && tip) {
    btn.addEventListener('click', function (e) {
      e.preventDefault();
      tip.hidden = false;
    });
    tip.addEventListener('click', function () { tip.hidden = true; });
  }
  if (/[?&]from=card/.test(location.search)) {
    var card = document.getElementById('from-card');
    if (card) card.hidden = false;
  }
})();
