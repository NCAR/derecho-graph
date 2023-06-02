#!/bin/bash -l

# write header info
cat << EOF > derecho.desc
graph G {
bgcolor="white"
fontname="Helvetica,Arial,sans-serif"
outputorder="edgesfirst"
node [fontname="Helvetica,Arial,sans-serif", fontsize=9, style=bold]
#size="256!"
layout="circo"
splines=false
mindist=0.002
EOF

# Query PBS to get node and switch info
ssh derecho.hpc.ucar.edu pbsnodes -a -F json | jq -r '.nodes[] | .resources_available | select(.host != null and .switch != null and .switchgroup != null) | .host + " " + .switch + " " + .switchgroup' > derecho-topo.txt
cnodes=`cat derecho-topo.txt | awk '{print $1}' | grep dec`
gnodes=`cat derecho-topo.txt | awk '{print $1}' | grep deg`
switches=`cat derecho-topo.txt | awk '{print $2}' | sort | uniq`
sgroups=`cat derecho-topo.txt | awk '{print $3}' | sort | uniq`
lsgroups=`cat derecho-topo.txt | awk '{print "log" $3}' | sort | uniq`

# CPU nodes
for n in $cnodes; do
   echo "$n [shape=rect, color=blue, style=filled, fillcolor=white, label=\"$n\"];" >> derecho.desc
done

# GPU nodes
for n in $gnodes; do
   echo "$n [shape=rect, color=blue, style=filled, fillcolor=white, label=\"$n\"];" >> derecho.desc
done

# switch groups
for g in $sgroups; do
   echo "$g [root=true, shape=circle, color=brown, style=filled, fillcolor=white, label=\"$g\"];" >> derecho.desc
done

# logical switch group connectors
for g in $lsgroups; do
   gl=`echo $g | cut -c 4-`
   echo "$g [root=true, shape=ellipse, color=brown, style=filled, fillcolor=white label=\"$gl\"];" >> derecho.desc
done

# switches
for s in $switches; do
   echo "$s [shape=ellipse, color=green, style=filled, fillcolor=white, label=\"$s\", fontsize=\"9\"];" >> derecho.desc
done

# first connect the groups
rem_groups=$sgroups
for g1 in $sgroups; do
   rem_groups=`echo $rem_groups | cut -d' ' -f2-`
   if [ `echo $rem_groups | wc -w` == 1 ]; then
      continue
   fi
   for g2 in $rem_groups; do
      echo "$g1 -- $g2 [penwidth=2, color=red];" >> derecho.desc
   done
done

# connect switches in each group
for group in $sgroups; do
   # get switches in group
   group_switches=`grep "$group\$" derecho-topo.txt | awk '{print $2}' | sort | uniq`
   group_switches="$group_switches log$group"
   rem_switches=$group_switches
   for s1 in $group_switches; do
      # connect to group
      #echo "$s1 -- $group [penwidth=2, color=orange];" >> derecho.desc
      rem_switches=`echo $rem_switches | cut -d' ' -f2-`
      if [ `echo $rem_switches | wc -w` == 1 ]; then
         continue
      fi
      for s2 in $rem_switches; do
         echo "$s1 -- $s2 [penwidth=2,color=orange];" >> derecho.desc
      done
   done
done

# connect nodes (in the computer sense) to switches
cat derecho-topo.txt | awk '{print $1 " -- " $2 " [penwidth=4, color=purple];"}' >> derecho.desc

# connect logical group connectors to groups
for g in $sgroups; do
  echo "log$g -- $g [penwidth=12, color=red];" >> derecho.desc
done

# write footer info
echo "}" >> derecho.desc

# Now make the SVG graph
circo -y -Tsvg -O derecho.desc

# Post process SVG to move overlapping node labels
julia -- svg_pp.jl
