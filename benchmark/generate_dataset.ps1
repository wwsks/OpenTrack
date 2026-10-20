# 一次性生成器：benchmark/sms_dataset.jsonl（全部虚构地名/驿站）
$rnd = New-Object System.Random(20261020)
$dir = "E:\OpenTrack\benchmark"
New-Item -ItemType Directory -Force $dir | Out-Null

$stations = [ordered]@{
  '临江大学南区菜鸟驿站' = @('临江南区菜鸟驿站','临江大学南区菜鸟驿站','临江大学南区菜鸟驿站(南苑楼一层)');
  '临江大学北区妈妈驿站' = @('临大北区妈妈驿站','临江大学北区妈妈驿站');
  '临江广场丰巢智能柜' = @('临江广场丰巢','临江广场丰巢智能柜');
  '校内快递服务中心'   = @('校内快递服务中心','校内快递服务中心(南苑楼一楼)');
  '万达广场菜鸟驿站'   = @('万达菜鸟驿站','万达广场菜鸟驿站');
  '临江大学北区菜鸟驿站' = @('临江大学北区菜鸟驿站');
}

function New-Code($kind) {
  switch ($kind) {
    'dash'   { '{0}-{1}-{2}' -f $rnd.Next(1,10), $rnd.Next(1,7), $rnd.Next(1000,9999) }
    'letter' { '{0}-{1}-{2}' -f [char](65+$rnd.Next(0,4)), $rnd.Next(1,7), $rnd.Next(1000,9999) }
    'short'  { '{0}' -f $rnd.Next(1000,9999) }
    'ab'     { '{0}{1}' -f [char](65+$rnd.Next(0,4)), $rnd.Next(10,99) }
  }
}

$lines = New-Object System.Collections.Generic.List[string]
$id = 0
function Emit($body, $code, $address, $locker, $sender, $station, $addressAny, $category) {
  $script:id++
  if (-not $category) { $category = 'standard' }
  $label = [ordered]@{ code = $code; address = $address; locker = $locker; sender = $sender }
  $any = @()
  if ($addressAny) { $any += $addressAny }
  # 带括号后缀的地址：解析器会截断括号段，两种写法都视为正确
  if ($address -match '\(.*\)$') { $any += ($address -replace '\(.*\)$','') }
  if ($any.Count -gt 0) { $label['address_any'] = $any }
  $obj = [ordered]@{ id = ('s{0:d3}' -f $script:id); body = $body; station = $station; category = $category; label = $label }
  $script:lines.Add(($obj | ConvertTo-Json -Compress -Depth 5))
}

# ---------- 干净模板（正则应能解析） ----------
foreach ($station in $stations.Keys) {
  foreach ($addr in $stations[$station]) {
    $code = New-Code 'dash'; $tail = $rnd.Next(1000,9999)
    Emit "【极兔速递】请凭${code}到${addr}取运单尾号${tail}包裹" $code $addr '' '极兔速递' $station

    $code = New-Code 'dash'
    Emit "【圆通快递】请凭${code}到${addr}取运单尾号$($rnd.Next(1000,9999))包裹" $code $addr '' '圆通快递' $station

    $code = New-Code 'letter'
    Emit "【京东快递】取件码$code，您的快件尾号$($rnd.Next(1000,9999))已送达$addr，取件和寄件可咨询 3.cn/-2O64NfS" $code $addr '' '京东快递' $station

    $code = New-Code 'short'
    Emit "【中通快递】尊敬的客户，您的包裹已到$addr，取件码$code，请及时领取" $code $addr '' '中通快递' $station

    $code = New-Code 'ab'; $locker = '{0}-{1}-{2}' -f $rnd.Next(1,10), $rnd.Next(1,7), $rnd.Next(1,50)
    Emit "【韵达快递】您的快件已存入$addr，取件码$code，柜号$locker，请24小时内取出" $code $addr $locker '韵达快递' $station '' 'nonstandard-code'

    $code = New-Code 'ab'; $locker = '{0}-{1}-{2}' -f $rnd.Next(1,10), $rnd.Next(1,7), $rnd.Next(1,50)
    Emit "【丰巢】您的包裹已存入$addr，取件码$code，柜号$locker，超时将收取滞留费" $code $addr $locker '丰巢' $station '' 'nonstandard-code'

    $code = New-Code 'short'
    Emit "【邮政快递】您有包裹已到$addr，取件码$code，请凭码取件" $code $addr '' '邮政快递' $station

    $c1 = New-Code 'short'; $c2 = New-Code 'short'
    Emit "【妈妈驿站】您有2个包裹已到$addr，取件码$c1, $c2，请尽快领取" "$c1, $c2" $addr '' '妈妈驿站' $station
  }
}

