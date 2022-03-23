# This implementation is based on the following article:
#
# LONG CHEN (2008). SHORT IMPLEMENTATION OF BISECTION IN MATLAB.
# In Recent Advances in Computational Sciences. WORLD SCIENTIFIC.
# DOI: 10.1142/9789812792389_0020


using SparseArrays
using Random
include("binarytree_core.jl")


_are_parallel(v, w) = v[1] * w[2] == v[2] * w[1]

function _print_forest(forest::AbstractArray{<:BinaryNode})
  num_leaves = 0
  for root_cell in forest
    print_tree(root_cell)
    num_leaves += length(collect(Leaves(root_cell)))
  end
  @show num_leaves
end

function _set_d_to_dface_to_old_node!(
  d_to_dface_to_oldid::AbstractArray{<:AbstractArray},
  d_to_dface_to_olddim::AbstractArray{<:AbstractArray},
  topo_ref::GridTopology,
  markers::AbstractArray{<:Integer},
)

  node_to_edge_ref = get_faces(topo_ref, 0, 1)
  num_nodes = length(node_to_edge_ref)
  push!(d_to_dface_to_oldid, Vector{}(undef, num_nodes))
  push!(d_to_dface_to_olddim, Vector{}(undef, num_nodes))
  for node_id = 1:num_nodes
    # Check if this node is in the marked list of edges. If so,
    # then it's index is the index of the edge that it is the midpoint
    # of.
    if (edge_index = findfirst(i -> i == node_id, markers)) != nothing
      d_to_dface_to_oldid[1][node_id] = edge_index
      d_to_dface_to_olddim[1][node_id] = 2
      # If not, it existed already so we take the id of the old node.
    else
      d_to_dface_to_oldid[1][node_id] = node_id
      d_to_dface_to_olddim[1][node_id] = 1
    end
  end
end

function _set_d_to_dface_to_old_edge!(
  d_to_dface_to_oldid::AbstractArray{<:AbstractArray},
  d_to_dface_to_olddim::AbstractArray{<:AbstractArray},
  forest::AbstractArray{<:BinaryNode},
  topo::GridTopology,
  topo_ref::GridTopology,
  vertices::AbstractArray{<:VectorValue},
)
  edge_to_node_ref = get_faces(topo_ref, 1, 0)
  num_edges = length(edge_to_node_ref)
  push!(d_to_dface_to_oldid, Vector{}(undef, num_edges))
  push!(d_to_dface_to_olddim, Vector{}(undef, num_edges))
  cell_to_node = get_faces(topo, 2, 0)
  cell_to_edge = get_faces(topo, 2, 1)
  edge_to_node = get_faces(topo, 1, 0)
  cell_to_edge_ref = get_faces(topo_ref, 2, 1)
  for root_cell in forest
    root_nodes = cell_to_node[root_cell.data]
    root_edges = cell_to_edge[root_cell.data]
    for leaf_cell in Leaves(root_cell)
      # Set because of possible repeats for new cells that are neighbors
      leaf_edges = Set(cell_to_edge_ref[leaf_cell.data])
      for leaf_edge in leaf_edges
        leaf_edge_nodes = edge_to_node_ref[leaf_edge]
        is_on_top_of_former_edge = false
        # Leaf_edge_nodes ∩  root_nodes != ∅ ⟹   must bisect
        if !isempty(intersect(leaf_edge_nodes, root_nodes))
          # We need to check if this edge is parallel to any of the
          # other edges in the old cell to see if it doesn't bisect
          for root_edge in root_edges
            root_edge_nodes = edge_to_node[root_edge]
            root_edge_vector = vertices[root_edge_nodes[2]] - vertices[root_edge_nodes[1]]
            leaf_edge_vector = vertices[leaf_edge_nodes[2]] - vertices[leaf_edge_nodes[1]]
            if _are_parallel(root_edge_vector, leaf_edge_vector)
              #println(
              #  "parent of edge $(edge_to_node_ref[leaf_edge]) is edge $(edge_to_node[root_edge])",
              #)
              d_to_dface_to_oldid[2][leaf_edge] = root_edge
              d_to_dface_to_olddim[2][leaf_edge] = 1
              is_on_top_of_former_edge = true
            end
          end
        end
        # Default case that this edge bisects an element
        if !is_on_top_of_former_edge
          #println(
          #  "parent of edge $(edge_to_node_ref[leaf_edge]) is cell $(cell_to_node[root_cell.data])",
          #)
          d_to_dface_to_oldid[2][leaf_edge] = root_cell.data
          d_to_dface_to_olddim[2][leaf_edge] = 2
        end
      end
    end
  end
