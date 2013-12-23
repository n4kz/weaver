assert  = require('assert')
weaver  = require('../lib/weaver.js')

(require 'vows')
	.describe('define')
	.addBatch
		'property#writable': ->
			name  = "test_#{Math.random()}"
			value = Math.random()

			weaver.define 'property', name, value

			assert name of weaver
			assert.equal weaver[name], value

		'property#protected': ->
			name  = "test_#{Math.random()}"
			value = Math.random()

			weaver.define 'property', name, value, writable: false

			assert name of weaver
			assert.equal weaver[name], value
			assert.throws ->
				weaver.define 'property', name, 1 + value

		'method#parameters': ->
			name  = "test_#{Math.random()}"

			assert.throws ->
				weaver.define 'method', name, null

			assert.throws ->
				weaver.define 'method', name, {}

			weaver.define 'method', name, ->

			assert not weaver.propertyIsEnumerable name
			assert.equal typeof weaver[name], 'function'

		'method#protected': ->
			name = "test_#{Math.random()}"

			weaver.define 'method', name, (->), writable: false

			assert.throws ->
				weaver.define 'method', name, ->

		handler: ->
			listeners = weaver.listeners('error').length

			for i in [1 .. 5]
				weaver.define 'handler', 'error', ->
				assert.equal ++listeners, weaver.listeners('error').length

		parameters: ->
			assert.throws ->
				weaver.define()

			assert.throws ->
				weaver.define 'event'

		target: ->
			name   = "test_#{Math.random()}"
			value  = Math.random()
			target = Object.create null

			weaver.define 'property', name, value, target: target

			assert not (name of weaver)
			assert      name of target
			assert.equal target[name], value

	.export(module)
