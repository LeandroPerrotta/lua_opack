local socket = require("socket")

PORT=9000
---The parameter backlog specifies the number of client connections
-- that can be queued waiting for service. If the queue is full and
-- another client attempts connection, the connection is refused.
BACKLOG=5
--}}Options

-- create a TCP socket and bind it to the local host, at any port
server=assert(socket.tcp())
assert(server:bind("*", PORT))
server:listen(BACKLOG)

-- Print IP and port
local ip, port = server:getsockname()
print("Listening on IP="..ip..", PORT="..port.."...")

local headers = {
	['content-type'] = 'text/html'
	,['cache-control'] = 'no-cache, no-store, must-revalidate'
	,['pragma'] = 'no-cache'
	,['expires'] = '0'
}

local body = [[
<html>
	<head>
		<title>Test</title>
	</head>
	<body>
		<h3>Test of socket</h3>
		<p>If you see this message the luasocket is working.</>
	</body>
</html>
]]

-- loop forever waiting for clients
while 1 do
	-- wait for a connection from any client
	local client,err = server:accept()

	if client then
		local line, err = client:receive()
		-- if there was no error, send it back to the client
		if not err then

			local message = "HTTP/1.0 200 OK\r\n"

			for k,v in pairs(headers) do
				message = message .. string.format('%s: %s\r\n', k, v)
			end

			message = message .. '\r\n'

			message = message .. body

			client:send(message)
			print("Sent")
		end

	else
		print("Error happened while getting the connection.nError: "..err)
	end

	-- done with client, close the object
	client:close()
	print("Terminated")
end