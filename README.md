# ssselixir
Shadowsocks server for Elixir, but more


# Install Erlang/Elixir via asdf

Run the following commands to install Erlang/Elixir:

```sh
# Install asdf on Ubuntu
git clone https://github.com/asdf-vm/asdf.git ~/.asdf
echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc
echo -e '\n. $HOME/.asdf/completions/asdf.bash' >> ~/.bashrc
source ~/.bashrc

# Install required packages before installing Erlang/Elixir
sudo apt update
sudo apt install -y build-essential automake autoconf libreadline-dev libncurses-dev libssl-dev libyaml-dev libxslt-dev libffi-dev libtool unixodbc-dev

# Add plugin and install Erlang 20.0
asdf plugin-add erlang
asdf install erlang 20.0
asdf global erlang 20.0

# Add plugin and install Elixir 1.5.2
asdf plugin-add elixir
asdf install elixir 1.5.2
asdf global elixir 1.5.2
```

## Setup

Copy-paste the following into command line:

```
git clone https://github.com/ssselixir/ssselixir.git ~/ssselixir
cd ~/ssselixir
cp config/app_config.yml.sample config/app_config.yml
cp config/config.exs.sample config/config.exs
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
you can insert/update any record you needed via the following code:

```
# For a existing record, the command will update it,
# ff new record exists, it will create the record for you,
# then reload into process
mix ssselixir.user --port 55574 --password your-password
```

**Note** Please restart the server once you added the new user.

## Start/stop the server

```
cd ~/ssselixir
mix ssselixir.start
mix ssselixir.stop
```
