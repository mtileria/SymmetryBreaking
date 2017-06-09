defmodule SimpleLeaderElectionTest do
  use ExUnit.Case
  doctest TESIS

  test "the truth" do

    p0 = KneighborLE.start("p0",50)
    p1 = KneighborLE.start("p1",100)
    p2 = KneighborLE.start("p2",90)
    p3 = KneighborLE.start("p3",70)
    p4 = KneighborLE.start("p4",20)
    p5 = KneighborLE.start("p5",80)
    p6 = KneighborLE.start("p6",40)
    p7 = KneighborLE.start("p7",10)

    KneighborLE.left_right_neighbors(p1,p4,p0)
    KneighborLE.left_right_neighbors(p2,p0,p1)
    KneighborLE.left_right_neighbors(p3,p1,p2)
    KneighborLE.left_right_neighbors(p4,p2,p3)
    KneighborLE.left_right_neighbors(p5,p3,p4)
    KneighborLE.left_right_neighbors(p6,p4,p5)
    KneighborLE.left_right_neighbors(p7,p5,p6)
    KneighborLE.left_right_neighbors(p0,p6,p7)
    IO.puts("start on: #{inspect p1}")
    KneighborLE.start_leader_election(p1)

     assert 1 + 1 == 2
  end
end
