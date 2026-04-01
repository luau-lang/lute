local system = require("@std/system")

print(
	string.format(
		"%s (%s-%s) - %d cores, uptime for %ss | freemem: %dMB | totalmem: %dMB",
		system.hostName(),
		system.os,
		system.arch,
		system.threadCount(),
		tostring(system.uptime()),
		system.freeMemory(),
		system.totalMemory()
	)
)

for _i, _cpu in system.cpus() do
	-- print(`[core {string.format("%.02i", i)}] speed: {cpu.speed}, model: {cpu.model}`)

	-- for key, time in cpu.times do
	-- 	print(`   [times] {key}: {time}`)
	-- end
end
