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

function system.availablememory(): number
	error("unimplemented")
end

function system.availableparallelism(): number
	error("unimplemented")
end

function system.hostname(): string
	error("unimplemented")
end

function system.freememory(): number
	error("unimplemented")
end

function system.cpus(): { CpuInfo }
	error("unimplemented")
end

system.os = "" :: string
system.arch = "" :: string

return system
