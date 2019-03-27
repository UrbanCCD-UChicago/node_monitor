FROM vforgione/ubuntu-phoenix:21-1.8-10

ARG VERSION

ENV MIX_ENV=prod

RUN mkdir /node_monitor
COPY . /node_monitor
WORKDIR /node_monitor

# install hex and npm dependencies

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    cd assets && \
    yarn install && \
    cd ..

# compile and digest all the things

RUN mix compile && \
    cd assets && \
    yarn run deploy && \
    cd .. && \
    mix phx.digest && \
    mix release --env=prod && \
    cd /node_monitor/_build/prod/rel/ && \
    mv node_monitor $VERSION && \
    tar czf node_monitor-$VERSION.tar.gz $VERSION && \
    cd /node_monitor && \
    mv /node_monitor/_build/prod/rel/node_monitor-$VERSION.tar.gz .
