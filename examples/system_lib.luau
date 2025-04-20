local system = require("@lute/system")

print(system.os)
print(system.arch)
print(system.threadcount())

for i, cpu in system.cpus() do
	-- print(`[core {string.format("%.02i", i)}] speed: {cpu.speed}, model: {cpu.model}`)

	-- for key, time in cpu.times do
	-- 	print(`   [times] {key}: {time}`)
	-- end
end
