# ssselixir
Shadowsocks server for Elixir, but more

**Note** Please check the following link to install elixir via `asdf`

https://github.com/asdf-vm/asdf#setup

## Install

Copy-paste the following into command line:

```
git clone https://github.com/ssselixir/ssselixir.git ~/ssselixir
cp config/app_config.yml.sample config/app_config.yml
```

Change the ports and passwords in `config/app_config.yml`

## Run it background

```
cd ~/ssselixir
mix deps.get
nohup iex -S mix > /dev/null 2>&1 &
```
