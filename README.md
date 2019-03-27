# Node Monitor

## Dev Environment

This project uses Elixir and NodeJS. I highly recommend using the super awesome
[asdf vm](https://github.com/asdf-vm/asdf) to manage your environment run times.

- Erlang Plugin: https://github.com/asdf-vm/asdf-erlang
- Elixir Plugin: https://github.com/asdf-vm/asdf-elixir
- NodeJS Plugin: https://github.com/asdf-vm/asdf-nodejs

Once you have the plugins installed, you can bootstrap your environment with:

```bash
asdf install
mix deps.get
npm install -g yarn
cd assets && yarn && cd ..
```

This project uses PostgreSQL with the TimescaleDB extension. Again, abstraction
is your friend here -- use docker to manage your database:

```bash
docker pull timescale/timescaledb
docker run -p 5432:5432 -e POSTGRES_PASSWORD=password timescale/timescaledb
```

With that up and running, you can now run the database migrations and seed your
database with:

```bash
mix ecto.setup
```

And finally, start the web server:

```bash
mix phx.server
```

## Building and Deploying

Before you build anything, make sure you bump the version in `mix.exs`.

There is a convenience script included to assist in building the release target. All
you need to do to build is run:

```bash
./build.sh
```

This will build a docker image, load the code, and then do all the fetching
and compiling needed. It will then copy the release archive to your host machine
under the `_build/prod` directory.

To deploy the application, you will need to `scp` it to the remote server and then
run a few commands to update the running version:

```bash
# local
scp _build/prod/node_monitor-VERSION remote-machine:releases/
ssh remote-machine

## on the remote machine
# decompress the archive
cd releases
tar xzf node_monitor-VERSION.tar.gz
rm node_monitor-VERSION.tar.gz
cd ..

# stop the running version and update the link
./node_monitor/bin/node_monitor stop
unlink node_monitor
ln -s releases/VERSION node_monitor

# if you need to run migrations, do it now
./node_monitor/bin/node_monitor migrate

# start up the new version
./node_monitor/bin/node_monitor start
```
