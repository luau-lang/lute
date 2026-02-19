local fs = require("@std/fs")

for _, file in fs.listdirectory("./examples") do
	print(`Example {file.name} is a {file.type}`)
end
