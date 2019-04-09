# School of RabbitMQ in Elixir

This is a workshop through out which one develops a simple RabbitMQ applicaiton 
in Elixir.

- [School of RabbitMQ in Elixir](#school-of-rabbitmq-in-elixir)
  - [Repo structure](#repo-structure)
  - [The workshop](#the-workshop)
    - [Step 0: Connections and Channels](#step-0-connections-and-channels)
    - [Step 1: Simple producer and consumer](#step-1-simple-producer-and-consumer)
      - [Managing queues](#managing-queues)
      - [Publising and consuming](#publising-and-consuming)
      - [Simple producer and consumer implementation](#simple-producer-and-consumer-implementation)
    - [Step 2: Message routing](#step-2-message-routing)
      - [Managing exchanges](#managing-exchanges)

## Repo structure

* master holds the end solution
* each step has its own branch
  * the branches are named with `step/{ORIDINAL}-{EXERCISE-SHORT-DESC}`, e.g. (`step/0-connect-to-rabbit`)
  * the beginning of a branch is tagged with `step-{ORIDINAL}-start`, e.g. (`step-0-start`) to see what a completion of one step takes via a diff
  * HEAD of a branch contains the final state for the step
  * if a "step branch" changes, it is merged to master and possibly the master 
  has to be merged to all the subsequent "step branches"
* README at the master branch holds instructions to the correspondins steps

## The workshop

To complete the workshop an instance of the RabbitMQ server is required. One
can be started with docker using the [docker-compose.yml](./docker-compose.yml)
provided: `docker-compose up`.

This will spawn a [RabbitMQ container](https://hub.docker.com/_/rabbitmq) and
create the following ports bindings (host->container): `5672:5672` and `15672:15672`.
They are used for AMQP and RabbitMQ server Managment UI respectively 
(http://localhost:15672).

### Step 0: Connections and Channels

1. Open [`test/rabbit_hole/protocol/connection_test.exs`](test/rabbit_hole/protocol/connection_test.exs) to see how a connection is established and channels are opened
2. Run the tests: `mix test test/rabbit_hole/protocol/connection_test.exs`

### Step 1: Simple producer and consumer

#### Managing queues

1. Open [`test/rabbit_hole/protocol/queue_declare_test.exs`](test/rabbit_hole/protocol/queue_declare_test.exs) to see how a queue is declared
2. Run the tests `mix test test/rabbit_hole/protocol/queue_declare_test.exs`

#### Publising and consuming

1. Open [`test/rabbit_hole/protocol/publish_consume_test.exs`](test/rabbit_hole/protocol/publish_consume_test.exs) to see how a message can be published to and consumed from a queue
2. Run the tests `mix test test/rabbit_hole/protocol/publish_consume_test.exs`
3. Comment out the queue deletion operation in the first test in `test/rabbit_hole/protocol/publish_consume_test.exs`, run it:

   `mix test test/rabbit_hole/protocol/publish_consume_test.exs:23`
   
and see the message enqueued in the `my_queue` through the the management UI: `http://localhost:15672/#/queues` (user/pass: guest/guest).

#### Simple producer and consumer implementation

1. Checkout at [step-1-start](https://github.com/lambdaacademy/2019.04_elixir/tree/step-1-start) tag: `git checkout step-1-start`.
2. Open [`test/rabbit_hole/producer_consumer_test.exs`](test/rabbit_hole/producer_consumer_test.exs) and see the expected behaviour of the [`RabbitHole.Producer`](lib/rabbit_hole/producer.ex) and the [`RabbitHole.Consumer`](lib/rabbit_hole/consumer.ex).
3. Implement the producer and consumer modules.
4. Check the solution by looking at the diff between the tag and the  head of the [1-simple-producer-consumer branch](https://github.com/lambdaacademy/2019.04_elixir/tree/step/1-simple-producer-consumer): [step-1-start...step/1-simple-producer-consumer](https://github.com/lambdaacademy/2019.04_elixir/compare/step-1-start...step/1-simple-producer-consumer).

### Step 2: Message routing

#### Managing exchanges

1. Open [`test/rabbit_hole/protocol/exchange.ex`](test/rabbit_hole/protocol/exchange.ex) to see how to declare an exchange.
2. Run the tests: `mix test --trace test/rabbit_hole/protocol/exchange_declare_test.exs`.
