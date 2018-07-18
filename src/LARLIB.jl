module LARLIB

	using NearestNeighbors
	using DataStructures
	using NearestNeighbors
	using IntervalTrees
	using TRIANGLE
   
	"""
		Points = Array{Number,2,1}
	
	Alias declation of LAR-specific data structure.
	Dense `Array{Number,2,1}` ``M\times N`` to store the position of *vertices* (0-cells)
	of a *cellular complex*. The number of rows ``M`` is the dimension 
	of the embedding space. The number of columns ``N`` is the number of vertices.
	"""
	const Points = Matrix


	"""
		Cells = Array{Array{Int,1},1}
	
	Alias declation of LAR-specific data structure.
	Dense `Array` to store the indices of vertices of `P-cells`
	of a cellular complex. 
	The linear space of `P-chains` is generated by `Cells` as a basis.
	Simplicial `P-chains` have `P+1` vertex indices for `cell` element in `Cells` array.
	Cuboidal `P-chains` have ``2^P`` vertex indices for `cell` element in `Cells` array.
	Other types of chain spaces may have different numbers of vertex indices for `cell` 
	element in `Cells` array.
	"""
	const Cells = Array{Array{Int,1},1}


	"""
		Chain = SparseVector{Int8,Int}
	
	Alias declation of LAR-specific data structure.
	Binary `SparseVector` to store the coordinates of a `chain` of `N-cells`. It is
	`nnz=1` with `value=1` for the coordinates of an *elementary N-chain*, constituted by 
	a single *N-chain*.
	"""
	const Chain = SparseVector{Int8,Int}


	"""
		ChainOp = SparseMatrixCSC{Int8,Int}
	
	Alias declation of LAR-specific data structure. 
	`SparseMatrix` in *Compressed Sparse Column* format, contains the coordinate 
	representation of an operator between linear spaces of `P-chains`. 
	Operators ``P-Boundary : P-Chain -> (P-1)-Chain``
	and ``P-Coboundary : P-Chain -> (P+1)-Chain`` are typically stored as 
	`ChainOp` with elements in ``\{-1,0,1\}`` or in ``\{0,1\}``, for 
	*signed* and *unsigned* operators, respectively.
	"""
	const ChainOp = SparseMatrixCSC{Int8,Int}


	"""
		ChainComplex = Array{ChainOp,1}
	
	Alias declation of LAR-specific data structure. It is a 
	1-dimensional `Array` of `ChainOp` that provides storage for either the 
	*chain of boundaries* (from `D` to `0`) or the transposed *chain of coboundaries* 
	(from `0` to `D`), with `D` the dimension of the embedding space, which may be either 
	``\R^2`` or ``\R^3``.
	"""
	const ChainComplex = Array{ChainOp,1}


	"""
		LARmodel = Tuple{Points,Array{Cells,1}}
	
	Alias declation of LAR-specific data structure.
	`LARmodel` is a pair (*Geometry*, *Topology*), where *Geometry* is stored as 
	`Points`, and *Topology* is stored as `Array` of `Cells`. The number of `Cells` 
	values may vary from `1` to `N+1`.
	"""
	const LARmodel = Tuple{Points,Array{Cells,1}}


	"""
		LAR = Tuple{Points,Cells}
	
	Alias declation of LAR-specific data structure.
	`LAR` is a pair (*Geometry*, *Topology*), where *Geometry* is stored as 
	`Points`, and *Topology* is stored as `Cells`. 
	"""
	const LAR = Tuple{Points,Cells}
   
   
   # Characteristic Array{Number,2} $M_2$, i.e. M(FV)
   function characteristicMatrix(FV)
      I,J,V = Int64[],Int64[],Int8[] 
      for f=1:length(FV)
         for k in FV[f]
            push!(I,f)
            push!(J,k)
            push!(V,1)
         end
      end
      M_2 = sparse(I,J,V)
      return M_2
   end
   
   
   # Computation of sparse boundary $C_1 \to C_0$
   function boundary1(EV)
      spboundary1 = LARLIB.characteristicMatrix(EV)'
      for e = 1:length(EV)
         spboundary1[EV[e][1],e] = -1
      end
      return spboundary1
   end
   
   
   # Computation of sparse uboundary2
   function uboundary2(FV,EV)
      cscFV = characteristicMatrix(FV)
      cscEV = characteristicMatrix(EV)
      temp = cscFV * cscEV'
      I,J,V = Int64[],Int64[],Int8[]
      for j=1:size(temp,2)
         for i=1:size(temp,1)
            if temp[i,j] == 2
               push!(I,i)
               push!(J,j)
               push!(V,1)
            end
         end
      end
      sp_uboundary2 = sparse(I,J,V)
      return sp_uboundary2
   end
   
   
   
   # Local storage
   function columninfo(infos,EV,next,col)
       infos[1,col] = 1
       infos[2,col] = next
       infos[3,col] = EV[next][1]
       infos[4,col] = EV[next][2]
       vpivot = infos[4,col]
   end
   
   
   # Initialization
   function boundary2(FV,EV)
       sp_u_boundary2 = LARLIB.uboundary2(FV,EV)
       larEV = LARLIB.characteristicMatrix(EV)
       # unsigned incidence relation
       FE = [findn(sp_u_boundary2[f,:]) for f=1:size(sp_u_boundary2,1) ]
       I,J,V = Int64[],Int64[],Int8[]
       vedges = [findn(larEV[:,v]) for v=1:size(larEV,2)]
   
       # Loop on faces
       for f=1:length(FE)
           fedges = Set(FE[f])
           next = pop!(fedges)
           col = 1
           infos = zeros(Int64,(4,length(FE[f])))
           vpivot = infos[4,col]
           vpivot = columninfo(infos,EV,next,col)
           while fedges != Set()
               nextedge = intersect(fedges, Set(vedges[vpivot]))
               fedges = setdiff(fedges,nextedge)
               next = pop!(nextedge)
               col += 1
               vpivot = columninfo(infos,EV,next,col)
               if vpivot == infos[4,col-1]
                   infos[3,col],infos[4,col] = infos[4,col],infos[3,col]
                   infos[1,col] = -1
                   vpivot = infos[4,col]
               end
           end
           for j=1:size(infos,2)
               push!(I, f)
               push!(J, infos[2,j])
               push!(V, infos[1,j])
           end
       end
       
       spboundary2 = sparse(I,J,V)
       return spboundary2
   end
   
   # Chain 3-complex construction
   function chaincomplex(W,FW,EW)
       V = convert(Array{Float64,2},W')
       EV = characteristicMatrix(EW)
       FE = boundary2(FW,EW)
       V,cscEV,cscFE,cscCF = LARLIB.spatial_arrangement(V,EV,FE)
       ne,nv = size(cscEV)
       nf = size(cscFE,1)
       nc = size(cscCF,1)
       EV = [findn(cscEV[e,:]) for e=1:ne]
       FV = [collect(Set(vcat([EV[e] for e in findn(cscFE[f,:])]...)))  for f=1:nf]
       CV = [collect(Set(vcat([FV[f] for f in findn(cscCF[c,:])]...)))  for c=2:nc]
       function ord(cells)
           return [sort(cell) for cell in cells]
       end
       temp = copy(cscEV')
       for k=1:size(temp,2)
           h = findn(temp[:,k])[1]
           temp[h,k] = -1
       end    
       cscEV = temp'
       bases, coboundaries = (ord(EV),ord(FV),ord(CV)), (cscEV,cscFE,cscCF)
       return V',bases,coboundaries
   end
   
   # Collect LAR models in a single LAR model
   function collection2model(collection)
      W,FW,EW = collection[1]
      shiftV = size(W,2)
      for k=2:length(collection)
         V,FV,EV = collection[k]
         W = [W V]
         FW = [FW; FV + shiftV]
         EW = [EW; EV + shiftV]
         shiftV = size(W,2)
      end
      return W,FW,EW
   end
   
   # Triangulation of a single facet
   function facetriangulation(V,FV,EV,cscFE,cscCF)
      function facetrias(f)
         vs = [V[:,v] for v in FV[f]]
         vs_indices = [v for v in FV[f]]
         vdict = Dict([(i,index) for (i,index) in enumerate(vs_indices)])
         dictv = Dict([(index,i) for (i,index) in enumerate(vs_indices)])
         es = findn(cscFE[f,:])
      
         vts = [v-vs[1] for v in vs]
      
         v1 = vts[2]
         v2 = vts[3]
         v3 = cross(v1,v2)
         err, i = 1e-8, 1
         while norm(v3) < err
            v2 = vts[3+i]
            i += 1
            v3 = cross(v1,v2)
         end   
      
         M = [v1 v2 v3]
   
         vs_2D = hcat([(inv(M)*v)[1:2] for v in vts]...)'
         pointdict = Dict([(vs_2D[k,:],k) for k=1:size(vs_2D,1)])
         edges = hcat([[dictv[v] for v in EV[e]]  for e in es]...)'
      
         trias = TRIANGLE.constrained_triangulation_vertices(
            vs_2D, collect(1:length(vs)), edges)
   
         triangles = [[pointdict[t[1,:]],pointdict[t[2,:]],pointdict[t[3,:]]] 
            for t in trias]
         mktriangles = [[vdict[t[1]],vdict[t[2]],vdict[t[3]]] for t in triangles]
         return mktriangles
      end
      return facetrias
   end
   
   # Triangulation of the 2-skeleton
   function triangulate(cf,V,FV,EV,cscFE,cscCF)
      mktriangles = LARLIB.facetriangulation(V,FV,EV,cscFE,cscCF)
      TV = Array{Int64,1}[]
      for (f,sign) in zip(cf[1],cf[2])
         triangles = mktriangles(f)
         if sign == 1
            append!(TV,triangles )
         elseif sign == -1
            append!(TV,[[t[2],t[1],t[3]] for t in triangles] )
         end
      end
      return TV
   end
   
   # Map 3-cells to local bases
   function map_3cells_to_localbases(V,CV,FV,EV,cscCF,cscFE)
      local3cells = []
      for c=1:length(CV)
         cf = findnz(cscCF[c+1,:])
         tv = LARLIB.triangulate(cf,V,FV,EV,cscFE,cscCF)
         vs = sort(collect(Set(hcat(tv...))))
         vsdict = Dict([(v,k) for (k,v) in enumerate(vs)])
         tvs = [[vsdict[t[1]],vsdict[t[2]],vsdict[t[3]]] for t in tv]
         v = hcat([V[:,w] for w in vs]...)
         cell = [v,tvs]
         append!(local3cells,[cell])
      end
      return local3cells
   end
   
   include("./utilities.jl")
   include("./minimal_cycles.jl")
   include("./dimension_travel.jl")
   include("./planar_arrangement.jl")
   include("./spatial_arrangement.jl")
   include("./largrid.jl")
   include("./mapper.jl")
   include("./struct.jl")
   
end
