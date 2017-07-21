
from sbm.sbm import SBM
from random import randint
import math
import csv
import sys
num_vertices = int(sys.argv[1]) # number of unique vertices
num_communities = int(math.log1p(num_vertices))  # number of communities
community_labels = []
for i in range(num_vertices):
	community_labels.insert(i,randint(0, num_communities-1))  # community label assigned to each vertices
print 'num nodes: ' + str(num_vertices)
print 'Community Labels: ' + str(community_labels)
p1 = 0.32   #1.9*math.log1p(num_vertices)/num_vertices   probability of diagonal i == j
p2 = 0.01   #1.2*math.log1p(num_vertices)/num_vertices	 probability of i <> j
p_matrix = [[0 for j in range(num_communities)] for i in range(num_communities)]

for i in range(num_communities):
	for j in range(num_communities):
		if i==j:
			p_matrix[i][j]=p1
		else:
			p_matrix[i][j]=p2
print 'The matrix:'
print p_matrix
model = SBM(num_vertices, num_communities, community_labels, p_matrix)

print model.block_matrix


with open('/home/marcos/rhul/generator/topologies/' + str(num_vertices) + 'edges.txt', 'wb') as text_file:
	#sw = csv.writer(csvfile, delimiter=' ',quotechar='|', quoting=csv.QUOTE_MINIMAL)
	#sw.writerow(['from','to','weigth','type'])
	for i in range(num_vertices):
		text = 'A' + str(i) + ' '
		for j in range(num_vertices):
			if model.block_matrix[i][j]==1:
				text = text + 'A'+str(j) + ' '
				#sw.writerow(['A'+`i`,'A'+`j`,1,community_labels[i]+1])
		text_file.write(text + "\n")

#
# with open('nodes.csv', 'wb') as csvfile:
# 	sw = csv.writer(csvfile, delimiter=',',quotechar='|', quoting=csv.QUOTE_MINIMAL)
# 	sw.writerow(['Id','media','media.type','media.label','audience.size'])
# 	for i in range(num_vertices):
# 		sw.writerow(['s'+`i`,'NN',community_labels[i]+1,'NN',20])