end

function _set_d_to_dface_to_old_cell!(
  d_to_dface_to_oldid::AbstractArray{<:AbstractArray},
  d_to_dface_to_olddim::AbstractArray{<:AbstractArray},
  forest::AbstractArray{<:BinaryNode},
  topo_ref::GridTopology,
)
  cell_to_node_ref = get_faces(topo_ref, 2, 0)
  num_cells = length(cell_to_node_ref)
  push!(d_to_dface_to_oldid, Vector{}(undef, num_cells))
  push!(d_to_dface_to_olddim, Vector{}(undef, num_cells))
  # Can basically just use the forest. All new cells should point
  # to the root of their tree
  for root_cell in forest
    root_id = root_cell.data
    for leaf_cell in Leaves(root_cell)
      leaf_id = leaf_cell.data
      d_to_dface_to_oldid[3][leaf_id] = root_id
      d_to_dface_to_olddim[3][leaf_id] = 3
    end
  end
end

function _create_d_to_dface_to_old(
  forest::AbstractArray{<:BinaryNode},
  topo::GridTopology,
  topo_ref::GridTopology,
  vertices::AbstractArray{<:VectorValue},
  markers::AbstractArray{<:Integer},
)
  d_to_dface_to_oldid = Vector{Vector}()
  d_to_dface_to_olddim = Vector{Vector}()
  #_print_forest(forest)
  # The order is important here! node, edge, cell
  _set_d_to_dface_to_old_node!(d_to_dface_to_oldid, d_to_dface_to_olddim, topo_ref, markers)
  _set_d_to_dface_to_old_edge!(
    d_to_dface_to_oldid,
    d_to_dface_to_olddim,
    forest,
    topo,
    topo_ref,
    vertices,
  )
  _set_d_to_dface_to_old_cell!(d_to_dface_to_oldid, d_to_dface_to_olddim, forest, topo_ref)
  # HARDCODED FOR 2D
  d = 2
  for i = 1:d+1
    @test undef ∉ d_to_dface_to_oldid[i]
    @test undef ∉ d_to_dface_to_olddim[i]
    @test length(d_to_dface_to_olddim[i]) == length(d_to_dface_to_olddim[i])
    @show i
    @show d_to_dface_to_olddim[i]
    @show d_to_dface_to_oldid[i]
  end
  d_to_dface_to_olddim, d_to_dface_to_oldid
end

function _propogate_labeling!(model, d_to_dface_to_olddim, d_to_dface_to_oldid)
  labels = get_face_labeling(model)
  labels_ref = FaceLabeling(length.(d_to_dface_to_oldid))
  #@test length(labels.tag_to_entities) == length(labels.tag_to_name)
  for entity in labels.tag_to_entities
    push!(labels_ref.tag_to_entities, entity)
  end
  for name in labels.tag_to_name
    push!(labels_ref.tag_to_name, name)
  end
  @show labels_ref.tag_to_name
  @show labels_ref.tag_to_entities
  #for d = 0:(num_dims(model)-1)
  #  facet_ids = get_face_nodes(model, d)
  #  for (j, facet_id) in enumerate(facet_ids)
  #    cur_entity = labels.d_to_dface_to_entity[d+1][j]
  #    labels.d_to_dface_to_entity[d+1][j] = entity_id
  #  end
  #end
end

function _shift_to_first(v::AbstractVector{T}, i::T) where {T<:Integer}
  circshift(v, -(i - 1))
end

