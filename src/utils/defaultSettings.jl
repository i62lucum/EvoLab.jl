"""
    setDefaultAlgorithm(genj::GenJulia)

Set the evolutionary algorithm by default.
"""
function setDefaultAlgorithm(genj::GenJulia)
    genj._experimentInfo._algorithm = basicExperiment
    genj._experimentInfo._algorithmArgs = Array{Any}(undef, 0)
end # function



"""
    setDefaultStopCondition(genj::GenJulia)

Set 500 as the maximum number of iterations by default.
"""
function setDefaultStopCondition(genj::GenJulia)
    setStopCondition(genj = genj, maxEvaluations = typemax(Int64),
                     maxIterations = 500, maxIterNotImproving = typemax(Int64),
                     maxTime = Inf)
end # function



"""
    setDefaultSelector()

Set the default selection method and its arguments.
"""
function setDefaultSelector(genj::GenJulia)
    aux = getDefaultSelector()
    setSelector(aux[1], aux[2]..., nSelected=genj._generator._popSize, genj=genj)
end # function



"""
    setDefaultCrossoverOp(genj::GenJulia)

Set the default crossover method and arguments for the registered individual type
set by the user.
"""
function setDefaultCrossoverOp(genj::GenJulia)
    aux = getDefaultCrossoverOp(genj._experimentInfo._individualType)
    setCrossoverOperator(aux[1], aux[2]..., genj=genj)
end # function



"""
    setDefaultMutationOp(genj::GenJulia)

Set the default mutation method and arguments for the registered individual type
set by the user.
"""
function setDefaultMutationOp(genj::GenJulia)
    aux = getDefaultMutationOp(genj._experimentInfo._individualType)
    setMutationOperator(aux[1], aux[2]..., genj=genj)
end # function



"""
    setDefaultReplacementOp(genj::GenJulia)

Set the default replacement method and its arguments.
"""
function setDefaultReplacementOp(genj::GenJulia)
    aux = getDefaultReplacementOp()
    setReplacementOperator(aux[1], aux[2]..., genj=genj)
end # function



"""
    setDefaultReplacementOp(genj::GenJulia)

Set the default replacement method and its arguments.
"""
function setDefaultExperimentSummary(genj::GenJulia)
    setExperimentSummary(genj=genj)
end # function



"""
    fillCross()

!!! warning
    To be implemented
"""
function fillCross(genj::GenJulia)

    crossoverOp = genj._crossoverOp
    experimentInfo = genj._experimentInfo
    nParents = crossoverOp._nParents # Number of individual used per cross
    nChildren = crossoverOp._nChildren # Number of individual generated by cross
    nSelected = genj._selector._nSelectedParents # Number of selected individuals that are going to be cross

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

    # A method is created depending on the genotype, but with the same interface.
    if experimentInfo._individualType <: GPGenotype
        method = (selectedParents, rng) -> crossoverOp._method(selectedParents..., experimentInfo._GPExperimentInfo, rng, crossoverOp._varArgs...)
    else
        method = (selectedParents, rng) -> crossoverOp._method(selectedParents..., rng, crossoverOp._varArgs...)
    end

    CrossoverOperator(method, crossoverOp._probability, crossoverOp._nParents, crossoverOp._nChildren, crossoverOp._varArgs,
                     indexSelected, indexOff, crossIterations, sizeOffspring, crossoverOp._method)
    return nothing
end


"""
    setDefaultSettings(; genj::GenJulia = GenJ)

Set the default tools in case the user did not set them.
"""
function setDefaultSettings(; genj::GenJulia = GenJ, i::Integer=0)

    if !isdefined(genj._experimentInfo, :_algorithm)
        setDefaultAlgorithm(genj)
    end

    if !isdefined(genj, :_stopCondition)
        setDefaultStopCondition(genj)
    end

    if isdefined(genj._experimentInfo, :_individualType)
        if !isdefined(genj, :_crossoverOp)
            setDefaultCrossoverOp(genj)
        end

        if !isdefined(genj, :_mutationOp)
            setDefaultMutationOp(genj)
        end
    else
        if i == 0
            error("individualType is mandatory and must be set")
        else
            error("individualType is mandatory and must be set in experiment $i")
        end
    end

    if !isdefined(genj, :_selector)
        setDefaultSelector(genj)
    else
        if !(typeof(genj._selector._nSelectedParents) <: Integer)
            popSize = genj._generator._popSize
            nSelectedParents = genj._selector._nSelectedParents
            nParents = genj._crossoverOp._nParents

            nSelectedParents = convert(Integer, round(nSelectedParents * popSize))
            remainder = nSelectedParents % nParents

            if remainder != 0
                nSelectedParents = nSelectedParents + nParents - remainder
            end
            if !genj._selector._samplingWithRep
                if nSelectedParents > popSize
                    nSelectedParents -= nParents
                end
            end

            genj._selector = SelectionOperator(genj._selector._method, nSelectedParents,
                                               genj._selector._needsComparison,
                                               genj._selector._samplingWithRep,
                                               genj._selector._varArgs)
        end
    end

    #fillCross(genj)

    if !isdefined(genj, :_replacementOp)
        setDefaultReplacementOp(genj)
    end

    if !isdefined(genj._experimentInfo, :_experimentSummary)
        setDefaultExperimentSummary(genj)
    end
end # function
