using Underscores
using Printf

# post-process the SVG file to move the node labels
function svg_pp()
   sdvec=Dict{String, Vector{Float64}}()         # dictionary to hold node --> displacement vector mappings
   active_sdvec=Vector{Float64}()                # displacement vector for the current node
   sg_new_coords=Dict{String, Vector{Float64}}() # dictionary to hold switch group --> coordinate mappings
   move_text=false                               # flag to indicate if we are moving text on the next line
	# read file by lines into an array
	ifile=open("derecho.desc.svg")
	lines=readlines(ifile)
   close(ifile)
   # open new SVG file for writing
   ofile=open("derecho.desc.tmp.svg","w")
   ### regular expressions used to find nodes and edges
   # used to pull 2 points out of the bezier curve representing a linear graph edge
   # between a node and a switch
   node2switch_rexp=r"<path\s+.+\s+stroke=\"purple\"\s+.+\s+d=\"
                      M(-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)
                      C(-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)\s+"x
   # used to pull points out of the bezier curve representing a linear graph
   # edge between two switch groups
   sg2sg_rexp=r"<path\s+.+\s+stroke=\"red\"\s+stroke-width=\"8\"\s+d=\"
                      M(-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)
                      C(-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)\s+
                       (-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)\s+
                       (-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)"x
   # used to pull points out of the bezier curve representing a linear graph
   # edge between logical switch group and switch group
   lsg2sg_rexp=r"<path\s+.+\s+stroke=\"red\"\s+stroke-width=\"12\"\s+d=\"
                      M(-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)
                      C(-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)\s+
                       (-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)\s+
                       (-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)"x
   # used to find the node associated with the edge
   edge_node_rexp=r"<title>(de.[0-9]+)&.+</title>"
   # used to find switch group in logical switch group to switch group connection
   edge_sg_rexp=r"<title>log(x[0-9]{4}).+</title>"
   # used to find nodes
   node_rexp=r"<title>(de.{1}[0-9]+)</title>"
   # used to find switch groups
   sg_rexp=r"<title>(x[0-9]{4})</title>"
   # used to find both switch groups on an edge
   sg2sg_names_rexp=r"<title>(x[0-9]{4}).+(x[0-9]{4})</title>"
   # used to find node boxes that need to be moved
   node_box_rexp=r"<polygon fill=\"white\"\s+stroke=\"blue\"\s+points="
   # used to find switch group ellipses that need to be moved
   sg_ellipse_rexp=r"<ellipse fill=\"white\" stroke=\"brown\"\s+cx="
   # used to extract x,y center of an ellipse
   ellipse_ctr_rexp=r"cx=\"(-?[0-9]+\.?[0-9]*)\"\s+cy=\"(-?[0-9]+\.?[0-9]*)\""
   
   #-- loop through file and calculate displacement vectors for each node label
   println("   post-processing pass 1 (move nodes and switch groups)")
   for (i,l) in enumerate(lines)
      # try to match various edge and node types 
      n2s_edge_m=match(node2switch_rexp,l)
      sg2sg_edge_m=match(sg2sg_rexp,l)
      lsg2sg_edge_m=match(lsg2sg_rexp,l)
      node_m=match(node_rexp,l)
      node_box_m=match(node_box_rexp,l)
      sg_m=match(sg_rexp,l)
      sg_ellipse_m=match(sg_ellipse_rexp,l)
      if(n2s_edge_m!=nothing)
         # find what node the edge matched for
         nm=match(edge_node_rexp,lines[i-1])
         node=nm.captures[1]
         p1=str_to_vec(n2s_edge_m.captures[1])
         p2=str_to_vec(n2s_edge_m.captures[2])
         dvec=p1-p2
         sfac=37/sqrt(dvec[1]^2+dvec[2]^2)
         sdvec[node]=sfac*dvec
         write(ofile,l*"\n")
      elseif(lsg2sg_edge_m!=nothing)
         sgm=match(edge_sg_rexp,lines[i-1])
         sg=sgm.captures[1]
         p1=str_to_vec(lsg2sg_edge_m.captures[1])
         p2=str_to_vec(lsg2sg_edge_m.captures[4])
         dvec=p2-p1
         sfac=1000/sqrt(dvec[1]^2+dvec[2]^2)
         sdvec[sg]=sfac*dvec
         # transform bezier curve representation to line and write to output
         old_endpoint=str_to_vec(lsg2sg_edge_m.captures[4])
         new_endpoint=old_endpoint-sdvec[sg]
         new_edge="<path fill=\"none\" stroke=\"red\" stroke-width=\"12\" d=\"M$(lsg2sg_edge_m.captures[1])L$(new_endpoint[1]),$(new_endpoint[2])\"/>"
         write(ofile,new_edge*"\n")
      elseif(node_m!=nothing)
         active_sdvec=sdvec[node_m.captures[1]]
         write(ofile,l*"\n")
      elseif(sg_m!=nothing)
         active_sdvec=sdvec[sg_m.captures[1]]
         write(ofile,l*"\n")
      elseif(node_box_m!=nothing) # move the box to the new location
         write(ofile,new_box(l,active_sdvec)*"\n")
         move_text=true
      elseif(sg_ellipse_m!=nothing) # move the ellipse to the new location
         # get switch group name
         sgm=match(sg_rexp,lines[i-1])
         sg=sgm.captures[1]
         ne=new_ellipse(l,active_sdvec) 
         write(ofile,ne*"\n")
         # keep coordinates of new elipse center for 2nd pass
         el_ctr=match(ellipse_ctr_rexp,ne)
         new_coords_str="$(el_ctr.captures[1]),$(el_ctr.captures[2])"
         sg_new_coords[sg]=str_to_vec(new_coords_str)
         move_text=true
      else
         if(move_text)
            # move the text to the new box location
            write(ofile,new_text(l,active_sdvec)*"\n")
            move_text=false
         else
            write(ofile,l*"\n")
         end
      end
   end
   close(ofile)

   # now make a 2nd pass
   ifile=open("derecho.desc.tmp.svg")
   lines=readlines(ifile)
   close(ifile)
   ofile=open("docs/derecho.desc.pp.svg","w")
   println("   post-processing pass 2 (connect relocated switch groups)")
   for (i,l) in enumerate(lines)
      sg2sg_edge_m=match(sg2sg_rexp,l)
      if(sg2sg_edge_m!=nothing)
         # get the two switchgroups being connected
         sg_names=match(sg2sg_names_rexp,lines[i-1])
         # get coordinates of the switch groups
         sg1_coords=sg_new_coords[sg_names.captures[1]]
         sg2_coords=sg_new_coords[sg_names.captures[2]]
         # line between new switchgroups
         new_edge="<path fill=\"none\" stroke=\"red\" stroke-width=\"8\" d=\"M$(sg1_coords[1]),$(sg1_coords[2])L$(sg2_coords[1]),$(sg2_coords[2])\"/>"
         write(ofile,new_edge*"\n")      
      else
         write(ofile,l*"\n")
      end
   end
   close(ofile)
   println("Final image rendered to docs/derecho.desc.pp.svg")
