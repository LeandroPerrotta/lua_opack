# lua_opack
Very simple Lua implementation for OPACK encoding.

Just for testing if pure Lua can handle without using C-based libs.

It's still unfinished, and miss a lot of features.


## Testing for luasocket

1) Install luarocks:

On many Linux distros it is in package manager. On Ubuntu/Debian should be (may require sudo):

`# apt install luarocks`

On Windows you should take a look:
https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Windows

2) Install luasocket using luarocks:

The command is (may require sudo):

`# luarocks install luasocket`


3) Start application by command:

`# lua simplehttp.lua`

It will start listening on port 9000.

4) Check output
Here only need go something like
http://my.server.ip:9000

If all work, you should see the message:

![Success image](https://i.ibb.co/wR4rFgf/image.png)
