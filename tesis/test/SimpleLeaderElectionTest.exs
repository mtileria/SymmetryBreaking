defmodule SimpleLeaderElectionTest do
  use ExUnit.Case
  doctest TESIS

  test "the truth" do
    p0 = SimpleLeaderElection.start("p0",50)
    p1 = SimpleLeaderElection.start("p1",100)
    p2 = SimpleLeaderElection.start("p2",90)
    p3 = SimpleLeaderElection.start("p3",70)
    p4 = SimpleLeaderElection.start("p4",20)
    p5 = SimpleLeaderElection.start("p5",80)
    p6 = SimpleLeaderElection.start("p6",40)
    p7 = SimpleLeaderElection.start("p7",10)
    SimpleLeaderElection.left_neighbor(p1,p0)
    SimpleLeaderElection.left_neighbor(p2,p1)
    SimpleLeaderElection.left_neighbor(p3,p2)
    SimpleLeaderElection.left_neighbor(p4,p3)
    SimpleLeaderElection.left_neighbor(p5,p4)
    SimpleLeaderElection.left_neighbor(p6,p5)
    SimpleLeaderElection.left_neighbor(p7,p6)
    SimpleLeaderElection.left_neighbor(p0,p7)
    SimpleLeaderElection.start_leader_election(p4)

     assert 1 + 1 == 2
  end
end
