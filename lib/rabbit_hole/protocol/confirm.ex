defmodule RabbitHole.Protocol.Confirm do
  @moduledoc """
  Provides methods of the Confirm class.
  """

  alias AMQP.Confirm, as: C

  defdelegate select(channel), to: C

  defdelegate wait_for_confirms(channel), to: C

end
