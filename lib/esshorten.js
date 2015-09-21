/*!
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

    let assert;

    const escope = require('escope');
    const estraverse = require('estraverse');
    const esutils = require('esutils');
    const utility = require('./utility');
    const version = require('../package.json').version;

    const Syntax = estraverse.Syntax;

    assert = function assert(cond, message) {
        if (!cond) {
            throw new Error(message);
        }
    };

    if (!version.endsWith('-dev')) {
        assert = () => { };
    }

    class NameGenerator {
        constructor(scope, options) {
            this._scope = scope;
            this._functionName = '';
            if (!options.distinguishFunctionExpressionScope &&
                    this._scope.upper &&
                    this._scope.upper.functionExpressionScope) {
                this._functionName = this._scope.upper.block.id.name;
            }
        }

        passAsUnique(name) {
            if (this._functionName === name) {
                return false;
            }
            if (esutils.keyword.isKeywordES5(name, true) || esutils.keyword.isRestrictedWord(name)) {
                return false;
            }
            if (this._scope.taints.has(name)) {
                return false;
            }
            for (let through of this._scope.through) {
                if (through.identifier.name === name) {
                    return false;
                }
            }
            return true;
        }

        generateName(tip) {
            do {
                tip = utility.generateNextName(tip);
            } while (!this.passAsUnique(tip));
            return tip;
        }
    }

    const run = (scope, options) => {
        let generator = new NameGenerator(scope, options);

        const shouldRename = options && options.shouldRename || () => true;

        if (scope.isStatic()) {
            let name = '9';

            scope.variables.sort((a, b) => {
                if (a.tainted) {
                    return 1;
                }
                if (b.tainted) {
                    return -1;
                }
                return (b.identifiers.length + b.references.length) - (a.identifiers.length + a.references.length);
            });

            for (let variable of scope.variables) {

                if (variable.tainted) {
                    continue;
                }

                // Because `arguments` definition is nothing.
                // But if `var arguments` is defined, identifiers.length !== 0
                // and this doesn't indicate arguments.
                if (variable.identifiers.length === 0) {
                    // do not change names because this is special name
                    continue;
                }

                name = generator.generateName(name);

                for (let def of variable.identifiers) {
                    // change definition's name
                    if (shouldRename(def.name)) {
                        def.name = name;
                    }
                }

                for (let ref of variable.references) {
                    // change reference's name
                    if (shouldRename(ref.identifier.name)) {
                        ref.identifier.name = name;
                    }
                }
            }
        }
    };

    class Label {
        constructor(node, upper) {
            this.node = node;
            this.upper = upper;
            this.users = [];
            this.names = new Map();
            this.name = null;
        }

        mangle() {
            let tip = '9';

            // merge already used names
            for (let current = this.upper; current; current = current.upper) {
                if (current.name !== null) {
                    this.names.set(current.name, true);
                }
            }

            do {
                tip = utility.generateNextName(tip);
            } while (this.names.has(tip));

            this.name = tip;

            for (let current = this.upper; current; current = current.upper) {
                current.names.set(tip, true);
            }

            this.node.label.name = tip;
            this.users.forEach(user => user.label.name = tip);
        }
    }


    class LabelScope {
        constructor (upper) {
            this.map = new Map();
            this.upper = upper;
            this.label = null;
            this.labels = [];
        }

        register(node) {
            let name;

            assert(node.type === Syntax.LabeledStatement, 'node should be LabeledStatement');

            this.label = new Label(node, this.label);
            this.labels.push(this.label);

            name = node.label.name;
            assert(!this.map.has(name), 'duplicate label is found');
            this.map.set(name, this.label);
        }

        unregister(node) {
            let name, ref;
            if (node.type !== Syntax.LabeledStatement) {
                return;
            }

            name = node.label.name;
            ref = this.map.get(name);
            this.map.delete(name);

            this.label = ref.upper;
        }

        resolve(node) {
            if (node.label) {
                let name = node.label.name;
                assert(this.map.has(name), 'unresolved label');
                this.map.get(name).users.push(node);
            }
        }

        close() {
            this.labels.sort((lhs, rhs) => rhs.users.length - lhs.users.length);

            this.labels.forEach(label => label.mangle());

            return this.upper;
        }
    }

    const mangleLabels = tree => {
        let labelScope;
        const FuncOrProgram = [Syntax.Program, Syntax.FunctionExpression, Syntax.FunctionDeclaration];
        estraverse.traverse(tree, {
            enter: node => {
                if (FuncOrProgram.indexOf(node.type) >= 0) {
                    labelScope = new LabelScope(labelScope);
                    return;
                }

                switch (node.type) {
                case Syntax.LabeledStatement:
                    labelScope.register(node);
                    break;

                case Syntax.BreakStatement:
                case Syntax.ContinueStatement:
                    labelScope.resolve(node);
                    break;
                }
            },
            leave: node => {
                labelScope.unregister(node);
                if (FuncOrProgram.indexOf(node.type) >= 0) {
                    labelScope = labelScope.close();
                }
            }
        });

        return tree;
    };

    const mangle = (tree, options) => {
        let result, manager;

        if (options == null) {
            options = { destructive: true };
        }

        result = (options.destructive == null || options.destructive) ? tree : utility.deepCopy(tree);
        manager = escope.analyze(result, { directive: true });

        // mangling names
        manager.scopes.forEach(scope => run(scope, options));

        // mangling labels
        return mangleLabels(result);
    };

    module.exports = {
        mangle,
        version,
        generateNextName: utility.generateNextName
    };
})();
/* vim: set sw=4 ts=4 et tw=80 : */
