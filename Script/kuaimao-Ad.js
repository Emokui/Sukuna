// ==UserScript==
// @name         快猫去广告
// @namespace    http://tampermonkey.net/
// @version      1.9
// @description  简单去广
// @author       Ron
// @match        http://23.225.181.59/*
// @match        https://24y2if5.xyz/*
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    // 广告图片的域名前缀
    const adDomains = [
        'https://ad.xmmnsd.com/uploads/images/',
        'https://69vvnstttaaa888.dzlndygh.com/i/',
        'https://hongniu.getehu.com/i/'
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

        // 移除特定的 div 和类
        const selectors = [
            'ul.g-list',
            '.van-notice-bar',
            '.swiper',
            '.vip_ad',
            'div[style="width: 100%; height: 10px; background: rgb(241, 241, 241); margin-top: 0.4rem;"]',
            'div.collect',
            'div.timeout',
            'div.bootup',
            'div.van-overlay[style="z-index: 2003;"]', // 新增选择器
            '.download', // 新增下载广告元素选择器
            'li[data-v-68d705c0]', // 新增下载 APP 元素选择器
            'ul.foot-box', // 新增移除 <ul class="foot-box"> 元素
            '.share-box', // 新增移除分享框元素
            '.gbox', // 新增移除 <div class="gbox"> 元素
            'div.van-overlay[style="z-index: 2007;"]', // 新增移除这个 div
            'div[data-v-0eeea3a1].van_second.van-popup.van-popup--bottom', // 新增移除该弹窗
            'div[data-v-0eeea3a1].van-popup.van-popup--center', // 新增移除该弹窗
            'div[data-v-0eeea3a1].next' // 新增移除关闭和下一条按钮的 div
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
