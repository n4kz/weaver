assert  = require('assert')
weaver  = require('../lib/weaver.js')
emitter = require('events').EventEmitter

(require 'vows')
	.describe('validate')
	.addBatch
		optional: ->
			# One task required
			assert.throws ->
				weaver.validate
					tasks: {}

			# Task should be object
			assert.throws ->
				weaver.validate
					tasks: test: null

			assert.throws ->
				weaver.validate
					tasks: test: undefined

			# Source and count required
			assert.throws ->
				weaver.validate
					tasks: test: {}

			# All required fields present
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0

			# All required fields and one optional
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							cwd: './'
							count: 0

		path: ->
			# Path should be string
			assert.throws ->
				weaver.validate
					path: true
					tasks:
						test:
							source: 'test'
							count: 0

			# Path ok
			assert.doesNotThrow ->
				weaver.validate
					path: '.'
					tasks:
						test:
							source: 'test'
							count: 0

		# Count required
		'required#count': ->
			assert.throws ->
				weaver.validate
					tasks: test: source: 'test'

		# Source required
		'required#source': ->
			assert.throws ->
				weaver.validate
					tasks: test: count: 0

		# Count should be number
		'format#count': ->
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: ''
							count: ''

			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: '1739'
							count: false

			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: '1234'
							count: null

			# Count should be positive or zero
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: '1739'
							count: -1

			# Count should not be fractional
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: '1739'
							count: 1.1

		# Source should be string
		'format#source': ->
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: false
							count: 1

			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 0
							count: 2

			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: null
							count: 3

		# Watch
		'format#watch': ->
			# Only array allowed
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 3
							watch: null

			# Empty is ok
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 3
							watch: []

			# Only string patterns allowed
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 3
							watch: [/test/, null]

			# All ok
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 3
							watch: ['**/*.js']

		# Arguments
		'format#arguments': ->
			# Only array allowed
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 3
							arguments: null

			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 3
							arguments: {}

			# Empty array is ok
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 3
							arguments: []

			# Values with right type
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 3
							arguments: ['test', 0, [1,2,3]]

			# Null not allowed
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 3
							arguments: [null]

			# Object not allowed
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 3
							arguments: [{}]

			# Wrong option count
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 3
							arguments: [[1,2]]

		# Unexpected option
		'unknown': ->
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: false
							count: 1
							abcef: 92

	.export(module)
