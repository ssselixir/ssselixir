# ssselixir
Shadowsocks server for Elixir, but more

**Note** Please check the following link to install elixir via `asdf`

https://github.com/asdf-vm/asdf#setup

## Install

Copy-paste the following into command line:

```
git clone https://github.com/ssselixir/ssselixir.git ~/ssselixir
cd ~/ssselixir
cp config/app_config.yml.sample config/app_config.yml
mix deps.get
mix local.rebar --force
```
### Manage port and password with file

If you want to store port and password with file, please change it:
https://github.com/ssselixir/ssselixir/blob/master/mix.exs#L12

To

```
pp_store: :file
```
Then change contents of `config/app_config.yml`

### Manage port and password with database(mysql)

If you want to store port and password with database, please change it:
https://github.com/ssselixir/ssselixir/blob/master/mix.exs#L12

To

```
pp_store: :db
```
You also need to change the database setting in these lines:

https://github.com/ssselixir/ssselixir/blob/master/config/config.exs#L10-L13

Then execute the following commands:

```
cd ~/ssselixir
mix ecto.create
mix ecto.migrate
```

Once you executed the commands above, the table 'ssselixir_repo.port_passwords' should be created,
you can insert any records you needed via the following code:

```
mix ssselixir.newuser --port 55574 --password your-password
```

**Note** Please restart the server once you added the new user.

## Start/stop the server

```
cd ~/ssselixir
mix ssselixir.start
mix ssselixir.stop
```
