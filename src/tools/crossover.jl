"
`CrossoverOperator` represents the method that crosses the parents selected to
create a new generation of individuals.

# Fields
- `_method::Function`: method used for crossover.
- `_probability::Float32`: the probability for a set of nParents to being cross.
- `_nParents::Int8`: number of parents used per cross.
- `_nChildren::Int8`: number of children generated by cross.
- `_varArgs::Array{Any}`: aditional arguments for method.

See also: [`setCrossoverOperator`](@ref)
"
struct CrossoverOperator
    _method::Function
    _probability::Float32
    _nParents::UInt8
    _nChildren::UInt8
    _varArgs::Array{Any}
end # struct



"""
    getMethod(crossoverOp::CrossoverOperator)::Function

Obtains the method associated to crossover.
"""
getMethod(crossoverOp::CrossoverOperator)::Function = crossoverOp._method
# function



"""
    getCrossProbability(crossoverOp::CrossoverOperator)::Float32

Obtains the probability for a set of individuals to be cross.
"""
getCrossProbability(crossoverOp::CrossoverOperator)::Float32 = crossoverOp._probability
# function



"""
    getNParents(crossoverOp::CrossoverOperator)::Int8

Obtains the number of parents per cross.
"""
getNParents(crossoverOp::CrossoverOperator)::UInt8 = crossoverOp._nParents
# function



"""
    getNChildren(crossoverOp::CrossoverOperator)::Int8

Obtains the number of children generated by the crossover method.
"""
getNChildren(crossoverOp::CrossoverOperator)::UInt8 = crossoverOp._nChildren
# function



"""
    getFunctionArgs(crossoverOp::CrossoverOperator)::Array

Obtains the aditional arguments associated to crossover method.
"""
getFunctionArgs(crossoverOp::CrossoverOperator)::Array = crossoverOp._varArgs
# function



"""
    getDefaultCrossover(individualType::DataType)

Returns a default crossover method for each registered individual type. For
all `GAGenotype`, it is [`uniformCross`](@ref),
for both `CGPGenotype` and `STGPGenotype` it is [`subtreeCross`](@ref) with a
probability of 0.2; for `GEPGenotype` it is [`kPointRecombinationCross`](@ref)
with one crosspoint.
"""
getDefaultCrossoverOp(individualType::Genotype) = nothing
# function






function cross_(crossoverOp::CrossoverOperator, selected::Array{Individual},
                experimentInfo::ExperimentInfo)::Array{Individual}

    rng = getRNG(experimentInfo) # Obtaining random number generator
    nParents = getNParents(crossoverOp) # Number of individual used per cross
    nChildren = getNChildren(crossoverOp) # Number of individual generated by cross
    nSelected = length(selected) # Number of selected individuals that are going to be cross

    # Calculates the total crossover operations.
    crossIterations = div(nSelected, nParents)
    # Offspring size is the number of children per cross multiplied by the number
    # of crossover operations.
    sizeOffspring = crossIterations * nChildren

    # Reserves memory for the offspring
    offspring = Array{Individual}(undef, sizeOffspring)

    # An array of ranges for offspring, accesing at iteration i of cross and i + 1,
    # we can access the array at the correct positions.
    # For example: suppose nChildren equals 3, the associated array is [0, 3, 6, ..., sizeOffspring].
    # In the first cross, offspring[indexOff[1]+1:indexOff[1+1]] -> offspring[1:3]
    indexOff = collect(0:nChildren:sizeOffspring)
    # An array of ranges for selected parents. See explication for indexOff above.
    indexSelected = collect(0:nParents:nSelected)

    # Obtains an array with the genotypes of selected individuals
    selectedRep = getGenotype(selected)

    # Type of genotype which determines the arguments that cross method receives
    genotypeType = getIndividualType(experimentInfo)

    crossMethod = getMethod(crossoverOp)
    functionArgs = getFunctionArgs(crossoverOp)

    # A method is created depending on the genotype, but with the same interface.
