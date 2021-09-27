FROM hexpm/elixir:1.13.0-erlang-24.2-debian-stretch-20210902-slim AS build

RUN apt install -y git

RUN mkdir /app
WORKDIR /app

RUN mix do local.hex --force, local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile

COPY priv priv
COPY lib lib
RUN mix compile

RUN mix release

FROM hexpm/elixir:1.13.0-erlang-24.2-debian-stretch-20210902-slim AS app

RUN apt install -y ffmpeg youtube-dl

ENV MIX_ENV=prod

RUN mkdir /app
WORKDIR /app

COPY --from=build /app/_build/prod/rel/amadeus .
COPY entrypoint.sh .
RUN chown -R nobody: /app
USER nobody

ENV HOME=/app
CMD ["bash", "/app/entrypoint.sh"]
