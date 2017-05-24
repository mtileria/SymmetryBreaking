defmodule SimpleLeaderElectionTest do
  use ExUnit.Case
  doctest TESIS

  test "the truth" do
      p0 = SimpleLeaderElection.start("p0")
      p1 = SimpleLeaderElection.start("p1")
      p2 = SimpleLeaderElection.start("p2")

      SimpleLeaderElection.left_right_neighbors(p1,p2,p0) 
    #   CausalBC.start("p2", ["p0","p1","p2"],{0,0,0},2)
    #  CausalBC.bc_send("Hello World!",p0
    #  CausalBC.bc_send("message 2 for everyone!",p0)
    #  CausalBC.bc_send("Good night guys!",p1)
     assert 1 + 1 == 3
  end
end
