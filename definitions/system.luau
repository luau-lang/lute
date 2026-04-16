export type CpuInfo = {
	model: string,
	speed: number,

	times: {
		sys: number,
		idle: number,
		irq: number,
		nice: number,
		user: number,
	},
}

local system = {}

function system.threadCount(): number
	error("unimplemented")
end

function system.hostName(): string
	error("unimplemented")
end

function system.tmpdir(): string
	error("unimplemented")
end

function system.totalMemory(): number
	error("unimplemented")
end

function system.freeMemory(): number
	error("unimplemented")
end

function system.uptime(): number
	error("unimplemented")
end

function system.cpus(): { CpuInfo }
	error("unimplemented")
end

system.os = "" :: string
system.arch = "" :: string

return system
