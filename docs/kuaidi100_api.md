# 快递100 实时快递单号查询 API 文档

## 接口信息

- **URL**: `https://poll.kuaidi100.com/poll/query.do`
- **Method**: POST
- **Content-Type**: `application/x-www-form-urlencoded`

## 签名计算

将 `param + key + customer` 拼接后进行 MD5 哈希，转换为 **32位大写** 字符串。

```
sign = MD5(param + key + customer).toUpperCase()
```

支持的签名算法（signType）：MD5（默认）、SHA256、SM3、SM3-HMAC

## 请求参数

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| customer | String | 是 | 授权码 |
| sign | String | 是 | 签名 |
| signType | String | 否 | 签名算法，默认 MD5 |
| param (JSON) | Object | 是 | 查询参数，包含以下子字段 |

### param 子字段

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| com | String | 是 | 快递公司编码（小写），如 yuantong、ems |
| num | String | 是 | 快递单号（6-32位） |
| phone | String | 否 | 收/寄件人手机号，顺丰/中通必填 |
| from | String | 否 | 出发地 |
| to | String | 否 | 目的地，resultv2=8 时必填 |
| resultv2 | String | 否 | `1`=增加区域解析+状态名; `4`=增加高级状态+出发/目的/当前城市; `8`=额外返回预计到达时间和预测路线 |
| show | String | 否 | 输出格式: 0=JSON(默认), 1=XML, 2=HTML, 3=文本 |
| order | String | 否 | 排序: desc(默认), asc |
| lang | String | 否 | 语言: zh=中文, en=英文 |
| needCourierInfo | Boolean | 否 | 是否提取快递员信息 |

## 请求示例

```
customer = **********
sign = ******************
param = {
    "com": "ems",
    "num": "em263999513jp",
    "phone": "13868688888",
    "from": "广东省深圳市南山区",
    "to": "北京市朝阳区",
    "resultv2": "4",
    "show": "0",
    "order": "desc",
    "lang": "zh"
}
```

## 响应字段

### 顶层字段

| 字段 | 类型 | 说明 |
|---|---|---|
| message | String | 消息体 |
| state | String | 高级状态: 0=在途, 1=揽收, 2=疑难, 3=签收, 4=退签, 5=派件, 6=退回, 7=转投, 8=清关, 14=拒签 |
| status | String | 通讯状态（忽略） |
| com | String | 快递公司编码 |
| nu | String | 快递单号 |
| data | Array | 轨迹事件数组，最新在前 |
| isLoop | Boolean | 是否存在路由环路（需 resultv2=4/8） |
| routeInfo | Object | 路由信息（需 resultv2=4/8） |
| arrivalTime | String | 预计到达时间 "YYYY-MM-DD HH"（需 resultv2=8） |
| totalTime | String | 平均在途时间（需 resultv2=8） |
| remainTime | String | 剩余时间（需 resultv2=8） |
| probability | String | 到达准确率（需 resultv2=8） |

### data[] 每项

| 字段 | 类型 | 说明 |
|---|---|---|
| context | String | 轨迹事件描述 |
| time | String | 原始时间戳 |
| ftime | String | 格式化时间 |
| status | String | 状态名（需 resultv2=1/4/8） |
| statusCode | String | 高级状态码（需 resultv2=4/8） |
| areaCode | String | 行政区划代码（需 resultv2=1/4/8） |
| areaName | String | 行政区划名称（需 resultv2=1/4/8） |
| location | String | 当前位置（需 resultv2=4/8） |

## 状态码参考

| state | 名称 | 说明 |
|---|---|---|
| 1 | 揽收 | 包裹已揽收 |
| 0 | 在途 | 运输中 |
| 5 | 派件 | 派送中 |
| 3 | 签收 | 已签收 |
| 6 | 退回 | 退回中 |
| 4 | 退签 | 已取消 |
| 14 | 拒签 | 被拒收 |
| 7 | 转投 | 转交其他快递 |
| 2 | 疑难 | 有问题 |
| 8 | 清关 | 清关中 |

## 错误码

| 码 | 说明 |
|---|---|
| 200 | 查询成功 |
| 400 | 找不到对应公司 |
| 408 | 手机号验证错误 |
| 500 | 无结果，稍后再试 |
| 501 | 服务器错误 |
| 502 | 服务器繁忙 |
| 503 | 签名验证失败 |
| 601 | key 已过期 |

## 频率限制

每个单号查询频率至少间隔 **30分钟**，否则会造成锁单。
