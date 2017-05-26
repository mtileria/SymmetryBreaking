defmodule SimpleLeaderElectionTest do
  use ExUnit.Case
  doctest TESIS

  test "the truth" do
    p0 = SimpleLeaderElection.start("p0",50)
    p1 = SimpleLeaderElection.start("p1",100)
    p2 = SimpleLeaderElection.start("p2",90)
    p3 = SimpleLeaderElection.start("p3",70)
    p4 = SimpleLeaderElection.start("p4",20)

    SimpleLeaderElection.left_neighbor(p1,p0)
    SimpleLeaderElection.left_neighbor(p2,p1)
    SimpleLeaderElection.left_neighbor(p3,p2)
    SimpleLeaderElection.left_neighbor(p4,p3)
    SimpleLeaderElection.left_neighbor(p0,p4)

    SimpleLeaderElection.start_leader_election(p4)

     assert 1 + 1 == 3
  end
end
