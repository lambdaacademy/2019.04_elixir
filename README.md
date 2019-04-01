# School of RabbitMQ in Elixir

This is a workshop through out which one develops a simple RabbitMQ applicaiton 
in Elixir.

## Repo structure

* master holds the end solution
* each step has its own branch
  * the branches are named with `step/{ORIDINAL}-{EXERCISE-SHORT-DESC}`, e.g. (`step/0-connect-to-rabbit`)
  * the beginning of a branch is tagged with `step-{ORIDINAL}-start`, e.g. (`step-0-start`) to see what a completion of one step takes via a diff
  * HEAD of a branch contains the final state for the step
  * if a "step branch" changes, it is merged to master and possibly the master 
  has to be merged to all the subsequent "step branches"
* README holds instructions to the correspondins steps

## The workshop

To complete the workshop an instance of the RabbitMQ server is required. One
can be started with docker using the [docker-compose.yml](./docker-compose.yml)
provided: `docker-compose up`.

This will spawn a [RabbitMQ container](https://hub.docker.com/_/rabbitmq) and
create the following ports bindings (host->container): `5672:5672` and `15672:15672`.
They are used for AMQP and RabbitMQ server Managment UI respectively 
(http://localhost:15672).

### Step 0: Connections and Channels

1. Open [`test/rabbit_hole/protocol/connection_test.exs`] to see how a connection
is established and channels are opened
2. Run the tests: `mix test test/rabbit_hole/protocol/connection_test.exs`

