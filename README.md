# ssselixir
Shadowsocks server for Elixir, but more

## Wiki
[Ecrypt/Decrypt data](https://github.com/ssselixir/ssselixir/wiki/Ssselixir-Encrypt-&-Decrypt-data)

## Install Erlang/Elixir via asdf

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

You need to change the following content in `config/config.exs`:

```elixir
config :ssselixir, Ssselixir.Repo,
    adapter: Ecto.Adapters.MySQL,
    database: "your-database",
    username: "username",
    password: "password",
    hostname: "hostname"
```

Then execute the following commands:

```
cd ~/ssselixir
mix ecto.create
mix ecto.migrate
```

Once you executed the commands above, the table 'ssselixir_repo.port_passwords' should be created,
you can insert/update any record you needed via the following code:

The following arguments can be passed:

- `--port`: Listening port
- `--password`: The password you want to use
- `--start-time`: Set start time of the user, you can set it to `now` or `"YYYY-MM-DD HH:MM:SS"`
- `--range`: Set term of validity, you can set it to `x.hour(s)`, `x.day(s)`, `x.month(s)` , `x.year(s)` or `forever`

**Note** These arguments are required for creating a user.

**Examples**

Create a user and provide service from now until 10 days later.

```
mix ssselixir.user --port 55555 --password my-password --start-time now --range 10.days
```

Update an existing user

```
mix ssselixir.user --port 55555 --password my-new-password
```


## Start/stop the server

```
cd ~/ssselixir
mix ssselixir.start
mix ssselixir.stop
```
