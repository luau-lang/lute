local test = require("@std/test")
local time = require("@std/time")

local duration = time.duration

test.suite("TimeSuite", function(suite)
	suite:case("constructorsSecondsMillisMicroNanos", function(assert)
		-- seconds
		local d1 = duration.seconds(5)
		assert.eq(d1:toMilliseconds(), 5000)
		assert.eq(d1:toMicroseconds(), 5_000_000)
		assert.eq(d1:toNanoseconds(), 5_000_000_000)

		-- milliseconds
		local d2 = duration.milliseconds(1500)
		assert.eq(d2:toMilliseconds(), 1500)
		assert.eq(d2:subsecmillis(), 500)
		-- 1.5 is exactly representable; check seconds too
		assert.eq(d2:toSeconds(), 1.5)

		-- microseconds
		local d3 = duration.microseconds(1_234_567)
		assert.eq(d3:toMicroseconds(), 1_234_567)
		assert.eq(d3:subsecmicros(), 234_567)
		assert.eq(d3:toMilliseconds(), 1234) -- floor down

		-- nanoseconds (with normalization)
		local d4 = duration.nanoseconds(1_234_567_890)
		assert.eq(d4:toNanoseconds(), 1_234_567_890)
		assert.eq(d4:subsecnanos(), 234_567_890)
		assert.eq(d4:toMilliseconds(), 1234)

		-- boundary normalization: exactly 1s in nanoseconds
		local d5 = duration.nanoseconds(1_000_000_000)
		assert.eq(d5:toSeconds(), 1)
		assert.eq(d5:subsecnanos(), 0)
	end)

	suite:case("constructorsMinutesHoursDaysWeeks", function(assert)
		local mins = duration.minutes(3)
		assert.eq(mins:toSeconds(), 180)

		local hours = duration.hours(2)
		assert.eq(hours:toSeconds(), 2 * 60 * 60)

		local days = duration.days(1)
		assert.eq(days:toSeconds(), 24 * 60 * 60)

		local weeks = duration.weeks(2)
		assert.eq(weeks:toSeconds(), 2 * 7 * 24 * 60 * 60)
	end)

	suite:case("createRawValuesAndNormalizationViaOps", function(assert)
		local d = duration.create(1, 500_000_000)
		assert.eq(d:toSeconds(), 1.5)
		assert.eq(d:subsecnanos(), 500_000_000)
		assert.eq(d:toMilliseconds(), 1500)

		local d2 = duration.create(1, 1_500_000_000)
		assert.eq(d2:toSeconds(), 2.5)
		assert.eq(d2:subsecnanos(), 500_000_000)

		local normalized = d2 + duration.seconds(0)
		assert.eq(normalized:toSeconds(), 2.5)
		assert.eq(normalized:subsecnanos(), 500_000_000)
	end)

	suite:case("subsecondAccessors", function(assert)
		local d = duration.milliseconds(987)
		assert.eq(d:subsecmillis(), 987)

		local d2 = duration.microseconds(654_321)
		assert.eq(d2:subsecmicros(), 654_321 % 1_000_000)

		local d3 = duration.nanoseconds(123_456_789)
		assert.eq(d3:subsecnanos(), 123_456_789 % 1_000_000_000)
	end)

	suite:case("conversionsToMsUsNs", function(assert)
		local d = duration.seconds(2)
		assert.eq(d:toMilliseconds(), 2000)
		assert.eq(d:toMicroseconds(), 2_000_000)
		assert.eq(d:toNanoseconds(), 2_000_000_000)

		local mix = duration.milliseconds(1234) + duration.microseconds(567_000) + duration.nanoseconds(890)
		-- 1234ms + 567ms + 0.000890ms = 1801.00089ms
		assert.eq(mix:toMilliseconds(), 1801)
		assert.eq(mix:toMicroseconds(), 1_801_000)
		assert.eq(mix:toNanoseconds(), 1_801_000_890)
	end)

	suite:case("additionNormalizesNanoseconds", function(assert)
		local a = duration.milliseconds(800)
		local b = duration.milliseconds(300)
		local c = a + b
		assert.eq(c:toMilliseconds(), 1100)

		local a2 = duration.nanoseconds(800_000_000)
		local b2 = duration.nanoseconds(300_000_000)
		local c2 = a2 + b2 -- should carry +1s and leave 100_000_000ns
		assert.eq(c2:toSeconds(), 1.1)
		assert.eq(c2:subsecnanos(), 100_000_000)
	end)

	suite:case("subtractionBorrowsNanoseconds", function(assert)
		local a = duration.milliseconds(1100) -- 1s 100ms
		local b = duration.milliseconds(200)
		local c = a - b -- 900ms after borrow
		assert.eq(c:toMilliseconds(), 900)

		local d = duration.seconds(5) - duration.seconds(5)
		assert.eq(d:toMilliseconds(), 0)
	end)

	suite:case("multiplicationAndDivision", function(assert)
		local a = duration.milliseconds(250)
		local twice = a * 2
		assert.eq(twice:toMilliseconds(), 500)

		local b = duration.milliseconds(600) * 3
		assert.eq(b:toMilliseconds(), 1800)

		local c = duration.seconds(2) / 2
		assert.eq(c:toMilliseconds(), 1000)
	end)

	suite:case("comparisonsAndEquality", function(assert)
		local a = duration.seconds(1)
		local b = duration.milliseconds(1000)
		local c = duration.milliseconds(999)

		assert.that(a == b)
		assert.eq(a == c, false)
		assert.that(c < a)
		assert.that(c <= a)
		assert.that(a <= b)
		assert.eq(a < b, false)
	end)

	suite:case("largeSecondsDurationToNanoseconds", function(assert)
		-- 10 billion seconds (~317 years) exceeds the ~292-year threshold at which
		-- tv_sec * NANOSECONDS_PER_SECOND overflows int64. Before the fix, the
		-- multiplication would overflow before being cast to double, yielding a large
		-- negative value (~-8.45e18) instead of the correct 1e19.
		local d = duration.seconds(10_000_000_000)
		assert.eq(d:toNanoseconds(), 1e19)
	end)

	suite:case("mulDivInvalidFactorErrors", function(assert)
		local d = duration.seconds(1)

		-- infinite factor
		assert.throws(function()
			return d * math.huge
		end)
		assert.throws(function()
			return d / math.huge
		end)

		-- negative factor
		assert.throws(function()
			return d * -1
		end)

		-- zero divisor
		assert.throws(function()
			return d / 0
		end)
	end)

	suite:case("tostringFormat", function(assert)
		local a = duration.seconds(1)
		assert.eq(tostring(a), "1.000000000")

		local b = duration.milliseconds(1)
		assert.eq(tostring(b), "0.001000000")

		local c = duration.nanoseconds(5)
		assert.eq(tostring(c), "0.000000005")

		local d = duration.milliseconds(123) + duration.nanoseconds(456)
		-- 0s 123_000_456ns
		assert.eq(tostring(d), "0.123000456")
	end)
end)