function _sort_longest_edge!(
  elem::AbstractVector{<:AbstractVector{T}},
  node::AbstractVector{<:VectorValue},
) where {T<:Integer}
  NT = length(elem)
  edgelength = zeros(NT, 3)
  for t = 1:NT
    elem_t = elem[t][:]
    for (j, e) in enumerate(elem_t)
      arr = filter(x -> x != e, elem_t)
      diff = norm(node[arr[1]] - node[arr[2]]) .^ 2
      edgelength[t, j] = diff
    end
  end
  max_indices = findmax(edgelength, dims = 2)[2]
  for t = 1:NT
    shifted = _shift_to_first(elem[t][:], T(max_indices[t][2]))
    elem[t] = shifted
    #for j = 1:3
    #  elem.data[elem.ptrs[t]+j-1] = shifted[j]
    #end
  end
end

function _setup_markers_and_nodes!(
  node::AbstractVector{<:VectorValue},
  elem::AbstractVector{<:AbstractVector{T}},
  d2p::SparseMatrixCSC{T,T},
  dualedge::SparseMatrixCSC{T},
  NE::T,
  η_arr::AbstractArray,
  θ::AbstractFloat,
) where {T<:Integer}
  #@show d2p
  total_η = sum(η_arr)
  partial_η = 0
  sorted_η_idxs = sortperm(-η_arr)
  markers = zeros(T, NE)
  # Loop over global triangle indices
  for t in sorted_η_idxs
    if (partial_η >= θ * total_η)
      break
    end
    need_to_mark = true
    # Get triangle index with next largest error
    #ct = sorted_η_idxs[t]
    while (need_to_mark)
      # Base point
      base = d2p[elem[t][2], elem[t][3]]
      # Already marked
      if markers[base] > 0
        need_to_mark = false
      else
        # Get the estimator contribution for the current triangle
        partial_η = partial_η + η_arr[t]
        # Increase the number of nodes to add new midpoint
        N = size(node, 1) + 1
        # The markers of the current elements is this node
        markers[d2p[elem[t][2], elem[t][3]]] = N
        # Coordinates of new node
        elem2 = elem[t][2]
        elem3 = elem[t][3]
        midpoint = _get_midpoint(node[[elem2, elem3], :])
        node = push!(node, midpoint)
        t = dualedge[elem[t][3], elem[t][2]]
        # There is no dual edge here, go to next triangle index
        if t == 0
          need_to_mark = false
        end
      end
    end
  end
  node, markers
end

function _divide!(elem::AbstractVector, t::T, p::AbstractVector{T}) where {T<:Integer}
  new_row = [p[4], p[3], p[1]]
  update_row = [p[4], p[1], p[2]]
  push!(elem, new_row)
  elem[t] = update_row
  #elem = append_tables_globally(elem, Table([new_row]))
  #for j = 1:3
  #  elem.data[elem.ptrs[t] - 1 + j] = update_row[j]
  #end
  #elem[t][:] = [p[4] p[1] p[2]]
  elem
end

function _bisect(
  d2p::SparseMatrixCSC{T,T},
  elem::AbstractVector,
  markers::AbstractVector{T},
  NT::T,
) where {T<:Integer}
  forest = Vector{BinaryNode}()
  #@show [node.data for node in Leaves(cell_to_cell_root)]
  for t in UnitRange{T}(1:NT)
    base = d2p[elem[t][2], elem[t][3]]
    if (markers[base] > 0)
      newnode = BinaryNode(t)
      p = vcat(elem[t][:], markers[base])
      elem = _divide!(elem, t, p)
      cur_size::T = size(elem, 1)
      l = leftchild(t, newnode)
      r = rightchild(cur_size, newnode)
      left = d2p[p[1], p[2]]
      right = d2p[p[3], p[1]]
      if (markers[right] > 0)
        leftchild(cur_size, r)
        rightchild(cur_size + 1, r)
        elem = _divide!(elem, cur_size, [p[4], p[3], p[1], markers[right]])
      end
      if (markers[left] > 0)
        leftchild(t, l)
        rightchild(cur_size + 1, l)
        elem = _divide!(elem, t, [p[4], p[1], p[2], markers[left]])
      end
      push!(forest, newnode)
    else
      push!(forest, BinaryNode(t))
    end
  end
  elem, forest