# ---------- 真实格式样例（脱敏后） ----------
Emit '【极兔速递】请凭3-2-5031到临江南区菜鸟驿站取运单尾号2081包裹' '3-2-5031' '临江南区菜鸟驿站' '' '极兔速递' '临江大学南区菜鸟驿站'
Emit '【京东快递】取件码J-2-5216，您的快件尾号1494已送达临江大学南校区服务站，地址：吉林临江市朝阳区临江大学南校区，取件和寄件可咨询 3.cn/-2O64NfS' 'J-2-5216' '吉林临江市朝阳区临江大学南校区' '' '京东快递' '校内快递服务中心' '临江大学南校区服务站'
Emit '【圆通速递】请凭4-2-4077到临江南区菜鸟驿站取件，地址：校内快递服务中心（南苑楼一楼）。' '4-2-4077' '临江南区菜鸟驿站' '' '圆通速递' '临江大学南区菜鸟驿站' '校内快递服务中心（南苑楼一楼）'
Emit '【圆通快递】请凭4-6-3017到临江南区菜鸟驿站取运单尾号6799包裹' '4-6-3017' '临江南区菜鸟驿站' '' '圆通快递' '临江大学南区菜鸟驿站'

# ---------- 难例（正则可能失败，兜底提取目标） ----------
$hard = @(
  @{ t = '亲你的快递到啦，在{addr}，码是{code}，记得拿哈'; k = 'short' },
  @{ t = '快递已到{addr}，凭{code}领取，过期退回'; k = 'short' },
  @{ t = '【菜鸟驿站】包裹到柜：{addr} 取件码：{code}'; k = 'dash' },
  @{ t = '{addr}有你的包裹，取件号码{code}，请尽快来取'; k = 'letter' },
  @{ t = '【快递通知】您有包裹待取 地点{addr} 取件码{code}'; k = 'ab' },
  @{ t = '你好，我是快递小哥，包裹放在{addr}了，取件码是{code}，麻烦尽快取一下'; k = 'short' },
  @{ t = '【丰巢智能柜】凭码取件 {code} 柜号{locker} 地址{addr}'; k = 'ab'; needLocker = $true },
  @{ t = '您的快递已存放至{addr}，取件码{code}，柜门已开请及时取出'; k = 'ab' }
)
$hardStations = @('临江大学南区菜鸟驿站','临江广场丰巢智能柜','校内快递服务中心','万达广场菜鸟驿站')
for ($i = 0; $i -lt 24; $i++) {
  $h = $hard[$i % $hard.Count]
  $station = $hardStations[$i % $hardStations.Count]
  $addr = $stations[$station][$i % $stations[$station].Count]
  $code = New-Code $h.k
  $locker = ''
  $body = $h.t.Replace('{addr}',$addr).Replace('{code}',$code)
  if ($h.needLocker) {
    $locker = '{0}-{1}-{2}' -f $rnd.Next(1,10), $rnd.Next(1,7), $rnd.Next(1,50)
    $body = $body.Replace('{locker}',$locker)
  }
  Emit $body $code $addr $locker '' $station '' 'hard'
}

# ---------- 负样本（不应提取出取件码） ----------
$neg = @(
  '【淘宝】亲，您关注的店铺参加满300减50活动，速来抢购→ taobao.cn/-x8',
  '【快递】您的包裹已签收，感谢使用，期待再次为您服务',
  '【中通快递】您的服务体验调研邀请，点击链接参与抽奖',
  '【京东】618大促开启，跨店满减叠加红包，戳我抢购',
  '【韵达快递】温馨提示：快递实名制，寄件请出示身份证',
  '【丰巢】丰巢管家全新上线，寄件5元起，欢迎体验',
  '【极兔速递】您的评价对我们很重要，回复1非常满意回复2一般',
  '【菜鸟】您有新的包裹消息提醒设置可前往App查看物流详情',
  '【圆通】安全提醒：谨防冒充客服诈骗，勿泄露验证码',
  '【妈妈驿站】五一期间营业时间调整为9:00-18:00',
  '【快递100】您的物流订阅已到期，回复TD退订',
  '【邮政】中国邮政便民服务：水电费代缴上线啦'
)
foreach ($b in $neg) { Emit $b '' '' '' '' '' '' 'negative' }

Set-Content -Path "$dir\sms_dataset.jsonl" -Value $lines -Encoding UTF8
"generated $($lines.Count) samples"
