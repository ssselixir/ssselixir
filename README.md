# ssselixir
Shadowsocks server for Elixir, but more

**Note** Please check the following link to install elixir via `asdf`

https://github.com/asdf-vm/asdf#setup

## Install

Copy-paste the following into command line:

```
git clone https://github.com/ssselixir/ssselixir.git ~/ssselixir
```

Change the port on this line:

https://github.com/ssselixir/ssselixir/blob/master/server.exs#L17

Change the password:

https://github.com/ssselixir/ssselixir/blob/master/server.exs#L18

## Run it background

```
cd ~/ssselixir
nohup elixir server.exs > /dev/null 2>&1 &
```
