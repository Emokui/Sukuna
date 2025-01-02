let body = $response.body;

// 移除廣告圖片 URL 列表
const adUrls = [
    'https://ad.xmmnsd.com/uploads/images/1734339513.gif',
    'https://69vvnstttaaa888.dzlndygh.com/i/2024/09/23/vhpf81.gif',
    // ... 省略其他 URL，請添加完整列表
];

// 遍歷廣告 URL，移除對應圖片
adUrls.forEach(url => {
    let regex = new RegExp(`<img[^>]*src=["']${url}["'][^>]*>`, 'g');
    body = body.replace(regex, '');
});

// 移除特定的 HTML 元素
const elementsToRemove = [
    { selector: '<ul class="g-list">.*?</ul>', type: 'regex' },
    { selector: '<div class="vip_ad">.*?</div>', type: 'regex' },
    { selector: '<div style="width: 100%; height: 10px; background: rgb\\(241, 241, 241\\); margin-top: 0.4rem;">.*?</div>', type: 'regex' },
    { selector: '<div class="collect">.*?</div>', type: 'regex' },
    { selector: '<div class="swiper">.*?</div>', type: 'regex' },
    { selector: '<div class="van-notice-bar">.*?快猫正在增加优化播放线路.*?</div>', type: 'regex' },
    { selector: '<div class="van-notice-bar">.*?请耐心等待缓冲.*?</div>', type: 'regex' }
];

elementsToRemove.forEach(item => {
    if (item.type === 'regex') {
        let regex = new RegExp(item.selector, 'g');
        body = body.replace(regex, '');
    }
});

$done({ body });
