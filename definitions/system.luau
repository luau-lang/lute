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

function system.threadcount(): number
	error("unimplemented")
end

function system.hostname(): string
	error("unimplemented")
end

function system.totalmemory(): number
	error("unimplemented")
end

function system.freememory(): number
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
