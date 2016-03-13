/*
  Copyright (C) 2013 Yusuke Suzuki <utatane.tea@gmail.com>

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

(() => {
    'use strict';

    let NameSequence, ZeroSequenceCache;

    const deepCopy = obj => {
        const deepCopyInternal = (obj, result) => {
            for (let key in obj) {
                let val;
                if (!obj.hasOwnProperty(key) || key.startsWith('__')) {
                    continue;
                }
                val = obj[key];
                if (typeof val === 'object' && val !== null) {
                    if (val instanceof RegExp) {
                        val = new RegExp(val);
                    } else {
                        val = deepCopyInternal(val, Array.isArray(val) ? [] : {});
                    }
                }
                result[key] = val;
            }
            return result;
        };
        return deepCopyInternal(obj, Array.isArray(obj) ? [] : {});
    };

    const stringRepeat = (str, num) => {
        let result = '';

        for (num |= 0; num > 0; num >>>= 1, str += str) {
            if (num & 1) {
                result += str;
            }
        }

        return result;
    };

    // generateNextName

    ZeroSequenceCache = [];

    const zeroSequence = num => {
        let res = ZeroSequenceCache[num];
        if (res !== undefined) {
            return res;
        }
        res = stringRepeat('0', num);
        ZeroSequenceCache[num] = res;
        return res;
    };

    NameSequence = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_$'.split('');

    const generateNextName = name => {
        let cur = name.length - 1;
        do {
            let ch, index;
            ch = name.charAt(cur);
            index = NameSequence.indexOf(ch);
            if (index !== (NameSequence.length - 1)) {
                return name.substring(0, cur) + NameSequence[index + 1] + zeroSequence(name.length - (cur + 1));
            }
            --cur;
        } while (cur >= 0);
        return 'a' + zeroSequence(name.length);
    };

    module.exports = {
        generateNextName,
        deepCopy
    };
})();
/* vim: set sw=4 ts=4 et tw=80 : */
