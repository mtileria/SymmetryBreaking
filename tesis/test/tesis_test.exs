defmodule TESISTest do
  use ExUnit.Case
  doctest TESIS

  test "the truth" do
    #  p0 = CausalBC.start("p0", ["p0","p1","p2"],{0,0,0},0)
    #  p1 = CausalBC.start("p1", ["p0","p1","p2"],{0,0,0},1)
    #   CausalBC.start("p2", ["p0","p1","p2"],{0,0,0},2)
    #  CausalBC.bc_send("Hello World!",p0
    #  CausalBC.bc_send("message 2 for everyone!",p0)
    #  CausalBC.bc_send("Good night guys!",p1)
    p0 = SimpleLeaderElection.start("p0")
    p1 = SimpleLeaderElection.start("p1")
    p2 = SimpleLeaderElection.start("p2")

    SimpleLeaderElection.left_right_neighbors(p1,p2,p0)
     assert 1 + 1 == 2
  end
end
