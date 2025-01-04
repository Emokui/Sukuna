// ==UserScript==
// @name         快猫去广告
// @namespace    http://tampermonkey.net/
// @version      3.0
// @description  简单去广告
// @author       Ron
// @match        http://23.225.181.59/*
// @match        https://24y2if5.xyz/*
// @match        https://i4433b6.xyz/*
// @match        https://kmsvip.xyz/*
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    // 广告图片的域名前缀
    const adDomains = [
        'https://ad.xmmnsd.com/uploads/images/',
        'https://69vvnstttaaa888.dzlndygh.com/i/',
        'https://hongniu.getehu.com/i/',
        'https://ad.xmmnsl.com/uploads/images/' 
    ];

    // 移除广告图片、链接和特定元素
    const removeElements = () => {
        // 移除广告图片
        document.querySelectorAll('img').forEach(img => {
            if (adDomains.some(domain => img.src.startsWith(domain))) {
                img.remove();
                console.log(`广告图片移除: ${img.src}`);
            }
        });

        // 移除特定的 <a> 标签
        document.querySelectorAll('a[href=""][target="_blank"]').forEach(link => {
            const img = link.querySelector('img');
            if (img && adDomains.some(domain => img.src.startsWith(domain))) {
                link.remove();
                console.log(`广告链接移除: ${img.src}`);
            }
        });

        // 移除具有 van-overlay 类并且 z-index 在 2000 到 2020 之间的 div
        document.querySelectorAll('div.van-overlay').forEach(element => {
            const zIndex = element.style.zIndex || element.style['z-index']; // 获取 z-index 值
            if (zIndex && zIndex >= 2000 && zIndex <= 2020) {
                element.remove();
                console.log(`移除 z-index 在 2000 至 2020 之间的 van-overlay 元素`);
            }
        });

        // 移除 z-index 在 2000 到 2050 之间的 van-overlay 元素
        document.querySelectorAll('div.van-overlay').forEach(element => {
            const zIndex = element.style.zIndex || element.style['z-index']; // 获取 z-index 值
            if (zIndex && parseInt(zIndex) >= 2000 && parseInt(zIndex) <= 2050) {
                element.remove();
                console.log(`移除 z-index 在 2000 至 2050 之间的 van-overlay 元素`);
            }
        });

        // 移除 "优秀推荐应用" 和其图片部分
        document.querySelectorAll('div.my-tab').forEach(element => {
            const tabText = element.querySelector('.tab span')?.innerText?.trim();
            const image = element.querySelector('img.gobox');
            if (tabText === '优秀推荐应用' && image) {
                element.remove();
                console.log(`移除 "优秀推荐应用" 及其图片`);
            }
        });

        // 移除其他广告元素
        const selectors = [
            'ul.g-list',
            '.van-notice-bar',
            '.swiper',
            '.vip_ad',
            'div[style="width: 100%; height: 10px; background: rgb(241, 241, 241); margin-top: 0.4rem;"]',
            'div.collect',
            'div.timeout',
            'div.bootup',
            '.download',
            'ul.foot-box',
            '.share-box',
            '.gbox',
        ];

        selectors.forEach(selector => {
            document.querySelectorAll(selector).forEach(element => {
                element.remove();
                console.log(`元素移除: ${selector}`);
            });
        });
    };

    // 初始执行
    removeElements();

    // 动态监听 DOM 变化
    const observer = new MutationObserver(() => {
        removeElements();
    });

    observer.observe(document.body, { childList: true, subtree: true });

    console.log('广告和提示信息屏蔽脚本已加载');
})();