end
	   
function str_to_vec(s::AbstractString)
   return @_ split(s,",") |> map(parse(Float64,_),__)
end

# Move a box by adding a displacement vector to each point in the path
function new_box(old_box::String, v::Vector{Float64})
   rexp=r"(-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)\s+
          (-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)\s+
          (-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)\s+
          (-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)\s+
          (-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)"x
   sexp = SubstitutionString(new_points(old_box,v))
   @_ replace(old_box, rexp => sexp) |> return(__)
end

# Take a string of points and add a displacement vector to each point
function new_points(s::String, t::Vector{Float64})
   rexp=r"(-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)\s+
          (-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)\s+
	       (-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)\s+
	       (-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)\s+
	       (-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*)"x
   m=match(rexp,s)
   new_points=""
   for c in m.captures
      v=str_to_vec(c)
      nv=v-t
      new_points=new_points*"$(@sprintf("%.2f",nv[1])),$(@sprintf("%.2f",nv[2])) "
   end
   return new_points[1:end-1]
end

# move an ellipse by adding a displacement vector to the center coordinates
function new_ellipse(old_ellipse::String, v::Vector{Float64})
   rexp=r"(cx=\"-?[0-9]+\.?[0-9]*\"\s+cy=\"-?[0-9]+\.?[0-9]*\")"
   sexp=SubstitutionString(new_center(old_ellipse,v))
   @_ replace(old_ellipse, rexp => sexp) |> return(__)
end # finish 

# Take a string specifying an ellipse center and add a displacement vector
function new_center(s::String, t::Vector{Float64})
   rexp=r"cx=\"(-?[0-9]+\.?[0-9]*)\"\s+cy=\"(-?[0-9]+\.?[0-9]*)\""
   m=match(rexp,s)
   old_center=str_to_vec(m.captures[1]*","*m.captures[2])
   new_center=old_center-t
   return(@sprintf("cx=\"%.2f\" cy=\"%.2f\"",new_center[1],new_center[2]))
end #finish me


# Move the text by adjusting the x and y coordinates to the new box
function new_text(l::String, v::Vector{Float64})
   rexp=r"x=\"(-?[0-9]+\.?[0-9]*)\"\s+y=\"(-?[0-9]+\.?[0-9]*)\"\s+"
   m=match(rexp,l)
   new_x = @_ parse(Float64,m.captures[1]) - v[1] |> @sprintf("%.2f",__)
   new_y = @_ parse(Float64,m.captures[2]) - v[2] |> @sprintf("%.2f",__)
   sexp=SubstitutionString("x=\"$new_x\" y=\"$new_y\" ")
   @_ replace(l, rexp => sexp) |> return(__)
end

svg_pp()
