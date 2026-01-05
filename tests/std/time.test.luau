local test = require("@std/test")
local time = require("@std/time")

local duration = time.duration

test.suite("TimeSuite", function(suite)
	suite:case("constructors_seconds_millis_micros_nanos", function(assert)
		-- seconds
		local d1 = duration.seconds(5)
		assert.eq(d1:tomilliseconds(), 5000)
		assert.eq(d1:tomicroseconds(), 5_000_000)
		assert.eq(d1:tonanoseconds(), 5_000_000_000)

		-- milliseconds
		local d2 = duration.milliseconds(1500)
		assert.eq(d2:tomilliseconds(), 1500)
		assert.eq(d2:subsecmillis(), 500)
		-- 1.5 is exactly representable; check seconds too
		assert.eq(d2:toseconds(), 1.5)

		-- microseconds
		local d3 = duration.microseconds(1_234_567)
		assert.eq(d3:tomicroseconds(), 1_234_567)
		assert.eq(d3:subsecmicros(), 234_567)
		assert.eq(d3:tomilliseconds(), 1234) -- floor down

		-- nanoseconds (with normalization)
		local d4 = duration.nanoseconds(1_234_567_890)
		assert.eq(d4:tonanoseconds(), 1_234_567_890)
		assert.eq(d4:subsecnanos(), 234_567_890)
		assert.eq(d4:tomilliseconds(), 1234)

		-- boundary normalization: exactly 1s in nanoseconds
		local d5 = duration.nanoseconds(1_000_000_000)
		assert.eq(d5:toseconds(), 1)
		assert.eq(d5:subsecnanos(), 0)
	end)

	suite:case("constructors_minutes_hours_days_weeks", function(assert)
		local mins = duration.minutes(3)
		assert.eq(mins:toseconds(), 180)

		local hours = duration.hours(2)
		assert.eq(hours:toseconds(), 2 * 60 * 60)

		local days = duration.days(1)
		assert.eq(days:toseconds(), 24 * 60 * 60)

		local weeks = duration.weeks(2)
		assert.eq(weeks:toseconds(), 2 * 7 * 24 * 60 * 60)
	end)

	suite:case("create_raw_values_and_normalization_via_ops", function(assert)
		-- create keeps raw values without normalization
		local d = duration.create(1, 500_000_000)
		assert.eq(d:toseconds(), 1.5)
		assert.eq(d:subsecnanos(), 500_000_000)
		assert.eq(d:tomilliseconds(), 1500)

		-- if nanoseconds exceed a second, create still allows it
		local d2 = duration.create(1, 1_500_000_000)
		assert.eq(d2:toseconds(), 2.5)
		assert.eq(d2:subsecnanos(), 1_500_000_000)

		-- operations like addition normalize nanoseconds
		local normalized = d2 + duration.seconds(0)
		assert.eq(normalized:toseconds(), 2.5)
		assert.eq(normalized:subsecnanos(), 500_000_000)
	end)

	suite:case("subsecond_accessors", function(assert)
		local d = duration.milliseconds(987)
		assert.eq(d:subsecmillis(), 987)

		local d2 = duration.microseconds(654_321)
		assert.eq(d2:subsecmicros(), 654_321 % 1_000_000)

		local d3 = duration.nanoseconds(123_456_789)
		assert.eq(d3:subsecnanos(), 123_456_789 % 1_000_000_000)
	end)

	suite:case("conversions_to_ms_us_ns", function(assert)
		local d = duration.seconds(2)
		assert.eq(d:tomilliseconds(), 2000)
		assert.eq(d:tomicroseconds(), 2_000_000)
		assert.eq(d:tonanoseconds(), 2_000_000_000)

		local mix = duration.milliseconds(1234) + duration.microseconds(567_000) + duration.nanoseconds(890)
		-- 1234ms + 567ms + 0.000890ms = 1801.00089ms
		assert.eq(mix:tomilliseconds(), 1801)
		assert.eq(mix:tomicroseconds(), 1_801_000)
		assert.eq(mix:tonanoseconds(), 1_801_000_890)
	end)

	suite:case("addition_normalizes_nanoseconds", function(assert)
		local a = duration.milliseconds(800)
		local b = duration.milliseconds(300)
		local c = a + b
		assert.eq(c:tomilliseconds(), 1100)

		local a2 = duration.nanoseconds(800_000_000)
		local b2 = duration.nanoseconds(300_000_000)
		local c2 = a2 + b2 -- should carry +1s and leave 100_000_000ns
		assert.eq(c2:toseconds(), 1.1)
		assert.eq(c2:subsecnanos(), 100_000_000)
	end)

	suite:case("subtraction_borrows_nanoseconds", function(assert)
		local a = duration.milliseconds(1100) -- 1s 100ms
		local b = duration.milliseconds(200)
		local c = a - b -- 900ms after borrow
		assert.eq(c:tomilliseconds(), 900)

		local d = duration.seconds(5) - duration.seconds(5)
		assert.eq(d:tomilliseconds(), 0)
	end)

	suite:case("multiplication_and_division", function(assert)
		local a = duration.milliseconds(250)
		local twice = a * 2
		assert.eq(twice:tomilliseconds(), 500)

		local b = duration.milliseconds(600) * 3
		assert.eq(b:tomilliseconds(), 1800)

		local c = duration.seconds(2) / 2
		assert.eq(c:tomilliseconds(), 1000)
	end)

	suite:case("comparisons_and_equality", function(assert)
		local a = duration.seconds(1)
		local b = duration.milliseconds(1000)
		local c = duration.milliseconds(999)

		assert.eq(a == b, true)
		assert.eq(a == c, false)
		assert.eq(c < a, true)
		assert.eq(c <= a, true)
		assert.eq(a <= b, true)
		assert.eq(a < b, false)
	end)

	suite:case("tostring_format", function(assert)
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
