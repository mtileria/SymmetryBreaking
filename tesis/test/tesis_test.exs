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


p0 = KneighborLE.start("p0",50)
p1 = KneighborLE.start("p1",100)
p2 = KneighborLE.start("p2",90)
p3 = KneighborLE.start("p3",70)
p4 = KneighborLE.start("p4",20)

KneighborLE.left_right_neighbors(p1,p4,p0)
KneighborLE.left_right_neighbors(p2,p0,p1)
KneighborLE.left_right_neighbors(p3,p1,p2)
KneighborLE.left_right_neighbors(p4,p2,p3)
KneighborLE.left_right_neighbors(p0,p3,p4)

KneighborLE.start_leader_election(p1)