end

function _build_edges(elem::AbstractVector{<:AbstractVector{T}}) where {T<:Integer}
  edge = zeros(T, 3 * length(elem), 2)
  for t = 1:length(elem)
    off = 3 * (t - 1)
    edge[off+1, :] = [elem[t][1] elem[t][2]]
    edge[off+2, :] = [elem[t][1] elem[t][3]]
    edge[off+3, :] = [elem[t][2] elem[t][3]]
  end
  unique(sort!(edge, dims = 2), dims = 1)
end

function _build_directed_dualedge(
  elem::AbstractVector{<:AbstractVector{T}},
  N::T,
  NT::T,
) where {T<:Integer}
  dualedge = spzeros(T, N, N)
  for t = 1:NT
    dualedge[elem[t][1], elem[t][2]] = t
    dualedge[elem[t][2], elem[t][3]] = t
    dualedge[elem[t][3], elem[t][1]] = t
  end
  dualedge
end

function _dual_to_primal(edge::Matrix{T}, NE::T, N::T) where {T<:Integer}
  d2p = spzeros(T, T, N, N)
  for k = 1:NE
    i = edge[k, 1]
    j = edge[k, 2]
    d2p[i, j] = k
    d2p[j, i] = k
  end
  d2p
end

function _is_against_top(face::Table{<:Integer}, top::GridTopology, d::Integer)
  face_vec = sort.([face[i][:] for i = 1:size(face, 1)])
  face_top = sort.(get_faces(top, d, 0))
  issetequal_bitvec = issetequal(face_vec, face_top)
  all(issetequal_bitvec)
end

function _is_against_top(face::Matrix{<:Integer}, top::GridTopology, d::Integer)
  face_vec = sort.([face[i, :] for i = 1:size(face, 1)])
  face_top = sort.(get_faces(top, d, 0))
  issetequal_bitvec = issetequal(face_vec, face_top)
  all(issetequal_bitvec)
end

_get_midpoint(ngon::AbstractArray{<:VectorValue}) = sum(ngon) / length(ngon)

function _sort_ccw(cell_coords::AbstractVector{<:VectorValue})
  midpoint = _get_midpoint(cell_coords)
  offset_coords = cell_coords .- midpoint
  sortperm(offset_coords, by = v -> atan(v[2], v[1]))
end

function _sort_cell_node_ids_ccw!(
  cell_node_ids::AbstractVector{<:AbstractVector{T}},
  node_coords::AbstractVector{<:VectorValue},
) where {T<:Integer}
  #cell_node_ids_ccw = vcat(cell_node_ids'...)
  #@show cell_node_ids_ccw
  for (i, cell) in enumerate(cell_node_ids)
    cell_coords = node_coords[cell]
    perm = _sort_ccw(cell_coords)
    cell_node_ids[i] = cell[perm]
    #permed = cell[perm]
    #for j = 1:3
    #  cell_node_ids.data[cell_node_ids.ptrs[i]+j-1] = permed[j]
    #end
  end
end

"""
Lowest level interface to the newest vertex bisection algorithm. This step
takes places after unpacking the Grid. It also uses the `should_sort` to
determine if an initial sorting by the longest edge (for nonuniform meshes) is
necessary.

`node_coords, cell_node_ids -> node_coords, cell_node_ids`

# Arguments

 -`node_coords::AbstractVector{<:VectorValue}`: The vector of d-dimensional
 nodal coordinates stored as `VectorValue`s

 -`cell_node_ids::AbstractVector{<:AbstractVector{T}}`: Contains the elements
 as ordered tuples of nodal indices.

 -`η_arr::AbstractArray`: The values of the estimator on each cell of the domain

 -`θ::AbstractArray`: Dörfler marking parameter: 0 = no refinement,
   1=uniform refinement.

"""
function newest_vertex_bisection(
  node_coords::AbstractVector{<:VectorValue},
  cell_node_ids::AbstractVector{<:AbstractVector{T}},
  η_arr::AbstractArray,
  θ::AbstractFloat,
) where {T<:Integer}
  # Number of nodes
  N::T = size(node_coords, 1)
  elem = cell_node_ids
  # Number of cells (triangles in 2D)
  NT::T = size(elem, 1)
  @assert length(η_arr) == NT
  edge = _build_edges(elem)
  NE::T = size(edge, 1)
  dualedge = _build_directed_dualedge(elem, N, NT)
  d2p = _dual_to_primal(edge, NE, N)
  node_coords, markers =
    _setup_markers_and_nodes!(node_coords, elem, d2p, dualedge, NE, η_arr, θ)
  #@show marker
  # TODO: figure out why this constructor is necessary
  elem = Vector{Vector}(elem)
  cell_node_ids, forest = _bisect(d2p, elem, markers, NT)
  node_coords, cell_node_ids, forest, markers
