local system = require("@lute/system")

print(
	string.format(
		"%s (%s-%s) - %d cores, uptime for %ss | freemem: %dMB | totalmem: %dMB",
		system.hostname(),
		system.os,
		system.arch,
		system.threadcount(),
		system.uptime(),
		system.freememory(),
		system.totalmemory()
	)
)

for i, cpu in system.cpus() do
	-- print(`[core {string.format("%.02i", i)}] speed: {cpu.speed}, model: {cpu.model}`)

	-- for key, time in cpu.times do
	-- 	print(`   [times] {key}: {time}`)
	-- end
end
