let cache = $persistentStore.read("request_count") || "{}";
let requestCount = JSON.parse(cache);

let now = Math.floor(Date.now() / 1000); // 取得當前秒數
let domain = $request.hostname;

// 初始化計數器
if (!requestCount[domain] || requestCount[domain].timestamp !== now) {
    requestCount[domain] = { count: 0, timestamp: now };
}

// 增加計數
requestCount[domain].count += 1;

// 設定 1 秒內最大請求數
let limit = 5;

// 如果超過閾值，延遲請求
if (requestCount[domain].count > limit) {
    let delay = 500; // 500ms 延遲
    setTimeout(() => {
        $done({});
    }, delay);
} else {
    $persistentStore.write(JSON.stringify(requestCount), "request_count");
    $done({});
}
