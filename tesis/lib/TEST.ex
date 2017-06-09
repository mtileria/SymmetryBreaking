defmodule TESIS do

def readfile () do
  stream = File.stream!("/home/marcos/rhul/tesis/files/16nodes.txt")
  p_names = String.split(List.first(Enum.take(stream, 1)))


end




end
