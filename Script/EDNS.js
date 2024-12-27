const dnsPacket = require('dns-packet');
const { Buffer } = require('buffer');

// 解析傳入的 $argument 參數
let queryParams;
if (typeof $argument !== 'undefined') {
  queryParams = Object.fromEntries($argument.split('&').map(item => item.split('=')));
} else {
  queryParams = {};
}

// 日誌輸出函數
function log(...args) {
  if (`${queryParams?.log}` === '1') {
    console.log(...args);
  }
}
log(`傳入的 $argument: ${JSON.stringify(queryParams, null, 2)}`);

// 結果對象初始化
let result = { addresses: [], ttl: parseInt(queryParams?.ttl || 60) };

// 執行 DNS 查詢
!(async () => {
  let type = queryParams?.type || 'A,AAAA';  // 查詢類型，默認是 A 和 AAAA
  type = type.split(/\s*,\s*/).filter(i => ['A', 'AAAA'].includes(i));
  const url = queryParams?.doh || 'https://8.8.4.4/dns-query';  // 默認使用 Google DoH 服務
  const domain = $domain;  // 目標域名
  const timeout = parseInt(queryParams?.timeout || 2);  // 默認超時設置
  let edns = queryParams?.edns || '114.114.114.114';  // 默認的 EDNS 地址

  // 為特定的 Apple 和 iCloud 域名設置專門的 EDNS 地址
  if (domain.includes('icloud.com') || domain.includes('apple.com')) {
    edns = '183.198.67.65';  // 設置 Apple 和 iCloud 域名的 EDNS 地址
    log(`為域名 [${domain}] 設置專用的 EDNS 地址: ${edns}`);
  }

  log(`[${domain}] 使用 ${url} 查詢 ${type} 結果`);

  // 進行查詢
  const res = await Promise.all(type.map(i => query({
    url,
    domain,
    type: i,
    timeout,
    edns,
  })));

  // 處理查詢結果
  res.forEach(i => {
    i.answers.forEach(ans => {
      if (ans.type === 'A' || ans.type === 'AAAA') {
        result.addresses.push(ans.data);
        if (ans.ttl > 0) {
          result.ttl = ans.ttl;
        }
      }
    });
  });

  log(`[${domain}] 使用 ${url} 查詢 ${type} 結果: ${JSON.stringify(result, null, 2)}`);

  // 若查詢結果為空，拋出錯誤
  if (result.addresses.length === 0) {
    throw new Error(`[${domain}] 使用 ${url} 查詢 ${type} 結果為空`);
  }
})().catch(async e => {
  log(e);
  // 啟用兜底機制時，返回空結果
  if (`${queryParams?.fallback}` === '1') {
    result = {};
  }
}).finally(async () => {
  $done(result);  // 返回結果
})();

// 判斷是否為 IPv4 地址
function isIPv4(ip) {
  return /^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)(\.(?!$)|$)){4}$/.test(ip);
}

// 判斷是否為 IPv6 地址
function isIPv6(ip) {
  return /^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$/.test(ip);
}

// 判斷是否為有效的 IP 地址
function isIP(ip) {
  return isIPv4(ip) || isIPv6(ip);
}

// 執行 DNS 查詢
async function query({ url, domain, type = 'A', timeout, edns }) {
  const buf = dnsPacket.encode({
    type: 'query',
    id: 0,
    flags: dnsPacket.RECURSION_DESIRED,
    questions: [{
      type,
      name: domain,
    }],
    additionals: [{
      type: 'OPT',
      name: '.',
      udpPayloadSize: 4096,
      flags: 0,
      options: [{
        code: 'CLIENT_SUBNET',
        ip: edns,
        sourcePrefixLength: isIPv4(edns) ? 24 : 56,
        scopePrefixLength: 0,
      }],
    }],
  });

  const res = await httpRequest({
    url: `${url}?dns=${buf.toString('base64').toString('utf-8').replace(/=/g, '')}`,
    headers: { Accept: 'application/dns-message' },
    'binary-mode': true,
    encoding: null,  // 使用二進制格式
    timeout,
  });

  return dnsPacket.decode(Buffer.from(res.body));
}

// 發送 HTTP 請求
async function httpRequest(opt) {
  return new Promise((resolve, reject) => {
    $httpClient.get(opt, (error, response, data) => {
      if (response) {
        response.body = data;
        resolve(response);
      } else {
        reject(error);
      }
    });
  });
}