end

"""
Middle level interface to the newest vertex bisection algorithm. This step
takes places after unpacking the DiscreteModel and performs sorting if
necessary. It maps

`Grid -> Grid, buffer`

# Arguments

 -`grid::Grid`: The current Grid.

 -`η_arr::AbstractArray`: The values of the estimator on each cell of the domain

 -`θ::AbstractArray`: Dörfler marking parameter: 0 = no refinement,
   1=uniform refinement.

"""
function newest_vertex_bisection(grid::Grid, η_arr::AbstractArray, θ::AbstractFloat)
  node_coords = get_node_coordinates(grid)
  # Need "un lazy" version for resize!
  node_coords = [v for v in node_coords]
  #@show cell_node_ids = get_cell_node_ids(grid)
  cell_node_ids = get_cell_node_ids(grid)
  # Convert from Table to Vector{Vector}
  cell_node_ids = [v for v in cell_node_ids]
  # Should always sort on the first iteration
  _sort_cell_node_ids_ccw!(cell_node_ids, node_coords)
  _sort_longest_edge!(cell_node_ids, node_coords)
  node_coords_ref, cell_node_ids_unsort, forest, markers =
    newest_vertex_bisection(node_coords, cell_node_ids, η_arr, θ)
  reffes = get_reffes(grid)
  cell_types = get_cell_type(grid)
  # I need to do this because I can't append! to LazyVector
  cell_types = [c for c in cell_types]
  # TODO : Gracefully handle cell_types?
  new_cell_types = fill(1, length(cell_node_ids_unsort) - length(cell_node_ids))
  append!(cell_types, new_cell_types)
  cell_node_ids_ref = Table([c for c in cell_node_ids_unsort])
  buffer = (; cell_node_ids_ref, node_coords_ref, cell_types, reffes)
  # TODO: IMPORTANT: This appears to be necessary when instatianting the RT space
  sort!.(cell_node_ids_unsort)
  cell_node_ids_ref = Table([c for c in cell_node_ids_unsort])
  grid_ref = UnstructuredGrid(node_coords_ref, cell_node_ids_ref, reffes, cell_types)
  grid_ref, buffer, forest, markers
end

"""
The newest vertex bisection algorithm provides a method of local refinement
without creating hanging nodes. For now, only 2D simplicial meshes are
supported.

This is the highest level version of the function, it maps

`DiscreteModel -> DiscreteModel, buffer`


# Arguments

 -`model::DiscreteModel`: The current DiscreteModel to be refined.

 -`η_arr::AbstractArray`: The values of the estimator on each cell of the domain
 i.e. one should have `length(η_arr) == num_cells(model)`

 -`θ::AbstractArray=1.0`: Dörfler marking parameter: 0 = no refinement,
   1=uniform refinement.

"""
function newest_vertex_bisection(
  model::DiscreteModel,
  η_arr::AbstractArray;
  θ = 1.0, # corresponds to uniform refinement
)
  @assert length(η_arr) == num_cells(model)
  # Not sure if necessary to keep old model unchanged. For my tests I use this
  grid = get_grid(model)
  topo = GridTopology(grid)
  grid_ref, buffer, forest, markers = newest_vertex_bisection(grid, η_arr, θ)
  topo_ref = GridTopology(grid_ref)
  d_to_dface_to_olddim, d_to_dface_to_oldid = _create_d_to_dface_to_old(
    forest,
    topo,
    topo_ref,
    get_node_coordinates(grid_ref),
    markers,
  )
  labels_ref = _propogate_labeling!(model, d_to_dface_to_olddim, d_to_dface_to_oldid)
  @show labels_ref
  #ref_labels = # Compute them from the original labels (This is perhaps the most tedious part)
  ref_labels = FaceLabeling(topo_ref)
  DiscreteModel(grid_ref, topo_ref, ref_labels), buffer