"""
    if genotypeType <: GPGenotype
        method = (selectedParents) -> crossMethod(selectedParents..., experimentInfo._GPExperimentInfo, rng, functionArgs...)
    else
        method = (selectedParents) -> crossMethod(selectedParents..., rng, functionArgs...)
    end
"""
    GP = genotypeType <: GPGenotype
    if GP
        gpExperimentInfo = experimentInfo._GPExperimentInfo
    end
    # If nChildren are equal to nParents, then the accesing indexes works as it is supposed to.
    if nChildren == nParents
        @inbounds for i=1:crossIterations
            if rand(rng) < crossoverOp._probability
                if GP
                    offspringRep = crossMethod(selectedRep[indexSelected[i]+1:indexSelected[i+1]]..., gpExperimentInfo, rng, functionArgs...)
                else
                    offspringRep = crossMethod(selectedRep[indexSelected[i]+1:indexSelected[i+1]]..., rng, functionArgs...)
                end
                #offspringRep = method(view(selectedRep, indexSelected[i]+1:indexSelected[i+1]))
                map!(x->Individual(x), view(offspring, indexOff[i]+1:indexOff[i+1]), offspringRep)
            else
                offspring[indexOff[i]+1:indexOff[i+1]] = selected[indexSelected[i]+1:indexSelected[i+1]]
            end
        end

    # If nChildren are less than nParents, for the case in which there is no
    # cross due to probability, the children will be equal to the nChildren
    # first parents of that cross.
    elseif nChildren < nParents
        @inbounds for i=1:crossIterations
            if rand(rng) < crossoverOp._probability
                if GP
                    offspringRep = crossMethod(selectedRep[indexSelected[i]+1:indexSelected[i+1]]..., gpExperimentInfo, rng, functionArgs...)
                else
                    offspringRep = crossMethod(selectedRep[indexSelected[i]+1:indexSelected[i+1]]..., rng, functionArgs...)
                end
                map!(x->Individual(x), view(offspring, indexOff[i]+1:indexOff[i+1]), offspringRep)
            else
                offspring[indexOff[i]+1:indexOff[i+1]] = selected[indexSelected[i]+1:indexSelected[i]+nChildren]
            end
        end
    # If nChildren is greater than nParents, an array with the crossed Parents
    # will be carried over through the iterations, for the case in which there is no
    # cross due to probability, we take the parents for that cross as children,
    # and for the rest, we do a sampling among the crossed parents.
    else
        rest =  nChildren-nParents
        selectedForCross = zeros(Bool, len)
        for i=1:crossIterations
            if rand(rng) < crossoverOp._probability
                selectedForCross[indexSelected[i]+1:indexSelected[i+1]] = ones(Bool,nParents)
                if GP
                    offspringRep = crossMethod(selectedRep[indexSelected[i]+1:indexSelected[i+1]]..., gpExperimentInfo, rng, functionArgs...)
                else
                    offspringRep = crossMethod(selectedRep[indexSelected[i]+1:indexSelected[i+1]]..., rng, functionArgs...)
                end
                map!(x->Individual(x), view(offspring, indexOff[i]+1:indexOff[i+1]), offspringRep)
            else
                offspring[indexOff[i]+1:indexOff[i]+nParents] = selected[indexSelected[i]+1:indexSelected[i+1]]
                crossedParents = view(selected, selectedForCross)
                if isempty(crossedParents)
                    map!(x -> selected[indexSelected[i]+x], view(offspring, indexOff[i]+nParents+1:indexOff[i+1]), rand(rng, 1:nParents, rest))
                else
                    map!(x -> crossedParents[x], view(offspring, indexOff[i]+nParents+1:indexOff[i+1]), rand(rng, 1:length(crossedParents), rest))
                end
            end
        end

    end

    return offspring
end # function

println("cross:",precompile(cross_,(CrossoverOperator, Vector{Individual}, ExperimentInfo)))
