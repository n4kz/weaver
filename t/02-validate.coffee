assert  = require('assert')
weaver  = require('../lib/weaver.js')
emitter = require('events').EventEmitter

(require 'vows')
	.describe('validation')
	.addBatch
		# Basic validation
		basic: ->
			assert.throws -> weaver.validate undefined
			assert.throws -> weaver.validate null
			assert.throws -> weaver.validate []
			assert.throws -> weaver.validate {}
			assert.throws -> weaver.validate tasks: null
			assert.throws -> weaver.validate tasks: []
			assert.throws -> weaver.validate tasks: {}
			assert.throws -> weaver.validate tasks: test: null
			assert.throws -> weaver.validate tasks: test: []
			assert.throws -> weaver.validate tasks: test: {}

			# Okay
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0

		'path': ->
			# Path should be string
			assert.throws ->
				weaver.validate
					path: null
					tasks:
						test:
							source: 'test'
							count: 0

			# Path should not be empty
			assert.throws ->
				weaver.validate
					path: ''
					tasks:
						test:
							source: 'test'
							count: 0

			# Okay
			assert.doesNotThrow ->
				weaver.validate
					path: '.'
					tasks:
						test:
							source: 'test'
							count: 0

		'count': ->
			# Count should be present
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'

			# Count should be number
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: null

			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 'test'

			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: true

			# Count should be positive or zero
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: -1

			# Count should not be fractional
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 1.1

		'source': ->
			# Source should be present
			assert.throws ->
				weaver.validate
					tasks:
						test:
							count: 0

			# Source should be string
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: null
							count: 0

			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: true
							count: 0

			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 0
							count: 0

			# Source should not be empty
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: ''
							count: 0

		'cwd': ->
			# cwd should be string
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							cwd: null
							count: 0

			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							cwd: true
							count: 0

			# cwd should be empty
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							cwd: ''
							count: 0

			# Okay
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							cwd: '.'
							count: 0

		'timeout': ->
			# Timeout should be number
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							timeout: null

			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							timeout: ''

			# Timeout should be positive or zero
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							timeout: -1

			# Timeout should not be fractional
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							timeout: 1.1

		'runtime': ->
			# Runtime should be number
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							runtime: null

			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							runtime: ''

			# Runtime should be positive or zero
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							runtime: -1

			# Runtime should not be fractional
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							runtime: 1.1

		'persistent': ->
			# Should be boolean
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							persistent: 0

			# Okay
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							persistent: true

		'executable': ->
			# Should be boolean
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							executable: 0

			# Okay
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							executable: true

		'watch': ->
			# Only array allowed
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							watch: null

			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							watch: {}

			# Empty is okay
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							watch: []

			# Only string patterns allowed
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							watch: [null]

			# No empty strings
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							watch: ['']

			# Okay
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							watch: ['**/*.js']

		# Arguments
		'arguments': ->
			# Only array allowed
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							arguments: null

			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							arguments: {}

			# Empty array is okay
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							arguments: []

			# Null not allowed
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							arguments: [null]

			# Object not allowed
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							arguments: [{}]

			# Boolean not allowed
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							arguments: [true, true, true]

			# Nested array length should match task count option count
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 1
							arguments: [[1, 2]]

			# Empty nested array is okay
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							arguments: [[]]

			# Empty strings are okay
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 1
							arguments: ['', ['']]

			# Okay
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 3
							arguments: ['--test', [1, 2, 3], '--verbose', 1]

		'env': ->
			# Env should be object
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							env: null

			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							env: []

			# Values should be strings or boolean
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							env:
								NODE_ENV: null

			# Empty object is okay
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							env: {}

			# Okay
			assert.doesNotThrow ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							env:
								NODE_ENV: true
								PATH: '/bin:/usr/bin'
								TEST: ''

		'name': ->
			# Task without a name
			assert.throws ->
				weaver.validate
					tasks:
						'':
							source: 'test'
							count: 0

			# Task with fancy name
			assert.throws ->
				weaver.validate
					tasks:
						'❄':
							source: 'test'
							count: 0

		'unexpected': ->
			# Unexpected parameters on top level
			assert.throws ->
				weaver.validate
					whoa: 'so unexpected'
					tasks:
						test:
							source: 'test'
							count: 0

			# Unexpected parameters for task
			assert.throws ->
				weaver.validate
					tasks:
						test:
							source: 'test'
							count: 0
							whoa: 'so unexpected'

	.export(module)
