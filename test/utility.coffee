###
Copyright (C) 2016 Thomas Rosenau

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

  * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
  * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 'AS IS'
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###

'use strict'

utility = require '../lib/utility'
expect = require('chai').expect

describe 'utility:', ->
    describe 'deepCopy:', ->
        it 'copies objects', ->
            o = {}
            copy = utility.deepCopy o
            expect(JSON.stringify copy).to.equal JSON.stringify o
            expect(copy).not.to.equal o

            a = []
            copy = utility.deepCopy a
            expect(JSON.stringify copy).to.equal JSON.stringify a
            expect(copy).not.to.equal a

            o2 = {a: 1, b: 2, c: [{d: true}]}
            copy = utility.deepCopy o2
            expect(JSON.stringify copy).to.equal JSON.stringify o2
            expect(copy).not.to.equal o2
            expect(copy.c).not.to.equal o2.c
            expect(copy.c[0]).not.to.equal o2.c[0]

        it 'filters internal properties', ->
            o = {__foo: true, bar: [{__baz: 1}, 2]}
            copy = utility.deepCopy o
            expect(copy.__foo).to.equal undefined
            expect(copy.bar[0].__baz).to.equal undefined
            expect(JSON.stringify copy).to.equal JSON.stringify {bar: [{}, 2]}

    describe 'generateNextName:', ->
        it 'generates names', ->
            expect(utility.generateNextName 'a').to.equal 'b'
            expect(utility.generateNextName 'b').to.equal 'c'
            expect(utility.generateNextName 'z').to.equal 'A'
            expect(utility.generateNextName 'A').to.equal 'B'
            expect(utility.generateNextName 'Z').to.equal '_'
            expect(utility.generateNextName '_').to.equal '$'
            expect(utility.generateNextName '$').to.equal 'a0'
            expect(utility.generateNextName 'a0').to.equal 'a1'
            expect(utility.generateNextName 'az').to.equal 'aA'
            expect(utility.generateNextName 'aZ').to.equal 'a_'
            expect(utility.generateNextName 'a_').to.equal 'a$'
            expect(utility.generateNextName 'a$').to.equal 'b0'
            expect(utility.generateNextName '$$').to.equal 'a00'
            expect(utility.generateNextName 'Z$$').to.equal '_00'
            expect(utility.generateNextName '_$$').to.equal '$00'
            expect(utility.generateNextName '$$_').to.equal '$$$'
            expect(utility.generateNextName '$$$').to.equal 'a000'
            expect(utility.generateNextName 'correcthorsebatterystaple').to.equal 'correcthorsebatterystaplf'
