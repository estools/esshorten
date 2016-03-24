# Copyright (C) 2014 Yusuke Suzuki <utatane.tea@gmail.com>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 'AS IS'
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

'use strict'

esshorten = require '../'
expect = require('chai').expect
esprima = require('esprima')

describe 'mangle:', ->
    describe 'basic functionality:', ->

        it 'does not touch top-level variable declarations', ->
            program = esprima.parse 'var foo, bar, baz;'

            result = esshorten.mangle program
            expect(result.body[0].declarations[0].id.name).to.equal 'foo'
            expect(result.body[0].declarations[1].id.name).to.equal 'bar'
            expect(result.body[0].declarations[2].id.name).to.equal 'baz'

        it 'shortens local variable declarations', ->
            program = esprima.parse 'function f() { var foo, bar, baz; }'

            result = esshorten.mangle program
            statements = result.body[0].body.body
            expect(statements[0].declarations[0].id.name).to.equal 'a'
            expect(statements[0].declarations[1].id.name).to.equal 'b'
            expect(statements[0].declarations[2].id.name).to.equal 'c'

        it 'shortens parameter names', ->
            program = esprima.parse 'function f(foo, bar, baz) { foo = 1; bar = 2; baz = 3; }'

            result = esshorten.mangle program
            params = result.body[0].params
            expect(params[0].name).to.equal 'a'
            expect(params[1].name).to.equal 'b'
            expect(params[2].name).to.equal 'c'
            statements = result.body[0].body.body
            expect(statements[0].expression.left.name).to.equal 'a'
            expect(statements[1].expression.left.name).to.equal 'b'
            expect(statements[2].expression.left.name).to.equal 'c'

        it 'does not mangle implicit globals', ->
            program = esprima.parse 'function f(bar) { foo = 1; bar = 2; baz = 3; }'

            result = esshorten.mangle program
            expect(result.body[0].params[0].name).to.equal 'a'
            statements = result.body[0].body.body
            expect(statements[0].expression.left.name).to.equal 'foo'
            expect(statements[1].expression.left.name).to.equal 'a'
            expect(statements[2].expression.left.name).to.equal 'baz'

        it 'does not overwrite existing identifiers', ->
            program = esprima.parse 'function f(foo) { function a(b) { c; } }'

            result = esshorten.mangle program
            f = result.body[0]
            a = result.body[0].body.body[0]
            expect(f.params[0].name).not.to.equal a.id.name
            expect(f.params[0].name).not.to.equal a.body.body[0].expression.name
            expect(a.id.name).not.to.equal a.body.body[0].expression.name

    describe 'nested scope handling:', ->
        it 'shortens nested function names', ->
            program = esprima.parse 'function f() { function g() {} }'

            result = esshorten.mangle program
            expect(result.body[0].id.name).to.equal 'f'
            expect(result.body[0].body.body[0].id.name).to.equal 'a'

        it 'shortens parameters in nested functions', ->
            program = esprima.parse 'function f(foo) { function g(foo) { foo; } }'

            result = esshorten.mangle program
            expect(result.body[0].params[0].name).to.equal 'a'
            g = result.body[0].body.body[0]
            expect(g.id.name).to.equal 'b'
            expect(g.params[0].name).to.equal 'a'
            expect(g.body.body[0].expression.name).to.equal 'a'

        it 'shortens variable names in nested functions', ->
            program = esprima.parse 'function f(foo) { var bar = 1; var baz = function inner(foo) { foo; var qux; } }'

            result = esshorten.mangle program
            f = result.body[0]
            expect(f.id.name).to.equal 'f'
            expect(f.params[0].name.length).to.equal 1
            statements = f.body.body
            expect(statements[0].declarations[0].id.name.length).to.equal 1
            expect(statements[1].declarations[0].id.name.length).to.equal 1
            inner = statements[1].declarations[0].init;
            expect(inner.id.name.length).to.equal 1
            expect(inner.params[0].name.length).to.equal 1
            innerStatements = inner.body.body
            expect(innerStatements[0].expression.name.length).to.equal 1
            expect(innerStatements[1].declarations[0].id.name.length).to.equal 1

    describe '`destructive` option:', ->
        fixture = 'function f() { var foo, bar, baz; }'

        it 'defaults to `true`', ->
            program = esprima.parse fixture

            result = esshorten.mangle program
            expect(result).to.equal program

        it 'accepts `true`', ->
            program = esprima.parse fixture

            result = esshorten.mangle program,
                destructive: yes
            expect(result).to.equal program

        it 'accepts `false`', ->
            program = esprima.parse fixture
            json = JSON.stringify program

            result = esshorten.mangle program,
                destructive: no
            expect(result).not.to.equal program
            expect(JSON.stringify program).to.equal json

    describe '`distinguishFunctionExpressionScope` option:', ->
        program = esprima.parse '(function name() { var i = 42; });'

        it 'defaults to `false`', ->
            result = esshorten.mangle program,
                destructive: no
            expect(result.body[0].expression.id.name).to.equal 'a'
            expect(result.body[0].expression.body.body[0].declarations[0].id.name).to.equal 'b'

        it 'accepts `false`', ->
            result = esshorten.mangle program,
                destructive: no
                distinguishFunctionExpressionScope: no
            expect(result.body[0].expression.id.name).to.equal 'a'
            expect(result.body[0].expression.body.body[0].declarations[0].id.name).to.equal 'b'

        it 'accepts `true`', ->
            result = esshorten.mangle program,
                destructive: no
                distinguishFunctionExpressionScope: yes
            expect(result.body[0].expression.id.name).to.equal 'a'
            expect(result.body[0].expression.body.body[0].declarations[0].id.name).to.equal 'a'

    describe '`shouldRename` option:', ->
        it 'renames by default', ->
            program = esprima.parse '(function name() { var foo, bar, baz; });'
            result = esshorten.mangle program

            expect(result.body[0].expression.id.name).to.equal 'a'

        it 'renames if it returns `true`', ->
            program = esprima.parse '(function name() { var foo, bar, baz; });'
            result = esshorten.mangle program,
                shouldRename: (id) ->
                    return id == 'name'

            expect(result.body[0].expression.id.name).to.equal 'a'

        it 'does not rename if it returns `false`', ->
            program = esprima.parse '(function name() { var foo, bar, baz; });'
            result = esshorten.mangle program,
                shouldRename: (id) ->
                    return id != 'name'

            expect(result.body[0].expression.id.name).to.equal 'name'
