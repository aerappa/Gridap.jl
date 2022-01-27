module RefinedDiscreteModelsTests

using Test
using Random
using Gridap.Arrays
using Gridap.Fields
using Gridap.ReferenceFEs
using Gridap.Geometry
using Gridap.Geometry: ConstantEst, RandomEst
using Gridap.Geometry: build_refined_models
using Gridap.Visualization
#using TimerOutputs

domain = (0, 1, 0, 1)
partition = (1, 1) # Initial partition
Nsteps = 12
est = ConstantEst(1.0)
θ = 1.0
uniform_write_to_vtk = false
# Uniform refinement
model_refs = build_refined_models(domain, partition, Nsteps, θ, est)
for (n, model_ref) =  enumerate(model_refs)
  trian_ref = get_triangulation(model_ref)
  if uniform_write_to_vtk
    writevtk(trian_ref, "uniform$(n)")
  end
  cell_map = get_cell_map(trian_ref)
  node_coords = get_node_coordinates(trian_ref)
  ncoords = length(node_coords)
  # Combinatorial checks for nodes
  if isodd(n)
    ncoords_true = Integer.(2 * (4^((n-1)/2) + 2^((n-1)/2)) + 1)
  else
   ncoords_true = Integer.(2^(n/2) + 1)^2
  end
  ncells = length(cell_map)
  @test ncoords_true == ncoords
  # Combinatorial checks for cells 
  @test ncells == 2^(n + 1)
end
# Nonuniform refinement. For now only visually checking conformity
domain = (0, 1, 0, 1)
partition = (1, 1) # Initial partition
seed = 5
est = RandomEst(seed)
θ = 0.4
nonuniform_write_to_vtk = true
model_refs = build_refined_models(domain, partition, Nsteps, θ, est)
if nonuniform_write_to_vtk
  for (n, model_ref) =  enumerate(model_refs)
    trian_ref = get_triangulation(model_ref)
    writevtk(trian_ref, "nonuniform$(n)")
  end
end

end
