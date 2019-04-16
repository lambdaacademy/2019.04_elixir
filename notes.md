## Steps

### 0: setup environment, connect, create channel

#### dev

Just look at the test and run.

#### concepts

* RabbitMQ
  * why 
  * what
  * how
* connections
  - long lived
* AMQP handshake
  - authentication
* channels
  - multiplexing clients over a connection
* architecture RPC-style protocol
  * show in wireshark
  * refert to method/class

#### testing 

* explaing the repo structure
* go to `Test/protocol/connection_tests.exs` and see how it works

#### ideas

* wireshark: `wireshark -k -i lo0`

### 1: create simple producer/consumers functions

Show a minimum example for producing and consuming.

#### concepts

* exchange
* queue
* binding (every queue bound to a defult exchange by the queue name provided as routing key)
* producer
* competing consumers

#### testing

* go to `queue_declare_test.exs` and `publish_consume_test.exs`
* look at the management UI after a test (comment out queue deletion in one test)

#### dev

* 
* implement publisher pure functions
  - declare a queue
  - publish messages (String w/ dots which indicate amount of work in seconds)
  - see in the management UI exchange stats and that the message got enqueued
* implement consumer pure functions
  - declare a queue (indempotence)
  - consume messages (sleep for dots number of seconds)
  - see in the Management UI a consumer is attached an the message got consumed
* create a simple publisher script (.exs)
* attach 2 consumers and see they got messages in a round robin fashion

### 2: route messages depending on the routing key

Explain binding queues to exchanges with routing keys and how that influences message distribution.

#### concepts

* routing key and binding key
* different matching algorithm between binding and routing key depending on the exchange type
* dropped message if there's no one to route to

#### dev

* implement a task producer process
  * declares an exchange `task`
  * provides an interface for running a task (Producer.run(Task))
  * a task can be `{other, Task}`, `{fun, {Fun, Args}}` or `{mfa, {M,F,A}}`
    * validates the task and publishes with `task.simple`, `task.fun` or `task.mfa` respectivelty
* implement `task_processor` process
  * configurable backend for different tasks types
  * can be started with different binding keys
    *  `task.{fun|mfa|*}` for funs, mfas and all other respectively
       *   e.g. `task_processor.start_link("task.fun", fun = _MsgTag, TaskProcessor.Fun)`
* run the system with one producer and 3 consumers

### 3: acknowledge consumed messages and setup prefetch

Illustrate basic mechanism for acknolwedging consumption and using prefetch for
consumption performance tuning.

#### concepts

* message acknolwedgments: auto/manual
* redelivery
* prefetch count: too low vs. too high

#### dev

* make it configurable to consume with manual acks
  * see their impact if we change Queue.delete to Queue.message count in publish consume test:22 (process sleep has to be added)
* make it configurable to set up channel prefetch count
* see the impact of the prefetch count:
  - example workload: 5s x5 + 1s x5
  - to low (1): every message is acknolwedge so time is spent for ACKs and the netowrk
    is congested with them
  - to high (5): one conumer gets overloaded while the other one has nothing to do

## TODO

* add ToMessage protocol for to/from string conversion for tasks
* handle the mandatory/immediate options and register the handler
* figure out tests templating

   ```elixir
   describe "x" do
    # publish_task_test("other", @other_task)
    for {type, task} <- [{"other", @other_task}, {"fun", @fun_task}, {"MFA", @mfa_task}] do
      # test "ala #{type}" do
      # assert 3 = 1 + 2
      # https://stackoverflow.com/questions/37135619/elixir-how-can-i-unquote-an-array-of-functions-in-my-macro
      test "publish a #{type} task", prams do
        # GIVEN
        {:ok, ref} = Producer.start(@task_queue)

        # WHEN

    defp publish_task_test(task, chan) do
      # GIVEN
      {:ok, ref} = Producer.start(@task_exchange)

      # WHEN
      Logger.debug "Publishing: #{inspect task}"
      :ok = Producer.publish(ref, task)

      # THEN
      Process.sleep(@enqueue_message_delay)
      assert 1 = Queue.message_count(chan, @task_queue)

      # CLEANUP
      :ok = Producer.stop(ref)
    end
  end
  ```