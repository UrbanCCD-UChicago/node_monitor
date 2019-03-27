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
