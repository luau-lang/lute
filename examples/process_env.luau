local process = require("@lute/process")

print(process.env.HOME)
print(process.env.LUTE_HOME)
process.env.LUTE_HOME = "/home/lute"
print(process.env.LUTE_HOME)

for k, v in process.env do
    print(k, v)
end