end

"""
Middle level interface to the newest vertex bisection algorithm. This step
takes places after unpacking the DiscreteModel and performs sorting if
necessary. It maps

`buffer -> Grid, buffer`

# Arguments

 -`buffer::NamedTuple`: The buffer providing all the itermediate information
 between refinements. This is used in lieu of the the Grid from the previous
 step for now.

 -`η_arr::AbstractArray`: The values of the estimator on each cell of the domain

 -`θ::AbstractArray`: Dörfler marking parameter: 0 = no refinement,
   1=uniform refinement.

"""
function newest_vertex_bisection(buffer::NamedTuple, η_arr::AbstractArray, θ::AbstractFloat)
  node_coords = buffer.node_coords_ref
  #@show cell_node_ids = buffer.cell_node_ids_ref
  cell_node_ids = buffer.cell_node_ids_ref
  node_coords_ref, cell_node_ids_unsort, forest, markers =
    newest_vertex_bisection(node_coords, cell_node_ids, η_arr, θ)
  reffes = buffer.reffes
  cell_types = buffer.cell_types
  # TODO : Gracefully handle cell_types?
  new_cell_types = fill(1, length(cell_node_ids_unsort) - length(cell_node_ids))
  append!(cell_types, new_cell_types)
  cell_node_ids_ref = Table([c for c in cell_node_ids_unsort])
  buffer = (; cell_node_ids_ref, node_coords_ref, cell_types, reffes)
  # TODO: IMPORTANT: This appears to be necessary when instatianting the RT space
  sort!.(cell_node_ids_unsort)
  cell_node_ids_ref = Table([c for c in cell_node_ids_unsort])
  grid_ref = UnstructuredGrid(node_coords_ref, cell_node_ids_ref, reffes, cell_types)
  grid_ref, buffer, forest, markers
end


"""
The newest vertex bisection algorithm provides a method of local refinement
without creating hanging nodes. For now, only 2D simplicial meshes are
supported.

This is the highest level version of the function, it maps

`DiscreteModel, buffer -> DiscreteModel, buffer`


# Arguments

 -`model::DiscreteModel`: The current DiscreteModel to be refined.

 -`buffer::NamedTuple`: The buffer providing all the itermediate information
 between refinements

 -`η_arr::AbstractArray`: The values of the estimator on each cell of the domain
 i.e. one should have `length(η_arr) == num_cells(model)`

 -`θ::AbstractArray=1.0`: Dörfler marking parameter: 0 = no refinement,
   1=uniform refinement.

"""
function newest_vertex_bisection(
  model::DiscreteModel,
  buffer::NamedTuple,
  η_arr::AbstractArray;
  θ = 1.0, # corresponds to uniform refinement
)
  @assert length(η_arr) == num_cells(model)
  grid = get_grid(model)
  topo = GridTopology(grid)
  # Not sure if necessary to keep old model unchanged. For my tests I use this
  grid_ref, buffer, forest, markers = newest_vertex_bisection(buffer, η_arr, θ)
  topo_ref = GridTopology(grid_ref)
  _create_d_to_dface_to_old(forest, topo, topo_ref, get_node_coordinates(grid_ref), markers)
  #ref_labels = # Compute them from the original labels (This is perhaps the most tedious part)
  ref_labels = FaceLabeling(topo_ref)
  model_ref = DiscreteModel(grid_ref, topo_ref, ref_labels)
  model_ref, buffer
end