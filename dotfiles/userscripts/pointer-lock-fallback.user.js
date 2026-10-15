// ==UserScript==
// @name         Pointer Lock Fallback
// @name:zh-CN   鼠标捕获自动回退
// @namespace    nix-config/userscripts
// @version      1.0.0
// @description  Retry ordinary pointer lock when raw mouse input is unsupported.
// @description:zh-CN 原始鼠标输入不受支持时，自动重试普通鼠标捕获。
// @match        *://*/*
// @run-at       document-start
// @grant        none
// @sandbox      raw
// @inject-into  page
// @license      MIT
// ==/UserScript==

(() => {
  "use strict";

  const requestPointerLock = Element.prototype.requestPointerLock;

  Element.prototype.requestPointerLock = async function (options) {
    try {
      return await requestPointerLock.call(this, options);
    } catch (error) {
      if (error.name !== "NotSupportedError" || !options?.unadjustedMovement) {
        throw error;
      }

      return requestPointerLock.call(this, {
        ...options,
        unadjustedMovement: false,
      });
    }
  };
})();
